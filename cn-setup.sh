#!/bin/bash
echo ##################################################
echo ############# Compute Node Setup #################
echo ##################################################
IPPRE=$1
USER=$2
yum install -y -q nfs-utils
mkdir -p /mnt/nfsshare
mkdir -p /mnt/resource/scratch
chmod 777 /mnt/nfsshare
systemctl enable rpcbind
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
localip=`hostname -i | cut --delimiter='.' -f -3`
echo "$IPPRE:/mnt/nfsshare    /mnt/nfsshare   nfs defaults 0 0" | tee -a /etc/fstab
echo "$IPPRE:/mnt/resource/scratch    /mnt/resource/scratch   nfs defaults 0 0" | tee -a /etc/fstab
showmount -e 10.0.0.4
mount -a

ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
ln -s /opt/intel/impi/5.1.3.181/lib64/ /opt/intel/impi/5.1.3.181/lib

echo export INTELMPI_ROOT=/opt/intel/impi/5.1.3.181 >> /home/$USER/.bashrc
echo export I_MPI_FABRICS=shm:dapl >> /home/$USER/.bashrc
echo export I_MPI_DAPL_PROVIDER=ofa-v2-ib0 >> /home/$USER/.bashrc
echo export I_MPI_ROOT=/opt/intel/compilers_and_libraries_2016.2.181/linux/mpi >> /home/$USER/.bashrc
echo export I_MPI_DYNAMIC_CONNECTION=0 >> /home/$USER/.bashrc

chown -R $USER:$USER /mnt/resource/

# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

df
