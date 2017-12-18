#!/bin/bash

log()
{
	echo "$1"
}

while getopts :a:k:u:t:p optname; do
	log "Option $optname set with value ${OPTARG}"
	case $optname in
		a)  # storage account
			export AZURE_STORAGE_ACCOUNT=${OPTARG}
			;;
		k)  # storage key
			export AZURE_STORAGE_ACCESS_KEY=${OPTARG}
			;;
	esac
done

# Shares
SHARE_HOME=/share/home

# User
HPC_USER=hpcuser
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007

install_intelmpi()
{
  cd /opt
  sudo curl -L -O http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/11595/l_mpi_2017.3.196.tgz
  sudo tar zxvf l_mpi_2017.3.196.tgz
  sudo rm -rf l_mpi_2017.3.196.tgz
  cd l_mpi_2017.3.196
  sudo sed -i -e "s/decline/accept/g" silent.cfg
  sudo ./install.sh --silent silent.cfg
}

setup_disks()
{
    mkdir -p $SHARE_HOME
}

mount_nfs()
{
	log "Install NFS on Ubuntu"	
	sudo apt-get update
	sudo apt-get -y install nfs-kernel-server
	sudo echo "$SHARE_HOME    *(rw,async)" >> /etc/exports
	sudo echo "/mnt/resource  *(rw,async)" >> /etc/exports
	sudo exportfs -a
	sudo systemctl enable nfs-kernel-server.service
	sudo systemctl start nfs-kernel-server.service
}

setup_user()
{
    sudo groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    sudo echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sudo sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers
   
	sudo useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

	sudo mkdir -p $SHARE_HOME/$HPC_USER/.ssh
	
	# Configure public key auth for the HPC user
	sudo ssh-keygen -t rsa -f $SHARE_HOME/$HPC_USER/.ssh/id_rsa -q -P ""
	sudo cat $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub >> $SHARE_HOME/$HPC_USER/.ssh/authorized_keys

	sudo echo "Host *" > $SHARE_HOME/$HPC_USER/.ssh/config
	sudo echo "    StrictHostKeyChecking no" >> $SHARE_HOME/$HPC_USER/.ssh/config
	sudo echo "    UserKnownHostsFile /dev/null" >> $SHARE_HOME/$HPC_USER/.ssh/config
	sudo echo "    PasswordAuthentication no" >> $SHARE_HOME/$HPC_USER/.ssh/config

	# Fix .ssh folder ownership
	sudo chown -R $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER

	# Fix permissions
	sudo chmod 700 $SHARE_HOME/$HPC_USER/.ssh
	sudo chmod 644 $SHARE_HOME/$HPC_USER/.ssh/config
	sudo chmod 644 $SHARE_HOME/$HPC_USER/.ssh/authorized_keys
	sudo chmod 600 $SHARE_HOME/$HPC_USER/.ssh/id_rsa
	sudo chmod 644 $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub
}

SETUP_MARKER=/var/tmp/master-setup.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

install_intelmpi

setup_disks

mount_nfs

setup_user

# Create marker file so we know we're configured
touch $SETUP_MARKER
exit 0
