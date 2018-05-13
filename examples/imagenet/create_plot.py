#!/usr/bin/env python
# -*- coding: utf-8 -*-

import glob
import json
import os

import matplotlib.pyplot as plt
import numpy as np


result = []
for fn in sorted(glob.glob('results/*/log')):
    n_gpus = int(os.path.dirname(fn).split('_')[-1])
    log = json.load(open(fn))
    whole_time = log[-1]['elapsed_time'] - log[0]['elapsed_time']
    n_iter = log[-1]['iteration'] - log[0]['iteration']
    iters_per_sec = n_iter / whole_time
    print('{},{}'.format(n_gpus, iters_per_sec))
