#!/bin/bash

CUPY_VERSION=2.3.0
CHAINER_VERSION=3.3.0
CHAINERMN_VERSION=1.1.0

check_gpu()
{
	lspci | grep NVIDIA
	return $?
}

setup_mkl()
{
	if [ ! -d l_mkl_2018.1.163 ]; then
		cd /opt
		sudo curl -L -O http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/12414/l_mkl_2018.1.163.tgz
		sudo tar zxvf l_mkl_2018.1.163.tgz
		sudo rm -rf l_mkl_2018.1.163.tgz
		cd l_mkl_2018.1.163
		sudo sed -i -e "s/decline/accept/g" silent.cfg
		sudo ./install.sh --silent silent.cfg
		source /opt/intel/compilers_and_libraries/linux/mkl/bin/mklvars.sh intel64
	fi
	if [ ! -f /etc/profile.d/intel_mkl.sh ]; then
		echo 'source /opt/intel/compilers_and_libraries/linux/mkl/bin/mklvars.sh intel64' >> /etc/profile.d/intel_mkl.sh
	fi
}

setup_python()
{
	sudo apt-get update -y && \
	sudo apt-get install -y \
	python3-dev \
	python3-dbg \
	python3-pip \
	python3-wheel \
	python3-setuptools \
	cmake \
	cmake-curses-gui \
	git

	sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
	sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10
	sudo pip install --upgrade pip

	sudo su hpcuser && \
	echo '[mkl]' >> ~/.numpy-site.cfg && \
	echo 'library_dirs = /opt/intel/mkl/lib/intel64' >> ~/.numpy-site.cfg && \
	echo 'include_dirs = /opt/intel/mkl/include' >> ~/.numpy-site.cfg && \
	echo 'mkl_libs = mkl_rt' >> ~/.numpy-site.cfg && \
	echo 'lapack_libs =' >> ~/.numpy-site.cfg && \
	pip install --no-binary :all: numpy
}

setup_intel_mpi()
{
	if [ ! -d /opt/l_mpi_2018.1.163 ]; then
		cd /opt
		sudo curl -L -O http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/12414/l_mpi_2018.1.163.tgz
		sudo tar zxvf l_mpi_2018.1.163.tgz
		sudo rm -rf l_mpi_2018.1.163.tgz
		cd l_mpi_2018.1.163
		sudo sed -i -e "s/decline/accept/g" silent.cfg
		sudo ./install.sh --silent silent.cfg
		source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh
	fi
	if [ ! -f /etc/profile.d/intel_mpi.sh ]; then
		echo 'export I_MPI_FABRICS=shm:dapl' >> /etc/profile.d/intel_mpi.sh
		echo 'export I_MPI_DAPL_PROVIDER=ofa-v2-ib0' >> /etc/profile.d/intel_mpi.sh
		echo 'export I_MPI_DYNAMIC_CONNECTION=0' >> /etc/profile.d/intel_mpi.sh
		echo 'export I_MPI_FALLBACK_DEVICE=0' >> /etc/profile.d/intel_mpi.sh
		echo 'source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh' >> /etc/profile.d/intel_mpi.sh
		echo 'echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope' >> /etc/profile.d/intel_mpi.sh
	fi
}

setup_chainermn()
{	
	sudo su - hpcuser && \
	source ~/.bashrc && \
	pip install cupy==${CUPY_VERSION} && \
	pip install chainer==${CHAINER_VERSION} && \
	pip install mpi4py && \
	CFLAGS="-I/usr/local/cuda/include" pip install git+https://github.com/chainer/chainermn
}

create_cron_job()
{
	# Register cron tab so when machine restart it downloads the secret from azure downloadsecret
	crontab -l > downloadsecretcron
	echo '@reboot /root/rdma-autoload.sh >> /root/execution.log' >> downloadsecretcron
	crontab downloadsecretcron
	rm downloadsecretcron
}

setup_mkl
setup_python
setup_intel_mpi
setup_chainermn	

mv /var/lib/waagent/custom-script/download/1/rdma-autoload.sh ~
echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
create_cron_job

shutdown -r +1
