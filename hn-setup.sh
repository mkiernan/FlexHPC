#!/bin/bash
#
# Head-Node Installation Script
#
# Tested On: CentOS 7.1, 7.2, Ubuntu 16.04
#
echo "##################################################"
echo "############### Head Node Setup ##################"
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
HPC_GROUP=$HPC_USER

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

} #--- end of setup_disks() ---#

setup_system_centos72()
{
	# disable selinux
	sed -i 's/enforcing/disabled/g' /etc/selinux/config
	setenforce permissive

	echo "* hard memlock unlimited" >> /etc/security/limits.conf
	echo "* soft memlock unlimited" >> /etc/security/limits.conf

	# do this before rpm's or too slow for the scaleset mounts
	yum install -y -q nfs-utils
	systemctl enable rpcbind
	systemctl enable nfs-server
	systemctl enable nfs-lock
	systemctl enable nfs-idmap
	systemctl start rpcbind
	systemctl start nfs-server
	systemctl start nfs-lock
	systemctl start nfs-idmap
	#systemctl restart nfs-server

	ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
	ln -s /opt/intel/impi/5.1.3.181/lib64/ /opt/intel/impi/5.1.3.181/lib

#-verify
	wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
	rpm -ivh epel-release-7-9.noarch.rpm
#-verify

	yum install -y -q sshpass nmap htop sysstat
	yum install -y -q libibverb-utils infiniband-diags
	yum install -y -q environment-modules
	#yum groupinstall -y "X Window System"
	#npm install -g azure-cli

} #--- end of setup_system_centos72() ---#

setup_system_ubuntu1604()
{
	env DEBIAN_FRONTEND noninteractive
        echo "* hard memlock unlimited" >> /etc/security/limits.conf
        echo "* soft memlock unlimited" >> /etc/security/limits.conf

	# do this before rpm's or too slow for the scaleset mounts
	apt-get install -y -q rpcbind nfs-kernel-server nfs-common
	systemctl start nfs-kernel-server.service

	apt-get -y update
	apt-get -y upgrade
	apt install -y pip
	pip install --upgrade-pip
	apt-get install -y -q sshpass nmap htop wget sysstat
	apt-get install -y -q infiniband-diags
	#apt-get install -y -q environment-modules

} #--- end of setup_system_ubuntu1604() ---#

setup_user()
{
        # Add User + Group
#	groupadd -g $HPC_GID $HPC_GROUP
#	useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER
	# Undo the HOME setup done by waagent ossetup -> move it to NFS share
	#mv -p /home/$HPC_USER $SHARE_HOME
	usermod -m -d $SHARE_HOME/$HPC_USER $HPC_USER

	# Don't require password for HPC user sudo
	echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

	# Disable tty requirement for sudo
	sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

	mkdir -p $SHARE_HOME/$HPC_USER/.ssh

	# Configure public key auth for the HPC user
	#ssh-keygen -t rsa -f $SHARE_HOME/$HPC_USER/.ssh/id_rsa -q -P ""
	ssh-keygen -t rsa -f $SHARE_HOME/$HPC_USER/.ssh/id_rsa -q -N ""
	cat $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub >> $SHARE_HOME/$HPC_USER/.ssh/authorized_keys

	echo "Host *" > $SHARE_HOME/$HPC_USER/.ssh/config
	echo "StrictHostKeyChecking no" >> $SHARE_HOME/$HPC_USER/.ssh/config
# 	echo "UserKnownHostsFile /dev/null" >> $SHARE_HOME/$HPC_USER/.ssh/config
# 	echo "PasswordAuthentication no" >> $SHARE_HOME/$HPC_USER/.ssh/config

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

} #--- end of setup_user() ---#

setup_utilities()
{
	mkdir -p $SHARE_HOME/$HPC_USER/bin
	mkdir -p $SHARE_HOME/$HPC_USER/hosts
	chmod 755 $SHARE_HOME/$HPC_USER/hosts
	chown $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER/bin
	chown $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER/hosts
	#mkdir -p $SHARE_HOME/$HPC_USER/deploy
	#chmod 755 $SHARE_HOME/$HPC_USER/deploy
	#chown $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER/deploy
	#cp hn-setup.sh cn-setup.sh $SHARE_HOME/$HPC_USER/deploy
	cp clusRun.sh pingpong.sh $SHARE_HOME/$HPC_USER/bin
	chmod 755 $SHARE_HOME/$HPC_USER/bin/*.sh

	nmap -sn $localip.* | grep $localip. | awk '{print $5}' > $SHARE_HOME/$HPC_USER/bin/nodeips.txt
	myhost=`hostname -i`
	sed -i '/\<'$myhost'\>/d' $SHARE_HOME/$HPC_USER/bin/nodeips.txt
	sed -i '/\<10.0.0.1\>/d' $SHARE_HOME/$HPC_USER/bin/nodeips.txt
#
# Problem to record scale set node names since the nodes are not up yet. 
# Workaround to have each scale set node create a file with it's hostname in ~/hosts directory. 
# See touch statement in cn-setup.sh. clusRun.sh updated accordingly. 
# This approach has the advantage that it's easy to add scale set nodes to the config also.
#
#	for NAME in `cat $SHARE_HOME/$HPC_USER/bin/nodeips.txt`; do sudo -u $HPC_USER -s ssh -o ConnectTimeout=2 $HPC_USER@$NAME 'hostname' >> $SHARE_HOME/$HPC_USER/bin/nodenames.txt;done
#	NAMES=`ls $SHARE_HOME/$HPC_USER/hosts`
#	for NAME in $NAMES; do echo $NAME >> $SHARE_HOME/$HPC_USER/bin/nodenames.txt; done

} #--- end of setup_utilities() ---#

#
# For later, will use environment modules to load user app environments
#
setup_environment_modules()
{
	echo "source /etc/profile.d/modules.sh" >> $SHARE_HOME/$HPC_USER/.bashrc
}

#passwd -l $HPC_USER #-- lock account to prevent treading on homedir changes

echo "Deploying $PUBLISHER, $OFFER, $SKU....."
setup_disks

if [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "16.04-LTS" ]]; then
	setup_system_ubuntu1604
elif [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "16.10" ]]; then
	setup_system_ubuntu1604
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
setup_utilities
#passwd -u $HPC_USER #-- unlock account
date

#chmod +x custom_extras.sh 
#source custom_extras.sh $USER
