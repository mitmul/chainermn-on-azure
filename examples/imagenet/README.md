# ImageNet Training with ChainerMN

## Download ImageNet dataset

```
# Login to jumpbox

# Install kaggle command
pip install kaggle

# Place .kaggle/kaggle.json to /share/home/hpcuser/.kaggle/kaggle.json

# Downlaod ImageNet dataset to shared data disk /data1
cd /data1
kaggle competitions download -c imagenet-object-localization-challenge -p ./
```

## Get list of IPs in VMSS

```
az vmss nic list -g chainermn --vmss-name vmss \
--query "[*].ipConfigurations[0].privateIpAddress" -o tsv
```

## Scale out

```
az vmss scale -g chainermn -n vmss --new-capacity 32
```
