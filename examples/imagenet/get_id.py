#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import json
import os
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('ip', type=str)
args = parser.parse_args()

out = subprocess.check_output(
    'az vmss nic list -g chainermn --vmss-name vmss', shell=True)

for datum in json.loads(out.decode('utf-8')):
    _ip = datum['ipConfigurations'][0]['privateIpAddress']
    _id = os.path.basename(datum['virtualMachine']['id'])
    if _ip.strip() == args.ip.strip():
        print(_id)
        exit()
