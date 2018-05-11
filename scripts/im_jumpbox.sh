#!/bin/bash

az vm create \
--image /subscriptions/74e4da0b-6512-49b0-867a-3dff205b77e5/resourceGroups/chainermn-image/providers/Microsoft.Compute/images/jumpbox-image \
--name jumpbox \
--resource-group chainermn \
--size Standard_DS3_v2 \
--admin-username ubuntu \
--ssh-key-value $HOME/.ssh/id_rsa.pub \
--vnet-name chainer-vnet
