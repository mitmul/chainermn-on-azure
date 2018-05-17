#!/bin/bash

if [ ! -d results ]; then
    mkdir results
fi

masterip=$(head -n 1 ~/hosts.txt)
for ip in $(cat ~/hosts.txt);
do
    if [ ${ip} == ${masterip} ]; then
        echo "skip ${masterip} - ${ip}"
        continue
    fi
    echo "${masterip} - ${ip}"
    mpirun -tune tune_128 -n 8 -ppn 4 -genvall -hosts ${masterip},${ip} \
    python mnist_3iter.py -g --communicator non_cuda_aware > results/${ip}.txt
    result=$(tail -n 2 results/${ip}.txt);
    if [[ $result == *"elapsed_time"* ]]; then
        echo ${ip} : "Success"
    else
        echo ${ip} : "Broken"
    fi
done
