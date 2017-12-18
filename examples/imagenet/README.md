ImageNet training with ChainerMN
================================

# Requirements

- Python3
- pip packages:
    - azure-cli

# Setup

## Azure CLI setup

```
$ az login
$ az account list
$ az account set --subscription [subscription_id]
```

## List the IPs

```
$ az vmss nic list -g [resource group name] --vmss-name chainer \
--query "[*].ipConfigurations[0].privateIpAddress" -o tsv > hosts.txt
```
