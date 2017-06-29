#!/bin/bash

# Shares
SHARE_HOME=/share/home
SHARE_SCRATCH=/share/scratch
NFS_ON_MASTER=/data
NFS_MOUNT=/data

# User
HPC_USER=hpcuser
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007

#############################################################################
log()
{
	echo "$1"
}

usage() { echo "Usage: $0 [-m <masterName>]" 1>&2; exit 1; }

while getopts :m:S:s:q:n:c: optname; do
  log "Option $optname set with value ${OPTARG}"
  
  case $optname in
    m)  # master name
		export MASTER_NAME=${OPTARG}
		;;
    S)  # Shared Storage (beegfs, nfsonmaster)
		export SHARED_STORAGE=${OPTARG}
		;;
    s)  # Scheduler (pbspro)
		export SCHEDULER=${OPTARG}
		;;
    n)  # monitoring
		export MONITORING=${OPTARG}
		;;
    c)  # post install command
		export POST_INSTALL_COMMAND=${OPTARG}
		;;
    q)  # queue name
		export QNAME=${OPTARG}
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

	if is_centos; then
		yum -y install nfs-utils nfs-utils-lib
	elif is_suse; then
		zypper -n install nfs-client
	elif is_ubuntu; then
		apt -qy install nfs-common 
	fi
	
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
	elif is_suse; then
		zypper -n install nfs-client
	elif is_ubuntu; then
		apt-get -qy install nfs-common 
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
mkdir -p /var/local
SETUP_MARKER=/var/local/cn-setup.marker
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
# Create marker file so we know we're configured
#touch $SETUP_MARKER
exit 0
