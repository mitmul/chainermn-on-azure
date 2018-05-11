#!/bin/bash

az group create -g chainermn -l eastus

image_id=$(az image show -g chainermn-image -n jumpbox-image --query "id" -o tsv)

az vm create \
--image ${image_id} \
--name jumpbox \
--resource-group chainermn \
--size Standard_DS3_v2 \
--admin-username ubuntu \
--ssh-key-value $HOME/.ssh/id_rsa.pub \
--vnet-name chainer-vnet
