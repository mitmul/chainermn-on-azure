#!/bin/bash

#############################################################################
is_ubuntu()
{
	python -mplatform | grep -qi Ubuntu
	return $?
}

is_centos()
{
	python -mplatform | grep -qi CentOS
	return $?
}

check_infini()
{
echo "\n\n check_infini \n\n"
if is_ubuntu; then 
	sudo modprobe rdma_ucm
	return $?
fi
if is_centos; then
	ibv_devices | grep mlx4
	return $?
fi
}

check_gpu()
{
	echo "\n\n check_gpu \n\n"
	lspci | grep NVIDIA
	return $?
}


enable_rdma()
{
	   # enable rdma    
	   cd /etc/
	   echo "OS.EnableRDMA=y">>/etc/waagent.conf
	   echo "OS.UpdateRdmaDriver=y">>/etc/waagent.conf
	   #sudo sed -i  "s/# OS.EnableRDMA=y/OS.EnableRDMA=y/g" /etc/waagent.conf
	   #sudo sed -i  "s/# OS.UpdateRdmaDriver=y/OS.UpdateRdmaDriver=y/g" /etc/waagent.conf
}

install_intel_mpi()
{

		if [ ! -d /opt/l_mpi_2017.3.196 ]; then
			cd /opt
			sudo mv intel intel_old
			sudo curl -L -O http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/11595/l_mpi_2017.3.196.tgz
			sudo tar zxvf l_mpi_2017.3.196.tgz
			sudo rm -rf l_mpi_2017.3.196.tgz
			cd l_mpi_2017.3.196
			sudo sed -i -e "s/decline/accept/g" silent.cfg
			sudo ./install.sh --silent silent.cfg
		fi

		if grep -q "I_MPI" ~/.bashrc; then :; else
			echo 'export I_MPI_FABRICS=shm:dapl' >> ~/.bashrc
			echo 'export I_MPI_DAPL_PROVIDER=ofa-v2-ib0' >> ~/.bashrc
			echo 'export I_MPI_DYNAMIC_CONNECTION=0' >> ~/.bashrc
			echo 'export I_MPI_FALLBACK_DEVICE=0' >> ~/.bashrc
			echo 'export I_MPI_DAPL_TRANSLATION_CACHE=0' >> ~/.bashrc
			echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc			
			echo 'source /opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/intel64/bin/mpivars.sh' >> ~/.bashrc
		fi
}

install_Chainer()
{
	cd /usr/local
	#install numpy and six required version as chainer is dependent on numpy
	#install_cython_protobuf #required for numpy/six/cupy
	pip install -U cython
	sudo curl -L -O https://pypi.python.org/packages/b2/30/ab593c6ae73b45a5ef0b0af24908e8aec27f79efcda2e64a3df7af0b92a2/protobuf-3.1.0-py2.py3-none-any.whl ##md5=f02742e46128f1e0655b44c33d8c9718
	pip install protobuf-3.1.0-py2.py3-none-any.whl
	
	#install_numpy
	cd /usr/local
	sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/numpy-1.13.3.tar.gz
	sudo tar -zxf numpy-1.13.3.tar.gz
	cd numpy-1.13.3
	#sudo python setup.py install
	python setup.py install
	
	#install_six
	cd /usr/local
	sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/six-1.11.0.tar.gz
	sudo tar -zxf six-1.11.0.tar.gz
	cd six-1.11.0
	python3 setup.py install	
	#if none of above commands work it will update six to 1.11.0
	easy_install --upgrade six
	
	#install_cupy
	cd /usr/local
	#may require NCCL first
	sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/cupy-2.2.0.tar.gz
	sudo tar -zxf cupy-2.2.0.tar.gz
	cd cupy-2.2.0
	PATH=/usr/local/cuda/bin:$PATH CUDA_PATH=/usr/local/cuda python3 setup.py install 
	
	#pip install chainer
	cd /usr/local
	sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/chainer-3.2.0.tar.gz
	sudo tar -zxf chainer-3.2.0.tar.gz
	cd chainer-3.2.0
	python3 setup.py install #install from root works well too
	#pip install chainer #works_fine_and_installs Chainer 3.2.0	
}

install_chainermn()
{
	#CFLAGS="-I/usr/local/cuda/include" pip install git+https://github.com/chainer/chainermn --version 1.1.0
	if is_centos; then
	sudo cp /opt/nccl/build/include/nccl.h /usr/local/cuda/include
	fi
	
	cd /usr/local
	CFLAGS="-I /usr/local/cuda/include" pip install chainermn==1.1.0
	# PKG_Name=chainermn-1.1.0.tar.gz
	# sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${PKG_Name}
	# tar -zxf ${PKG_Name}
	# cd ${PKG_Name::-7}
	#CFLAGS="-I /usr/local/cuda/include" python setup.py install
}

setup_chainermn_gpu()
{ 
echo "\n\n\n\n\n\n\n\n\n\n setup_chainermn_gpu_ NON INFINIBAND \n\n\n\n\n\n\n\n"
		if is_ubuntu; then
		sudo apt-get update
		sudo apt-get install git
		fi
		if is_centos; then
		yum -y install git-all
		sudo nvidia-smi -pm 1	
		fi

		if [ ! -d /opt/anaconda3 ]; then
			cd /opt
			#anaconda_3_5.0.1
			PKG_Name=Anaconda3-5.0.1-Linux.sh.gz
			sudo curl -L -O https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${PKG_Name}
			gzip -d ${PKG_Name}			
			sudo bash ${PKG_Name::-3} -b -p /opt/anaconda3
			sudo chown hpcuser:hpc -R anaconda3
			source /opt/anaconda3/bin/activate			
		fi

		if grep -q "anaconda" ~/.bashrc; then :; else
			echo 'source /opt/anaconda3/bin/activate' >> ~/.bashrc
		fi

		#NCCL package # for ubuntu : 2.1 # for centos 1.3.4
		if [ ! -d /opt/nccl ]; then
			cd /opt/nccl
			if is_ubuntu; then				
				sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/libnccl2_2.1.2-1+cuda9.0_amd64.deb
				sudo dpkg -i libnccl2_2.1.2-1+cuda9.0_amd64.deb
				sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/libnccl-dev_2.1.2-1+cuda9.0_amd64.deb
				sudo dpkg -i libnccl-dev_2.1.2-1+cuda9.0_amd64.deb
			fi
			if is_centos; then
				#Working using tar file
				sudo wget   https://pfnresources.blob.core.windows.net/chainermn-v1-packages/nccl-1.3.4-1.tar.gz
				tar -zxf nccl-1.3.4-1.tar.gz
				mv nccl-1.3.4-1 nccl
				cd nccl && sudo make -j && sudo make install
				
			fi			
		fi

		if grep -q "LD_LIBRARY_PATH" ~/.bashrc; then :; else
			echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
		fi


		#cudnn 
		if [ ! -f /usr/local/cuda/include/cudnn.h ]; then
			cd /usr/local
			if is_centos; then			
			CUDNN_PKG_NAME=cudnn-8.0-linux-x64-v6.0.tgz.gz
			sudo curl -L -O https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${CUDNN_PKG_NAME}
			gzip -d ${CUDNN_PKG_NAME}
			sudo tar zxvf ${CUDNN_PKG_NAME::-3}
			sudo rm -rf ${CUDNN_PKG_NAME::-3}
			
			PKG_Name=libcudnn7_7.0.5.15-1+cuda8.0_amd64.deb.gz
			sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${PKG_Name}
			gzip -d ${PKG_Name}
			sudo dpkg -i ${PKG_Name::-3}
			fi			
			if is_ubuntu; then
			PKG_Name=libcudnn7_7.0.5.15-1+cuda9.0_amd64.deb.gz
			sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${PKG_Name}
			gzip -d ${PKG_Name}
			sudo dpkg -i ${PKG_Name::-3}
			fi
		fi
					
		#install Chainer V3.1.0
		install_Chainer
		
		MPICC=/opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/intel64/bin/mpicc pip install mpi4py --no-cache-dir
		#CFLAGS="-I/usr/local/cuda/include" pip install git+https://github.com/chainer/chainermn@non-cuda-aware-comm
		
		install_chainermn
		alias python=python3		
		#CFLAGS="-I/usr/local/cuda/include" pip install git+https://github.com/chainer/chainermn@non-cuda-aware-comm	
		sudo nvidia-smi -pm 1		
}

setup_chainermn_gpu_infiniband()
{
echo "\n\n\n\n\n\n\n\n setup_chainermn_gpu_infiniband \n\n\n\n\n\n\n\n"
		if is_ubuntu; then
			sudo apt-get update
			sudo apt-get install git
		fi
		if is_centos; then
			echo "\n\nInstalling Hyper-V-RDMA \n\n"
			yum reinstall -y /opt/microsoft/rdma/rhel73/kmod-microsoft-hyper-v-rdma-4.2.2.144-20170706.x86_64.rpm
			yum -y install git-all
			sudo nvidia-smi -pm 1
			echo "\n\n Hyper-V-RDMA installed !!"
		fi	
		
		if [ ! -d /opt/anaconda3 ]; then
			cd /opt
			#anaconda_3_5.0.1
			PKG_Name=Anaconda3-5.0.1-Linux.sh.gz
			sudo curl -L -O https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${PKG_Name}
			gzip -d ${PKG_Name}			
			sudo bash ${PKG_Name::-3} -b -p /opt/anaconda3
			sudo chown hpcuser:hpc -R anaconda3
			source /opt/anaconda3/bin/activate			
		fi

		if grep -q "anaconda" ~/.bashrc; then :; else
			echo 'source /opt/anaconda3/bin/activate' >> ~/.bashrc
		fi
		
		#NCCL package # for ubuntu : 2.1 # for centos 1.3.4
		if [ ! -d /opt/nccl ]; then
			cd /opt/nccl
			if is_ubuntu; then				
				sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/libnccl2_2.1.2-1+cuda9.0_amd64.deb
				sudo dpkg -i libnccl2_2.1.2-1+cuda9.0_amd64.deb
				sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/libnccl-dev_2.1.2-1+cuda9.0_amd64.deb
				sudo dpkg -i libnccl-dev_2.1.2-1+cuda9.0_amd64.deb
			fi
			if is_centos; then
				#Working using tar file
				cd /opt
				sudo wget   https://pfnresources.blob.core.windows.net/chainermn-v1-packages/nccl-1.3.4-1.tar.gz
				tar -zxf nccl-1.3.4-1.tar.gz
				mv nccl-1.3.4-1 nccl
				cd nccl && sudo make -j && sudo make install
				cp /opt/nccl/build/include/nccl.h /usr/local/cuda/include
				export "PATH=/opt/nccl/build/include:$PATH"				
			fi			
		fi

		if grep -q "LD_LIBRARY_PATH" ~/.bashrc; then :; else
			echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
		fi
		
		#cudnn 7.0.4
		if [ ! -f /usr/local/cuda/include/cudnn.h ]; then
			cd /usr/local
			if is_centos; then
			
			CUDNN_PKG_NAME=cudnn-8.0-linux-x64-v6.0.tgz.gz
			sudo curl -L -O https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${CUDNN_PKG_NAME}
			gzip -d ${CUDNN_PKG_NAME}
			sudo tar zxvf ${CUDNN_PKG_NAME::-3}
			sudo rm -rf ${CUDNN_PKG_NAME::-3}
			
			PKG_Name=libcudnn7_7.0.5.15-1+cuda8.0_amd64.deb.gz
			sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${PKG_Name}
			gzip -d ${PKG_Name}
			sudo dpkg -i ${PKG_Name::-3}
			fi			
			if is_ubuntu; then
			PKG_Name=libcudnn7_7.0.5.15-1+cuda9.0_amd64.deb.gz
			sudo curl -L -O  https://pfnresources.blob.core.windows.net/chainermn-v1-packages/${PKG_Name}
			gzip -d ${PKG_Name}
			sudo dpkg -i ${PKG_Name::-3}
			fi
			#Copy CUDNN files to required locaiton			
			sudo cp cuda/include/cudnn.h /usr/local/cuda/include 
			sudo cp cuda/lib64/libcudnn* /usr/local/cuda/lib64
			chmod a+r /usr/local/cuda/include/cudnn.h /usr/local/cuda/lib64/libcudnn*
		fi
		
		#install Chainer V3.1.0
		install_Chainer
		
		MPICC=/opt/intel/compilers_and_libraries_2017.4.196/linux/mpi/intel64/bin/mpicc pip install mpi4py --no-cache-dir
		install_chainermn
		alias python=python3

echo "\n\n setup_chainermn_gpu_infiniband completed \n\n=========================\n\n"	
}

if check_gpu;then
	if check_infini;then
		enable_rdma
		#Code to setup ChainerMN on GPU based machine with infinband
		setup_chainermn_gpu_infiniband
		sudo nvidia-smi -pm 1
		echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
		if is_centos; then
		#"Install Infiniband and related packages"
		sudo yum groupinstall -y "Infiniband Support"
		sudo yum install -y infiniband-diags perftest qperf opensm git libverbs-devel 
		sudo chkconfig rdma on
		sudo chkconfig opensm on
		sudo service rdma start
		sudo service opensm start		
		sudo nvidia-smi -pm 1
		fi
		
		#install_Intel _MPI
		install_intel_mpi
		
		if is_centos; then
		create_cron_job()
		{
			# Register cron tab so when machine restart it downloads the secret from azure downloadsecret
			crontab -l > downloadsecretcron
			echo '@reboot /root/rdma-autoload.sh >> /root/execution.log' >> downloadsecretcron
			crontab downloadsecretcron
			rm downloadsecretcron
		}
		echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
		create_cron_job
		fi
		
	else 
		#Code to setup ChainerMN on GPU based machine
		#enable_rdma
		setup_chainermn_gpu	
		#install_Intel _MPI
		install_intel_mpi		
		sudo nvidia-smi -pm 1
		mv /var/lib/waagent/custom-script/download/1/rdma-autoload.sh ~
		create_cron_job()
		{
			# Register cron tab so when machine restart it downloads the secret from azure downloadsecret
			crontab -l > downloadsecretcron
			echo '@reboot /root/rdma-autoload.sh >> /root/execution.log' >> downloadsecretcron
			crontab downloadsecretcron
			rm downloadsecretcron
		}
		echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
		create_cron_job
	fi
else
	if check_infini;then
		echo "CPU with Infini"
	else
		echo "CPU only"
	fi
fi

shutdown -r +1
