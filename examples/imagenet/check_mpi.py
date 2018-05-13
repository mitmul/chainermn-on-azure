from mpi4py import MPI
import numpy as np


comm = MPI.COMM_WORLD

sendbuf = np.random.rand(32, 3, 512, 512).astype('f')
recvbuf = np.empty(sendbuf.shape, dtype='f')

comm.Allreduce(sendbuf, recvbuf, MPI.SUM)
