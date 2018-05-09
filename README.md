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

