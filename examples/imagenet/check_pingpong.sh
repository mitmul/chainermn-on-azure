#!/bin/bash

rm -rf pingpong_result
if [ ! -d pingpong_result ]; then
    mkdir pingpong_result
fi

for ((i=0; i < 10; i++));
do
    masterip=$(head -n 1 ~/hosts.txt)
    for ip in $(cat ~/hosts.txt);
    do
        rm -rf pingpong_result/${ip}.txt
        mpirun -n 2 -ppn 1 -hosts ${masterip},${ip} \
        -genvall IMB-MPI1 pingpong > pingpong_result/${ip}.txt;
        t=$(cat pingpong_result/${ip}.txt | grep -E "^\s+0" | awk '{print $3}');
        echo "${ip},${t}" | tee -a pingpong_result/summary.csv
    done
done

python pingpong_summary.py
