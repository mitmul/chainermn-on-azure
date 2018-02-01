#!/bin/bash

CUDA_VERSION=9.1
NCCL_VERSION=2.1
CUDNN_VERSION=7.0.5

# Shares
SHARE_HOME=/share/home
NFS_ON_MASTER=/mnt/resource
NFS_MOUNT=/mnt/resource

# User
HPC_USER=hpcuser
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007

#############################################################################
log()
{
	echo "$0,$1,$2,$3"
}
usage() { echo "Usage: $0 [-s <masterName>] " 1>&2; exit 1; }

while getopts :s: optname; do
	log "Option $optname set with value ${OPTARG}"

	case $optname in
		s)  # master name
			export MASTER_NAME=${OPTARG}
			;;
		*)
			usage
			;;
	esac
done

setup_user()
{
	log "setup_user"
	sudo apt-get update -y
	sudo apt-get -y install nfs-common
	
	# Automatically mount the user's home
    sudo mkdir -p $SHARE_HOME
	sudo echo "$MASTER_NAME:$SHARE_HOME $SHARE_HOME    nfs rsize=8192,wsize=8192,timeo=14,intr" >> /etc/fstab
	sudo showmount -e ${MASTER_NAME}
	sudo mount -a
    sudo groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    sudo echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sudo sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

	sudo useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER
}

mount_nfs()
{
	sudo log "install NFS"
	sudo mkdir -p ${NFS_MOUNT}
	sudo log "mounting NFS on " ${MASTER_NAME}
	sudo showmount -e ${MASTER_NAME}
	sudo mount -t nfs ${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT}
	sudo echo "${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT} nfs defaults,nofail 0 0" >> /etc/fstab
}

base_pkgs()
{
	log "setup base_pkgs"
	#Install Kernel 
	cd /etc/apt/
	sudo echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed restricted main multiverse universe" >> sources.list
	sudo apt-get update -y
	sudo apt-get -y upgrade
	
	# Install dapl, rdmacm, ibverbs, and mlx4
	sudo apt-get -y install libdapl2 libmlx4-1 ibverbs-utils
	
	# Set memlock unlimited
	cd /etc/security/
	sudo echo " *               hard    memlock          unlimited" >> limits.conf
	sudo echo " *               soft    memlock          unlimited" >> limits.conf

	# enable rdma
	sudo sed -i  "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" /etc/waagent.conf
	sudo sed -i  "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" /etc/waagent.conf

	ibv_devinfo
}

setup_cuda()
{
	log "setup_cuda-$CUDA_VERSION"
	CUDA_REPO_PKG=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
	sudo wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG} 
	sudo dpkg -i /tmp/${CUDA_REPO_PKG}
	sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub 
	sudo rm -f /tmp/${CUDA_REPO_PKG}
	sudo apt-get update -y

	# Install drivers
	sudo apt-get install -y cuda-drivers

	if [ $CUDA_VERSION = 9.1 ]; then
		sudo apt-get install -y cuda
	fi

	if [ ! -d /usr/local/cuda ]; then
		sudo ln -s /usr/local/cuda-$CUDA_VERSION /usr/local/cuda
	fi

	cd /usr/local/cuda/samples/1_Utilities/deviceQuery
	sudo make
	./deviceQuery

	# cd /opt
	# sudo curl -L -O http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
	# sudo dpkg -i nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
	# sudo rm -rf nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
	# sudo apt-get update
}

install_nccl()
{
	log "Install NCCL $NCCL_VERSION"
	if [ $CUDA_VERSION = 9.1 ]; then
		if [ $NCCL_VERSION = 2.1 ]; then
			# sudo apt-get install -y libnccl2 libnccl-dev
			cd /opt
			sudo curl -L -O https://www.dropbox.com/s/9xz1m7kr4lyjo9m/nccl-repo-ubuntu1604-2.1.4-ga-cuda9.1_1-1_amd64.deb
			sudo dpkg -i nccl-repo-ubuntu1604-2.1.4-ga-cuda9.1_1-1_amd64.deb
			sudo apt install libnccl2 libnccl-dev
			sudo rm -rf nccl-repo-ubuntu1604-2.1.4-ga-cuda9.1_1-1_amd64.deb
		fi
	fi
}

install_cudnn7()
{
	log "Install cuDNN $CUDNN_VERSION"
	if [ $CUDA_VERSION = 9.1 ]; then
		if [ $CUDNN_VERSION = 7.0.5 ]; then
			# sudo apt-get install -y libcudnn7 libcudnn7-dev
			cd /usr/local
			sudo curl -L -O https://www.dropbox.com/s/55ak48061dsgtde/cudnn-9.1-linux-x64-v7.tgz
			sudo tar zxvf cudnn-9.1-linux-x64-v7.tgz
			sudo rm -rf cudnn-9.1-linux-x64-v7.tgz
		fi
	fi
}

su $HPC_USER
sudo mkdir -p /var/local
SETUP_MARKER=/var/local/chainer-setup.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

setup_user
mount_nfs
base_pkgs
setup_cuda
install_cudnn7
install_nccl

# Add environment variables
if [ ! -f $SHARE_HOME/$HPC_USER/.bashrc ]; then
	sudo touch $SHARE_HOME/$HPC_USER/.bashrc
fi
if grep -q "CUDA_PATH" $SHARE_HOME/$HPC_USER/.bashrc; then :; else
	sudo su -c "echo 'export CUDA_PATH=/usr/local/cuda' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export CPATH=/usr/local/cuda/include:\$CPATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export CPATH=/usr/local/include:\$CPATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export LIBRARY_PATH=/usr/local/cuda/lib64:\$LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export LIBRARY_PATH=/usr/local/lib:\$LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export LD_LIBRARY_PATH=/usr/local/lib:\$LD_LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export PATH=/usr/local/cuda/bin:\$PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo sh -c "echo 'echo 0 | tee /proc/sys/kernel/yama/ptrace_scope' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo cp $SHARE_HOME/$HPC_USER/.bashrc /root/
fi

# Create marker file so we know we're configured
sudo touch $SETUP_MARKER

exit 0