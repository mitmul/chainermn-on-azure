# ChainerMN on Azure

## How to deploy the environment

### 1. Install Azure CLI and azure package

```
$ pip install azure-cli
$ pip install azure
```

### 2. Login to Azure using Azure CLI

```
$ az login
```

### 3. Select a subscription

```
$ az account list --all
```

Pick up a subscription ID you want to use from the above list.

```
$ az account set --subscription [YOUR SUBSCRIPTION ID]
```

### 4. Deploy

```
$ ./deploy.py \
--resource-group chainermn
--location westus2 \
--public-key-file ~/.ssh/id_rsa.pub
```

## Create images

### 1. Create jumpbox VM

```
python deploy.py \
-k ~/.ssh/id_rsa.pub \
-g chainermn-image \
-s chainermnscriptsimage \
--jumpbox-only
```

Login to the jumpbox server and run:

```
sudo waagent -deprovision+user -force
```

Then logout, then run these commands from your local machine:

```
az vm deallocate --resource-group chainermn-image --name jumpbox
az vm generalize --resource-group chainermn-image --name jumpbox
az image create --resource-group chainermn-image --name jumpbox-image --source jumpbox
python utils.py -g chainermn-images delete-vm jumpbox
```
