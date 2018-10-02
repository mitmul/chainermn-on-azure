# ImageNet Training with ChainerMN

## Download ImageNet dataset to shared data dir

```
# Login to jumpbox

# Install kaggle command
pip install kaggle

# Place .kaggle/kaggle.json to /share/home/hpcuser/.kaggle/kaggle.json

# Downlaod ImageNet dataset to shared data disk /data1
cd /data1
kaggle competitions download -c imagenet-object-localization-challenge -p ./
```

## Scale out

```
az vmss scale -g chainermn -n vmss --new-capacity 32
```

## Get list of IPs in VMSS

```
# Login to jumpbox

# Save VMSS IP list
az vmss nic list -g chainermn-v100 --vmss-name vmss \
--query "[*].ipConfigurations[0].privateIpAddress" -o tsv > ~/hosts.txt
```

## Login to a worker node

First, please login to the jumpbox, and then change the user to `hpcuser`.

```
# Login to jumpbox

# Become hpcuser
sudo su hpcuser
```

Then, let's login to a worker node.

```
ssh $(head -n 1 ~/hosts.txt)
```

Run this first on a worker node:

```
echo 'Host *' >> /share/home/hpcuser/.ssh/config
echo '    StrictHostKeyChecking   no' >> /share/home/hpcuser/.ssh/config
```

## Check all nodes

```
python setup.py
```

If it finds a broken instance, it deletes that from the VMSS.

## Check Pingpong performance

This shell script runs IMB-MPI1 Pingpong benchmark to check the performance of nodes.

```
python check_pingpong.py -d
```

## Try MNIST training

After that, if you want to ensure all nodes can run NNIST example
with `mpirun` command using multiple nodes, run this:

```
mpirun -n 128 -ppn 4 -f ~/hosts.txt -genvall \
python train_mnist.py -g -e 3 --communicator non_cuda_aware
```

## Dataset 

With the following two commands, you create Managed Disks for each node based on a snapshot which have ImageNet-1K dataset stored.

```
python attach_disks.py
```

## MPI-Tune

```
mpitune --application \"mpirun -n 1 -ppn 4 -f ~/hosts.txt -genvall -genv I_MPI_DAPL_TRANSLATION_CACHE=1 bash tune_cmd.sh\" -of tune_128 -hf ~/hosts.txt
```

## Experiment

```
bash scaleout_test.sh
```

# Experiment on V100

To use TensorCores of V100, you need to convert all the parameters of your model into float16 preliminarliry.

## NVPROF

```
mpirun \
-n $1 -ppn 4 -f ~/hosts.txt \
-genvall -genv I_MPI_DAPL_TRANSLATION_CACHE=1 \
nvprof -o profile_%q{PMI_RANK}.nvprof \
python train_imagenet_fp16.py \
train_cls_random.txt \
val_random.txt \
--root_train /imagenet1k/ILSVRC/Data/CLS-LOC/train \
--root_val /imagenet1k/ILSVRC//Data/CLS-LOC/val \
--batchsize 32 \
--communicator non_cuda_aware \
--out result/scaleout_$1 \
--test
```
