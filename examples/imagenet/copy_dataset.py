#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import subprocess
from multiprocessing import Process
from multiprocessing import Queue


def copy_func(host, src):
    subprocess.call(
        'ssh {host} "cp -r {src} /ramdisk/"'.format(
            host=host, src=src
        ), shell=True)
    print('{} done'.format(host))

sender_queue = Queue()

hosts = [l.strip() for l in open(os.path.expanduser('~/hosts.txt')).readlines()]

sender_queue.put((hosts[0], '/data1/ILSVRC'))

while True:
    host, src = sender_queue.get()
