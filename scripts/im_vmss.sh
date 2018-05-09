#!/bin/bash

az vmss create \
--image /subscriptions/74e4da0b-6512-49b0-867a-3dff205b77e5/resourceGroups/chainermn/providers/Microsoft.Compute/images/vmss-image \
--vm-sku Standard_NC24r \
--lb '' \
--name vmss \
--resource-group chainermn \
--admin-username ubuntu \
--public-ip-address '' \
--ssh-key-value $HOME/.ssh/id_rsa.pub \
--vnet-name chainer-vnet \
--subnet jumpboxSubnet 
