# MNIST with ChainerMN

```
git clone https://github.com/chainer/chainermn
cd chainermn/examples/mnist
mpirun \
-hosts 10.0.0.7,10.0.0.8 \
-ppn 4 -n 8 \
-envall \
python train_mnist.py -g --communicator non_cuda_aware
```
