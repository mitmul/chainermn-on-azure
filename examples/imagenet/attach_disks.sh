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
    id=$(az vmss nic list -g ${RESOURCE_GROUP} --vmss-name ${VMSS_NAME} --query "[?ipConfigurations[0].privateIpAddress=='${ip}'].virtualMachine.id" -o tsv | xargs basename);
    echo "$ip - $id ($SKU)";
    if ! [[ "$disk_names" =~ .*${ip}[[:space:]].* ]]; then
        echo "Creating disk-${ip} to $id"
        az disk create -g ${RESOURCE_GROUP} -n disk-${ip} --source ${SNAPSHOT_ID} --sku ${SKU};
    fi;
    managed_by=$(az disk list -g ${RESOURCE_GROUP} --query "[?name=='disk-${ip}'].managedBy" -o tsv)
    if ! [[ "$managed_by" == *"${id}" ]]; then
        echo "Attaching disk-${ip} to $id"
        az vmss disk attach -g ${RESOURCE_GROUP} --name ${VMSS_NAME} --disk disk-${ip} --instance-id ${id};
    fi
    dir_exist=$(ssh ${ip} "if [ -d /imagenet1k/archives ]; then echo \"exist\"; fi")
    if [[ "$dir_exist" == "exist" ]]; then
        echo "$ip has /imagenet1k dir";
    else
        ssh ${ip} "sudo mkdir /imagenet1k";
        ssh ${ip} "sudo mount -t ext4 /dev/sdc1 /imagenet1k";
    fi
}

export -f prepare_disk
for ip in $(cat ~/hosts.txt);
do
    prepare_disk $1 $ip &
done

