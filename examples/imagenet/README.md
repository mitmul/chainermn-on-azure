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
mpirun -n 4 -ppn 1 -hosts localhost,localhost,localhost,localhost \
-envall python -O train_mnist.py \
--gpu --communicator pure_nccl
```