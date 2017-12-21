from __future__ import print_function

import argparse
import collections
import datetime
import glob
import json
import multiprocessing
import os
import sys

import chainer
from chainer import training
import chainer.cuda
from chainer.training import extensions
import chainermn
import dataset
import resnet50

os.environ["CHAINER_TYPE_CHECK"] = "0"


archs = {
    'resnet50': resnet50.ResNet50,
}


def main():
    info = collections.OrderedDict()

    parser = argparse.ArgumentParser(
        description='Learning convnet from ILSVRC2012 dataset')
    parser.add_argument('train', help='Path to training image-label list file')
    parser.add_argument('val', help='Path to validation image-label list file')
    parser.add_argument('--root_train', default='.',
                        help='Root directory path of training image files')
    parser.add_argument('--root_val', default='.',
                        help='Root directory path of validation image files')

    parser.add_argument('--arch', '-a', choices=archs.keys(), default='resnet50',
                        help='Convnet architecture')
    parser.add_argument('--batchsize', '-B', type=int, default=32,
                        help='Learning minibatch size')
    parser.add_argument('--epoch', '-E', type=int, default=100,
                        help='Number of epochs to train')
    parser.add_argument('--loaderjob', '-j', type=int,
                        help='Number of parallel data loading processes')
    parser.add_argument('--resume', '-r', default='',
                        help='Initialize the trainer from given file')
    parser.add_argument('--initmodel',
                        help='Initialize the model from given file')
    parser.add_argument('--out', '-o', default='result',
                        help='Output directory')
    parser.add_argument('--dryrun', action='store_true')
    parser.add_argument('--communicator', default='non_cuda_aware')
    parser.add_argument('--tag', dest='tag', action='store', type=str,
                        help='Explanation of this execution')
    parser.add_argument('--lr', default=None, type=float)
    parser.set_defaults(test=False)
    args = parser.parse_args()

    info['run'] = {
        'program': sys.argv[0],
        'argv': sys.argv,
        'hostname': os.uname().nodename,
        'pid': os.getpid(),
        'start_datetime': '{:%Y-%m-%d %H:%M:%S}'.format(datetime.datetime.now())
    }

    #
    # ChainerMN initialization
    #
    comm = chainermn.create_communicator(args.communicator)
    device = comm.intra_rank
    info['chainermn'] = {
        'communicator': args.communicator,
        'size': comm.size,
        'inter_size': comm.inter_size,
        'intra_size': comm.intra_size,
    }
    chainer.cuda.get_device(device).use()
    chainer.cuda.set_max_workspace_size(1 * 1024 * 1024 * 1024)

    #
    # Logging
    #
    if comm.rank == 0:
        if args.dryrun:
            result_directory = os.path.join(args.out, 'dryrun')
        else:
            result_directory = args.out
        result_directory = os.path.join(
            result_directory, "{:0>3}-{:%m%d-%H%M}".format(
                len(glob.glob(os.path.join(result_directory, '*'))),
                datetime.datetime.now()))
        if args.tag:
            result_directory += '-' + args.tag
        os.makedirs(result_directory)
    else:
        import tempfile
        result_directory = tempfile.mkdtemp(dir='/tmp/')

    #
    # Model
    #
    model = archs[args.arch]()
    if args.initmodel:
        print('Load model from', args.initmodel)
        chainer.serializers.load_npz(args.initmodel, model)
    if comm.rank == 0:
        chainer.serializers.save_npz(os.path.join(
            result_directory, 'init_{}.npz'.format(args.arch)), model)

    model.to_gpu()
    info['model'] = {
        'arch': args.arch,
        'initmodel': args.initmodel,
    }

    #
    # Dataset
    #
    if comm.rank == 0:
        train = dataset.PreprocessedDataset(
            args.train, args.root_train, model.insize)
        val = dataset.PreprocessedDataset(
            args.val, args.root_val, model.insize, False)
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

    #
    # Optimizer
    #
    global_batchsize = comm.size * args.batchsize
    if args.lr:
        lr = args.lr
    else:
        lr = 0.1 * global_batchsize / 256
        # lr = 0.1 * global_batchsize / 512
    if comm.rank == 0:
        print('global_batchsize:', global_batchsize)
        print('Num of GPUs:', comm.size)

    weight_decay = 0.0001
    optimizer = chainer.optimizers.MomentumSGD(lr=lr, momentum=0.9)
    optimizer = chainermn.create_multi_node_optimizer(optimizer, comm)
    optimizer.setup(model)
    optimizer.add_hook(chainer.optimizer.WeightDecay(weight_decay))
    info['training'] = {
        'local_batchsize': args.batchsize,
        'global_batchsize': global_batchsize,
        'lr': lr
    }

    #
    # Trainer
    #
    val_interval = (10, 'iteration') if args.dryrun else (1, 'epoch')
    log_interval = (10, 'iteration') if args.dryrun else (1, 'epoch')

    updater = training.StandardUpdater(train_iter, optimizer, device=device)
    stop_trigger = (20, 'iteration') if args.dryrun else (args.epoch, 'epoch')
    trainer = training.Trainer(updater, stop_trigger, result_directory)

    evaluator = extensions.Evaluator(val_iter, model, device=device)
    evaluator = chainermn.create_multi_node_evaluator(evaluator, comm)
    trainer.extend(evaluator, trigger=val_interval, name='val')

    trainer.extend(
        trigger=(30, 'epoch'),
        extension=extensions.ExponentialShift('lr', 0.1, optimizer=optimizer))

    log_report_ext = extensions.LogReport(trigger=log_interval)
    trainer.extend(log_report_ext)

    if comm.rank == 0:
        trainer.extend(extensions.dump_graph('main/loss'))
        trainer.extend(extensions.observe_lr(), trigger=log_interval)
        trainer.extend(extensions.PrintReport([
            'elapsed_time', 'epoch', 'main/loss', 'val/main/loss',
            'main/accuracy', 'val/main/accuracy', 'lr'
        ]), trigger=log_interval)
        trainer.extend(extensions.ProgressBar(update_interval=10))
        trainer.extend(extensions.PlotReport(
            ['main/loss', 'val/main/loss'],
            'epoch', file_name='loss.png'))
        trainer.extend(extensions.PlotReport(
            ['main/accuracy', 'val/main/accuracy'],
            'epoch', file_name='accuracy.png'))
        # trainer.extend(extensions.snapshot_object(
        #     model, 'snapshot_{.updater.epoch}'), trigger=(10, 'epoch'))

    if args.resume:
        chainer.serializers.load_npz(args.resume, trainer)

    trainer.run()

    #
    # Storing the result
    #
    if comm.rank == 0:
        info['trainer'] = log_report_ext.log
        with open(os.path.join(result_directory, 'log.json'), 'w') as f:
            json.dump(info, f, indent=2, default=str)
        chainer.serializers.save_npz(os.path.join(
            result_directory, '{}.npz'.format(args.arch)), model)


if __name__ == '__main__':
    main()
