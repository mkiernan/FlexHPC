#!/bin/bash
echo "##################################################"
echo "############# Compute Node Setup #################"
echo "##################################################"
date
set -x
#set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

# Passed in user created by waagent
HPC_USER=$1
#HPC_GROUP=$HPC_USER

# Linux distro detection remains a can of worms, just pass it in here:
VMIMAGE=$2
# Or uncomment one of these if running this script by hand. 
#VMIMAGE="Canonical:UbuntuServer:16.04-LTS"
#VMIMAGE="Canonical:UbuntuServer:16.10"
#VMIMAGE="OpenLogic:CentOS-HPC:6.5"
#VMIMAGE="OpenLogic:CentOS:6.8"
#VMIMAGE="OpenLogic:CentOS-HPC:7.1"
#VMIMAGE="OpenLogic:CentOS:7.2"
#VMIMAGE="OpenLogic:CentOS:7.3"
#VMIMAGE="RedHat:RHEL:7.3"
#VMIMAGE="SUSE:SLES-HPC:12-SP2" 

PUBLISHER=`echo $VMIMAGE| awk -F ":" '{print $1}'`
OFFER=`echo $VMIMAGE| awk -F ":" '{print $2}'`
SKU=`echo $VMIMAGE| awk -F ":" '{print $3}'`

IPHEADNODE=10.0.0.4

# Shares
SHARE_DATA=/share/data
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

} #--- end of setup_disks() ---# 

setup_system_centos72()
{
        # disable selinux
        sed -i 's/enforcing/disabled/g' /etc/selinux/config
        setenforce permissive

        echo "* hard memlock unlimited" >> /etc/security/limits.conf
        echo "* soft memlock unlimited" >> /etc/security/limits.conf

	yum install -y -q nfs-utils

#	systemctl enable rpcbind
#	systemctl enable nfs-server
#	systemctl enable nfs-lock
#	systemctl enable nfs-idmap
#	systemctl start rpcbind
#	systemctl start nfs-server
#	systemctl start nfs-lock
#	systemctl start nfs-idmap

	ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
	ln -s /opt/intel/impi/5.1.3.181/lib64/ /opt/intel/impi/5.1.3.181/lib

        yum install -y -q sshpass nmap htop sysstat
        yum install -y -q libibverb-utils infiniband-diags
        yum install -y -q environment-modules

	echo "$IPHEADNODE:$SHARE_DATA $SHARE_DATA nfs4 rw,retry=5,timeo=60,auto,_netdev 0 0" | tee -a /etc/fstab
	echo "$IPHEADNODE:$SHARE_HOME $SHARE_HOME nfs4 rw,retry=5,timeo=60,auto,_netdev 0 0" | tee -a /etc/fstab
	cat /etc/fstab
	rpcinfo -p $IPHEADNODE
	showmount -e $IPHEADNODE
	mount -a
	df -h
	ls -lR $SHARE_HOME/$HPC_USER
	touch $SHARE_HOME/$HPC_USER/hosts/$HOSTNAME
	echo `hostname -i` >>$SHARE_HOME/$HPC_USER/hosts/$HOSTNAME

} #--- end of setup_system_centos72() ---#

setup_system_ubuntu1604()
{
	env DEBIAN_FRONTEND noninteractive
        echo "* hard memlock unlimited" >> /etc/security/limits.conf
        echo "* soft memlock unlimited" >> /etc/security/limits.conf

        # do this before rpm's or too slow for the scaleset mounts
        #apt-get install -y -q rpcbind nfs-kernel-server nfs-common
        apt-get install -y -q nfs-common
        #systemctl start nfs-kernel-server.service

        apt-get -y update
        apt-get -y upgrade
        apt-get install -y -q sshpass nmap htop wget sysstat
        apt-get install -y -q infiniband-diags
        #apt-get install -y -q environment-modules

	echo "$IPHEADNODE:$SHARE_DATA $SHARE_DATA nfs4 rw,retry=5,timeo=60,auto,_netdev 0 0" | tee -a /etc/fstab
	echo "$IPHEADNODE:$SHARE_HOME $SHARE_HOME nfs4 rw,retry=5,timeo=60,auto,_netdev 0 0" | tee -a /etc/fstab
	cat /etc/fstab
	rpcinfo -p $IPHEADNODE
	showmount -e $IPHEADNODE
	mount -a
	df -h
	ls -lR $SHARE_HOME/$HPC_USER
	touch $SHARE_HOME/$HPC_USER/hosts/$HOSTNAME
	echo `hostname -i` >>$SHARE_HOME/$HPC_USER/hosts/$HOSTNAME

} #--- end of setup_system_ubuntu1604() ---#

setup_env()
{
	echo export INTELMPI_ROOT=/opt/intel/impi/5.1.3.181 >> $SHARE_HOME/$HPC_USER/.bashrc
	echo export I_MPI_FABRICS=shm:dapl >> $SHARE_HOME/$HPC_USER/.bashrc
	echo export I_MPI_DAPL_PROVIDER=ofa-v2-ib0 >> $SHARE_HOME/$HPC_USER/.bashrc
	echo export I_MPI_ROOT=/opt/intel/compilers_and_libraries_2016.2.181/linux/mpi >> $SHARE_HOME/$HPC_USER/.bashrc
	echo export I_MPI_DYNAMIC_CONNECTION=0 >> $SHARE_HOME/$HPC_USER/.bashrc

} #--- end of setup_env() ---#

setup_user()
{
        # Add User + Group
#       groupadd -g $HPC_GID $HPC_GROUP
#       useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER
        # Undo the HOME setup done by waagent ossetup
        usermod -m -d $SHARE_HOME/$HPC_USER $HPC_USER

        # Don't require password for HPC user sudo
        echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

        # Disable tty requirement for sudo
        sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

} #--- end of setup_user() ---#

setup_gpus_ubuntu1604()
{
	#-- Detect presence of K80 GPU's and configure 
	gpus=`lspci | grep "NVIDIA Corporation" | grep "Tesla K80"`
	ngpus=`echo $gpus | wc -l`

	if [ "$gpus" == "" ]; then
		echo "No gpu found."
		return;
	else
		echo "$ngpus Tesla K80's found. Configuring...."
	fi

	CUDA_REPO_PKG=cuda-repo-ubuntu1604_8.0.61-1_amd64.deb
	wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG}
	sudo dpkg -i /tmp/${CUDA_REPO_PKG}
	rm -f /tmp/${CUDA_REPO_PKG}
	#-- disable kernel updates to prevent nvidia driver issues for now:
	for i in $(dpkg -l "*$(uname -r)*" | grep image | awk '{print $2}'); do echo $i hold | sudo dpkg --set-selections; done
	#-- you can remove reverse this with:
	#for i in $(dpkg -l "*$(uname -r)*" | grep image | awk '{print $2}'); do echo $i install | sudo dpkg --set-selections; done
	#sudo apt-get update
	#sudo apt-get upgrade -y
	sudo apt-get install cuda-drivers
	sudo apt-get install cuda
	echo "export PATH=$PATH:/usr/local/cuda-8.0/bin/" >> ~/.bashrc
	source ~/.bashrc
	nvidia-smi

} #--- end of setup_gpus_ubuntu1604() ---#

#passwd -l $HPC_USER #-- lock account to prevent treading on homedir changes
echo "Deploying $PUBLISHER, $OFFER, $SKU....."
setup_disks

if [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "16.04-LTS" ]]; then
        setup_system_ubuntu1604
	setup_gpus_ubuntu1604
elif [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "16.10" ]]; then
        setup_system_ubuntu1604
	setup_gpus_ubuntu1604
elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS-HPC" && $SKU == "6.5" ]]; then
        setup_system_centos72
elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS" && $SKU == "6.8" ]]; then
        setup_system_centos72
elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS-HPC" && $SKU == "7.1" ]]; then
        setup_system_centos72
elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS" && $SKU == "7.2" ]]; then
        setup_system_centos72
elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS" && $SKU == "7.3" ]]; then
        setup_system_centos72
elif [[ $PUBLISHER == "RedhHat" && $OFFER == "RHEL" && $SKU == "7.3" ]]; then
        setup_system_centos72
elif [[ $PUBLISHER == "SUSE" && $OFFER == "SLES-HPC" && $SKU == "12-SP2" ]]; then
        setup_system_centos72
else
        echo "***** IMAGE $PUBLISHER:$OFFER:$VERSION NOT SUPPORTED *****"
        exit -1
fi

setup_user
setup_env
date
#passwd -u $HPC_USER #-- unlock account
