#!/bin/bash

ips=$(cat ~/hosts.txt)
ips=$(for ip in $ips; do ssh ${ip} "if [ -d /mnt/ILSVRC ]; then echo ${ip}; fi"; done)

echo ${ips}

ips=$(cat ~/hosts.txt)
ips=$(for ip in $ips; do ssh ${ip} "if [ -f /mnt/imagenet_object_localization.tar.gz ]; then echo ${ip}; fi"; done)

echo ${ips}

