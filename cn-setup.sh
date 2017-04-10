#!/bin/bash
echo ##################################################
echo ############# Compute Node Setup #################
echo ##################################################
IPPRE=$1
HPC_USER=$2
#SHARE_HOME=/space/home
SHARE_HOME=/home
SHARE_SPACE=/space

setup_disks()
{
	mkdir -p $SHARE_SPACE
	mkdir -p $SHARE_HOME
	mkdir -p /mnt/resource/scratch
	chown -R $HPC_USER:$HPC_USER /mnt/resource/
	chmod 777 $SHARE_SPACE
}

setup_system_centos72()
{
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
	echo "$IPPRE:$SHARE_SPACE $SHARE_SPACE nfs defaults,nofail 0 0" | tee -a /etc/fstab
	echo "$IPPRE:$SHARE_HOME $SHARE_HOME nfs defaults,nofail 0 0" | tee -a /etc/fstab
	showmount -e 10.0.0.4
	mount -a
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
        # disable selinux
        sed -i 's/enforcing/disabled/g' /etc/selinux/config
        setenforce permissive

        # Don't require password for HPC user sudo
        echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

        # Disable tty requirement for sudo
        sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

        # Steps done by waagent ossetup
##      useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER
##      groupadd -g $HPC_GID $HPC_GROUP

        # Undo the HOME setup done by waagent ossetup
#        mv -p /home/$HPC_USER $SHARE_HOME
#        usermod -m -d $SHARE_HOME/$HPC_USER $HPC_USER

        mkdir -p $SHARE_HOME/$HPC_USER/.ssh

        # Configure public key auth for the HPC user
        ssh-keygen -t rsa -f $SHARE_HOME/$HPC_USER/.ssh/id_rsa -q -P ""
        cat $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub >> $SHARE_HOME/$HPC_USER/.ssh/authorized_keys

        echo "Host *" > $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    StrictHostKeyChecking no" >> $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    UserKnownHostsFile /dev/null" >> $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    PasswordAuthentication no" >> $SHARE_HOME/$HPC_USER/.ssh/config

        # Fix .ssh folder ownership
        chown -R $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER

        # Fix permissions
        chmod 700 $SHARE_HOME/$HPC_USER/.ssh
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/config
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/authorized_keys
        chmod 600 $SHARE_HOME/$HPC_USER/.ssh/id_rsa
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub
}
setup_disks
setup_system_centos72
setup_user
setup_env
df
