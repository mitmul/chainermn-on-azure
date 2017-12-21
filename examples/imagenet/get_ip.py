#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import json
import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('ip', type=str)
args = parser.parse_args()

out = subprocess.check_output(
    'az vmss nic list -g chainermn128 --vmss-name chainer', shell=True)

for datum in json.loads(out):
    _ip = datum['ipConfigurations'][0]['privateIpAddress']
    _id = os.path.basename(datum['virtualMachine']['id'])
    if _ip.strip() == args.ip.strip():
        print(_id)
        exit()
