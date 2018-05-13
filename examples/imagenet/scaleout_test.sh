#!/bin/bash -xe

check () {
    out=result/scaleout_$1
    mkdir -p $out
    mpirun \
    -n $1 -ppn 4 -f ~/hosts.txt \
    -envall python train_imagenet_check.py \
    train_cls_random.txt \
    val_random.txt \
    --root_train /data1/ILSVRC/Data/CLS-LOC/train \
    --root_val /data1/ILSVRC/Data/CLS-LOC/val \
    --batchsize 32 \
    --communicator non_cuda_aware \
    --out $out
}

for ((i=128; i <= 128; i=i*2));
do
    echo "# of GPUs: $i"
    check $i
    echo "done"
    sleep 1m
done
