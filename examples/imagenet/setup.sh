#!/bin/bash -xe

RESOURCE_GROUP=chainermn
VMSS_NAME=vmss

az vmss nic list -g ${RESOURCE_GROUP} --vmss-name ${VMSS_NAME} \
--query "[*].ipConfigurations[0].privateIpAddress" -o tsv > ~/hosts.txt

n_success=0
n_nodes=`wc -l < ~/hosts.txt`

for ip in `cat ~/hosts.txt`;
do
    host=`head -n 1 ~/hosts.txt`
    mpirun -n 2 -ppn 1 -hosts $host,$ip -envall python3 -c \
    "import chainermn; \
    comm = chainermn.create_communicator('hierarchical'); \
    comm.rank"
    cuda_status=`ssh ${ip} "source /share/home/hpcuser/.bash_profile && python -c \"import chainer; chainer.print_runtime_info()\""`
    if [ $? -ne 0 ]; then
        echo "Can't communicate with ${ip}"
    elif [[ ${cuda_status} = *"CUDARuntimeError"* ]]; then
        echo "CUDA is broken on ${ip}. Restarting..."
        id=$(python get_id.py ${ip})
        az vmss restart -n ${VMSS_NAME} -g ${RESOURCE_GROUP} --instance-ids $id
    else
        n_success=$(expr $n_success + 1)
        echo -e "$ip - Success (n_success: $n_success / $n_nodes)"
    fi
    echo "--------------------"
done

if [ $n_success -eq $n_nodes ]; then
    echo "All succeeded"
    mpirun -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -pm 1
    mpirun -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -i 0 -ac 2505,875
    mpirun -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -i 1 -ac 2505,875
    mpirun -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -i 2 -ac 2505,875
    mpirun -n ${n_nodes} -ppn 1 -f ~/hosts.txt sudo nvidia-smi -i 3 -ac 2505,875
else
    echo "Some nodes are failed."
fi
