#!/bin/bash

for ip in $(cat ~/hosts.txt);
do
    echo "Copying the dataset to ramdisk on ${ip}..."
    # ssh ${ip} "sudo cp -r /imagenet1k/imagenet_object_localization.tar.gz /mnt/" &
    ssh ${ip} "cd /mnt && sudo tar zxvf imagenet_object_localization.tar.gz" &
done
