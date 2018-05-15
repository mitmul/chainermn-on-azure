#!/bin/bash -xe

mpirun -n 128 -ppn 4 \
-f /share/home/hpcuser/hosts.txt -envall \
python train_imagenet_check.py \
train_cls_random.txt val_random.txt \
--root_train /mnt/ILSVRC/Data/CLS-LOC/train \
--root_val /mnt/ILSVRC//Data/CLS-LOC/val \
--batchsize 32 \
--communicator non_cuda_aware \
--out result/scaleout_128
