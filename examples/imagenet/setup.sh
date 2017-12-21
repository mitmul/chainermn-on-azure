#!/bin/bash

RESOURCE_GROUP=ChainerMN
VMSS_NAME=chainer

az vmss nic list -g ${RESOURCE_GROUP} --vmss-name ${VMSS_NAME} \
--query "[*].ipConfigurations[0].privateIpAddress" -o tsv > ~/hosts.txt

n_success=0
n_nodes=`wc -l < ~/hosts.txt`

for ip in `cat ~/hosts.txt`;
do
    host=`head -n 1 ~/hosts.txt`
    mpiexec -n 2 -ppn 1 -host $host,$ip -genvall -DAPL python -c \
    "import chainermn; \
    comm = chainermn.create_communicator('hierarchical'); \
    comm.rank"
    if [ $? -ne 0 ]; then
        id=`python get_id.py $ip`
        echo -e "$ip - Failed. Instance ID: $id"
        az vmss restart -n ${VMSS_NAME} -g ${RESOURCE_GROUP} --instance-ids $id
    else
        n_success=$(expr $n_success + 1)
        echo -e "$ip - Success (n_success: $n_success / $n_nodes)"
    fi
    echo "--------------------"
done

if [ $n_success -eq $n_nodes ]; then
    echo "All succeeded"
    mpiexec -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -pm 1
    mpiexec -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -i 0 -ac 2505,875
    mpiexec -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -i 1 -ac 2505,875
    mpiexec -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -i 2 -ac 2505,875
    mpiexec -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -i 3 -ac 2505,875
else
    echo "Some nodes are failed to be setup."
fi
