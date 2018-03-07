#!/bin/sh

# Install Python3
apt-get install -y ccache python3 python3-pip
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10

# Set environment variables
echo 'export LANG=en_US.UTF-8' | tee -a /home/ubuntu/.bashrc
echo 'export LC_CTYPE=en_US.UTF-8' | tee -a /home/ubuntu/.bashrc

# Install IntelMPI
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/11595/l_mpi_2017.3.196.tgz
tar zxvf l_mpi_2017.3.196.tgz
rm -rf l_mpi_2017.3.196.tgz
cd l_mpi_2017.3.196
sed -i -e "s/decline/accept/g" silent.cfg
./install.sh --silent silent.cfg
echo 'source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh' | tee -a /home/ubuntu/.bashrc
exec $SHELL

