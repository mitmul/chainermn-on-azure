#!/bin/bash

copy () {
    ip=$1
    echo "Copy imagenet_object_localization.tar.gz to /mnt/ on $ip..."
    ssh ${ip} "sudo cp /imagenet1k/archives/imagenet_object_localization.tar.gz /mnt/"
    echo "Extract dataset from an arxive on $ip..."
    ssh ${ip} "sudo tar zxf /mnt/imagenet_object_localization.tar.gz -C /mnt/"
    echo "Done! ($ip)"
}

export -f copy
for ip in $(cat ~/hosts.txt); 
do
    copy $ip &
done

