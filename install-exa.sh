#!/bin/bash
USER=$1
#LICIP=$2
HOST=`hostname`
#echo $USER,$LICIP,$HOST

mkdir /mnt/resource/scratch
mkdir /mnt/resource/scratch/benchmark
mkdir /mnt/resource/scratch/INSTALLERS

wget http://azbenchmarkstorage.blob.core.windows.net/exabenchmarkstorage/powerflow-5.3c-linux.tar.gz -O /mnt/resource/scratch/INSTALLERS/powerflow.tgz
cd /mnt/resource/scratch/INSTALLERS
tar -xzf powerflow.tgz
yum install -y compat-libstdc++-33.i686 rsh pax giflib libXpm X11 opengl
chown -R $1:$1 /mnt/resource/scratch
