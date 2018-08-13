

# FP32

N   Communicator     Mean    Median  Min     Max
1   non_cuda_aware   0.0709  0.0707  0.0696  0.0747
2   non_cuda_aware   0.0929  0.0926  0.0924  0.0995
4   non_cuda_aware   0.1089  0.1087  0.1082  0.1133
8   non_cuda_aware   0.1097  0.1095  0.1092  0.1174
16  non_cuda_aware   0.1189  0.1186  0.1105  0.1272
32  non_cuda_aware   0.1626  0.1621  0.1592  0.1739
64  non_cuda_aware   0.1656  0.1651  0.1628  0.1769
128 non_cuda_aware   0.1827  0.1814  0.1769  0.2005

hpcuser@vmss22b00000001:~/chainermn-imagenet-32k-master$ mpirun -n 1 -ppn 4 -f ~/hosts.txt -genvall python communication_micro_benchmark.py
Workers: Total=1, Inter=1, Intra=1
Model: ResNet50 (161 params, 102228128 bytes)
Trials: 100
-----------------------------------------------
Communicator     Mean    Median  Min     Max
non_cuda_aware   0.0709  0.0707  0.0696  0.0747
single_node      0.0031  0.0031  0.0031  0.0039
['vmss22b00000001']

hpcuser@vmss22b00000001:~/chainermn-imagenet-32k-master$ mpirun -n 2 -ppn 4 -f ~/hosts.txt -genvall python communication_micro_benchmark.py
Workers: Total=2, Inter=1, Intra=2
Model: ResNet50 (161 params, 102228128 bytes)
Trials: 100
-----------------------------------------------
Communicator     Mean    Median  Min     Max
non_cuda_aware   0.0929  0.0926  0.0924  0.0995
single_node      0.0177  0.0177  0.0176  0.0190
['vmss22b00000001']

hpcuser@vmss22b00000001:~/chainermn-imagenet-32k-master$ mpirun -n 4 -ppn 4 -f ~/hosts.txt -genvall python communication_micro_benchmark.py
Workers: Total=4, Inter=1, Intra=4
Model: ResNet50 (161 params, 102228128 bytes)
Trials: 100
-----------------------------------------------
Communicator     Mean    Median  Min     Max
non_cuda_aware   0.1089  0.1087  0.1082  0.1133
single_node      0.0356  0.0355  0.0354  0.0389
['vmss22b00000001']

hpcuser@vmss22b00000001:~/chainermn-imagenet-32k-master$ mpirun -n 8 -ppn 4 -f ~/hosts.txt -genvall python communication_micro_benchmark.py
Workers: Total=8, Inter=2, Intra=4
Model: ResNet50 (161 params, 102228128 bytes)
Trials: 100
-----------------------------------------------
Communicator     Mean    Median  Min     Max
non_cuda_aware   0.1097  0.1095  0.1092  0.1174
['vmss22b00000001', 'vmss22b00000010']

hpcuser@vmss22b00000001:~/chainermn-imagenet-32k-master$ mpirun -n 16 -ppn 4 -f ~/hosts.txt -genvall python communication_micro_benchmark.py
Workers: Total=16, Inter=4, Intra=4
Model: ResNet50 (161 params, 102228128 bytes)
Trials: 100
-----------------------------------------------
Communicator     Mean    Median  Min     Max
non_cuda_aware   0.1189  0.1186  0.1105  0.1272
['vmss22b00000001', 'vmss22b0000000G', 'vmss22b00000010', 'vmss22b0000001K']

hpcuser@vmss22b00000001:~/chainermn-imagenet-32k-master$ mpirun -n 32 -ppn 4 -f ~/hosts.txt -genvall python communication_micro_benchmark.py
Workers: Total=32, Inter=8, Intra=4
Model: ResNet50 (161 params, 102228128 bytes)
Trials: 100
-----------------------------------------------
Communicator     Mean    Median  Min     Max
non_cuda_aware   0.1626  0.1621  0.1592  0.1739
['vmss22b00000001', 'vmss22b00000003', 'vmss22b00000004', 'vmss22b0000000G', 'vmss22b0000000O', 'vmss22b00000010', 'vmss22b00000015', 'vmss22b0000001K']

hpcuser@vmss22b00000001:~/chainermn-imagenet-32k-master$ mpirun -n 64 -ppn 4 -f ~/hosts.txt -genvall python communication_micro_benchmark.py
Workers: Total=64, Inter=16, Intra=4
Model: ResNet50 (161 params, 102228128 bytes)
Trials: 100
-----------------------------------------------
Communicator     Mean    Median  Min     Max
non_cuda_aware   0.1656  0.1651  0.1628  0.1769
['vmss22b00000001', 'vmss22b00000003', 'vmss22b00000004', 'vmss22b00000006', 'vmss22b00000007', 'vmss22b0000000A', 'vmss22b0000000D', 'vmss22b0000000G', 'vmss22b0000000I', 'vmss22b0000000O', 'vmss22b00000010', 'vmss22b00000015', 'vmss22b0000001G', 'vmss22b0000001K', 'vmss22b0000001P', 'vmss22b0000001R']

hpcuser@vmss22b00000001:~/chainermn-imagenet-32k-master$ mpirun -n 128 -ppn 4 -f ~/hosts.txt -genvall python communication_micro_benchmark.py
Workers: Total=128, Inter=32, Intra=4
Model: ResNet50 (161 params, 102228128 bytes)
Trials: 100
-----------------------------------------------
Communicator     Mean    Median  Min     Max
non_cuda_aware   0.1827  0.1814  0.1769  0.2005
['vmss22b00000001', 'vmss22b00000002', 'vmss22b00000003', 'vmss22b00000004', 'vmss22b00000006', 'vmss22b00000007', 'vmss22b00000008', 'vmss22b00000009', 'vmss22b0000000A', 'vmss22b0000000B', 'vmss22b0000000C', 'vmss22b0000000D', 'vmss22b0000000E', 'vmss22b0000000G', 'vmss22b0000000H', 'vmss22b0000000I', 'vmss22b0000000L', 'vmss22b0000000O', 'vmss22b0000000S', 'vmss22b0000000W', 'vmss22b0000000Y', 'vmss22b0000000Z', 'vmss22b00000010', 'vmss22b00000015', 'vmss22b0000001D', 'vmss22b0000001G', 'vmss22b0000001K', 'vmss22b0000001L', 'vmss22b0000001P', 'vmss22b0000001R', 'vmss22b0000001T', 'vmss22b0000001X']
