#!/bin/bash

dealloc_start () {
    RESOURCE_GROUP="chainermn-k80"

    id=$(python get_id.py $1)
    echo "$1 - $id (${RESOURCE_GROUP})"
    az vmss deallocate -g ${RESOURCE_GROUP} -n vmss --instance-ids $id
    az vmss start -g ${RESOURCE_GROUP} -n vmss --instance-ids $id
}

hosts=($(cat ~/hosts.txt))
export -f dealloc_start
parallel dealloc_start ::: ${hosts[*]:16:32} 
