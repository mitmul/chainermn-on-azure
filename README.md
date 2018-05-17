# ChainerMN on Azure

## Deploy from ARM Template

Please note that it will take a long time.

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

### 1. Create jumpbox

```
python deploy.py \
-k ~/.ssh/id_rsa.pub \
-g chainermn-images \
-s chainermnscriptsimage \
--jumpbox-only
```

### 2. Create VMSS image

```
az vm create \
-n vmss-image \
-g chainermn-images \
--image Canonical:UbuntuServer:16.04-LTS:latest \
-l eastus \
--size Standard_NC24r \
--admin-username ubuntu \
--authentication-type ssh \
--ssh-key-value $HOME/.ssh/id_rsa.pub
```

Login to the VM and run the `scripts/setup_vmss.sh`.
Then reboot it once, then run:

```
sudo waagent -deprovision+user -force
```

Logout and run these commands on your local machine:

```
az vm deallocate --resource-group chainermn-images --name vmss-image && \
az vm generalize --resource-group chainermn-images --name vmss-image && \
az image create --resource-group chainermn-images --name vmss-image --source vmss-image && \
python utils.py -g chainermn-images delete-vm vmss-image
```

### 3. Create jumpbox image

Login to the jumpbox server and run:

```
sudo waagent -deprovision+user -force
```

Then logout, then run these commands from your local machine:

```
az vm deallocate --resource-group chainermn-images --name jumpbox && \
az vm generalize --resource-group chainermn-images --name jumpbox && \
az image create --resource-group chainermn-images --name jumpbox-image --source jumpbox && \
python utils.py -g chainermn-images delete-vm jumpbox
```

## Deploy using images

First, please create a resource group.

```
az group create -g chainermn-k80 -l eastus
```

### 1. Deploy jumpbox

```
image_id=$(az image show -g chainermn-images -n jumpbox-image --query "id" -o tsv)

az vm create \
--image ${image_id} \
--name jumpbox \
--resource-group chainermn-k80 \
--size Standard_DS3_v2 \
--admin-username ubuntu \
--ssh-key-value $HOME/.ssh/id_rsa.pub \
--vnet-name chainer-vnet
```

### 2. Deploy VMSS

```
image_id=$(az image show -g chainermn-images -n vmss-image --query "id" -o tsv)

az vmss create \
--image ${image_id} \
--vm-sku Standard_NC24r \
--lb '' \
--name vmss \
--resource-group chainermn-k80 \
--admin-username ubuntu \
--public-ip-address '' \
--ssh-key-value $HOME/.ssh/id_rsa.pub \
--vnet-name chainer-vnet \
--subnet jumpboxSubnet 
```
