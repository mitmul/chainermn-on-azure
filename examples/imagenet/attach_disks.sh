#!/bin/bash

prepare_disk () {
    RESOURCE_GROUP=$1
    ip=$2
    VMSS_NAME="vmss"
    SNAPSHOT_ID=$(az snapshot show -g chainermn-images -n imagenet1k --query="id" -o tsv)

    if [ ${RESOURCE_GROUP} == *"k80" ]; then
        SKU="Standard_LRS"
    else
        SKU="Premium_LRS"
    fi

    disk_names=$(az disk list -g ${RESOURCE_GROUP} --query "[].name" -o tsv)

    if ! [[ "$disk_names" =~ .*${ip}[[:space:]].* ]]; then
        az disk create -g ${RESOURCE_GROUP} -n disk-${ip} --source ${SNAPSHOT_ID} --sku ${SKU};
    fi;
    id=$(az vmss nic list -g ${RESOURCE_GROUP} --vmss-name ${VMSS_NAME} --query "[?ipConfigurations[0].privateIpAddress=='${ip}'].virtualMachine.id" -o tsv | xargs basename);
    echo "$ip - $id";
    managed_by=$(az disk list -g ${RESOURCE_GROUP} --query "[?name=='disk-${ip}'].managedBy" -o tsv)
    if ! [[ "$managed_by" == *"${id}" ]]; then
        az vmss disk attach -g ${RESOURCE_GROUP} --name ${VMSS_NAME} --disk disk-${ip} --instance-id ${id};
    fi
    ssh ${ip} "if [ ! -d /imagenet1k ]; then sudo mkdir /imagenet1k; fi && sudo mount -t ext4 /dev/sdc1 /imagenet1k";
}

export -f prepare_disk
parallel prepare_disk $1 ::: $(cat ~/hosts.txt)
