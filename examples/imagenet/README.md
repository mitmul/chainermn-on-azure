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
    mpirun -n 1 -ppn 1 \
    -hosts ${ip} -envall \
    python train_mnist.py -g --communicator non_cuda_aware
done
