#!/bin/bash -xe

RESOURCE_GROUP=$1
ip=$2
VMSS_NAME="vmss"

id=$(az vmss nic list -g ${RESOURCE_GROUP} --vmss-name ${VMSS_NAME} --query "[?ipConfigurations[0].privateIpAddress=='${ip}'].id" -o tsv)

echo "============================================="
cuda_status=$(ssh ${ip} "source /share/home/hpcuser/.bash_profile && python -c 'import chainer; chainer.print_runtime_info()'")
if ! $(mpirun -n 2 -ppn 1 -hosts ${host},${ip} -envall python -c "import chainermn; comm = chainermn.create_communicator('non_cuda_aware'); comm.rank"); then
    echo "Can't communicate with ${ip}";
    az vmss restart -n ${VMSS_NAME} -g ${RESOURCE_GROUP} --instance-ids ${id};
    echo "${ip},${id}" >> failed
elif [[ ${cuda_status} = *"CUDARuntimeError"* ]]; then
    echo "CUDA is broken on ${ip}."
    echo ${cuda_status}
    echo "Restarting...";
    az vmss restart -n ${VMSS_NAME} -g ${RESOURCE_GROUP} --instance-ids ${id};
    echo "${ip},${id}" >> failed
elif ! $(ssh ${ip} "source /share/home/hpcuser/.bash_profile && timeout 120 python -c 'import cupy; cupy.array(0); cupy.random.rand(2, 3).dot(cupy.random.rand(3, 4))'"); then
    echo "CuPy cannot run correctly on ${ip}. Restarting...";
    az vmss restart -n ${VMSS_NAME} -g ${RESOURCE_GROUP} --instance-ids ${id};
    echo "${ip},${id}" >> failed
else
    echo -e "$ip - Success";
    ecc=$(ssh ${ip} "sudo nvidia-smi -e 0");
    if [[ $ecc == *"already"* ]]; then
        echo "ECC has already been disabled."
        echo $ecc
        ssh ${ip} "sudo nvidia-smi -pm 1";
    else
        echo "ECC is just disabled now. Rebooting..."
        ssh ${ip} "sudo reboot";
    fi
fi

exit 0
