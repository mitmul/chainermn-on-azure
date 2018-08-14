#!/bin/bash -xe

# mpitune \
# -hf ~/hosts.txt \
# -fl shm:dapl \
# -hr 32:32 \
# -pr 4:4 \
# -odr tune \
# --skip-check-hosts

mpitune \
--application \"mpirun -n 128 -ppn 4 -f ~/hosts.txt -genvall ./tune_cmd.sh\" \
-of tune_128

# mpitune \
# --skip-check-hosts \
# --fast on \
# -of tune_128 \
# -hr 32:32 \
# -pr 4:4 \
# -dl rdma \
# -fl shm:dapl \
# -a \"mpirun -n 128 -ppn 4 -f /share/home/hpcuser/hosts.txt -envall python train_for_tune.py train_cls_random.txt val_random.txt --root_train /mnt/ILSVRC/Data/CLS-LOC/train --root_val /mnt/ILSVRC//Data/CLS-LOC/val --batchsize 32 --communicator non_cuda_aware --out result\"
