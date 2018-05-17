#!/bin/bash

ips=$(for ip in $(cat ~/hosts.txt); do ssh ${ip} "if [ ! -d /mnt/ILSVRC ]; then echo ${ip}; fi"; done)

parallel ssh {} "sudo cp /imagenet1k/archives/imagenet_object_localization.tar.gz /mnt/" ::: ${ips}
parallel ssh {} "sudo tar zxf /mnt/imagenet_object_localization.tar.gz -C /mnt/" ::: ${ips}
