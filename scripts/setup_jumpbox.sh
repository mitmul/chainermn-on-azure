#!/bin/sh -xe

# Setup hpcuser
HPC_USER=hpcuser
HPC_UID=7007
HPC_GROUP=hpcuser
HPC_GID=7007
groupadd -g $HPC_GID $HPC_GROUP

# sudo setting
echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

# Setup shared home dir
SHARE_HOME=/share/home
mkdir -p $SHARE_HOME
mkdir -p $SHARE_HOME/$HPC_USER
mkdir -p $SHARE_HOME/$HPC_USER/.ssh

# Create user
useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

# Configure public key auth for the HPC user
ssh-keygen -t rsa -f $SHARE_HOME/$HPC_USER/.ssh/id_rsa -q -P ""
cat $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub >> $SHARE_HOME/$HPC_USER/.ssh/authorized_keys
echo "Host *" | tee -a $SHARE_HOME/$HPC_USER/.ssh/config
echo "    StrictHostKeyChecking no" | tee -a $SHARE_HOME/$HPC_USER/.ssh/config
echo "    UserKnownHostsFile /dev/null" | tee -a $SHARE_HOME/$HPC_USER/.ssh/config
echo "    PasswordAuthentication no" | tee a $SHARE_HOME/$HPC_USER/.ssh/config
chown -R $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER
chmod 700 $SHARE_HOME/$HPC_USER/.ssh
chmod 644 $SHARE_HOME/$HPC_USER/.ssh/config
chmod 644 $SHARE_HOME/$HPC_USER/.ssh/authorized_keys
chmod 600 $SHARE_HOME/$HPC_USER/.ssh/id_rsa
chmod 644 $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub

apt-get update
apt-get -y install nfs-kernel-server		
echo "$SHARE_HOME    *(rw,async)" | tee -a /etc/exports
exportfs -a		
systemctl enable nfs-kernel-server.service
systemctl start nfs-kernel-server.service

# Install Python3
apt-get install -y ccache python3 python3-pip
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10

# Set environment variables
echo 'export LANG=en_US.UTF-8' >> /home/ubuntu/.bashrc
echo 'export LC_CTYPE=en_US.UTF-8' >> /home/ubuntu/.bashrc

# Install IntelMPI
cd /opt
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/11595/l_mpi_2017.3.196.tgz
tar zxvf l_mpi_2017.3.196.tgz
rm -rf l_mpi_2017.3.196.tgz
cd l_mpi_2017.3.196
sed -i -e "s/decline/accept/g" silent.cfg
./install.sh --silent silent.cfg
echo 'source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh' | tee -a /home/ubuntu/.bashrc
exec $SHELL

