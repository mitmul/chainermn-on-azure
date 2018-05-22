#!/bin/bash

dealloc_start () {
    RESOURCE_GROUP=$1
    VMSS_NAME="vmss"
    ip=$2
    id=$(az vmss nic list -g ${RESOURCE_GROUP} --vmss-name ${VMSS_NAME} --query "[?ipConfigurations[0].privateIpAddress=='${ip}'].virtualMachine.id" -o tsv | xargs basename);
    echo "$ip - $id (${RESOURCE_GROUP})"
    az disk delete -g ${RESOURCE_GROUP} -n disk-${ip} -y
    az vmss deallocate -g ${RESOURCE_GROUP} -n vmss --instance-ids $id
    az vmss start -g ${RESOURCE_GROUP} -n vmss --instance-ids $id
}

hosts=($(cat ~/hosts.txt))
export -f dealloc_start
parallel dealloc_start $1 ::: ${hosts[*]:24:32} 
