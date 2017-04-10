#!/bin/bash
#
# CentOS 7.2 Head-Node Installation Script: mkiernan@microsoft.com
#
set -x
#set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

#HPC_USER=$1
#$HPC_GROUP=$HPC_USER
#PASS=$2

# User
HPC_USER=hpc
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007

# Shares 
SHARE_DATA=/share/data
SHARE_HOME=/share/home
LOCAL_SCRATCH=/mnt/resource

IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
localip=`echo $IP | cut --delimiter='.' -f -3`

echo User is: $HPC_USER

setup_disks()
{
	mkdir -p $SHARE_DATA
	mkdir -p $SHARE_HOME
	mkdir -p $LOCAL_SCRATCH
	chmod -R 777 $SHARE_HOME
	chmod -R 777 $SHARE_DATA
	chmod -R 777 $LOCAL_SCRATCH
	echo "$SHARE_DATA $localip.*(rw,sync,no_root_squash,no_all_squash)" | tee -a /etc/exports
	echo "$SHARE_HOME $localip.*(rw,sync,no_root_squash,no_all_squash)" | tee -a /etc/exports
#	echo "$LOCAL_SCRATCH $localip.*(rw,sync,no_root_squash,no_all_squash)" | tee -a /etc/exports
}

setup_system_centos72()
{
	echo "* hard memlock unlimited" >> /etc/security/limits.conf
	echo "* soft memlock unlimited" >> /etc/security/limits.conf

	ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
	ln -s /opt/intel/impi/5.1.3.181/lib64/ /opt/intel/impi/5.1.3.181/lib

	wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm

	rpm -ivh epel-release-7-9.noarch.rpm
	yum install -y -q nfs-utils sshpass nmap htop
	yum groupinstall -y "X Window System"
	#npm install -g azure-cli

	systemctl enable rpcbind
	systemctl enable nfs-server
	systemctl enable nfs-lock
	systemctl enable nfs-idmap
	systemctl start rpcbind
	systemctl start nfs-server
	systemctl start nfs-lock
	systemctl start nfs-idmap
	systemctl restart nfs-server
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
   
        # Add User + Group
	groupadd -g $HPC_GID $HPC_GROUP
	useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

	# Undo the HOME setup done by waagent ossetup
#	mv -p /home/$HPC_USER $SHARE_HOME
#	usermod -m -d $SHARE_HOME/$HPC_USER $HPC_USER

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

#	chown $HPC_USER:$HPC_GROUP $SHARE_SCRATCH
#	chown $HPC_USER:$HPC_GROUP $SHARE_DATA
	chown $HPC_USER:$HPC_GROUP $LOCAL_SCRATCH

}

setup_utilities()
{
	mkdir -p $SHARE_HOME/$HPC_USER/bin
	mv clusRun.sh cn-setup.sh pingpong.sh $SHARE_HOME/$HPC_USER/bin
	chmod +x $SHARE_HOME/$HPC_USER/bin/*.sh
	chown $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER/bin

	nmap -sn $localip.* | grep $localip. | awk '{print $5}' > $SHARE_HOME/$HPC_USER/bin/nodeips.txt
	myhost=`hostname -i`
	sed -i '/\<'$myhost'\>/d' $SHARE_HOME/$HPC_USER/bin/nodeips.txt
	sed -i '/\<10.0.0.1\>/d' $SHARE_HOME/$HPC_USER/bin/nodeips.txt
}

setup_disks
setup_system_centos72
setup_user
setup_utilities

#chmod +x custom_extras.sh 
#source custom_extras.sh $USER
