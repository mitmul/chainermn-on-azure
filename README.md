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

### 1. Create jumpbox image

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
az vm deallocate --resource-group chainermn-image --name jumpbox && \
az vm generalize --resource-group chainermn-image --name jumpbox && \
az image create --resource-group chainermn-image --name jumpbox-image --source jumpbox && \
python utils.py -g chainermn-image delete-vm jumpbox
```

### 2. Create VMSS image

```
az vm create \
--image /subscriptions/74e4da0b-6512-49b0-867a-3dff205b77e5/resourceGroups/chainermn-image/providers/Microsoft.Compute/images/jumpbox-image \
--name jumpbox \
--resource-group chainermn-images \
--size Standard_DS3_v2 \
--admin-username ubuntu \
--ssh-key-value $HOME/.ssh/id_rsa.pub \
--vnet-name chainer-vnet
```

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
az vm generalize --resource-group chainermn-image --name  && \
az image create --resource-group chainermn-image --name vmss-image --source vmss-image && \
python utils.py -g chainermn-image delete-vm vmss-image
```
