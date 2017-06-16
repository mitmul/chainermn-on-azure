#!/bin/sh

# This script can be found on https://github.com/satohiro/Chainer-MN-on-Azure/blob/master/azuredeploy.sh
# This script is part of azure deploy ARM template
# This script assumes the Linux distribution to be Ubuntu (or at least have apt-get support)

create_newuser_on_nfsserver() {
  SSHDIR=/home/${NEWUSER}/.ssh

  useradd -s /bin/bash -m ${NEWUSER}
  mkdir ${SSHDIR}
  chmod 700 ${SSHDIR}
  ssh-keygen -t rsa -N ""  -f ${SSHDIR}/id_rsa
  cat ${SSHDIR}/id_rsa.pub >> ${SSHDIR}/authorized_keys
  echo "${GENERAL_USER_SSH_KEY}" >> ${SSHDIR}/authorized_keys
  chmod 600 ${SSHDIR}/authorized_keys
  echo "StrictHostKeyChecking no" >> ${SSHDIR}/config
  chmod 600 ${SSHDIR}/config
  chown -R ${NEWUSER}. /home/${NEWUSER}

  #setup .bashrc for chanermn
  echo "export PATH=\"/usr/local/cuda/bin:\$PATH\"" >> /home/${NEWUSER}/.bashrc
  echo "export PATH=\"/usr/local/cuda/bin:\$PATH\"" > /tmp/bashrc.$$
  echo "export CPATH=\"/usr/local/cuda/include:\$CPATH\"" >> /home/${NEWUSER}/.bashrc
  echo "export CPATH=\"/usr/local/cuda/include:\$CPATH\"" >> /tmp/bashrc.$$
  echo "export LD_LIBRARY_PATH=\"/usr/local/cuda/lib64:\$LD_LIBRARY_PATH\"" >> /home/${NEWUSER}/.bashrc
  echo "export LD_LIBRARY_PATH=\"/usr/local/cuda/lib64:\$LD_LIBRARY_PATH\"" >> /tmp/bashrc.$$
  echo "export MPI_ROOT=\"/usr/local/lib/openmpi\"" >> /home/${NEWUSER}/.bashrc
  echo "export MPI_ROOT=\"/usr/local/lib/openmpi\"" >> /tmp/bashrc.$$
  echo "export CPATH=\"/usr/local/include/openmpi:\$CPATH\"" >> /home/${NEWUSER}/.bashrc
  echo "export CPATH=\"/usr/local/include/openmpi:\$CPATH\"" >> /tmp/bashrc.$$
  echo "export LD_LIBRARY_PATH=\"/usr/local/lib/openmpi:\$LD_LIBRARY_PATH\"" >> /home/${NEWUSER}/.bashrc
  echo "export LD_LIBRARY_PATH=\"/usr/local/lib/openmpi:\$LD_LIBRARY_PATH\"" >> /tmp/bashrc.$$
  echo "export LIBRARY_PATH=\"/usr/local/lib/openmpi:\$LIBRARY_PATH\"" >> /home/${NEWUSER}/.bashrc
  echo "export LIBRARY_PATH=\"/usr/local/lib/openmpi:\$LIBRARY_PATH\"" >> /tmp/bashrc.$$
}

create_newuser_on_master_and_slave() {
  useradd -s /bin/bash ${NEWUSER}
}

create_etc_hosts() {
  echo $MASTER_IP $MASTER_NAME > /etc/hosts
  echo $MASTER_IP $MASTER_NAME > /tmp/hosts.$$
  echo $NFS_SERVER_IP $NFS_SERVER_NAME >> /etc/hosts
  echo $NFS_SERVER_IP $NFS_SERVER_NAME >> /tmp/hosts.$$
  i=0
  while [ $i -lt $NUMBER_OF_EXEC ]
  do
    workerip=`expr $i + $WORKER_IP_START`
    echo $WORKER_IP_BASE$workerip $WORKER_NAME$i >> /etc/hosts
    echo $WORKER_IP_BASE$workerip $WORKER_NAME$i >> /tmp/hosts.$$
    i=`expr $i + 1`
  done
}

setup_chainermn() {
  # check GPU device
  NVIDIA_DEVICE=$(lspci | grep -i NVIDIA)
  echo "$NVIDIA_DEVICE" > /tmp/gpu_check.$$
  if [ -z "$NVIDIA_DEVICE" ]; then
    echo "CPU node" >> /tmp/gpu_check.$$
  fi
  if [ -n "$NVIDIA_DEVICE" ]; then
    echo "GPU node" >> /tmp/gpu_check.$$
  fi

  #setup cuda (for GPU node)
  if [ -n "$NVIDIA_DEVICE" ]; then
    CUDA_REPO_PKG=cuda-repo-ubuntu1604_8.0.61-1_amd64.deb
    wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG}
    sudo dpkg -i /tmp/${CUDA_REPO_PKG}
    sudo apt-get update
    sudo apt-get install -y cuda-drivers
    sudo apt-get install -y cuda
    sudo nvidia-smi -pm 1 > /tmp/nvidia-smi.$$ 2>&1
  fi

  # setup libs
  sudo apt-get install -y git vim build-essential python-dev libgtk2.0-dev tmux byobu python-pip python3-pip libffi-dev

  # setup cudnn (for GPU node)
  if [ -n "$NVIDIA_DEVICE" ]; then
    cd /tmp
    curl http://developer.download.nvidia.com/compute/redist/cudnn/v6.0/cudnn-8.0-linux-x64-v6.0.tgz > cudnn-8.0-linux-x64-v6.0.tgz
    tar -zxf cudnn-8.0-linux-x64-v6.0.tgz
    sudo cp -a cuda/lib64/* /usr/local/cuda-8.0/lib64/
    sudo cp -a cuda/include/* /usr/local/cuda-8.0/include/
    # Bug fix start --
    #  reference https://askubuntu.com/questions/900285/libegl-so-1-is-not-a-symbolic-link
    sudo mv /usr/lib/nvidia-375/libEGL.so.1 /usr/lib/nvidia-375/libEGL.so.1.org
    sudo mv /usr/lib32/nvidia-375/libEGL.so.1 /usr/lib32/nvidia-375/libEGL.so.1.org
    sudo ln -s /usr/lib/nvidia-375/libEGL.so.375.39 /usr/lib/nvidia-375/libEGL.so.1
    sudo ln -s /usr/lib32/nvidia-375/libEGL.so.375.39 /usr/lib32/nvidia-375/libEGL.so.1
    # Bug fix end -- 
    sudo ldconfig > /tmp/ldconfig_cudnn.$$ 2>&1
  fi

  # setup nccl (for GPU node)
  if [ -n "$NVIDIA_DEVICE" ]; then
    cd /tmp
    mkdir nccl
    cd nccl
    git clone https://github.com/NVIDIA/nccl.git .
    make CUDA_HOME=/usr/local/cuda > /tmp/nccl.$$ 2>&1
    sudo make install >> /tmp/nccl.$$ 2>&1
  fi

  # setup openmpi
  OPENMPI_CUDA_OPTION=""
  if [ -n "$NVIDIA_DEVICE" ]; then
    OPENMPI_CUDA_OPTION="--with-cuda"
  fi
  echo $OPENMPI_CUDA_OPTION > /tmp/openmpi.$$ 2>&1
  cd /tmp
  mkdir -p /tmp/openmpi
  cd /tmp/openmpi
  wget https://www.open-mpi.org/software/ompi/v2.1/downloads/openmpi-2.1.0.tar.gz
  tar zxf openmpi-2.1.0.tar.gz
  cd openmpi-2.1.0
  ./configure $OPENMPI_CUDA_OPTION >> /tmp/openmpi.$$ 2>&1
  make -j4 all >> /tmp/openmpi.$$ 2>&1
  sudo make install >> /tmp/openmpi.$$ 2>&1

  # setup hostfile
  echo $MASTER_IP >> /usr/local/etc/openmpi-default-hostfile
  i=0
  while [ $i -lt $NUMBER_OF_EXEC ]
  do
    workerip=`expr $i + $WORKER_IP_START`
    echo $WORKER_IP_BASE$workerip  >> /usr/local/etc/openmpi-default-hostfile
    i=`expr $i + 1`
  done

  # setup cython
  sudo pip3 install cython > /tmp/cython.$$ 2>&1
  sudo ldconfig > /tmp/ldconfig_cython.$$ 2>&1

  # setup chainermn
  if [ -n "$NVIDIA_DEVICE" ]; then
    # for GPU node
    LDFLAGS="-L/usr/local/lib/openmpi -L/usr/local/lib" CFLAGS="-I/usr/local/cuda/include -I/usr/local/include" pip3 install git+https://github.com/pfnet/chainermn >> /tmp/chainermn.$$ 2>&1
  else
    # for CPU node
    cd /tmp
    git clone https://github.com/pfnet/chainermn
    cd chainermn
    LDFLAGS="-L/usr/local/lib/openmpi -L/usr/local/lib" CFLAGS="-I/usr/local/cuda/include -I/usr/local/include" python3 setup.py install --no-nccl >> /tmp/chainermn.$$ 2>&1
  fi
 }

# Create /tmp/setting.txt.$$
# deployer information
id > /tmp/setting.txt.$$ 2>&1
set >> /tmp/setting.txt.$$ 2>&1
# Basic info
date > /tmp/azuredeploy.log.$$ 2>&1
whoami >> /tmp/azuredeploy.log.$$ 2>&1
echo $@ >> /tmp/azuredeploy.log.$$ 2>&1

ROLE=$1
echo "Hello [$ROLE] world" > /tmp/helloworld.txt.$$ 2>&1
#
# Usage
if [ "${ROLE}" = "standalone" ];
then
  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 standalone" >> /tmp/azuredeploy.log.$$
    exit 1
  fi
else
  if [ "$#" -ne 11 ]; then
    echo "Usage: $0 master|exec MASTER_NAME MASTER_IP WORKER_NAME WORKER_IP_BASE WORKER_IP_START NFS_SERVER_NAME NFS_SERVER_IP NEWUSER NUMBER_OF_EXEC GENERAL_USER_SSH_KEY" >> /tmp/azuredeploy.log.$$
    exit 1
  fi
  ## Create /etc/hosts
  # MASTER_NAME MASTER_IP WORKER_NAME WORKER_IP_BASE WORKER_IP_START
  MASTER_NAME=$2
  MASTER_IP=$3
  WORKER_NAME=$4
  WORKER_IP_BASE=$5
  WORKER_IP_START=$6
  NFS_SERVER_NAME=$7
  NFS_SERVER_IP=$8
  NEWUSER=$9
  NUMBER_OF_EXEC=$10
  GENERAL_USER_SSH_KEY=$11
  # Create /etc/hosts
  create_etc_hosts
fi

# Install some files for Chef environments
sudo apt-get update
sudo apt-get install -y git curl

# Install ChefDK
curl -s --retry 3 -L https://www.opscode.com/chef/install.sh | sudo bash -s -- -P chefdk -v 1.2.20 > /tmp/chef.txt.$$ 2>&1

chef gem install knife-solo -v 0.6.0

# Install NFS common
sudo apt-get install -y nfs-common

# Check Ubuntu Version for chef
UBUNTUVERSION=$(lsb_release -cs)
SUFFIX=""
if [ "${UBUNTUVERSION}" = "xenial" ];
then
  SUFFIX="16.04."
fi
echo ${SUFFIX} >> /tmp/out

if [ "${ROLE}" = "master" ];
then
  # create newuser
  create_newuser_on_master_and_slave
  # mount home
  echo "${NFS_SERVER_IP}:/datadisks/disk1/home /home nfs rw 0 2" >> /etc/fstab
  mount /home
  # setup chainermn
  setup_chainermn
elif [ "${ROLE}" = "exec" ];
then
  # create newuser
  create_newuser_on_master_and_slave
  # mount home
  echo "${NFS_SERVER_IP}:/datadisks/disk1/home /home nfs rw 0 2" >> /etc/fstab
  mount /home
  # setup chainermn
  setup_chainermn
elif  [ "${ROLE}" = "nfsserver" ];
then
  echo "EXEC ${ROLE} == \"nfsserver\" " >> /tmp/out
  # Setup RAID disk
  curl -s -o /tmp/vm-disk-utils-0.1.sh https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
  chmod 755 /tmp/vm-disk-utils-0.1.sh
  bash /tmp/vm-disk-utils-0.1.sh -s -o defaults

　# do chef for NFS
  cd /tmp 
  mkdir nfssetup
  cd nfssetup/ 
  git clone https://github.com/satohiro/Chainer-MN-on-Azure.git .
  cd chef 
  HOME=/root berks vendor cookbooks >  /tmp/berks.txt.$$ 2>&1
  chef-client -j environments/nfsserver.${SUFFIX}json -z  > /tmp/chef-client.txt.$$ 2>&1
  # create newuser
  create_newuser_on_nfsserver > /tmp/create_newuser_on_nfsserver.txt.$$ 2>&1
  mv /home /datadisks/disk1
  ln -s /datadisks/disk1/home /home
else
  echo "EXEC ${ROLE} == \"other\" " >> /tmp/out
fi

exit 0
