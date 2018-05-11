#!/bin/bash -xe

CUPY_VERSION=4.0.0
CHAINER_VERSION=4.0.0

# Setup hpcuser
HPC_USER=hpcuser
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007
groupadd -g $HPC_GID $HPC_GROUP

# sudo setting
echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

# Setup shared home dir
SHARE_HOME=/share/home
DISK_MOUNT=/data1
MASTER_NAME=jumpbox
apt-get update
apt-get -y install nfs-common
mkdir -p $SHARE_HOME
mkdir -p $DISK_MOUNT
echo "$MASTER_NAME:$SHARE_HOME $SHARE_HOME    nfs defaults,nofail  0 0" | tee -a /etc/fstab
echo "$MASTER_NAME:$DISK_MOUNT $DISK_MOUNT    nfs defaults,nofail  0 0" | tee -a /etc/fstab
showmount -e ${MASTER_NAME}
mount -a
mount

# Create user
useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

# Install CUDA driver and CUDA
CUDA_REPO_PKG=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG}
dpkg -i /tmp/${CUDA_REPO_PKG}
apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
rm -f /tmp/${CUDA_REPO_PKG}
apt-get update
apt-get install -y cuda-drivers
apt-get install -y cuda-8-0

# Install Python3
apt-get install -y ccache python3 python3-dev python3-dbg python3-wheel python3-pip python3-cffi python3-setuptools
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10

# Install packages for OpenCV build
apt-get update -y && apt-get install -y \
curl git build-essential gfortran nasm tmux sudo openssh-client libgoogle-glog-dev rsync curl wget cmake automake libgmp3-dev cpio libtool libyaml-dev realpath valgrind software-properties-common unzip libz-dev vim emacs libssl-dev libffi-dev

# Install Intel MKL
cd /opt
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/12725/l_mkl_2018.2.199.tgz && \
tar zxvf l_mkl_2018.2.199.tgz && rm -rf l_mkl_2018.2.199.tgz && \
cd l_mkl_2018.2.199 && \
sed -i -E "s/ACCEPT_EULA=decline/ACCEPT_EULA=accept/g" silent.cfg && \
./install.sh -s silent.cfg
source /opt/intel/compilers_and_libraries_2018.2.199/linux/mkl/bin/mklvars.sh intel64

# Install numpy & scipy with mkl backend
echo "[mkl]" >> $HOME/.numpy-site.cfg
echo "library_dirs = /opt/intel/compilers_and_libraries_2018.2.199/linux/mkl/lib/intel64" >> $HOME/.numpy-site.cfg
echo "include_dirs = /opt/intel/compilers_and_libraries_2018.2.199/linux/mkl/include" >> $HOME/.numpy-site.cfg
echo "mkl_libs = mkl_rt" >> $HOME/.numpy-site.cfg
echo "lapack_libs =" >> $HOME/.numpy-site.cfg
pip install --no-binary :all: numpy
pip install --no-binary :all: scipy

# Install libjpeg-turbo
cd /opt
mkdir libjpeg-turbo && cd libjpeg-turbo
wget https://jaist.dl.sourceforge.net/project/libjpeg-turbo/1.5.1/libjpeg-turbo-1.5.1.tar.gz && \
tar zxvf libjpeg-turbo-1.5.1.tar.gz && \
rm -rf libjpeg-turbo-1.5.1.tar.gz && \
cd libjpeg-turbo-1.5.1 && \
./configure --prefix=${HOME} && \
make -j$(nproc) && \
make install

# Install OpenCV with libjpeg-turbo
cd /opt
mkdir opencv && cd opencv
wget https://github.com/opencv/opencv/archive/3.4.1.tar.gz && \
tar zxvf 3.4.1.tar.gz && rm -rf 3.4.1.tar.gz && \
wget https://github.com/opencv/opencv_contrib/archive/3.4.1.tar.gz && \
tar zxvf 3.4.1.tar.gz && rm -rf 3.4.1.tar.gz && \
mkdir build && cd build && \
cmake \
-DCMAKE_BUILD_TYPE=RELEASE \
-DCMAKE_INSTALL_PREFIX=/usr/local \
-DWITH_TBB=ON \
-DWITH_EIGEN=OFF \
-DWITH_FFMPEG=ON \
-DWITH_QT=OFF \
-DWITH_OPENCL=OFF \
-DWITH_CUDA=ON \
-DCUDA_ARCH_BIN=6.0 \
-DCUDA_ARCH_PTX= \
-DWITH_JPEG=ON \
-DBUILD_JPEG=OFF \
-DJPEG_INCLUDE_DIR=${HOME}/include \
-DJPEG_LIBRARY=${HOME}/lib/libjpeg.so \
-DOPENCV_EXTRA_MODULES_PATH=/opt/opencv/opencv_contrib-3.4.1/modules \
-DBUILD_opencv_python3=ON \
-DPYTHON3_EXECUTABLE=$(which python3) \
-DPYTHON3_INCLUDE_DIR=$(python3 -c 'from distutils.sysconfig import get_python_inc; print(get_python_inc())') \
-DPYTHON3_NUMPY_INCLUDE_DIRS=$(python3 -c 'import numpy; print(numpy.get_include())') \
-DPYTHON3_LIBRARY="/usr/lib/x86_64-linux-gnu/libpython3.5m.so" \
-DPYTHON_INCLUDE_DIR=$(python3 -c 'from distutils.sysconfig import get_python_inc; print(get_python_inc())') \
-DPYTHON_LIBRARY="/usr/lib/x86_64-linux-gnu/libpython3.5m.so" \
/opt/opencv/opencv-3.4.1 && \
make -j8 && \
make install

# Install Python packages
pip install --no-cache-dir \
ipython \
jupyter \
cython \
matplotlib \
scikit-learn \
pandas

# Install cuDNN
cd /usr/local
curl -L -O http://developer.download.nvidia.com/compute/redist/cudnn/v7.0.5/cudnn-8.0-linux-x64-v7.tgz
tar zxvf cudnn-8.0-linux-x64-v7.tgz
rm -rf cudnn-8.0-linux-x64-v7.tgz

# Install NCCL1
cd /opt
git clone https://github.com/NVIDIA/nccl.git
cd nccl
make CUDA_HOME=/usr/local/cuda test
make install

# Install cupy, chainer
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
pip install cython
cd /opt
wget https://github.com/cupy/cupy/archive/v${CUPY_VERSION}.tar.gz
tar zxvf v${CUPY_VERSION}.tar.gz
rm -rf v${CUPY_VERSION}.tar.gz
cd cupy-${CUPY_VERSION}
python setup.py install
pip install chainer==${CHAINER_VERSION}

# Setup RDMA network
apt-get update
apt-get install -y libdapl2 libmlx4-1
sed -i -E "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" /etc/waagent.conf
sed -i -E "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" /etc/waagent.conf
echo " *               hard    memlock          unlimited" | tee -a /etc/security/limits.conf
echo " *               soft    memlock          unlimited" | tee -a /etc/security/limits.conf

# Install IntelMPI
apt-get install -y cpio
cd /opt
curl -L -O http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/9278/l_mpi_p_5.1.3.223.tgz
tar zxvf l_mpi_p_5.1.3.223.tgz
rm -rf l_mpi_p_5.1.3.223.tgz
cd l_mpi_p_5.1.3.223
sed -i -e "s/decline/accept/g" silent.cfg
sed -i -e "s/exist_lic/trial_lic/g" silent.cfg
./install.sh --silent silent.cfg
source /opt/intel/compilers_and_libraries_2016.3.223/linux/mpi/bin64/mpivars.sh

# Install ChainerMN
pip install mpi4py
cd /opt
git clone https://github.com/chainer/chainermn.git
cd chainermn
python setup.py install

# Register cron tab so when machine restart it downloads the secret from azure downloadsecret
mv /var/lib/waagent/custom-script/download/1/rdma-autoload.sh ~
crontab -l > downloadsecretcron
echo '@reboot /root/rdma-autoload.sh >> /root/execution.log' >> downloadsecretcron
crontab downloadsecretcron
rm downloadsecretcron

# Install Azure CLI
pip install azure-cli

shutdown -r +1
