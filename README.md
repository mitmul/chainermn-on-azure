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

### 1. Create jumpbox

```
python deploy.py \
-k ~/.ssh/id_rsa.pub \
-g chainermn-image \
-s chainermnscriptsimage \
--jumpbox-only
```

### 2. Create VMSS image

```
az vm create \
-n vmss-image \
-g chainermn-image \
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
az vm deallocate --resource-group chainermn-image --name vmss-image && \
az vm generalize --resource-group chainermn-image --name vmss-image && \
az image create --resource-group chainermn-image --name vmss-image --source vmss-image && \
python utils.py -g chainermn-image delete-vm vmss-image
```

### 3. Create jumpbox image

Login to the jumpbox server and run:

```
sudo waagent -deprovision+user -force
```

Then logout, then run these commands from your local machine:

```
az vm deallocate --resource-group chainermn-image --name jumpbox && \
az vm generalize --resource-group chainermn-image --name jumpbox && \
az image create --resource-group chainermn-image --name jumpbox-image --source jumpbox && \
python utils.py -g chainermn-image delete-vm jumpbox
```

## Deploy using images

### 1. Deploy jumpbox

