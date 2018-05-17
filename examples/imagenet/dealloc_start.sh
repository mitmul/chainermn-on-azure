#!/bin/bash

RESOURCE_GROUP=chainermn-k80

id=$(python get_id.py $1)
az vmss deallocate -g ${RESOURCE_GROUP} -n vmss --instance-ids ${id}
