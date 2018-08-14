#!/usr/bin/env python
# -*- coding: utf-8 -*-

import collections

import numpy as np

ip_usec = {}
for line in open('pingpong_result/summary.csv'):
    if len(line.strip()) == 0:
        continue
    ip, usec = line.split(',')
    ip_usec[ip] = float(usec)

fp = open('/share/home/hpcuser/hosts.txt', 'w')
for ip, usecs in sorted(ip_usec.items(), key=lambda x: x[1]):
    print(ip, usecs)
    print(ip, file=fp)
fp.close()
