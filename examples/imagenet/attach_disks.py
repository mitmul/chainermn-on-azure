#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
from multiprocessing import Pool
import os
import re
import subprocess

from setup import get_id


def delete_disk(resource_group, vmss_name, disk):
    if disk.startswith('disk-'):
        ip = disk.split('-')[-1]

        print('Detaching {} from {}'.format(disk, ip))
        try:
            instance_id = int(get_id(resource_group, vmss_name, ip))
            subprocess.check_output(
                'az vmss disk detach --lun 0 -g {} --name {} --instance-id {}'.format(
                    resource_group, vmss_name, instance_id),
                shell=True
            )
        except Exception as e:
            print(str(type(e)), e, '{} has not attached to {}'.format(disk, ip))

        print('Deleting disk {}'.format(disk))
        try:
            subprocess.check_output(
                'az disk delete -g {} -n {} --no-wait --yes'.format(
                    resource_group, disk),
                shell=True
            )
        except Exception as e:
            print(str(type(e)), e, 'Could not delete {}'.format(disk))
        print('{} deleted'.format(disk))


def prepare_disk(resource_group, vmss_name, ip, disk_snapshot):
    if resource_group.endswith('k80'):
        sku = 'Standard_LRS'
    else:
        sku = 'Premium_LRS'

    disk_names = [n.strip() for n in subprocess.check_output(
        'az disk list -g {} --query "[].name" -o tsv'.format(
            resource_group), shell=True).decode('utf-8').strip().split()]

    instance_id = get_id(resource_group, vmss_name, ip)

    if 'disk-{}'.format(ip) not in disk_names:
        print('Creating disk-{}'.format(ip))
        try:
            subprocess.check_output(
                'az disk create -g {} -n disk-{} --source {} --sku {}'.format(
                    resource_group, ip, disk_snapshot, sku),
                shell=True
            )
        except Exception as e:
            print(str(type(e)), e)
            print('Could not create disk-{}'.format(ip))

        print('Attaching disk-{} to {}'.format(ip, instance_id))
        try:
            subprocess.check_output(
                'az vmss disk attach -g {} --name {} --disk disk-{} --instance-id {}'.format(
                    resource_group, vmss_name, ip, instance_id),
                shell=True
            )
        except Exception as e:
            print(str(type(e)), e)
            print(
                'Could not attach the disk-{} to the instance {}'.format(ip, instance_id))

        print('Unmounting /imagenet1k on {}'.format(ip))
        try:
            subprocess.check_output(
                'ssh {} "sudo umount /imagenet1k"'.format(ip),
                shell=True
            )
        except Exception as e:
            print(str(type(e)), e)
            print('Could not unmount /imagenet1k on {}'.format(ip))

        print('Make a dir /imagenet1k on {}'.format(ip))
        try:
            subprocess.check_output(
                'ssh {} "sudo mkdir /imagenet1k"'.format(ip),
                shell=True
            )
        except Exception as e:
            print(str(type(e)), e)
            print('Could not create a dir /imagenet1k on {}'.format(ip))

        print('Mount the disk on /imagenet1k on {}'.format(ip))
        try:
            devices = subprocess.check_output(
                'ssh {} "sudo fdisk -l"'.format(ip), shell=True).decode('utf-8').strip().split('\n')
            for d in devices:
                if '1023 GiB' in d:
                    target = re.search('(/[a-z]+/[a-z]+)', d).groups()[0] + '1'
                    break
            print('target path:', target)
            subprocess.check_output(
                'ssh {} "sudo mount -t ext4 {} /imagenet1k"'.format(
                    ip, target),
                shell=True
            )
        except Exception as e:
            print(str(type(e)), e)
            print('Could not mount {} to /imagenet1k on {}'.format(target, ip))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--disk-resource-group', type=str,
                        default='chainermn-images')
    parser.add_argument('--resource-group', type=str, default='chainermn-v100')
    parser.add_argument('--vmss-name', type=str, default='vmss')
    parser.add_argument('--disk-image', type=str, default='imagenet1k')
    parser.add_argument('--home-dir', type=str, default='/share/home/hpcuser')
    parser.add_argument('--delete', action='store_true', default=False)
    args = parser.parse_args()

    if args.delete:
        disk_names = [n.strip() for n in subprocess.check_output(
            'az disk list -g {} --query "[].name" -o tsv'.format(
                args.resource_group), shell=True).decode('utf-8').strip().split()]
        p = Pool(1)
        res = [p.apply_async(delete_disk, args=(args.resource_group, args.vmss_name, disk))
               for disk in disk_names]
        for r in res:
            r.get()
        exit()

    disk_snapshot = subprocess.check_output(
        'az snapshot show -g {} -n {} --query="id" -o tsv'.format(
            args.disk_resource_group, args.disk_image),
        shell=True
    ).decode('utf-8').strip()

    ips = [ip.strip() for ip in open(os.path.join(args.home_dir, 'hosts.txt'))]

    p = Pool(2)
    res = [p.apply_async(prepare_disk, args=(args.resource_group, args.vmss_name, ip, disk_snapshot))
           for ip in ips]
    for r in res:
        r.get()


if __name__ == '__main__':
    main()
