#!/bin/bash -xe

for ((i=1; i <= 128; i=i*2));
do
    echo "# of GPUs: $i"
    bash run_test_v100.sh $i
    echo "done"
    sleep 1m
done

# check () {
#     out=result/scaleout_$1
#     mkdir -p $out
#     mpirun \
#     -tune /share/home/hpcuser/examples/imagenet/tune_128 \
#     -n $1 -ppn 4 -f ~/hosts.txt \
#     -genvall -genv I_MPI_DAPL_TRANSLATION_CACHE=1 \
#     python train_imagenet_check.py \
#     train_cls_random.txt \
#     val_random.txt \
#     --root_train /mnt/ILSVRC/Data/CLS-LOC/train \
#     --root_val /mnt/ILSVRC//Data/CLS-LOC/val \
#     --batchsize 32 \
#     --communicator non_cuda_aware \
#     --out $out
# }


