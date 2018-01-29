#!/bin/bash

CUPY_VERSION=2.2.0
CHAINER_VERSION=3.2.0
CHAINERMN_VERSION=1.0.0

check_gpu()
{
	lspci | grep NVIDIA
	return $?
}

setup_chainermn()
{
	sudo apt-get update
	sudo apt-get install -y git

	# Install Intel MPI
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

	# Install Anaconda3
	if [ ! -d /opt/anaconda3 ]; then
		cd /opt
		sudo curl -L -O https://repo.continuum.io/archive/Anaconda3-5.0.1-Linux-x86_64.sh
		sudo bash Anaconda3-5.0.1-Linux-x86_64.sh -b -p /opt/anaconda3
		sudo rm -rf Anaconda3-5.0.1-Linux-x86_64.sh
		sudo chown -R hpcuser:hpc /opt/anaconda3
		source /opt/anaconda3/bin/activate
	fi
	
	sudo su - hpcuser
	source ~/.bashrc

	pip install cupy==${CUPY_VERSION}
	pip install chainer==${CHAINER_VERSION}
	pip install mpi4py --no-cache-dir
	CFLAGS="-I/usr/local/cuda/include" pip install git+https://github.com/chainer/chainermn
	sudo su -
}

create_cron_job()
{
	# Register cron tab so when machine restart it downloads the secret from azure downloadsecret
	crontab -l > downloadsecretcron
	echo '@reboot /root/rdma-autoload.sh >> /root/execution.log' >> downloadsecretcron
	crontab downloadsecretcron
	rm downloadsecretcron
}

if check_gpu; then
	
	setup_chainermn	
	
	mv /var/lib/waagent/custom-script/download/1/rdma-autoload.sh ~
	echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
	create_cron_job
fi

shutdown -r +1
