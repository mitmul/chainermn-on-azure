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
	echo $USER
	printenv
	
	apt-get update -y
	apt-get -y install nfs-common
	
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
	log "install NFS"
	mkdir -p ${NFS_MOUNT}
	log "mounting NFS on " ${MASTER_NAME}
	showmount -e ${MASTER_NAME}
	mount -t nfs ${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT}
	echo "${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT} nfs defaults,nofail 0 0" >> /etc/fstab
}

base_pkgs()
{
	log "setup base_pkgs"
	#Install Kernel 
	cd /etc/apt/
	echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed restricted main multiverse universe" >> sources.list
	apt-get update -y
	apt-get -y upgrade
	
	# Install dapl, rdmacm, ibverbs, and mlx4
	apt-get -y install libdapl2 libmlx4-1 ibverbs-utils
	
	# Set memlock unlimited
	cd /etc/security/
	echo " *               hard    memlock          unlimited" >> limits.conf
	echo " *               soft    memlock          unlimited" >> limits.conf

	# enable rdma
	sed -i  "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" /etc/waagent.conf
	sed -i  "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" /etc/waagent.conf
}

setup_cuda()
{
	log "setup_cuda-$CUDA_VERSION"
	CUDA_REPO_PKG=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
	wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG} 
	dpkg -i /tmp/${CUDA_REPO_PKG}
	apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub 
	rm -f /tmp/${CUDA_REPO_PKG}
	apt-get update

	# Install drivers
	apt-get install -y cuda-drivers

	if [ $CUDA_VERSION = 9.1 ]; then
		apt-get install -y cuda
	fi

	if [ ! -d /usr/local/cuda ]; then
		ln -s /usr/local/cuda-$CUDA_VERSION /usr/local/cuda
	fi

	cd /usr/local/cuda/samples/1_Utilities/deviceQuery
	make
	./deviceQuery

	cd /opt
	curl -L -O http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
	dpkg -i nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
	rm -rf nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb
	apt-get update
}

install_nccl()
{
	log "Install NCCL $NCCL_VERSION"
	if [ $CUDA_VERSION = 9.1 ]; then
		if [ $NCCL_VERSION = 2.1 ]; then
			apt-get install -y libnccl2 libnccl-dev
		fi
	fi
}

install_cudnn7()
{
	log "Install cuDNN $CUDNN_VERSION"
	if [ $CUDA_VERSION = 9.1 ]; then
		if [ $CUDNN_VERSION = 7.0.5 ]; then
			apt-get install -y libcudnn7 libcudnn7-dev
		fi
	fi
}

su $HPC_USER
mkdir -p /var/local
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

# Add environment variables
if [ ! -f $SHARE_HOME/$HPC_USER/.bashrc ]; then
	touch $SHARE_HOME/$HPC_USER/.bashrc
fi
if grep -q "CUDA_PATH" $SHARE_HOME/$HPC_USER/.bashrc; then :; else
	su -c "echo 'export CUDA_PATH=/usr/local/cuda' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	su -c "echo 'export CPATH=/usr/local/cuda/include:\$CPATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	su -c "echo 'export CPATH=/usr/local/include:\$CPATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	su -c "echo 'export LIBRARY_PATH=/usr/local/cuda/lib64:\$LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	su -c "echo 'export LIBRARY_PATH=/usr/local/lib:\$LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	su -c "echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	su -c "echo 'export LD_LIBRARY_PATH=/usr/local/lib:\$LD_LIBRARY_PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	su -c "echo 'export PATH=/usr/local/cuda/bin:\$PATH' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
	sh -c "echo 'echo 0 | tee /proc/sys/kernel/yama/ptrace_scope' >> $SHARE_HOME/$HPC_USER/.bashrc" $HPC_USER
fi

# Create marker file so we know we're configured
touch $SETUP_MARKER

exit 0