#!/bin/sh

# Install CUDA driver and CUDA
CUDA_REPO_PKG=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG}
sudo dpkg -i /tmp/${CUDA_REPO_PKG}
sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
rm -f /tmp/${CUDA_REPO_PKG}
sudo apt-get update
sudo apt-get install -y cuda-drivers
sudo apt-get install -y cuda-8-0

# Install Python3
sudo apt-get install -y ccache python3 python3-pip
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10

# Set environment variables
echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
echo 'export LC_CTYPE=en_US.UTF-8' >> ~/.bashrc
exec $SHELL

# Install cuDNN
pip install --user cudnnenv
cudnnenv install v7.0.5-cuda8
echo 'export LD_LIBRARY_PATH=~/.cudnn/active/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
echo 'export CPATH=~/.cudnn/active/cuda/include:$CPATH' >> ~/.bashrc
echo 'export LIBRARY_PATH=~/.cudnn/active/cuda/lib64:$LIBRARY_PATH' >> ~/.bashrc
exec $SHELL

# Install cupy, chainer
pip install --user cython
pip install --user cupy==2.4.0
pip install --user chainer==3.4.0

# Install NCCL1
git clone https://github.com/NVIDIA/nccl.git
cd nccl
make CUDA_HOME=/usr/local/cuda-8-0 test
sudo make install
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
echo 'export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH' >> ~/.bashrc
echo 'export CPATH=/usr/local/include:$CPATH' >> ~/.bashrc

# Setup RDMA network
sudo apt-get update
sudo apt-get install -y libdapl2 libmlx4-1
sudo sed -i -E "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" /etc/waagent.conf
sudo sed -i -E "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" /etc/waagent.conf
echo " *               hard    memlock          unlimited" | sudo tee -a /etc/security/limits.conf
echo " *               soft    memlock          unlimited" | sudo tee -a /etc/security/limits.conf

# Install IntelMPI
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/11595/l_mpi_2017.3.196.tgz
tar zxvf l_mpi_2017.3.196.tgz
rm -rf l_mpi_2017.3.196.tgz
cd l_mpi_2017.3.196
sudo sed -i -e "s/decline/accept/g" silent.cfg
sudo ./install.sh --silent silent.cfg
echo 0 | sudo tee -a /proc/sys/kernel/yama/ptrace_scope
echo 'source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh' | tee -a ~/.bashrc
echo 'export I_MPI_FABRICS=shm:dapl' | tee -a ~/.bashrc
echo 'export I_MPI_DAPL_PROVIDER=ofa-v2-ib0' | tee -a ~/.bashrc
echo 'export I_MPI_DYNAMIC_CONNECTION=0' | tee -a ~/.bashrc
echo 'export I_MPI_FALLBACK_DEVICE=0' | tee -a ~/.bashrc
echo 'export I_MPI_DAPL_TRANSLATION_CACHE=0' | tee -a ~/.bashrc
exec $SHELL

pip install --user chainermn==1.2.0
sudo reboot