#!/bin/bash
echo ##################################################
echo ############# Compute Node Setup #################
echo ##################################################
date
set -x
#set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

#IPHEADNODE=$1
IPHEADNODE=10.0.0.4
#HPC_USER=$2
#$HPC_GROUP=$HPC_USER

# User
#HPC_USER=$1
HPC_USER=hpc
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007

# Shares
SHARE_DATA=/share/data
#SHARE_HOME=/space/home
SHARE_HOME=/share/home
LOCAL_SCRATCH=/mnt/resource

setup_disks()
{
	mkdir -p $SHARE_DATA
	mkdir -p $SHARE_HOME
	mkdir -p $LOCAL_SCRATCH
	chmod -R 777 $SHARE_HOME
	chmod -R 777 $SHARE_DATA
	chmod -R 777 $LOCAL_SCRATCH
}

setup_system_centos72()
{
        # disable selinux
        sed -i 's/enforcing/disabled/g' /etc/selinux/config
        setenforce permissive

        echo "* hard memlock unlimited" >> /etc/security/limits.conf
        echo "* soft memlock unlimited" >> /etc/security/limits.conf

	ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
	ln -s /opt/intel/impi/5.1.3.181/lib64/ /opt/intel/impi/5.1.3.181/lib

	yum install -y -q nfs-utils

	systemctl enable rpcbind
	systemctl enable nfs-server
	systemctl enable nfs-lock
	systemctl enable nfs-idmap
	systemctl start rpcbind
	systemctl start nfs-server
	systemctl start nfs-lock
	systemctl start nfs-idmap
#localip=`hostname -i | cut --delimiter='.' -f -3`
	#echo "$IPHEADNODE:$SHARE_DATA $SHARE_DATA nfs defaults,nofail 0 0" | tee -a /etc/fstab
	#echo "$IPHEADNODE:$SHARE_HOME $SHARE_HOME nfs defaults,nofail 0 0" | tee -a /etc/fstab
	echo "$IPHEADNODE:$SHARE_DATA $SHARE_DATA nfs4 rw,auto,_netdev 0 0" | tee -a /etc/fstab
	echo "$IPHEADNODE:$SHARE_HOME $SHARE_HOME nfs4 rw,auto,_netdev 0 0" | tee -a /etc/fstab
	cat /etc/fstab
	rpcinfo -p 10.0.0.4
	showmount -e $IPHEADNODE
	mount -a
	df -h
}

setup_env()
{
	echo export INTELMPI_ROOT=/opt/intel/impi/5.1.3.181 >> $SHARE_HOME/$HPC_USER/.bashrc
	echo export I_MPI_FABRICS=shm:dapl >> $SHARE_HOME/$HPC_USER/.bashrc
	echo export I_MPI_DAPL_PROVIDER=ofa-v2-ib0 >> $SHARE_HOME/$HPC_USER/.bashrc
	echo export I_MPI_ROOT=/opt/intel/compilers_and_libraries_2016.2.181/linux/mpi >> $SHARE_HOME/$HPC_USER/.bashrc
	echo export I_MPI_DYNAMIC_CONNECTION=0 >> $SHARE_HOME/$HPC_USER/.bashrc
}

setup_user()
{
        # Add User + Group
        groupadd -g $HPC_GID $HPC_GROUP
        useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

        # Don't require password for HPC user sudo
        echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

        # Disable tty requirement for sudo
        sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

#	chown -R $HPC_USER:$HPC_USER /mnt/resource/

        # Undo the HOME setup done by waagent ossetup
#        mv -p /home/$HPC_USER $SHARE_HOME
#        usermod -m -d $SHARE_HOME/$HPC_USER $HPC_USER
}
setup_disks
setup_system_centos72
setup_user
setup_env
date
