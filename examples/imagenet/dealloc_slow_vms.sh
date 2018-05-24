#!/bin/bash

dealloc () {
    RESOURCE_GROUP=$1
    VMSS_NAME="vmss"
    ip=$2
    id=$(az vmss nic list -g ${RESOURCE_GROUP} --vmss-name ${VMSS_NAME} --query "[?ipConfigurations[0].privateIpAddress=='${ip}'].virtualMachine.id" -o tsv | xargs basename);
    echo "$ip - $id (${RESOURCE_GROUP})"
    az vmss deallocate -g ${RESOURCE_GROUP} -n vmss --instance-ids $id
    echo "Finished"
}

hosts=($(cat ~/hosts.txt))
export -f dealloc
parallel dealloc $1 ::: ${hosts[*]:32:64} 
