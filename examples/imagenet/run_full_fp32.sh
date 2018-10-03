#!/bin/bash -xe

if [ ! -d result/scaleout_$1 ]; then
    mkdir -p result/scaleout_$1
fi

# -tune /share/home/hpcuser/examples/imagenet/tune_128 \
mpirun \
-n $1 -ppn 4 -f ~/hosts.txt \
-genvall \
-genv I_MPI_DAPL_TRANSLATION_CACHE=1 \
-genv I_MPI_RDMA_SCALABLE_PROGRESS=0 \
python train_imagenet_fp32.py \
train_random.txt \
val_random.txt \
--root_train /imagenet1k/ILSVRC/Data/CLS-LOC/train \
--root_val /imagenet1k/ILSVRC//Data/CLS-LOC/val \
--batchsize 64 \
--communicator non_cuda_aware \
--out result/scaleout_$1
