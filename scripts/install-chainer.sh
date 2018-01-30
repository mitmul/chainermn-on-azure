#!/bin/bash

CUPY_VERSION=2.3.0
CHAINER_VERSION=3.3.0
CHAINERMN_VERSION=1.1.0

# Shares
SHARE_HOME=/share/home
HPC_USER=hpcuser
HPC_GROUP=hpc

check_gpu()
{
	lspci | grep NVIDIA
	return $?
}

setup_mkl()
{
	if [ ! -d /opt/l_mkl_2018.1.163 ]; then
		cd /opt
		sudo curl -L -O http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/12414/l_mkl_2018.1.163.tgz
		sudo tar zxvf l_mkl_2018.1.163.tgz
		sudo rm -rf l_mkl_2018.1.163.tgz
		cd l_mkl_2018.1.163
		sudo sed -i -e "s/decline/accept/g" silent.cfg
		sudo ./install.sh --silent silent.cfg
		sudo source /opt/intel/compilers_and_libraries/linux/mkl/bin/mklvars.sh intel64
	fi
	if [ ! -f /etc/profile.d/intel_mkl.sh ]; then
		sudo echo 'source /opt/intel/compilers_and_libraries/linux/mkl/bin/mklvars.sh intel64' >> /etc/profile.d/intel_mkl.sh
		sudo echo 'export LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries/linux/mkl/lib/intel64:$LD_LIBRARY_PATH' >> /etc/profile.d/intel_mkl.sh
	fi
}

setup_tbb()
{
	if [ ! -d /opt/l_tbb_2018.1.163 ]; then
		cd /opt
		sudo curl -L -O http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/12414/l_tbb_2018.1.163.tgz
		sudo tar zxvf l_tbb_2018.1.163.tgz
		sudo rm -rf l_tbb_2018.1.163.tgz
		cd l_tbb_2018.1.163
		sudo sed -i -e "s/decline/accept/g" silent.cfg
		sudo ./install.sh --silent silent.cfg
		sudo source /opt/intel/tbb/bin/tbbvars.sh intel64
	fi
	if [ ! -f /etc/profile.d/intel_tbb.sh ]; then
		sudo echo 'source /opt/intel/tbb/bin/tbbvars.sh intel64' >> /etc/profile.d/intel_tbb.sh
		sudo echo 'export CPATH=/opt/intel/tbb/include:$CPATH' >> /etc/profile.d/intel_tbb.sh
	fi
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
		sudo source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh
	fi
	if [ ! -f /etc/profile.d/intel_mpi.sh ]; then
		sudo echo 'export I_MPI_FABRICS=shm:dapl' >> /etc/profile.d/intel_mpi.sh
		sudo echo 'export I_MPI_DAPL_PROVIDER=ofa-v2-ib0' >> /etc/profile.d/intel_mpi.sh
		sudo echo 'export I_MPI_DYNAMIC_CONNECTION=0' >> /etc/profile.d/intel_mpi.sh
		sudo echo 'export I_MPI_FALLBACK_DEVICE=0' >> /etc/profile.d/intel_mpi.sh
		sudo echo 'source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh' >> /etc/profile.d/intel_mpi.sh
		sudo echo 'echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope' >> /etc/profile.d/intel_mpi.sh
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
	git \
	gfortran

	sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
	sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10
	sudo pip install --upgrade pip

	sudo echo '[mkl]' >> ~/.numpy-site.cfg
	sudo echo 'library_dirs = /opt/intel/mkl/lib/intel64' >> ~/.numpy-site.cfg
	sudo echo 'include_dirs = /opt/intel/mkl/include' >> ~/.numpy-site.cfg
	sudo echo 'mkl_libs = mkl_rt' >> ~/.numpy-site.cfg
	sudo echo 'lapack_libs =' >> ~/.numpy-site.cfg
	sudo pip install --no-binary :all: numpy
	sudo pip install --no-binary :all: scipy
}

setup_jpeg_turbo()
{
	if [ ! -d /opt/libjpeg-turbo-1.5.3 ]; then
		sudo apt-get install -y nasm
		sudo curl -L -O https://sourceforge.net/projects/libjpeg-turbo/files/1.5.3/libjpeg-turbo-1.5.3.tar.gz
		sudo tar zxvf libjpeg-turbo-1.5.3.tar.gz
		sudo rm -rf libjpeg-turbo-1.5.3.tar.gz
		cd libjpeg-turbo-1.5.3
		sudo sh -c "CFLAGS='-O3' ./configure --prefix=/usr/local"
		sudo make -j32 install
	fi
}

setup_ffmpeg()
{
	sudo add-apt-repository ppa:jonathonf/ffmpeg-3
	sudo apt-get update -y
	sudo apt-get install -y yasm x264 libav-tools x265 ffmpeg libavcodec-dev libavformat-dev libswscale-dev
}

setup_opencv()
{
	if [ ! -d /opt/opencv-3.4.0 ]; then
		cd /opt
		
		sudo curl -L -O https://github.com/opencv/opencv/archive/3.4.0.tar.gz
		sudo tar zxvf 3.4.0.tar.gz && rm -rf 3.4.0.tar.gz

		sudo curl -L -O https://github.com/opencv/opencv_contrib/archive/3.4.0.tar.gz
		sudo tar zxvf 3.4.0.tar.gz && rm -rf 3.4.0.tar.gz

		cd opencv-3.4.0 && sudo mkdir build && cd build
		sudo cmake \
		-DBUILD_TESTS=OFF \
		-DBUILD_JPEG=OFF \
		-DENABLE_AVX=ON \
		-DENABLE_AVX2=ON \
		-DENABLE_FAST_MATH=ON \
		-DENABLE_NOISY_WARNINGS=ON \
		-DENABLE_SSE41=ON \
		-DENABLE_SSE42=ON \
		-DENABLE_SSSE3=ON \
		-DOPENCV_ENABLE_NONFREE=ON \
		-DBUILD_opencv_python3=ON \
		-DPYTHON3_EXECUTABLE=/usr/bin/python3 \
		-DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.5m.so \
		-DPYTHON_LIBRARY_DEBUG=/usr/lib/x86_64-linux-gnu/libpython3.5m.so \
		-DPYTHON_LIBRARY_RELEASE=/usr/lib/x86_64-linux-gnu/libpython3.5m.so \
		-DPYTHON3_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.5m.so \
		-DPYTHON3_LIBRARY_DEBUG=/usr/lib/x86_64-linux-gnu/libpython3.5m.so \
		-DPYTHON3_PACKAGES_PATH=/usr/lib/python3/dist-packages \
		-DPYTHON3_INCLUDE_DIR=/usr/include/python3.5m \
		-DPYTHON3_INCLUDE_DIR2=/usr/include/x86_64-linux-gnu/python3.5m \
		-DWITH_OPENMP=ON \
		-DWITH_OPENCL=OFF \
		-DWITH_OPENCLAMDBLAS=OFF \
		-DWITH_OPENCLAMDFFT=OFF \
		-DWITH_OPENCL_SVM=OFF \
		-DWITH_1394=OFF \
		-DWITH_TBB=ON \
		-DWITH_JPEG=ON \
		-DHAVE_MKL=ON \
		-DMKL_WITH_OPENMP=ON \
		-DMKL_WITH_TBB=ON \
		-DBUILD_TIFF=ON \
		-DBUILD_CUDA_STUBS=OFF \
		-DBUILD_opencv_cudaarithm=OFF \
		-DBUILD_opencv_cudabgsegm=OFF \
		-DBUILD_opencv_cudacodec=OFF \
		-DBUILD_opencv_cudafeatures2d=OFF \
		-DBUILD_opencv_cudafilters=OFF \
		-DBUILD_opencv_cudaimgproc=OFF \
		-DBUILD_opencv_cudalegacy=OFF \
		-DBUILD_opencv_cudaobjdetect=OFF \
		-DBUILD_opencv_cudaoptflow=OFF \
		-DBUILD_opencv_cudastereo=OFF \
		-DBUILD_opencv_cudawarping=OFF \
		-DBUILD_opencv_cudev=OFF \
		-DWITH_CUDA=OFF \
		-DWITH_CUBLAS=OFF \
		-DWITH_CUFFT=OFF \
		-DWITH_FFMPEG=ON \
		-DINSTALL_PYTHON_EXAMPLES=ON \
		-DINSTALL_C_EXAMPLES=OFF \
		-DJPEG_INCLUDE_DIR=/usr/local/include \
		-DJPEG_LIBRARY=/usr/local/lib/libjpeg.so \
		-DMKL_INCLUDE_DIRS=/opt/intel/mkl/include \
		-DMKL_ROOT_DIR=/opt/intel/mkl \
		-DTBB_ENV_INCLUDE=/opt/intel/tbb/include \
		-DTBB_ENV_LIB=/opt/intel/tbb/lib/intel64/gcc4.7/libtbb.so \
		-DTBB_ENV_LIB_DEBUG=/opt/intel/tbb/lib/intel64/gcc4.7/libtbb_debug.so \
		-DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib-3.4.0/modules \
		-DCMAKE_BUILD_TYPE=Release \
		../ && \
		sudo make -j32 && sudo make install
	fi
}

setup_chainermn()
{	
	sudo pip install cupy==${CUPY_VERSION}
	sudo pip install chainer==${CHAINER_VERSION}
	sudo pip install mpi4py
	sudo pip install cython
	sudo su -c "CFLAGS=-I/usr/local/cuda/include pip install git+https://github.com/chainer/chainermn"
}

create_cron_job()
{
	# Register cron tab so when machine restart it downloads the secret from azure downloadsecret
	sudo mv /var/lib/waagent/custom-script/download/1/rdma-autoload.sh ~
	sudo crontab -l > downloadsecretcron
	sudo echo '@reboot /root/rdma-autoload.sh >> /root/execution.log' >> downloadsecretcron
	sudo crontab downloadsecretcron
	sudo rm downloadsecretcron
}

setup_mkl
setup_tbb
setup_intel_mpi
setup_python
setup_jpeg_turbo
setup_ffmpeg
setup_opencv
setup_chainermn	
create_cron_job

sudo shutdown -r +1
