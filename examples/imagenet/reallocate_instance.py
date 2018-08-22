#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
from setup import get_id
import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ip', '-i', type=str)
    parser.add_argument('--resource-group', type=str, default='chainermn-v100')
    parser.add_argument('--vmss-name', type=str, default='vmss')
    args = parser.parse_args()

    instance_id = get_id(args.resource_group, args.vmss_name, args.ip)
    current_capacity = int(subprocess.check_output(
        'az vmss show -g {} -n {} --query="sku.capacity"'.format(
            args.resource_group, args.vmss)).decode('utf-8').strip())
    subprocess.check_output(
        'az vmss delete-instances -g {} -n {} --instance-ids {}'.format(
            args.resource_group, args.vmss_name, instance_id))
    subprocess.check_output(
        'az vmss scale -g {} -n {} --new-capacity {}'.format(
            args.resource_group, args.vmss, current_capacity))


if __name__ == '__main__':
    main()
