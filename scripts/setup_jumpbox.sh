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

# Put all environment settings here for VMSS worker nodes
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export CPATH=/usr/local/cuda/include:$CPATH' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export LIBRARY_PATH=/usr/local/cuda/lib64:$LIBRARY_PATH' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export LANG=en_US.UTF-8' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export LC_CTYPE=en_US.UTF-8' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export I_MPI_FABRICS=shm:dapl' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export I_MPI_DAPL_PROVIDER=ofa-v2-ib0' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export I_MPI_DYNAMIC_CONNECTION=0' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export I_MPI_FALLBACK_DEVICE=0' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'export I_MPI_DAPL_TRANSLATION_CACHE=0' >> ${SHARE_HOME}/${HPC_USER}/.bashrc
echo 'echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope' >> ${SHARE_HOME}/${HPC_USER}/.bashrc

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

