#!/usr/bin/env python
# -*- coding: utf-8 -*-

import collections

import matplotlib.pyplot as plt
import numpy as np

import pandas as pd

ip_usec = collections.defaultdict(list)
for line in open('pingpong_result/summary.csv'):
    ip, usec = [l.strip() for l in line.split(',')]
    ip_usec[ip].append(float(usec))

order = []
means = []
stds = []
mean_ip = []
for ip, usecs in sorted(ip_usec.items()):
    print(ip, np.mean(usecs), np.std(usecs))
    order.append(ip)
    means.append(np.mean(usecs))
    stds.append(np.std(usecs))
    mean_ip.append((np.min(usecs), np.mean(usecs), np.std(usecs), np.min(usecs), np.max(usecs), ip))

fp = open('/share/home/hpcuser/hosts.txt', 'w')
print(len(mean_ip))
for min__, mean, std, min_, max_, ip in sorted(mean_ip):
    print(ip, min_, max_, mean, std)
    print(ip, file=fp)
fp.close()

# plt.errorbar(range(len(order)), means, yerr=stds)
# plt.xticks(range(len(order)), order)
# plt.savefig('test.png')

