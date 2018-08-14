#!/bin/bash

python train_imagenet_fp16.py \
train_cls_random.txt \
val_random.txt \
--root_train /imagenet1k/ILSVRC/Data/CLS-LOC/train \
--root_val /imagenet1k/ILSVRC//Data/CLS-LOC/val \
--batchsize 32 \
--communicator non_cuda_aware \
--test

