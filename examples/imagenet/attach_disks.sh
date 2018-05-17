#!/bin/bash

RESOURCE_GROUP="chainermn-k80"
SNAPSHOT_ID=$(az snapshot show -g chainermn-images -n imagenet1k --query="id" -o tsv)

for ip in $(cat ~/hosts.txt);
do
    # az disk create -g ${RESOURCE_GROUP} -n disk-${ip} --source ${SNAPSHOT_ID} --sku Standard_LRS;
    # id=$(python get_id.py ${ip} -g ${RESOURCE_GROUP});
    # az vmss disk attach -g ${RESOURCE_GROUP} --name vmss --disk disk-${ip} --instance-id ${id};
    ssh ${ip} "if [ ! -d /imagenet1k ]; then sudo mkdir /imagenet1k; fi && sudo mount -t ext4 /dev/sdc1 /imagenet1k";
done
