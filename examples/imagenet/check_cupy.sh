#!/bin/bash

# cat ~/hosts.txt | parallel -a - ssh {} \
# "source /share/home/hpcuser/.bash_profile && echo {} && python /share/home/hpcuser/examples/imagenet/check_cupy.py"

for ip in $(cat ~/hosts.txt);
do
    echo $ip
    mpirun -n 2 -ppn 1 -hosts 10.0.0.5,$ip python /share/home/hpcuser/examples/imagenet/check_cupy.py
done
