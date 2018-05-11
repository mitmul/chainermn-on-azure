#!/bin/bash

image_id=$(az image show -g chainermn-image -n vmss-image --query "id" -o tsv)

az vmss create \
--image ${image_id} \
--vm-sku Standard_NC24r \
--lb '' \
--name vmss \
--resource-group chainermn \
--admin-username ubuntu \
--public-ip-address '' \
--ssh-key-value $HOME/.ssh/id_rsa.pub \
--vnet-name chainer-vnet \
--subnet jumpboxSubnet 
