#!/usr/bin/env python
# -*- coding: utf-8 -*-

import glob
import json
import os

import matplotlib.pyplot as plt
import numpy as np

import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--dirname', '-d', type=str)
args = parser.parse_args()

result = []
for fn in sorted(glob.glob('{}/*/log'.format(args.dirname))):
    try:
        n_gpus = int(os.path.dirname(fn).split('_')[-1])
        log = json.load(open(fn))
        whole_time = log[-1]['elapsed_time'] - log[0]['elapsed_time']
        n_iter = log[-1]['iteration'] - log[0]['iteration']
        iters_per_sec = n_iter / whole_time
        print('-' * 10, n_gpus, '-' * 10)
        print('mean: {}'.format(iters_per_sec))
        result.append(iters_per_sec)

        iters_sec = []
        t = log[0]['elapsed_time']
        i = log[0]['iteration']
        for l in log[1:]:
            dt = l['elapsed_time'] - t
            it = l['iteration'] - i
            iters_sec.append(it / dt)
            t = l['elapsed_time']
            i = l['iteration']
        print('min: {}'.format(np.min(iters_sec)))
        print('max: {}'.format(np.max(iters_sec)))
    except Exception as e:
        print(str(type(e)), e)
        print(fn, 'failed')


for r in result:
    print(r)
