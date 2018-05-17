#!/bin/bash

cat ~/hosts.txt | parallel -a - ssh {} "sudo cp /imagenet1k/archives/imagenet_object_localization.tar.gz /mnt/"
cat ~/hosts.txt | parallel -a - ssh {} "sudo tar zxf /mnt/imagenet_object_localization.tar.gz"

