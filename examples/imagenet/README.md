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

## Check all nodes

```
sudo apt-get install -y parallel

bash save_hosts.sh chainermn-k80
bash setup.sh chainermn-k80
```

Some nodes may be rebooted due to errors.

After that, if you want to ensure all nodes can run NNIST example
with `mpirun` command using multiple nodes, run this:

```
bash check_mnist_seq.sh
```

## Check Pingpong performance

This shell script runs IMB-MPI1 Pingpong benchmark to check the performance of nodes.

```
bash check_pingpong.sh chainermn-k80
```

## Dataset 

With the following two commands, you create Managed Disks for each node based on a snapshot which have ImageNet-1K dataset inside. Then you copy the dataset to local SSD of each node for faster data access. Note that you need to copy the archive of image data first (`imagenet_object_localization.tar.gz`), and then extract images from it on the SSD of each node. Do not copy the extracted images from Managed Disk to SSD, it takes much more time!

```
bash attach_disks.sh chainermn-k80
bash copy_to_ssd.sh
```

## Experiment

```
bash scaleout_test.sh
```

# Experiment on V100

## Install DALI

```
pip install --extra-index-url https://developer.download.nvidia.com/compute/redist nvidia-dali
```

## Install DALI-supported Chainer 

```
sudo pip install git+https://github.com/anaruse/chainer.git@support_dali
```
