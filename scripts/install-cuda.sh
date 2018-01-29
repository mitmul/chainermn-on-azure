#!/bin/bash

CUDA_VERSION=9.1
NCCL_VERSION=2.1

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
	sudo apt-get update
	sudo apt-get -y install nfs-common
	
	# Automatically mount the user's home
    mkdir -p $SHARE_HOME
	echo "$MASTER_NAME:$SHARE_HOME $SHARE_HOME    nfs rsize=8192,wsize=8192,timeo=14,intr" >> /etc/fstab
	showmount -e ${MASTER_NAME}
	mount -a
    groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

	useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER
}

mount_nfs()
{
	sudo apt-get -y install nfs-common

	log "install NFS"
	mkdir -p ${NFS_MOUNT}
	log "mounting NFS on " ${MASTER_NAME}
	showmount -e ${MASTER_NAME}
	mount -t nfs ${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT}
	sudo echo "${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT} nfs defaults,nofail 0 0" >> /etc/fstab
}

base_pkgs()
{
	#Install Kernel 
	cd /etc/apt/
	sudo echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed restricted main multiverse universe" >> sources.list
	sudo apt-get update
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
}

setup_cuda()
{
	log "setup_cuda-$CUDA_VERSION"
	CUDA_REPO_PKG=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
	wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG} 
	sudo dpkg -i /tmp/${CUDA_REPO_PKG}
	sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub 
	rm -f /tmp/${CUDA_REPO_PKG}
	sudo apt-get update

	# Kernel downgrade
	if [ $CUDA_VERSION = 8.0 ]; then
		sudo apt-get install -y linux-image-4.11.0-1016-azure
		prefix=`grep -oh "gnulinux-advanced-[0-9a-z-]*" /boot/grub/grub.cfg`
		kernel=`grep -oh "gnulinux-4.11.0-1016-azure-advanced-[0-9a-z-]*" /boot/grub/grub.cfg`
		sudo sed -i -e 's/GRUB_DEFAULT=0/GRUB_DEFAULT="'"${prefix}>${kernel}"'"/g' /etc/default/grub
		sudo update-grub
	fi

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
}

install_nccl()
{
	log "Install NCCL $NCCL_VERSION"
	if [ $CUDA_VERSION = 9.1 ]; then
		if [ $NCCL_VERSION = 2.1 ]; then
			cd /opt
			sudo curl -L -O http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/libnccl2_2.1.4-1+cuda9.1_amd64.deb
			sudo curl -L -O http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/libnccl-dev_2.1.4-1+cuda9.1_amd64.deb
			sudo dpkg -i libnccl2_2.1.4-1+cuda9.1_amd64.deb
			sudo rm -rf libnccl2_2.1.4-1+cuda9.1_amd64.deb
			sudo dpkg -i libnccl-dev_2.1.4-1+cuda9.1_amd64.deb
			sudo rm -rf libnccl-dev_2.1.4-1+cuda9.1_amd64.deb
		fi
	fi
}

install_cudnn7()
{
	if [ $CUDA_VERSION = 9.1 ]; then
		cd /opt
		sudo curl -L -O http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/libcudnn7_7.0.5.15-1+cuda9.1_amd64.deb
		sudo curl -L -O http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/libcudnn7-dev_7.0.5.15-1+cuda9.1_amd64.deb
		sudo dpkg -i libcudnn7_7.0.5.15-1+cuda9.1_amd64.deb
		sudo rm -rf libcudnn7_7.0.5.15-1+cuda9.1_amd64.deb
		sudo dpkg -i libcudnn7-dev_7.0.5.15-1+cuda9.1_amd64.deb
		sudo rm -rf libcudnn7-dev_7.0.5.15-1+cuda9.1_amd64.deb
	fi
}

sudo su $HPC_USER
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

install_nccl

install_cudnn7

if [ ! -f $SHARE_HOME/$HPC_USER/.bashrc ]; then
	touch $SHARE_HOME/$HPC_USER/.bashrc
fi
if grep -q "anaconda" $SHARE_HOME/$HPC_USER/.bashrc; then :; else
	sudo su -c "echo 'source /opt/anaconda3/bin/activate' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export CUDA_PATH=/usr/local/cuda' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export CPATH=/usr/local/cuda/include:\$CPATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export CPATH=/usr/local/include:\$CPATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export LIBRARY_PATH=/usr/local/cuda/lib64:\$LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export LIBRARY_PATH=/usr/local/lib:\$LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export LD_LIBRARY_PATH=/usr/local/lib:\$LD_LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo su -c "echo 'export PATH=/usr/local/cuda/bin:\$PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sudo sh -c "echo 'echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
fi

# Create marker file so we know we're configured
sudo touch $SETUP_MARKER

exit 0