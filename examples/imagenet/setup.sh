#!/bin/bash

cat ~/hosts.txt | parallel -a - bash setup_k80.sh {}
