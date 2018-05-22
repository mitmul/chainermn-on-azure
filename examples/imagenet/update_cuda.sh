#!/bin/bash

apt-get purge -y cuda-8-0
apt-get install -y cuda
apt-get install -y parallel
apt autoremove -y

cd /usr/local
rm -rf /usr/local/cuda
rm -rf /usr/local/cuda-8.0
ln -s /usr/local/cuda-9.2 /usr/local/cuda
curl -L -O http://developer.download.nvidia.com/compute/redist/cudnn/v7.1.4/cudnn-9.2-linux-x64-v7.1.tgz
tar zxf cudnn-9.2-linux-x64-v7.1.tgz
rm -rf cudnn-9.2-linux-x64-v7.1.tgzp

cd /opt/nccl
rm -rf build
make
make install

pip uninstall -y cupy
cd /opt/cupy-4.0.0
rm -rf build
python setup.py install

source /share/home/hpcuser/.bash_profile && \
python -c 'import chainer;chainer.print_runtime_info()'
