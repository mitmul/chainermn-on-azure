#!/bin/bash

python train_for_tune.py train_cls_random.txt val_random.txt \
--root_train /mnt/ILSVRC/Data/CLS-LOC/train \
--root_val /mnt/ILSVRC//Data/CLS-LOC/val \
--batchsize 32 --communicator non_cuda_aware --out result
