from __future__ import print_function

import argparse
import json
import multiprocessing
import os
import random

import chainermn
import cv2 as cv
import numpy as np

import chainer
from chainer import training
import chainer.cuda
import chainer.links as L
from chainer.training import extensions
from chainer.dataset import convert
from chainercv import transforms
import resnet50

os.environ["CHAINER_TYPE_CHECK"] = "0"


class PreprocessedDataset(chainer.dataset.DatasetMixin):

    def __init__(self, path, root, crop_size, random=True):
        self.base = chainer.datasets.LabeledImageDataset(path, root)
        self.mean = np.array(
            [123.152, 115.903, 103.063], dtype=np.float32)  # RGB
        self.mean = self.mean[:, None, None]
        self.crop_size = crop_size
        self.random = random

    def __len__(self):
        return len(self.base)

    def get_example(self, i):
        # It reads the i-th image/label pair and return a preprocessed image.
        # It applies following preprocesses:
        #     - Cropping (random or center rectangular)
        #     - Random flip
        #     - Scaling to [0, 1] value
        crop_size = self.crop_size

        path, int_label = self.base._pairs[i]
        full_path = os.path.join(self.base._root, path)

        image = cv.imread(full_path).astype(self.base._dtype)
        image = image[:, :, ::-1].transpose(2, 0, 1)  # to RGB

        if image.shape[1] < crop_size or image.shape[2] < crop_size:
            image = transforms.scale(image, crop_size)

        label = np.array(int_label, dtype=self.base._label_dtype)

        _, h, w = image.shape

        if self.random:
            # Randomly crop a region and flip the image
            top = random.randint(0, h - crop_size - 1) if h > crop_size else 0
            left = random.randint(0, w - crop_size - 1) if w > crop_size else 0
            if random.randint(0, 1):
                image = image[:, :, ::-1]
        else:
            # Crop the center
            top = (h - crop_size) // 2
            left = (w - crop_size) // 2
        bottom = top + crop_size
        right = left + crop_size

        image = image[:, top:bottom, left:right]
        image -= self.mean
        image *= (1.0 / 255.0)  # Scale to [0, 1]
        return image, label


def main():
    parser = argparse.ArgumentParser(
        description='Learning convnet from ILSVRC2012 dataset')
    parser.add_argument('train', help='Path to training image-label list file')
    parser.add_argument('val', help='Path to validation image-label list file')
    parser.add_argument('--root_train', default='.',
                        help='Root directory path of training image files')
    parser.add_argument('--root_val', default='.',
                        help='Root directory path of validation image files')
    parser.add_argument('--batchsize', '-B', type=int, default=32,
                        help='Learning minibatch size')
    parser.add_argument('--loaderjob', '-j', type=int,
                        help='Number of parallel data loading processes')
    parser.add_argument('--out', '-o', default='result',
                        help='Output directory')
    parser.add_argument('--communicator', default='non_cuda_aware')
    parser.add_argument('--test', action='store_true', default=False)
    args = parser.parse_args()

    #
    # ChainerMN initialization
    #
    comm = chainermn.create_communicator(args.communicator)
    device = comm.intra_rank
    print('device:', device)
    chainer.cuda.get_device(device).use()
    chainer.cuda.set_max_workspace_size(1048 * 1024 * 1024)
    chainer.config.use_cudnn_tensor_core = 'auto'
    chainer.config.autotune = True
    chainer.config.cudnn_fast_batch_normalization = True
    if comm.rank == 0:
        print('Initialized')

    #
    # Logging
    #
    if comm.rank == 0:
        result_directory = args.out
    else:
        import tempfile
        result_directory = tempfile.mkdtemp(dir='/tmp/')

    #
    # Model
    #
    model = L.Classifier(resnet50.ResNet50())
    model.to_gpu()
    if comm.rank == 0:
        print('Model prepared')

    #
    # Dataset
    #
    if comm.rank == 0:
        train = PreprocessedDataset(
            args.train, args.root_train, model.predictor.insize)
        val = PreprocessedDataset(
            args.val, args.root_val, model.predictor.insize, False)
    else:
        train = None
        val = None
    train = chainermn.scatter_dataset(train, comm)
    val = chainermn.scatter_dataset(val, comm)

    multiprocessing.set_start_method('forkserver')
    train_iter = chainer.iterators.MultiprocessIterator(
        train, args.batchsize, n_processes=args.loaderjob)
    val_iter = chainer.iterators.MultiprocessIterator(
        val, args.batchsize, repeat=False, n_processes=args.loaderjob)
    converter = convert.ConcatWithAsyncTransfer()

    #
    # Optimizer
    #
    global_batchsize = comm.size * args.batchsize
    lr = 0.1 * global_batchsize / 256
    if comm.rank == 0:
        print('global_batchsize:', global_batchsize)
        print('Num of GPUs:', comm.size)
        info = {
            'local_batchsize': args.batchsize,
            'global_batchsize': global_batchsize,
            'n_gpus': comm.size,
            'lr': lr
        }
        json.dump(info, open(os.path.join(args.out, 'info.json'), 'w'))

    weight_decay = 0.0001
    optimizer = chainer.optimizers.MomentumSGD(lr=lr, momentum=0.9)
    optimizer = chainermn.create_multi_node_optimizer(optimizer, comm)
    optimizer.setup(model)
    optimizer.add_hook(chainer.optimizer.WeightDecay(weight_decay))

    #
    # Trainer
    #
    if args.test:
        log_interval = (10, 'iteration')
        train_length = (210, 'iteration')
    else:
        log_interval = (10, 'iteration')
        val_interval = (1, 'epoch')
        train_length = (90, 'epoch')

    updater = training.StandardUpdater(train_iter, optimizer, converter=converter, device=device)
    trainer = training.Trainer(updater, train_length, result_directory)

    if not args.test:
        evaluator = extensions.Evaluator(val_iter, model, converter=converter, device=device)
        evaluator = chainermn.create_multi_node_evaluator(evaluator, comm)
        trainer.extend(evaluator, trigger=val_interval, name='val')

    if not args.test:
        trainer.extend(
            trigger=(30, 'epoch'),
            extension=extensions.ExponentialShift('lr', 0.1, optimizer=optimizer))

    log_report_ext = extensions.LogReport(trigger=log_interval)
    trainer.extend(log_report_ext)

    if comm.rank == 0:
        trainer.extend(extensions.ProgressBar(update_interval=10))
        trainer.extend(extensions.observe_lr(), trigger=log_interval)
        trainer.extend(extensions.PrintReport([
            'elapsed_time', 'epoch', 'main/loss', 'val/main/loss',
            'main/accuracy', 'val/main/accuracy', 'lr'
        ]), trigger=log_interval)
        trainer.extend(extensions.snapshot_object(
            model, 'snapshot_{.updater.epoch}'), trigger=(10, 'epoch'))

    trainer.run()


if __name__ == '__main__':
    main()

