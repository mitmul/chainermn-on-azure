#!/bin/bash

check () {
    out=result/scaleout_$1
    mkdir -p $out
    mpirun \
    -tune ~/tune/mpiexec_shm-dapl_nn_1_np_4_ppn_4.conf \
    -n $1 -ppn 4 -f ~/hosts.txt \
    -genvall -DAPL python -OO train_imagenet_check.py \
    /mnt/share/ILSVRC2012/train_random.txt \
    /mnt/share/ILSVRC2012/val_random.txt \
    --root_train /mnt/share/ILSVRC2012 \
    --root_val /mnt/share/ILSVRC2012 \
    --arch resnet50 \
    --batchsize 32 \
    --communicator non_cuda_aware \
    --out $out
}

for ((i=1; i <= 128; i=i*2));
do
    echo "# of GPUs: $i"
    check $i
    echo "done"
    sleep 1m
done
