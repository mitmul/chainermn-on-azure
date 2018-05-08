# MNIST with ChainerMN

```
git clone https://github.com/chainer/chainermn
cd chainermn/examples/mnist
mpiexec \
-hosts localhost \
-ppn 4 -n 4 \
python train_mnist.py -g --communicator non_cuda_aware
```
