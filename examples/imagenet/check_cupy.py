#!/usr/bin/env python
# -*- coding: utf-8 -*-

import cupy

for i in range(4):
    with cupy.cuda.Device(i) as d:
        print('Device {} is OK'.format(i))
        array = cupy.array(0)
