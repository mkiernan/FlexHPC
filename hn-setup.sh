#!/bin/bash
################################################################################
#
# Head-Node Installation Script
#
# Tested On:
# CentOS HPC:6.5, 6.8, HPC:7.1, 7.2, 7.3
# Ubuntu 16.04-LTS, 16.10
# RedHat 7.3
# SUSE SLES-HPC:12-SP1
#
################################################################################
set -x
#set -xeuo pipefail #-- strict/exit on fail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

# Passed in user created by waagent
HPC_ADMIN=$1
HPC_GROUP=$HPC_ADMIN
HPC_GID=1000

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
#VMIMAGE="SUSE:SLES-HPC:12-SP1"

PUBLISHER=`echo $VMIMAGE| awk -F ":" '{print $1}'`
OFFER=`echo $VMIMAGE| awk -F ":" '{print $2}'`
SKU=`echo $VMIMAGE| awk -F ":" '{print $3}'`
OSVERS=`echo $VMIMAGE| awk -F ":" '{print $4}'`

# Shares 
SHARE_ROOT=/share
SHARE_DATA=/share/data
SHARE_HOME=/share/home
SHARE_CLUSTERMAP=/share/clustermap
#LOCAL_SCRATCH=/mnt/resource

# Local filesystem to map shares to
DATAFS=/data
#SCRATCHFS=/scratch_local
CLUSTERMAPFS=/clustermap

IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
localip=`echo $IP | cut --delimiter='.' -f -3`

echo User is: $HPC_ADMIN

SECONDS=0 #-- use builtin shell var to record function times
WALLTIME=0 #-- record wall time of script
functiontimer()
{
        echo "Function $1 took $SECONDS seconds";
        let WALLTIME+=$SECONDS
        SECONDS=0

} #--- end of functiontimer() ---#

setup_shares()
{
	mkdir -p $SHARE_DATA
	mkdir -p $SHARE_HOME
#	mkdir -p $SCRATCHFS
	mkdir -p $SHARE_CLUSTERMAP
	chmod -R 777 $SHARE_HOME
	chmod -R 777 $SHARE_DATA
#	chmod -R 777 $SCRATCHFS
	chmod -R 777 $SHARE_CLUSTERMAP
	echo "$SHARE_DATA $localip.*(rw,sync,no_root_squash,no_all_squash,no_subtree_check)" | tee -a /etc/exports
	echo "$SHARE_HOME $localip.*(rw,sync,no_root_squash,no_all_squash,no_subtree_check)" | tee -a /etc/exports
	echo "$SHARE_CLUSTERMAP $localip.*(rw,sync,no_root_squash,no_all_squash,no_subtree_check)" | tee -a /etc/exports
	exportfs -a
	functiontimer "setup_shares()"

} #--- end of setup_disks() ---#

setup_system_centosredhat()
{
	# disable selinux
	sed -i 's/enforcing/disabled/g' /etc/selinux/config
	setenforce permissive

        if [[ $PUBLISHER == "RedHat" && $OFFER == "RHEL" && $SKU == "7.3" ]]; then
		systemctl disable firewalld
		service firewalld stop
	fi

	echo "* hard memlock unlimited" >> /etc/security/limits.conf
	echo "* soft memlock unlimited" >> /etc/security/limits.conf

	yum install -y -q nfs-utils autofs
        if [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS-HPC" && $SKU == "6.5" ]]; then
		chkconfig nfs on 
		chkconfig rpcbind on 
		service rpcbind start
		service nfs start
	else 
		systemctl enable rpcbind
		systemctl enable nfs-server
		systemctl enable nfs-lock
		systemctl enable nfs-idmap
		systemctl start rpcbind
		systemctl start nfs-server
		systemctl start nfs-lock
		systemctl start nfs-idmap
		#systemctl restart nfs-server
#-verify
		wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
		rpm -ivh epel-release-7-9.noarch.rpm
#-verify
	fi

	yum install -y -q sshpass nmap htop sysstat lsscsi
	yum install -y -q libibverb-utils infiniband-diags
	yum install -y -q environment-modules
	yum install -y -q openmpi-bin openmpi-common openmpi-dev openmpi-doc
	yum install -y -q gcc g++ kernel-devel
	#yum groupinstall -y "X Window System"
	#npm install -g azure-cli

	#-- Microsoft -HPC images should have this installed already
	rpm -v -i --nodeps /opt/intelMPI/intel_mpi_packages/*.rpm
	ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
	ln -s /opt/intel/impi/5.1.3.181/lib64/ /opt/intel/impi/5.1.3.181/lib

	#--- Setup BeeGFS Management Node
	setup_beegfs_mgmt_centos

	functiontimer "setup_system_centosredhat()"

} #--- end of setup_system_centosredhat() ---#

setup_system_suse()
{
	echo "* hard memlock unlimited" >> /etc/security/limits.conf
        echo "* soft memlock unlimited" >> /etc/security/limits.conf

	pkgs="libbz2-1 libz1 openssl libopenssl-devel gcc gcc-c++ nfs-client nfs-utils rpcbind\
              mdadm make automake multipath-tools nmap infiniband-diags nfs-kernel-server autofs"

	zypper -n install $pkgs
	zypper -n install environment-modules

	systemctl enable rpcbind.service
	systemctl start rpcbind.service
	systemctl enable nfsserver.service
	systemctl start nfsserver.service

	# rdma pkgs not pre-installed on SLES so add them now. 
	rpm -v -i --nodeps /opt/intelMPI/intel_mpi_packages/*.rpm
	ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
	ln -s /opt/intel/impi/5.1.3.181/lib64/ /opt/intel/impi/5.1.3.181/lib
	#disable kernel updates to prevent rdma issues; unlock with zypper rl
	zypper al 'kernel*'

	functiontimer "setup_system_suse()"

} #--- end of setup_system_suse() ---#

setup_system_ubuntu()
{
	export DEBIAN_FRONTEND=noninteractive
        echo "* hard memlock unlimited" >> /etc/security/limits.conf
        echo "* soft memlock unlimited" >> /etc/security/limits.conf

	apt-get -y update
	apt-get -y upgrade
	apt-get install -y -q nfs-common rpcbind nfs-kernel-server autofs
	apt-get install -y -q build-essential
	apt-get install -y -q openmpi-bin openmpi-common openmpi-dev openmpi-doc
	systemctl start nfs-kernel-server.service

	#apt install -y pip
	#pip install --upgrade-pip
	apt-get install -y -q sshpass nmap htop wget sysstat lsscsi
	apt-get install -y -q infiniband-diags
	#apt-get install -y -q environment-modules

	functiontimer "setup_system_ubuntu()"

} #--- end of setup_system_ubuntu() ---#

setup_system()
{
        if [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "16.04-LTS" ]]; then
                setup_system_ubuntu
        elif [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "16.10" ]]; then
                setup_system_ubuntu
        elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS-HPC" && $SKU == "6.5" ]]; then
                setup_system_centosredhat
        elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS" && $SKU == "6.8" ]]; then
                setup_system_centosredhat
        elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS-HPC" && $SKU == "7.1" ]]; then
                setup_system_centosredhat
        elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS" && $SKU == "7.2" ]]; then
                setup_system_centosredhat
        elif [[ $PUBLISHER == "OpenLogic" && $OFFER == "CentOS" && $SKU == "7.3" ]]; then
                setup_system_centosredhat
        elif [[ $PUBLISHER == "RedHat" && $OFFER == "RHEL" && $SKU == "7.3" ]]; then
                setup_system_centosredhat
        elif [[ $PUBLISHER == "SUSE" && $OFFER == "SLES-HPC" && $SKU == "12-SP1" ]]; then
                setup_system_suse
        else
                echo "***** IMAGE $PUBLISHER:$OFFER:$VERSION NOT SUPPORTED *****"
                exit -1
        fi
	functiontimer "setup_system()"

} #--- end of setup_system() ---#

setup_user()
{
        # Add User + Group 
	# waagent takes care of the user and group; except on SLES for some reason we still need to groupadd
	# will fail harmlessly on all but SLES
	groupadd -g $HPC_GID $HPC_GROUP
#	useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_ADMIN -s /bin/bash -u $HPC_UID $HPC_ADMIN

	# Undo the HOME setup done by waagent ossetup -> move it to NFS share
	#usermod -m -d $SHARE_HOME/$HPC_ADMIN $HPC_ADMIN
	# automount will pick this up at the /share/home location and map it back to /home
	# purpose of this is to have plenty of space in the homedir and keep it off the os disk. 
	mv /home/$HPC_ADMIN $SHARE_HOME
	usermod -d $SHARE_HOME/$HPC_ADMIN $HPC_ADMIN

	# Don't require password for HPC user sudo
	echo "$HPC_ADMIN ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

	# Disable tty requirement for sudo
	sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

	mkdir -p $SHARE_HOME/$HPC_ADMIN/.ssh

	# Configure public key auth for the HPC user
	#ssh-keygen -t rsa -f $SHARE_HOME/$HPC_ADMIN/.ssh/id_rsa -q -P ""
	ssh-keygen -t rsa -f $SHARE_HOME/$HPC_ADMIN/.ssh/id_rsa -q -N ""
	cat $SHARE_HOME/$HPC_ADMIN/.ssh/id_rsa.pub >> $SHARE_HOME/$HPC_ADMIN/.ssh/authorized_keys

	echo "Host *" > $SHARE_HOME/$HPC_ADMIN/.ssh/config
	echo "StrictHostKeyChecking no" >> $SHARE_HOME/$HPC_ADMIN/.ssh/config
# 	echo "UserKnownHostsFile /dev/null" >> $SHARE_HOME/$HPC_ADMIN/.ssh/config
# 	echo "PasswordAuthentication no" >> $SHARE_HOME/$HPC_ADMIN/.ssh/config

	# Fix .ssh folder ownership
	chown -R $HPC_ADMIN:$HPC_GROUP $SHARE_HOME/$HPC_ADMIN

	# Fix permissions
	chmod 700 $SHARE_HOME/$HPC_ADMIN/.ssh
	chmod 644 $SHARE_HOME/$HPC_ADMIN/.ssh/config
	chmod 644 $SHARE_HOME/$HPC_ADMIN/.ssh/authorized_keys
	chmod 600 $SHARE_HOME/$HPC_ADMIN/.ssh/id_rsa
	chmod 644 $SHARE_HOME/$HPC_ADMIN/.ssh/id_rsa.pub

	functiontimer "setup_user()"

} #--- end of setup_user() ---#

setup_utilities()
{
	mkdir -p $SHARE_CLUSTERMAP/hosts
	chmod 755 $SHARE_CLUSTERMAP/hosts
	mkdir -p $SHARE_HOME/$HPC_ADMIN/bin
	chown $HPC_ADMIN:$HPC_GROUP $SHARE_HOME/$HPC_ADMIN/bin
	#mkdir -p $SHARE_HOME/$HPC_ADMIN/deploy
	#chmod 755 $SHARE_HOME/$HPC_ADMIN/deploy
	#chown $HPC_ADMIN:$HPC_GROUP $SHARE_HOME/$HPC_ADMIN/deploy
	#cp hn-setup.sh cn-setup.sh $SHARE_HOME/$HPC_ADMIN/deploy
	cp clusRun.sh pingpong.sh $SHARE_HOME/$HPC_ADMIN/bin
	chmod 755 $SHARE_HOME/$HPC_ADMIN/bin/*.sh

	nmap -sn $localip.* | grep $localip. | awk '{print $5}' > $SHARE_HOME/$HPC_ADMIN/bin/nodeips.txt
	myhost=`hostname -i`
	sed -i '/\<'$myhost'\>/d' $SHARE_HOME/$HPC_ADMIN/bin/nodeips.txt
	sed -i '/\<10.0.0.1\>/d' $SHARE_HOME/$HPC_ADMIN/bin/nodeips.txt
#
# Problem to record scale set node names since the nodes are not up yet. 
# Workaround to have each scale set node create a file with it's hostname in /clustermap/hosts directory. 
# See touch statement in cn-setup.sh. clusRun.sh updated accordingly. 
# This approach has the advantage that it's easy to add scale set nodes to the config also.
#
#	for NAME in `cat $SHARE_HOME/$HPC_ADMIN/bin/nodeips.txt`; do sudo -u $HPC_ADMIN -s ssh -o ConnectTimeout=2 $HPC_ADMIN@$NAME 'hostname' >> $SHARE_HOME/$HPC_ADMIN/bin/nodenames.txt;done
#	NAMES=`ls $SHARE_HOME/$HPC_ADMIN/hosts`
#	for NAME in $NAMES; do echo $NAME >> $SHARE_HOME/$HPC_ADMIN/bin/nodenames.txt; done

	functiontimer "setup_utilities()"

} #--- end of setup_utilities() ---#

#
# For later, will use environment modules to load user app environments
#
setup_environment_modules()
{
	echo "source /etc/profile.d/modules.sh" >> $SHARE_HOME/$HPC_ADMIN/.bashrc
	functiontimer "setup_environment_modules()"
}

setup_diskpack()
{
	raidDevice="md10"
	filesystem="ext4"
	mountPoint=$SHARE_ROOT

	# Dump the current disk config for debugging
	fdisk -l

	# Dump the scsi config
	lsscsi

	# Get the root/OS disk so we know which device it uses and can ignore it later
	rootDevice=`mount | grep "on / type" | awk '{print $1}' | sed 's/[0-9]//g'`

	# Get the TMP disk so we know which device and can ignore it later
	#tmpDevice=`mount | grep "on /mnt type" | awk '{print $1}' | sed 's/[0-9]//g'`
	tmpDevice=`mount | grep "on /mnt" | awk '{print $1}' | sed 's/[0-9]//g'`

	createdPartitions=""
	storageDiskSize=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | awk '{print $3}' | sort -n | tail -1`
	echo $storageDiskSize
	devices="`fdisk -l | grep '^Disk /dev/' | grep $storageDiskSize | awk '{print $2}' | awk -F: '{print $1}' | sort | tr '\n' ' ' | sed 's|/dev/||g'`"
	echo $devices

	# Loop through and partition disks until not found
	for disk in $devices; do
		fdisk -l /dev/$disk || break
		fdisk /dev/$disk << EOF
n
p
1


t
fd
w
EOF
	createdPartitions="$createdPartitions /dev/${disk}1"
	done
	sleep 10

	# Create RAID-0 volume
	if [ -n "$createdPartitions" ]; then
		devices=`echo $createdPartitions | wc -w`
		mdadm --create /dev/$raidDevice --level 0 --raid-devices $devices $createdPartitions
		sleep 10
		mdadm /dev/$raidDevice
		#- beware this is VERY slow on CentOS 6.5 (about 30 minutes for 10TB)
		mkfs.ext4 -i 4096 -I 512 -J size=400 -Odir_index,filetype /dev/$raidDevice
		sleep 5
		tune2fs -o user_xattr /dev/$raidDevice
		mkdir -p $mountPoint
		# have to fix /etc/fstab to avoid md device number cycling on Ubuntu; by hand:
		# https://support.clustrix.com/hc/en-us/articles/203655739-How-to-make-the-mdadm-RAID-volume-persists-after-reboot
		e2label /dev/md10 SPACE
		# insert into /etc/fstab:
		# LABEL=SPACE /space ext4 noatime,nodiratime,nobarrier,nofail 0 2
		echo "LABEL=SPACE $mountPoint $filesystem noatime,nodiratime,nobarrier,nofail 0 2" >> /etc/fstab
		#echo "/dev/$raidDevice $mountPoint $filesystem noatime,nodiratime,nobarrier,nofail 0 2" >> /etc/fstab
		sleep 10
		mount /dev/$raidDevice
		df -h
		# Backup mdadm config to its config file. (optional)
		mdadm --verbose --detail --scan >> /etc/mdadm.conf
        fi
	functiontimer "setup_diskpack()"

} #--- end of setup_diskpack() ---#

#-- currently this is CentOS specific
setup_beegfs_mgmt_centos()
{
	MGMT_HOSTNAME=`hostname`
	# BeeGFS 
	BEEGFS_SBIN=/opt/beegfs/sbin
	BEEGFS_MGMT=/var/beegfs/mgmt

	wget -O /etc/yum.repos.d/beegfs-rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
	rpm --import http://www.beegfs.com/release/beegfs_6/gpg/RPM-GPG-KEY-beegfs
	yum install -y beegfs-mgmtd beegfs-helperd beegfs-utils beegfs-admon
        
	# Install management server and admon
	mkdir -p $BEEGFS_MGMT
	$BEEGFS_SBIN/beegfs-setup-mgmtd -p $BEEGFS_MGMT

	#sed -i 's|^storeMgmtdDirectory.*|storeMgmtdDirectory = '$BEEGFS_MGMT'|g' /etc/beegfs/beegfs-mgmtd.conf
	sed -i 's/^sysMgmtdHost.*/sysMgmtdHost = '$MGMT_HOSTNAME'/g' /etc/beegfs/beegfs-admon.conf
	systemctl daemon-reload
	systemctl enable beegfs-mgmtd.service
	systemctl enable beegfs-admon.service

	functiontimer "setup_beegfs_mgmt()"

} #--- end of setup_beegfs_mgmt() ---#

echo "##################################################"
echo "############### Head Node Setup ##################"
echo "##################################################"
#comment out the password locks when testing. 
passwd -l $HPC_ADMIN #-- lock account to prevent conflicts during install
echo "Deploying $PUBLISHER, $OFFER, $SKU....."
setup_system
setup_diskpack
setup_shares
setup_user
setup_utilities
passwd -u $HPC_ADMIN #-- unlock account
#reboot #--- not really necessary, just to be 100% sure storage devices persist before users put data here. 
echo "Script ran for $WALLTIME seconds."
#chmod +x custom_extras.sh 
#source custom_extras.sh $USER
