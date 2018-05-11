# MNIST with ChainerMN

```
git clone https://github.com/chainer/chainermn
cd chainermn/examples/mnist
mpirun \
-f ~/hosts.txt \
-ppn 4 -n 32 \
-envall \
python train_mnist.py -g --communicator non_cuda_aware
```
