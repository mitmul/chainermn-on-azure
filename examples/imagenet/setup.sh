#!/bin/bash

RESOURCE_GROUP=$1
VMSS_NAME="vmss"

echo ${RESOURCE_GROUP}
echo ${VMSS_NAME}

cat ~/hosts.txt | parallel -a - bash setup_each.sh ${RESOURCE_GROUP} ${VMSS_NAME} {}
