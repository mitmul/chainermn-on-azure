#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
from multiprocessing import Pool
import subprocess


def get_id(resource_group, vmss_name, ip):
    return subprocess.check_output(
        'az vmss nic list -g {} --vmss-name {} '
        '--query "[?ipConfigurations[0].privateIpAddress==\'{}\'].id" '
        '-o tsv'.format(resource_group, vmss_name, ip),
        shell=True
    ).decode('utf-8').strip().split('/')[-3]


def get_cuda_status(ip, home_dir):
    return subprocess.check_output(
        'ssh {} "source {}/.bash_profile && '
        'python -c \'import chainer; chainer.print_runtime_info()\'"'.format(
            ip, home_dir), shell=True
    ).decode('utf-8').strip()


def set_locale(ip, home_dir):
    return subprocess.check_output(
        'ssh {} "'
        'source {}/.bash_profile && '
        'sudo locale-gen && '
        'sudo update-locale LC_ALL=\"en_US.UTF-8\""'.format(
            ip, home_dir, home_dir), shell=True
    ).decode('utf-8').strip()


def get_mpi_status(host, ip):
    try:
        return subprocess.check_output(
            'mpirun -n 2 -ppn 1 -hosts {},{} -envall '
            'python -c "'
            'import chainermn; '
            'comm = chainermn.create_communicator(\'non_cuda_aware\'); '
            'print(comm.rank)"'.format(host, ip),
            shell=True
        ).decode('utf-8').strip()
    except Exception as e:
        print(str(type(e)), e, 'on', ip)
        return ''


def restart_vm(resource_group, vmss_name, ip):
    try:
        instance_id = get_id(resource_group, vmss_name, ip)
        print(
            subprocess.check_output(
                'az vmss delete-instances -g {} -n {} --instance-ids {}'.format(
                    resource_group, vmss_name, instance_id),
                shell=True
            ).decode('utf-8').strip()
        )
    except Exception as e:
        print(str(type(e)), e, ip)
        return ''


def get_cupy_status(ip, home_dir):
    return subprocess.check_output(
        'ssh {} "'
        'source {}/.bash_profile && '
        'timeout 120 python -c \''
        'import cupy; '
        'cupy.array(0); '
        'cupy.random.rand(2, 3).dot(cupy.random.rand(3, 4)); '
        'print(\\"success\\")\''
        '"'.format(ip, home_dir),
        shell=True
    ).decode('utf-8').strip()


def set_gpu_persistent(ip):
    return subprocess.check_output(
        'ssh {} "sudo nvidia-smi -pm 1"'.format(ip),
        shell=True
    ).decode('utf-8').strip()


def setup_each(resource_group, vmss_name, home_dir, host, ip):
    ip = ip.strip()

    set_locale(ip, home_dir)

    cuda_status = get_cuda_status(ip, home_dir)
    if 'CUDARuntimeError' in cuda_status:
        print('CUDA is broken on {}'.format(ip))
        restart_vm(resource_group, vmss_name, ip)
        return ip, False

    mpi_status = get_mpi_status(host, ip)
    if '0' not in mpi_status or '1' not in mpi_status:
        print('Cannot communicate with {}'.format(ip))
        restart_vm(resource_group, vmss_name, ip)
        return ip, False

    cupy_status = get_cupy_status(ip, home_dir)
    if cupy_status != 'success':
        print('CuPy cannot run correctly on {}. Restarting...'.format(ip))
        restart_vm(resource_group, vmss_name, ip)
        return ip, False

    set_gpu_persistent(ip)

    return ip, True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--resource-group', type=str, default='chainermn-v100')
    parser.add_argument('--vmss-name', type=str, default='vmss')
    parser.add_argument('--home-dir', type=str, default='/share/home/hpcuser')
    parser.add_argument('--hostfile', type=str,
                        default='/share/home/hpcuser/hosts.txt')
    args = parser.parse_args()

    ips = [ip.strip() for ip in open(args.hostfile)]
    host = ips[0]
    p = Pool()
    rets = [
        p.apply_async(
            setup_each,
            args=(args.resource_group, args.vmss_name, args.home_dir,
                  host if host != ip else ips[-1], ip)
        )
        for ip in ips
    ]

    fp = open('failed_ips.txt', 'w')
    for ret in rets:
        ip, result = ret.get()
        print(ip, 'SUCCESS' if result else 'FAILED')
        print(ip, 'SUCCESS' if result else 'FAILED', file=fp)


if __name__ == '__main__':
    main()
