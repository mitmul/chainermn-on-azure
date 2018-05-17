#!/bin/bash

cat ~/hosts.txt | parallel -a - ssh {} \
"source /share/home/hpcuser/.bash_profile && echo {} && python /share/home/hpcuser/examples/imagenet/check_cupy.py"
