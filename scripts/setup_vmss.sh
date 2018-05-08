#!/bin/bash

CUPY_VERSION=4.0.0
CHAINER_VERSION=4.0.0

# Setup hpcuser
HPC_USER=hpcuser
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007
groupadd -g $HPC_GID $HPC_GROUP

# sudo setting
echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

# Setup shared home dir
SHARE_HOME=/share/home
DISK_MOUNT=/data1
MASTER_NAME=jumpbox
apt-get update
apt-get -y install nfs-common
mkdir -p $SHARE_HOME
mkdir -p $DISK_MOUNT
echo "$MASTER_NAME:$SHARE_HOME $SHARE_HOME    nfs defaults,nofail  0 0" | tee -a /etc/fstab
echo "$MASTER_NAME:$DISK_MOUNT $DISK_MOUNT    nfs defaults,nofail  0 0" | tee -a /etc/fstab
showmount -e ${MASTER_NAME}
mount -a
mount

# Create user
useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

# Install CUDA driver and CUDA
CUDA_REPO_PKG=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG}
dpkg -i /tmp/${CUDA_REPO_PKG}
apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
rm -f /tmp/${CUDA_REPO_PKG}
apt-get update
apt-get install -y cuda-drivers
apt-get install -y cuda-8-0

# Install Python3
apt-get install -y ccache python3 python3-dev python3-dbg python3-wheel python3-pip python3-cffi
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10

# Install cuDNN
cd /usr/local
curl -L -O http://developer.download.nvidia.com/compute/redist/cudnn/v7.0.5/cudnn-8.0-linux-x64-v7.tgz
tar zxvf cudnn-8.0-linux-x64-v7.tgz
rm -rf cudnn-8.0-linux-x64-v7.tgz

# Install NCCL1
cd /opt
git clone https://github.com/NVIDIA/nccl.git
cd nccl
make CUDA_HOME=/usr/local/cuda-8-0 test
make install

# Install cupy, chainer
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
pip install cython
cd /opt
wget https://github.com/cupy/cupy/archive/v${CUPY_VERSION}.tar.gz
tar zxvf v${CUPY_VERSION}.tar.gz
rm -rf v${CUPY_VERSION}.tar.gz
cd cupy-${CUPY_VERSION}
python setup.py install
pip install chainer==${CHAINER_VERSION}

# Setup RDMA network
apt-get update
apt-get install -y libdapl2 libmlx4-1
sed -i -E "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" /etc/waagent.conf
sed -i -E "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" /etc/waagent.conf
echo " *               hard    memlock          unlimited" | tee -a /etc/security/limits.conf
echo " *               soft    memlock          unlimited" | tee -a /etc/security/limits.conf

# Install IntelMPI
cd /opt
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/11595/l_mpi_2017.3.196.tgz
tar zxvf l_mpi_2017.3.196.tgz
rm -rf l_mpi_2017.3.196.tgz
cd l_mpi_2017.3.196
sed -i -e "s/decline/accept/g" silent.cfg
./install.sh --silent silent.cfg

# Install ChainerMN
pip install mpi4py
pip install chainermn

# Register cron tab so when machine restart it downloads the secret from azure downloadsecret
mv /var/lib/waagent/custom-script/download/1/rdma-autoload.sh ~
crontab -l > downloadsecretcron
echo '@reboot /root/rdma-autoload.sh >> /root/execution.log' >> downloadsecretcron
crontab downloadsecretcron
rm downloadsecretcron

shutdown -r +1