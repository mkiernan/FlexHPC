#!/bin/bash
################################################################################
#
# BeeGFS Scaleset Installation Script
#
# Tested On:
# CentOS 7.2
#
# Not yet on: 
# CentOS HPC:6.5, 6.8, HPC:7.1, 7.2, 7.3
# Ubuntu 16.04-LTS, 16.10
# RedHat 7.3
# SUSE SLES-HPC:12-SP1
#
################################################################################
set -x
#set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

# Passed in user created by waagent
HPC_ADMIN=$1
HPC_GROUP=$HPC_ADMIN
HPC_GID=1000
HOMEDIR="/home/$HPC_ADMIN"

# Number of Metadata & Storage Disks Passed in From Template
NMETADATADISKS=$3

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
SHARE_HOME=/share/home
SHARE_SCRATCH=/share/beegfs

# BeeGFS Management Node
MGMT_HOSTNAME="headnode"
# BeeGFS 
BEEGFS_SBIN=/opt/beegfs/sbin
BEEGFS_METADATA=/data/meta
BEEGFS_STORAGE=/data/storage
BEEGFS_MGMT=/var/beegfs/mgmt

SECONDS=0 #-- record wall time of script + functions
timestamp() { echo "ELAPSED TIME> $SECONDS seconds"; }

SECONDS=0 #-- use builtin shell var to record function times
WALLTIME=0 #-- record wall time of script
functiontimer()
{
        echo "Function $1 took $SECONDS seconds";
        let WALLTIME+=$SECONDS
        SECONDS=0

} #--- end of functiontimer() ---#


# Installs all required packages.
#
install_pkgs()
{
	yum -y install epel-release
	yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs gcc gcc-c++ nfs-utils rpcbind mdadm wget python-pip kernel kernel-devel openmpi openmpi-devel automake autoconf
	functiontimer "install_pkgs()"
}

# Partitions all data disks attached to the VM and creates
# a RAID-0 volume with them.
#
setup_data_disks()
{
    mountPoint="$1"
    filesystem="$2"
    devices="$3"
    raidDevice="$4"
    createdPartitions=""

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

        if [ "$filesystem" == "xfs" ]; then
            mkfs -t $filesystem /dev/$raidDevice
            echo "/dev/$raidDevice $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,sunit=1024,swidth=4096,nofail 0 2" >> /etc/fstab
        else
            mkfs.ext4 -i 2048 -I 512 -J size=400 -Odir_index,filetype /dev/$raidDevice
            sleep 5
            tune2fs -o user_xattr /dev/$raidDevice
            echo "/dev/$raidDevice $mountPoint $filesystem noatime,nodiratime,nobarrier,nofail 0 2" >> /etc/fstab
        fi
        
        sleep 10
        
        mount /dev/$raidDevice
    fi
	functiontimer "setup_data_disks()"

} #-- end of setup_data_disks() --#

setup_disks()
{      
	# Dump the current disk config for debugging
	fdisk -l
    
	# Dump the scsi config
	lsscsi
    
	# Get the root/OS disk so we know which device it uses and can ignore it later
	rootDevice=`mount | grep "on / type" | awk '{print $1}' | sed 's/[0-9]//g'`
    
	# Get the TMP disk so we know which device and can ignore it later
	tmpDevice=`mount | grep "on /mnt/resource type" | awk '{print $1}' | sed 's/[0-9]//g'`

	# Get the metadata and storage disk sizes from fdisk, we ignore the disks above
	metadataDiskSize=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | awk '{print $3}' | sort -n -r | tail -1`
	storageDiskSize=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | awk '{print $3}' | sort -n | tail -1`

	if [ "$metadataDiskSize" == "$storageDiskSize" ]; then
		# Compute number of disks
		nbDisks=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | wc -l`
		echo "nbDisks=$nbDisks"
		let nbMetadaDisks=$NMETADATADISKS
		let nbStorageDisks=nbDisks-$nbMetadaDisks
	        let nbStorageDisks=nbDisks-nbMetadaDisks
		echo "nbMetadaDisks=$nbMetadaDisks nbStorageDisks=$nbStorageDisks"			
		
		metadataDevices="`fdisk -l | grep '^Disk /dev/' | grep $metadataDiskSize | awk '{print $2}' | awk -F: '{print $1}' | sort | head -$nbMetadaDisks | tr '\n' ' ' | sed 's|/dev/||g'`"
		storageDevices="`fdisk -l | grep '^Disk /dev/' | grep $storageDiskSize | awk '{print $2}' | awk -F: '{print $1}' | sort | tail -$nbStorageDisks | tr '\n' ' ' | sed 's|/dev/||g'`"
		else
		# Based on the known disk sizes, grab the meta and storage devices
		metadataDevices="`fdisk -l | grep '^Disk /dev/' | grep $metadataDiskSize | awk '{print $2}' | awk -F: '{print $1}' | sort | tr '\n' ' ' | sed 's|/dev/||g'`"
		storageDevices="`fdisk -l | grep '^Disk /dev/' | grep $storageDiskSize | awk '{print $2}' | awk -F: '{print $1}' | sort | tr '\n' ' ' | sed 's|/dev/||g'`"
	fi

	mkdir -p $BEEGFS_STORAGE
	setup_data_disks $BEEGFS_STORAGE "xfs" "$storageDevices" "md10"
	mkdir -p $BEEGFS_METADATA    
	setup_data_disks $BEEGFS_METADATA "ext4" "$metadataDevices" "md20"

	mount -a

	functiontimer "setup_disks()"

} #-- end of setup_disks() --#

install_beegfs()
{
	# Install BeeGFS repo
	wget -O /etc/yum.repos.d/beegfs-rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
	rpm --import http://www.beegfs.com/release/beegfs_6/gpg/RPM-GPG-KEY-beegfs

	# setup metata data
	yum install -y beegfs-meta
	$BEEGFS_SBIN/beegfs-setup-meta -p $BEEGFS_METADATA -m $MGMT_HOSTNAME -f
	tune_meta
	systemctl daemon-reload
	systemctl enable beegfs-meta.service
		
	# setup storage
	yum install -y beegfs-storage
	$BEEGFS_SBIN/beegfs-setup-storage -p $BEEGFS_STORAGE -m $MGMT_HOSTNAME
	tune_storage
	systemctl daemon-reload
	systemctl enable beegfs-storage.service

	functiontimer "install_beegfs()"

} #-- end of install_beegfs() --#

tune_storage()
{
	#echo deadline > /sys/block/md10/queue/scheduler
	#echo 4096 > /sys/block/md10/queue/nr_requests
	#echo 32768 > /sys/block/md10/queue/read_ahead_kb

	sed -i 's/^connMaxInternodeNum.*/connMaxInternodeNum = 800/g' /etc/beegfs/beegfs-storage.conf
	sed -i 's/^tuneNumWorkers.*/tuneNumWorkers = 128/g' /etc/beegfs/beegfs-storage.conf
	sed -i 's/^tuneFileReadAheadSize.*/tuneFileReadAheadSize = 32m/g' /etc/beegfs/beegfs-storage.conf
	sed -i 's/^tuneFileReadAheadTriggerSize.*/tuneFileReadAheadTriggerSize = 2m/g' /etc/beegfs/beegfs-storage.conf
	sed -i 's/^tuneFileReadSize.*/tuneFileReadSize = 256k/g' /etc/beegfs/beegfs-storage.conf
	sed -i 's/^tuneFileWriteSize.*/tuneFileWriteSize = 256k/g' /etc/beegfs/beegfs-storage.conf
	sed -i 's/^tuneWorkerBufSize.*/tuneWorkerBufSize = 16m/g' /etc/beegfs/beegfs-storage.conf	
	functiontimer "tune_storage()"

} #--end of tune_storage() --#

tune_meta()
{
	# See http://www.beegfs.com/wiki/MetaServerTuning#xattr
	#echo deadline > /sys/block/md20/queue/scheduler
	#echo 128 > /sys/block/md20/queue/nr_requests
	#echo 128 > /sys/block/md20/queue/read_ahead_kb

	sed -i 's/^connMaxInternodeNum.*/connMaxInternodeNum = 800/g' /etc/beegfs/beegfs-meta.conf
	sed -i 's/^tuneNumWorkers.*/tuneNumWorkers = 128/g' /etc/beegfs/beegfs-meta.conf
	functiontimer "tune_meta()"

} #-- end of tune_meta() --#
 
tune_tcp()
{
	echo "net.ipv4.neigh.default.gc_thresh1=1100" >> /etc/sysctl.conf
	echo "net.ipv4.neigh.default.gc_thresh2=2200" >> /etc/sysctl.conf
	echo "net.ipv4.neigh.default.gc_thresh3=4400" >> /etc/sysctl.conf
	funtiontimer "tune_tcp()"

} #--end of tune_tcp() --#

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

	functiontimer "setup_system_centosredhat()"

} #--- end of setup_system_centosredhat() ---#

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

echo "##################################################"
echo "############## BeeGFS Node Setup #################"
echo "##################################################"
#comment out the password locks when testing.
passwd -l $HPC_ADMIN #-- lock account to prevent conflicts during install
echo "Deploying $PUBLISHER, $OFFER, $SKU....."
SETUP_MARKER=/var/local/install_beegfs.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

install_pkgs
setup_disks
tune_tcp
setup_domain
install_beegfs

# Create marker file so we know we're configured
touch $SETUP_MARKER
passwd -u $HPC_ADMIN #-- unlock account
echo "Script ran for $WALLTIME seconds."
shutdown -r +1 &
exit 0
