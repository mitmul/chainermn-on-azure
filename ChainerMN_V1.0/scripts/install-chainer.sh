#!/bin/bash
#Shares
SHARE_HOME=/share/home
SHARE_SCRATCH=/share/scratch
NFS_ON_MASTER=/share/home
NFS_MOUNT=/data
#User
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

install_waagent()
{
		# WALinux Agent Installation
	   git clone https://github.com/Azure/WALinuxAgent.git
	   cd WALinuxAgent
	   sudo python setup.py install --register-service
}

base_pkgs_ubuntu()
{	  
       cd /etc/apt/
       echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed restricted main multiverse universe">>sources.list       
       sudo apt-get update
       sudo apt-get -y install linux-azure
       
       # Install dapl, rdmacm, ibverbs, and mlx4
       sudo apt-get -y install libdapl2 libmlx4-1    
       enable_rdma
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

base_pkgs_centos()
{
	#echo "\n\nEntering base_pkgs_centos \n\n=========================\n\n"	
	#yum -y update
	#next two lines are already in cuda
	yum -y install epel-release
	yum -y install dkms
	yum -y install kernel-devel
	yum -y install gcc
	yum -y install zlib -y zlib-devel
	#echo "\n\n base_pkgs_centos completed \n\n=========================\n\n"
}

mount_nfs()
{
	if is_centos; then
		yum -y install nfs-utils nfs-utils-lib
		log "install NFS"
		mkdir -p ${NFS_MOUNT}
		log "mounting NFS on " ${MASTER_NAME}
		showmount -e ${MASTER_NAME}
		mount -t nfs ${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT}
		
		echo "${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT} nfs defaults,nofail  0 0" >> /etc/fstab
	fi
	if is_ubuntu; then	
		sudo apt-get -y install nfs-common	
		log "install NFS"
		mkdir -p ${NFS_MOUNT}
		log "mounting NFS on " ${MASTER_NAME}
		showmount -e ${MASTER_NAME}
		mount -t nfs ${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT}
		
		echo "${MASTER_NAME}:${NFS_ON_MASTER} ${NFS_MOUNT} nfs defaults,nofail  0 0" >> /etc/fstab
	fi
}

setup_user()
{
	#echo "\n\nEntering setup_user\n\n=========================\n\n"
	if is_centos; then
		yum -y install nfs-utils nfs-utils-lib	
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
	fi
	if is_ubuntu; then
		sudo apt-get update
		sudo apt-get -y install nfs-common

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
	fi
	#echo "\n\nsetup_user completed \n\n=========================\n\n"
}


install_python()
{
#echo "\n\nEntering install_python\n\n=========================\n\n"
	wget  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/Python-3.6.3.tar.xz
	tar -xf Python-3.6.3.tar.xz >> /dev/null
	cd Python-3.6.3
	./configure --enable-optimizations
	
	if is_centos; then
		make && make install
		yum -y install python-pip
		pip install --upgrade pip
		yum -y install python-devel 
		yum -y install python-wheel
	fi
	if is_ubuntu; then
		sudo make altinstall
		sudo apt -y install python-pip
		sudo apt -y install python-devel
		sudo apt -y install python-wheel
		sudo pip install --upgrade pip
	fi

#echo "\n\n install_python completed \n\n=========================\n\n"
}

setup_cuda() 
{
#echo "\n\nEntering setup_cuda\n\n=========================\n\n"
	log "setup_cuda8"
	if is_centos; then
		setup_cuda_centos
	fi
	if is_ubuntu; then
		setup_cuda_ubuntu
	fi
	rsync -a /usr/local/cuda-9.1/targets/x86_64-linux/include /usr/local/cuda/include/
	echo "export CUDA_PATH=/usr/local/cuda" >> /etc/profile.d/cuda.sh
	echo "export PATH=/usr/local/cuda/bin\${PATH:+:\${PATH}}" >> /etc/profile.d/cuda.sh
	
#echo "\n\n setup_cuda completed \n\n=========================\n\n"
}

setup_cuda_centos()
{
	yum -y install kernel-devel-$(uname -r) kernel-headers-$(uname -r) --disableexcludes=all	
	#rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	#rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-10.noarch.rpm
	rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
	yum -y install dkms
	CUDA_RPM=cuda-repo-rhel7-8.0.61-1.x86_64.rpm
	sudo curl -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${CUDA_RPM}
	sudo rpm -i ${CUDA_RPM}
	sudo yum clean expire-cache
	sudo yum -y install cuda-8-0
	nvidia-smi
}

setup_cuda_ubuntu()
{
	#Insall Kernal 
	sudo apt-get install -y linux-headers-$(uname -r)
	#using CUDA_local_DEB_Package_around_1.2GB
	CUDA_DEB=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
	sudo curl -O https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${CUDA_DEB}
	sudo dpkg -i  ${CUDA_DEB}
	sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
	sudo apt-get -y update
	sudo apt-get -y install cuda
	nvidia-smi
}

verify_packages()
{
#echo "\n\nEntering verify_packages\n\n=========================\n\n"

	python3.6 -V
	if is_centos; then
	cat /usr/local/cuda-8.0/version.txt
	elif is_ubuntu; then
	cat /usr/local/cuda/version.txt
	fi

#echo "\n\n verify_packages completed \n\n=========================\n\n"	
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

#echo -e "setup_user \n\n=============================================================================================="
setup_user
#echo -e "\n\n============================================================================================== mount_nfs \n\n "
mount_nfs
#echo -e "\n\n============================================================================================== base_pkgs \n\n "
base_pkgs
#echo -e "\n\n============================================================================================== install_python \n\n "
install_python
#echo -e "\n\n============================================================================================== setup_cuda \n\n "
setup_cuda
#echo -e "\n\n============================================================================================== create_marker \n\n "
# Create marker file so we know we're configured
touch $SETUP_MARKER
#shutdown -r +1 &
#echo -e "\n\n============================================================================================== verify_packages \n\n "
#verify_packages
#echo -e "\n\n============================================================================================== end of install_chainer.sh script \n\n "
exit 0
