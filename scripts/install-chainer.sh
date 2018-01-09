#!/bin/bash

CUDA_VERSION=8.0

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

enable_rdma()
{
	# enable rdma    
	cd /etc/
	sed -i  "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" waagent.conf
	sed -i  "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" waagent.conf
}

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
	sudo echo "${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT} nfs defaults,nofail  0 0" >> /etc/fstab
}

base_pkgs()
{
	#Install Kernel 
	cd /etc/apt/
	sudo echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed restricted main multiverse universe" >> sources.list
	sudo apt-get update
	sudo apt-get -y install linux-azure
	
	# Install dapl, rdmacm, ibverbs, and mlx4
	sudo apt-get -y install libdapl2 libmlx4-1
	
	#Set memlock unlimited
	cd /etc/security/
	sudo echo " *               hard    memlock          unlimited" >> limits.conf
	sudo echo " *               soft    memlock          unlimited" >> limits.conf
}

setup_cuda()
{
	log "setup_cuda$CUDA_VERSION"
	sudo apt-get install linux-headers-$(uname -r)
	sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
	sudo apt-get update

	if [ $CUDA_VERSION = 8.0 ]; then
		sudo curl -L -O https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_8.0.61-1_amd64.deb
		sudo dpkg -i cuda-repo-ubuntu1604_8.0.61-1_amd64.deb
		sudo rm -rf cuda-repo-ubuntu1604_8.0.61-1_amd64.deb
		sudo apt-get update
		sudo apt-get install -y cuda-8-0
	fi
	if [ $CUDA_VERSION = 9.0 ]; then
		sudo curl -L -O https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_9.0.176-1_amd64.deb
		sudo dpkg -i cuda-repo-ubuntu1604_9.0.176-1_amd64.deb
		sudo rm -rf cuda-repo-ubuntu1604_9.0.176-1_amd64.deb
		sudo apt-get update
		sudo apt-get install -y cuda-9-0
	fi

	if [ ! -d /usr/local/cuda ]; then
		sudo ln -s /usr/local/cuda-$CUDA_VERSION /usr/local/cuda
	fi

	echo "export CUDA_PATH=/usr/local/cuda" >> /etc/profile.d/cuda.sh
	echo "export CPATH=/usr/local/cuda/include:\$CPATH" >> /etc/profile.d/cuda.sh
	echo "export LIBRARY_PATH=/usr/local/cuda/lib64:\$LIBRARY_PATH" >> /etc/profile.d/cuda.sh
	echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH" >> /etc/profile.d/cuda.sh
	echo "export PATH=/usr/local/cuda/bin:\$PATH" >> /etc/profile.d/cuda.sh
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

# Create marker file so we know we're configured
sudo touch $SETUP_MARKER

exit 0

