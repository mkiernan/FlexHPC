#!/bin/bash

# set the number of nodes and processes per node
#PBS -l nodes=2:ppn=1
# set name of job
#PBS -N mpi-pingpong
source /opt/intel/impi/5.1.3.181/bin64/mpivars.sh

CLUSTERMAPFS=/clustermap
HOSTS=`ls -m $CLUSTERMAPFS/hosts | sed "s/ //g"`

source /opt/intel/impi/5.1.3.181/bin64/mpivars.sh
mpirun -ppn 1 -n 2 -hosts $HOSTS -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 hostname

echo "MPI hostname test completed"

#mpirun -env I_MPI_FABRICS=dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 IMB-MPI1 pingpong
mpirun -np 32 -ppn 16 -host $HOSTS -env I_MPI_FABRICS=dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 IMB-MPI1 pingpong

echo "MPI pingpong test completed."
