#!/bin/bash

for ip in $(cat ~/hosts.txt);
do
    echo "Copying the dataset to ramdisk on ${ip}..."
    ssh ${ip} "if [ ! -d /ramdisk ]; then mkdir /ramdisk; fi && sudo mount -t tmpfs -o size=200G tmpfs /ramdisk && cp -r /imagenet1k/ILSVRC /ramdisk/" &
done
