#!/usr/bin/env python
# -*- coding: utf-8 -*-

import cupy
import chainer
import chainer.functions as F
import chainer.links as L


for i in range(4):
    with cupy.cuda.Device(i) as d:
        array = cupy.array(0)
        cupy.random.rand(2, 3).dot(cupy.random.rand(3, 4))
        x = chainer.Variable(cupy.random.rand(1, 3, 224, 224).astype(cupy.float32))
        conv = L.Convolution2D(None, 5, 3, 1, 1).to_gpu()
        y = conv(x)
        print('Device {} is OK'.format(i))
