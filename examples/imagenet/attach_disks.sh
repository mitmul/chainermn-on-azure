#!/bin/bash

for ip in $(cat ~/hosts.txt);
do
    az disk create -g chainermn -n disk-${ip} --source imagenet1kstd --sku Standard_LRS;
    id=$(python get_id.py ${ip});
    az vmss disk attach -g chainermn --name vmss --disk disk-${ip} --instance-id ${id};
    ssh ${ip} "if [ ! -d /imagenet1k ]; then sudo mkdir /imagenet1k; fi && sudo mount -t ext4 /dev/sdc1 /imagenet1k";
done
