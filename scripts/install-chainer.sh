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
is_ubuntu()
{
	python -mplatform | grep -qi Ubuntu
	return $?
}
is_centos()
{
	python -mplatform | grep -qi CentOS
	return $?
}
base_pkgs()
{
 	log "base_pkgs"
	if is_ubuntu; then
		base_pkgs_ubuntu
	elif is_centos; then
		base_pkgs_centos
	fi
}
enable_rdma()
{
	# enable rdma    
	cd /etc/
	#echo "OS.EnableRDMA=y">>/etc/waagent.conf
	#echo "OS.UpdateRdmaDriver=y">>/etc/waagent.conf
	sed -i  "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" waagent.conf
	sed -i  "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" waagent.conf
}
base_pkgs_ubuntu()
{
	#Install Kernel 
	cd /etc/apt/
	echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed restricted main multiverse universe">>sources.list       
	sudo apt-get update
	sudo apt-get -y install linux-azure
	
	# Install dapl, rdmacm, ibverbs, and mlx4
	sudo apt-get -y install libdapl2 libmlx4-1    
	# enable_rdma
	# WALinux Agent Installation
	git clone https://github.com/Azure/WALinuxAgent.git
	cd WALinuxAgent
	sudo apt-get -y install python3-pip
	sudo python3 ./setup.py install --force      
	
	#Set memlock unlimited
	cd /etc/security/
	echo " *               hard    memlock          unlimited">>limits.conf
	echo " *               soft    memlock          unlimited">>limits.conf
	
	# Disable unattended-upgrades to avoide automatic updates
	cd /etc/apt/apt.conf.d
	sed -i  's#"${distro_id}:${distro_codename}"#//       "${distro_id}:${distro_codename}"#g;' 50unattended-upgrades
	sed -i  's#"${distro_id}:${distro_codename}-security"#//       "${distro_id}:${distro_codename}-security"#g;' 50unattended-upgrades
}
mount_nfs()
{
	if is_centos; then
		yum -y install nfs-utils nfs-utils-lib
	fi
	if is_ubuntu; then
		sudo apt-get -y install nfs-common
	fi

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
	if is_ubuntu; then
		sudo apt-get update
		sudo apt-get -y install nfs-common	
	fi

    mkdir -p $SHARE_HOME
    mkdir -p $SHARE_SCRATCH
	if is_centos; then
		echo "$MASTER_NAME:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab	
	fi	
	if is_ubuntu; then
		echo "$MASTER_NAME:$SHARE_HOME $SHARE_HOME    nfs rsize=8192,wsize=8192,timeo=14,intr" >> /etc/fstab
		showmount -e ${MASTER_NAME}
	fi
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
setup_cuda9()
{
	log "setup_cuda9"
	if is_centos; then
		setup_cuda9_centos
	fi
	if is_ubuntu; then
		setup_cuda9_ubuntu
	fi

	echo "export CUDA_PATH=/usr/local/cuda" >> /etc/profile.d/cuda.sh
	echo "export PATH=/usr/local/cuda/bin\${PATH:+:\${PATH}}" >> /etc/profile.d/cuda.sh
}
setup_cuda9_centos()
{
	sudo yum install kernel-devel-$(uname -r) kernel-headers-$(uname -r)
	curl -L -O http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-repo-rhel7-9.1.85-1.x86_64.rpm
	sudo rpm --install cuda-repo-rhel7-9.1.85-1.x86_64.rpm
	sudo rm -rf cuda-repo-rhel7-9.1.85-1.x86_64.rpm
	sudo yum clean all
	sudo yum -y install cuda

	nvidia-smi
}
setup_cuda8_ubuntu()
{
	sudo apt-get install linux-headers-$(uname -r)
	curl -L -O http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
	sudo dpkg -i cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
	sudo rm -rf cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
	sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/amd64/7fa2af80.pub
	sudo apt-get update
	sudo apt-get install -y cuda

	nvidia-smi
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
base_pkgs
setup_cuda9
# Create marker file so we know we're configured
touch $SETUP_MARKER
#shutdown -r +1 &
exit 0


