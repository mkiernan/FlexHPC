#!/bin/bash
echo ##################################################
echo ############# Compute Node Setup #################
echo ##################################################
IPPRE=$1
HPC_USER=$2
SHARE_HOME=/space/home
SHARE_SPACE=/space
yum install -y -q nfs-utils
mkdir -p $SHARE_SPACE
mkdir -p $SHARE_HOME
##mkdir -p /mnt/resource/scratch
##chown -R $HPC_USER:$HPC_USER /mnt/resource/
##chmod 777 /space

systemctl enable rpcbind
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
localip=`hostname -i | cut --delimiter='.' -f -3`
echo "$IPPRE:$SHARE_SPACE $SHARE_SPACE nfs defaults,nofail 0 0" | tee -a /etc/fstab
echo "$IPPRE:$SHARE_HOME $SHARE_HOME nfs defaults,nofail 0 0" | tee -a /etc/fstab
showmount -e 10.0.0.4
mount -a

ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
ln -s /opt/intel/impi/5.1.3.181/lib64/ /opt/intel/impi/5.1.3.181/lib

echo export INTELMPI_ROOT=/opt/intel/impi/5.1.3.181 >> $SHARE_HOME/$HPC_USER/.bashrc
echo export I_MPI_FABRICS=shm:dapl >> $SHARE_HOME/$HPC_USER/.bashrc
echo export I_MPI_DAPL_PROVIDER=ofa-v2-ib0 >> $SHARE_HOME/$HPC_USER/.bashrc
echo export I_MPI_ROOT=/opt/intel/compilers_and_libraries_2016.2.181/linux/mpi >> $SHARE_HOME/$HPC_USER/.bashrc
echo export I_MPI_DYNAMIC_CONNECTION=0 >> $SHARE_HOME/$HPC_USER/.bashrc


# Don't require password for HPC user sudo
echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

df
