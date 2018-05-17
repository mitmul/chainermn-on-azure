#!/bin/bash -xe

RESOURCE_GROUP=chainermn-k80
VMSS_NAME=vmss

ip=$1

cuda_status=$(ssh ${ip} "source /share/home/hpcuser/.bash_profile && python -c 'import chainer; chainer.print_runtime_info()'")
if ! $(mpirun -n 2 -ppn 1 -hosts ${host},${ip} -envall python -c "import chainermn; comm = chainermn.create_communicator('non_cuda_aware'); comm.rank"); then
    echo "Can't communicate with ${ip}";
    id=$(python get_id.py ${ip} -g ${RESOURCE_GROUP});
    az vmss restart -n ${VMSS_NAME} -g ${RESOURCE_GROUP} --instance-ids ${id};
    echo "${ip},${id}" >> failed
elif [[ ${cuda_status} = *"CUDARuntimeError"* ]]; then
    echo "CUDA is broken on ${ip}."
    echo ${cuda_status}
    echo "Restarting...";
    id=$(python get_id.py ${ip} -g ${RESOURCE_GROUP});
    az vmss restart -n ${VMSS_NAME} -g ${RESOURCE_GROUP} --instance-ids ${id};
    echo "${ip},${id}" >> failed
elif ! $(ssh ${ip} "source /share/home/hpcuser/.bash_profile && timeout 120 python -c 'import cupy; cupy.array(0)'"); then
    echo "CuPy cannot run correctly on ${ip}. Restarting...";
    id=$(python get_id.py ${ip} -g ${RESOURCE_GROUP});
    az vmss restart -n ${VMSS_NAME} -g ${RESOURCE_GROUP} --instance-ids ${id};
    echo "${ip},${id}" >> failed
else
    echo -e "$ip - Success";
    ecc=$(ssh ${ip} "sudo nvidia-smi -e 0");
    if [[ $ecc == *"already"* ]]; then
        echo "ECC has already been disabled."
        ssh ${ip} "sudo nvidia-smi -pm 1";
    else
        ssh ${ip} "sudo reboot";
    fi
fi

exit 0
