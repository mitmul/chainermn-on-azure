#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import argparse
import os
import shutil
from setup import get_id


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--resource-group', type=str, default='chainermn-v100')
    parser.add_argument('--vmss-name', type=str, default='vmss')
    parser.add_argument('--home-dir', type=str, default='/share/home/hpcuser')
    parser.add_argument('--num', '-n', type=int, default=32)
    parser.add_argument('--delete-slow-intances', '-d', action='store_true', default=False)
    args = parser.parse_args()

    subprocess.check_output(
        'az vmss nic list -g {} --vmss-name {} '
        '--query "[*].ipConfigurations[0].privateIpAddress" -o tsv '
        '> ~/hosts.txt'.format(args.resource_group, args.vmss_name),
        shell=True
    )
    ips = [ip.strip() for ip in open(os.path.join(args.home_dir, 'hosts.txt'))]

    ip_usec = {}
    masterip = ips[0]
    for ip in ips:
        r = subprocess.check_output(
            'mpirun -n 2 -ppn 1 -hosts {},{} '
            '-genvall IMB-MPI1 pingpong -iter 100000'.format(masterip, ip),
            shell=True
        ).decode('utf-8').strip()
        one_line_before = False
        for line in r.split('\n'):
            if one_line_before:
                usec = [v.strip() for v in line.split()][2]
                print(ip, usec)
                ip_usec[ip] = usec
                break
            if '#bytes' in line:
                one_line_before = True

    fp = open(os.path.join(args.home_dir, 'hosts.txt'), 'w')
    for i, (ip, usec) in enumerate(sorted(ip_usec.items(), key=lambda x: x[1])):
        print(ip, '\t', usec)
        if i < args.num:
            print(ip, file=fp)
        elif args.delete_slow_instances:
            print(ip, 'deleting...')
            instance_id = get_id(args.resource_group, args.vmss_name, ip)
            subprocess.check_output(
                'az vmss delete-instances -g {} -n {} --instance-ids {} --no-wait'.format(
                    args.resource_group, args.vmss_name, instance_id),
                shell=True
            )


if __name__ == '__main__':
    main()
