#!/bin/bash

# Install CUDA driver and CUDA
CUDA_REPO_PKG=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG}
dpkg -i /tmp/${CUDA_REPO_PKG}
apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
rm -f /tmp/${CUDA_REPO_PKG}
apt-get update
apt-get install -y cuda-drivers
apt-get install -y cuda-8-0
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' | tee -a /home/ubuntu/.bashrc
echo 'export CPATH=/usr/local/cuda/include:$CPATH' | tee -a /home/ubuntu/.bashrc
echo 'export LIBRARY_PATH=/usr/local/cuda/lib64:$LIBRARY_PATH' | tee -a /home/ubuntu/.bashrc
echo 'export PATH=/usr/local/cuda/bin:$PATH' | tee -a /home/ubuntu/.bashrc
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export CPATH=/usr/local/include:$CPATH
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH
export PATH=/usr/local/cuda/bin:$PATH

# Install Python3
apt-get install -y ccache python3 python3-pip python3-cffi
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10

# Set environment variables
echo 'export LANG=en_US.UTF-8' | tee -a /home/ubuntu/.bashrc
echo 'export LC_CTYPE=en_US.UTF-8' | tee -a /home/ubuntu/.bashrc

# Install cuDNN
cd /usr/local
curl -L -O http://developer.download.nvidia.com/compute/redist/cudnn/v7.0.5/cudnn-8.0-linux-x64-v7.tgz
tar zxvf cudnn-8.0-linux-x64-v7.tgz
rm -rf cudnn-8.0-linux-x64-v7.tgz

# Install cupy, chainer
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
pip install cython
cd /opt
git clone https://github.com/cupy/cupy
cd cupy
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
PATH=/usr/local/bin:/usr/local/cuda/bin:$PATH \
CPATH=/usr/local/include:$CPATH \
LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH \
python setup.py install
git clone https://github.com/chainer/chainer
python setup.py install

# Install NCCL1
cd /opt
git clone https://github.com/NVIDIA/nccl.git
cd nccl
make CUDA_HOME=/usr/local/cuda-8-0 test
make install

# Setup RDMA network
apt-get update
apt-get install -y libdapl2 libmlx4-1
sed -i -E "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" /etc/waagent.conf
sed -i -E "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" /etc/waagent.conf
echo " *               hard    memlock          unlimited" | tee -a /etc/security/limits.conf
echo " *               soft    memlock          unlimited" | tee -a /etc/security/limits.conf

# Install IntelMPI
cd /opt
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/11595/l_mpi_2017.3.196.tgz
tar zxvf l_mpi_2017.3.196.tgz
rm -rf l_mpi_2017.3.196.tgz
cd l_mpi_2017.3.196
sed -i -e "s/decline/accept/g" silent.cfg
./install.sh --silent silent.cfg
echo 0 | tee -a /proc/sys/kernel/yama/ptrace_scope
echo 'source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh' | tee -a /home/ubuntu/.bashrc
echo 'export I_MPI_FABRICS=shm:dapl' | tee -a /home/ubuntu/.bashrc
echo 'export I_MPI_DAPL_PROVIDER=ofa-v2-ib0' | tee -a /home/ubuntu/.bashrc
echo 'export I_MPI_DYNAMIC_CONNECTION=0' | tee -a /home/ubuntu/.bashrc
echo 'export I_MPI_FALLBACK_DEVICE=0' | tee -a /home/ubuntu/.bashrc
echo 'export I_MPI_DAPL_TRANSLATION_CACHE=0' | tee -a /home/ubuntu/.bashrc
echo 'echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope' | tee -a /home/ubuntu/.bashrc
exec $SHELL

# Install ChainerMN
cd /opt
git clone https://github.com/chainer/chainermn
cd chainermn
LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/intel64/lib:$LD_LIBRARY_PATH \
PATH=/opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/intel64/bin:$PATH \
CPATH=/opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/include64:$CPATH \
pip install mpi4py
LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/intel64/lib:$LD_LIBRARY_PATH \
PATH=/opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/intel64/bin:$PATH \
CPATH=/opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/include64:$CPATH \
python setup.py install

# Add .ssh/config
echo 'Host *' | tee -a /home/ubuntu/.ssh/config
echo '    StrictHostKeyChecking no' | tee -a /home/ubuntu/.ssh/config
