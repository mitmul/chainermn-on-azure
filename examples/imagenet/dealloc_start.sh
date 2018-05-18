#!/bin/bash

dealloc_start () {
    RESOURCE_GROUP=$1
    VMSS_NAME=$2
    ip=$3
    id=$(az vmss nic list -g ${RESOURCE_GROUP} --vmss-name ${VMSS_NAME} --query "[?ipConfigurations[0].privateIpAddress=='${ip}'].virtualMachine.id" -o tsv | xargs basename);
    echo "$ip - $id (${RESOURCE_GROUP})"
    az vmss deallocate -g ${RESOURCE_GROUP} -n vmss --instance-ids $id
    az vmss start -g ${RESOURCE_GROUP} -n vmss --instance-ids $id
}

hosts=($(cat ~/hosts.txt))
export -f dealloc_start
parallel dealloc_start $1 $2 ::: ${hosts[*]:8:32} 
