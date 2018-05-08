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
