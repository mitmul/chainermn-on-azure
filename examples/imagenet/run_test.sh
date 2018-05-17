#!/bin/bash -xe

if [ ! -d result/scaleout_$1 ]; then
    mkdir result/scaleout_$1
fi

mpirun \
-tune /share/home/hpcuser/examples/imagenet/tune_128 \
-n $1 -ppn 4 -f ~/hosts.txt \
-genvall -genv I_MPI_DAPL_TRANSLATION_CACHE=1 \
python train_imagenet_check.py \
train_cls_random.txt \
val_random.txt \
--root_train /mnt/ILSVRC/Data/CLS-LOC/train \
--root_val /mnt/ILSVRC//Data/CLS-LOC/val \
--batchsize 32 \
--communicator non_cuda_aware \
--out result/scaleout_$1

