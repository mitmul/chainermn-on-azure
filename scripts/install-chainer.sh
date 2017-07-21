#!/bin/bash

# Shares
SHARE_HOME=/share/home
SHARE_SCRATCH=/share/scratch
NFS_ON_MASTER=/share/home
NFS_MOUNT=/data

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
is_centos()
{
	python -mplatform | grep -qi CentOS
	return $?
}
mount_nfs()
{
	log "install NFS"
	mkdir -p ${NFS_MOUNT}
	log "mounting NFS on " ${MASTER_NAME}
	showmount -e ${MASTER_NAME}
	mount -t nfs ${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT}
	
	echo "${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT} nfs defaults,nofail  0 0" >> /etc/fstab
}
setup_user()
{
	if is_centos; then
		yum -y install nfs-utils nfs-utils-lib	
	fi

    mkdir -p $SHARE_HOME
    mkdir -p $SHARE_SCRATCH

	echo "$MASTER_NAME:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
	mount -a
	mount
   
    groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

	useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

    chown $HPC_USER:$HPC_GROUP $SHARE_SCRATCH	
}
setup_python_centos()
{
	yum -y install epel-release
	yum -y install python34 python34-devel
	curl -O https://bootstrap.pypa.io/get-pip.py
	python3 get-pip.py
}

setup_cuda8()
{
	log "setup_cuda8"
	if is_centos; then
		setup_cuda8_centos
	fi

	echo "export CUDA_PATH=/usr/local/cuda" >> /etc/profile.d/cuda.sh
	echo "export PATH=/usr/local/cuda/bin\${PATH:+:\${PATH}}" >> /etc/profile.d/cuda.sh
}
setup_cuda8_centos()
{
	yum -y install kernel-devel-$(uname -r) kernel-headers-$(uname -r) --disableexcludes=all
	rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	#rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-10.noarch.rpm
	yum -y install dkms
	CUDA_RPM=cuda-repo-rhel7-8.0.61-1.x86_64.rpm
	curl -O http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/${CUDA_RPM}
	rpm -i ${CUDA_RPM}
	yum clean expire-cache
	yum -y install cuda

	nvidia-smi
}
setup_chainermn()
{
	setup_cuda8
	if is_centos; then		
		yum reinstall -y /opt/microsoft/rdma/rhel73/kmod-microsoft-hyper-v-rdma-4.2.2.144-20170706.x86_64.rpm				
	fi	
}
mkdir -p /var/local
SETUP_MARKER=/var/local/chainer-setup.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

if is_centos; then
	# disable selinux
	sed -i 's/enforcing/disabled/g' /etc/selinux/config
	setenforce permissive
fi
setup_user
mount_nfs
#sudo yum update -y
setup_chainermn
# Create marker file so we know we're configured
touch $SETUP_MARKER
exit 0
