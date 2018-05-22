#!/bin/bash

RESOURCE_GROUP=$1

disk_names=$(az disk list -g ${RESOURCE_GROUP} --query="[].name" -o tsv)
for n in $disk_names; do az disk delete -g ${RESOURCE_GROUP} -y -n $n; done

