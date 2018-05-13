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
az vmss nic list -g chainermn --vmss-name vmss \
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
ip=$(head -n 1 ~/hosts.txt)
ssh $ip
```

Run this first on a worker node:
```
echo 'Host *' >> /share/home/hpcuser/.ssh/config
echo '    StrictHostKeyChecking   no' >> /share/home/hpcuser/.ssh/config
```

Upload 

mpirun -f ~/hosts.txt -ppn 1 -n 32 -envall IMB-MPI1 pingpong


for ip in `cat ~/hosts.txt`;
do
    mpirun -n 2 -ppn 1 \
    -hosts localhost,${ip} -envall \
    IMB-MPI1 pingpong;
done


mpirun -n 1 -ppn 4 -hosts localhost \
-envall python train_imagenet_check.py \
train_cls_random.txt val_random.txt \
--root_train /data1/ILSVRC/Data/CLS-LOC/train \
--root_val /data1/ILSVRC/Data/CLS-LOC/val \
--batchsize 1 --communicator non_cuda_aware

mpirun -n 128 -ppn 4 -f ~/hosts.txt -envall IMB-MPI1 pingpong
