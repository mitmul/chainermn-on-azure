ImageNet training with ChainerMN
================================

# Requirements

- Python3
- pip packages:
    - azure-cli

# Setup

## Azure CLI setup

```
$ az login
$ az account list
$ az account set --subscription [subscription_id]
```

## List the IPs

```
$ az vmss nic list -g [resource group name] --vmss-name chainer \
--query "[*].ipConfigurations[0].privateIpAddress" -o tsv > hosts.txt
```

## Copy data

Move to the data directory put in a shared point.

```
[On jumpbox]
nc -l 9999 | pigz -d | tar xv

[On client]
ssh -L 9999:localhost:9999 hpcuser@[Azure Jumpbox IP]
tar cf - ILSVRC2015 | pigz -c | nc localhost 9999
```

```
wget -c http://dl.caffe.berkeleyvision.org/caffe_ilsvrc12.tar.gz
tar zxvf caffe_ilsvrc12.tar.gz
rm -rf caffe_ilsvrc12.tar.gz
sort -R train.txt > train_random.txt
sort -R val.txt > val_random.txt
```

```
az storage file upload-batch --source ILSVRC2012 --destination imagenet --account-name chainermnimagenet
```

```


## Run the training

```
CHAINER_TYPE_CHECK=0 MPLBACKEND=Agg \
mpirun -n 128 -ppn 4 -f ~/hosts.txt \
-genvall -DAPL python -O train_imagenet.py \
/mnt/share/train_random.txt \
/mnt/share/val_random.txt \
--root_train /mnt/share/train \
--root_val /mnt/share/val \
--arch resnet50 \
--batchsize 32 \
--epoch 100 \
--communicator pure_nccl
```

```
CHAINER_TYPE_CHECK=0 MPLBACKEND=Agg \
mpirun -n 2 -ppn 1 -hosts 10.0.0.7,10.0.0.10 \
-envall python train_mnist.py \
--gpu --communicator non_cuda_aware
```

```
mpirun -hosts localhost,localhost -ppn 1 -n 2 -envall IMB-MPI1 pingpong
```

```
CHAINER_TYPE_CHECK=0 MPLBACKEND=Agg \
mpirun -n 2 -ppn 1 -hosts localhost,localhost \
-envall python train_mnist.py \
--gpu --communicator non_cuda_aware
```

mpiexec -n 1 -ppn 1 -hosts localhost python -c "from mpi4py import MPI; import chainermn"

NCCL_DEBUG=DEBUG NCCL_IB_CUDA_SUPPORT=0 MPLBACKEND=Agg mpiexec -n 1 -ppn 1 -hosts localhost python train_mnist.py --gpu --communicator non_cuda_aware