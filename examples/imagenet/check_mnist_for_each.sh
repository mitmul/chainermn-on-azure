#!/bin/bash

# run_mnist () {
#     echo "====================="
#     echo $ip
#     mpirun -n 4 -ppn 4 -hosts $ip -genvall python train_mnist.py -g
# }

# ip=$(cat ~/hosts.txt)
# export -f run_mnist
# parallel run_mnist ::: $ip

for ip in $(cat ~/hosts.txt);
do 
    echo "====================="
    echo $ip
    mpirun -n 4 -ppn 4 -hosts $ip -genvall python train_mnist.py -g -e 1
done
