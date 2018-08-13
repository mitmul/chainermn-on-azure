#!/usr/bin/env python
"""Example code of learning a large scale convnet from ILSVRC2012 dataset.

Prerequisite: To run this example, crop the center of ILSVRC2012 training and
validation images, scale them to 256x256 and convert them to RGB, and make
two lists of space-separated CSV whose first column is full path to image and
second column is zero-origin label (this format is same as that used by Caffe's
ImageDataLayer).

"""
from __future__ import print_function

import argparse
import ctypes
import json
import multiprocessing
import os
import random

import chainermn
import cv2 as cv
import numpy as np

import chainer
from chainer import dataset
from chainer import training
from chainer.backends import cuda
from chainer.configuration import config
from chainer.dataset import convert
import chainer.links as L
from chainer.training import extensions
from chainercv import transforms
import resnet50_fp16


def _pair(x):
    if hasattr(x, '__getitem__'):
        return x
    return x, x


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
    parser.add_argument('--batchsize', '-B', type=int, default=32,
                        help='Learning minibatch size')
    parser.add_argument('--epoch', '-E', type=int, default=10,
                        help='Number of epochs to train')
    parser.add_argument('--initmodel',
                        help='Initialize the model from given file')
    parser.add_argument('--loaderjob', '-j', type=int, default=24,
                        help='Number of parallel data loading processes')
    parser.add_argument('--mean', '-m', default='mean.npy',
                        help='Mean file (computed by compute_mean.py)')
    parser.add_argument('--resume', '-r', default='',
                        help='Initialize the trainer from given file')
    parser.add_argument('--out', '-o', default='result',
                        help='Output directory')
    parser.add_argument('--root_train', default='.',
                        help='Root directory path of training image files')
    parser.add_argument('--root_val', default='.',
                        help='Root directory path of validation image files')
    parser.add_argument('--val_batchsize', '-b', type=int, default=250,
                        help='Validation minibatch size')
    parser.add_argument('--test', action='store_true')
    parser.set_defaults(test=False)
    parser.add_argument('--dali', action='store_true')
    parser.set_defaults(dali=False)
    parser.add_argument('--communicator', default='non_cuda_aware')
    args = parser.parse_args()

    #
    # ChainerMN initialization
    #
    comm = chainermn.create_communicator(args.communicator)
    device = comm.intra_rank

    chainer.cuda.get_device(device).use()
    chainer.cuda.set_max_workspace_size(1048 * 1024 * 1024)
    config.use_cudnn_tensor_core = 'auto'
    config.autotune = True
    config.cudnn_fast_batch_normalization = True

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
    model = L.Classifier(resnet50_fp16.ResNet50_fp16())
    model.to_gpu()
    if comm.rank == 0:
        print('Model prepared: ResNet50_fp16')

    # Load the dataset files
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

    # These iterators load the images with subprocesses running in parallel
    # to the training/validation.
    multiprocessing.set_start_method('forkserver')
    train_iter = chainer.iterators.MultiprocessIterator(
        train, args.batchsize, n_processes=args.loaderjob)
    val_iter = chainer.iterators.MultiprocessIterator(
        val, args.batchsize, repeat=False, n_processes=args.loaderjob)
    # converter = dataset.concat_examples
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
        json.dump(info, open(os.path.join(result_directory, 'info.json'), 'w'))

    weight_decay = 0.0001
    optimizer = chainer.optimizers.MomentumSGD(lr=lr, momentum=0.9)
    optimizer.setup(model)
    optimizer.use_fp32_update()
    optimizer.add_hook(chainer.optimizer.WeightDecay(weight_decay))
    optimizer = chainermn.create_multi_node_optimizer(optimizer, comm)

    # Set up a trainer
    updater = training.StandardUpdater(
        train_iter, optimizer, device=device, converter=converter,
        loss_scale=128)

    if args.test:
        log_interval = (10, 'iteration')
        train_length = (210, 'iteration')
    else:
        log_interval = (10, 'iteration')
        train_length = (90, 'epoch')

    trainer = training.Trainer(updater, train_length, result_directory)

    # trainer.extend(extensions.Evaluator(
    #     val_iter, model, converter=converter,
    #     device=device), trigger=val_interval)
    # trainer.extend(extensions.dump_graph('main/loss'))
    # trainer.extend(extensions.snapshot(), trigger=val_interval)
    # trainer.extend(extensions.snapshot_object(
    #     model, 'model_iter_{.updater.iteration}'), trigger=val_interval)

    # Be careful to pass the interval directly to LogReport
    # (it determines when to emit log rather than when to read observations)
    if comm.rank == 0:
        trainer.extend(extensions.LogReport(trigger=log_interval))
        # trainer.extend(extensions.PrintReport([
        #     'epoch', 'iteration', 'main/loss', 'validation/main/loss',
        #     'main/accuracy', 'validation/main/accuracy', 'elapsed_time'
        # ]), trigger=log_interval)
        trainer.extend(extensions.ProgressBar(update_interval=10))

    if args.resume:
        chainer.serializers.load_npz(args.resume, trainer)

    trainer.run()


if __name__ == '__main__':
    main()
