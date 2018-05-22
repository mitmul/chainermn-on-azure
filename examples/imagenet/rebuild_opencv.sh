#!/bin/bash

# Install OpenCV with libjpeg-turbo
cd /opt/opencv/build
make uninstall
cd /opt
rm -rf opencv
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
-DWITH_CUDA=OFF \
-DCUDA_ARCH_BIN=6.0 \
-DCUDA_ARCH_PTX= \
-DWITH_JPEG=ON \
-DBUILD_JPEG=OFF \
-DJPEG_INCLUDE_DIR=/usr/local/include \
-DJPEG_LIBRARY=/usr/local/lib/libjpeg.so \
-DOPENCV_EXTRA_MODULES_PATH=/opt/opencv/opencv_contrib-3.4.1/modules \
-DBUILD_opencv_python3=ON \
-DPYTHON3_EXECUTABLE=$(which python) \
-DPYTHON3_INCLUDE_DIR=$(python -c 'from distutils.sysconfig import get_python_inc; print(get_python_inc())') \
-DPYTHON3_NUMPY_INCLUDE_DIRS=$(python -c 'import numpy; print(numpy.get_include())') \
-DPYTHON3_LIBRARY="/usr/lib/x86_64-linux-gnu/libpython3.5m.so" \
-DPYTHON_INCLUDE_DIR=$(python -c 'from distutils.sysconfig import get_python_inc; print(get_python_inc())') \
-DPYTHON_LIBRARY="/usr/lib/x86_64-linux-gnu/libpython3.5m.so" \
/opt/opencv/opencv-3.4.1 && \
make -j8 && \
make install

