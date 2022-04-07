#!/bin/bash

sdb=$1; sdc=$2; sdd=$3
ISO_address=$4

if [ -e /var/log/logging.txt ]
	then
		echo "log will be record on /var/log/logging.txt"
	else
		touch /var/log/logging.txt && echo "New log file hase been created"
		echo "log will be record on /var/log/logging.txt"
fi

log='/var/log/logging.txt'

# task 1
# install and check SSH status
run_ssh(){
	echo "Installing SSH client"
	yum -y install openssh-server 1>>${log} && echo "SSH was installed"
	(systemctl status sshd | grep running) 1>>${log} && status=$"OK"
	case $status in
		OK)
			echo "SSH is active" ;;
		*)
			echo "SSH is inactive"
		exit 1 ;;
	esac

	#Check network working
	sed -e "s/ONBOOT='no'/ONBOOT='yes'/" /etc/sysconfig/network-scripts/ifcfg-enp0s3 1>>${log} && echo "Network is working"
}

#task 2
configure_sshd(){
	sed -i "s/#PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config && echo "Root logging still permited"

	service sshd restart 2>&1>>${log}
	echo "SSHD service has been restarted"

	#Installing iptables
	yum install iptables -y 1>>${log} && echo "iptables has been installed"
	iptables -A INPUT -p tcp --dport 22 -j ACCEPT && echo "Port 22 is open"
}

#task 3
repo_DVD(){
	#Creating a directory for mount ISO
	mkdir -p /mnt/iso && echo "Directory for mout ISO was created"
	modprobe loop 1>>${log}
	#Mount ISO
	mount ${ISO_address}CentOS-7-x86_64-DVD-2009.iso /mnt/iso/ -t iso9660 -o loop 1>>${log} && echo "Mount compleated"

	#Configuring local.repos file
	cd /etc/yum.repos.d/ && echo -e "[LocalRepo] \nname=LocalRepo \nbaseurl=file:///mnt/iso \nenabled=1 \ngpgcheck=1 \ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7" > local.repo && echo "local.repo file was configured"

	#Make the local repository the only one available
	yum update --disablerepo "*" --enablerepo=LocalRepo 1>>${log} && echo "LocalRepo is available"
	yum clean all 1>>${log}
}
#task 4..5
configure_RAID_with_LVM(){
	#Tell LVM which physical hard disks we intend to use
	pvcreate /dev/${sdb} /dev/${sdc} /dev/${sdd} 1>>${log} && echo "Pvcreate is compleated"
	#Create the new volume group
	vgcreate storage /dev/${sdb} /dev/${sdc} /dev/${sdd} 1>>${log} && echo "New group has been created"
	#Create the new logical volume as a RAID 5
	lvcreate --type raid5 -l 100%FREE -n storageVolumeLMV storage 1>>${log} && echo "New logical volume has been created"
}

#task 6..7
configure_xfs_and_mount(){
	#Format the filesystem
	mkfs.xfs -d su=64k,sw=5 /dev/storage/storageVolumeLMV 1>>${log} && echo "New filesystem has been created"
	#Create directory for storage and moun it
	mkdir -p /mnt/storage
	#Add info into the fstab file
	echo "/dev/storage/storageVolumeLMV /mnt/storage xfs defaults 0 0" >> /etc/fstab && echo "fstab file was changed"
	mount /mnt/storage 1>>${log} && echo "Mount completed"
}

#task8
create_nfs(){
	#installing NFS
	yum install nfs-utils -y 1>>${log} && echo "nfs-utils has been installed"
	#Add nfs-server service to autoran and start
	systemctl enable nfs-server.service 1>>${log} && systemctl start nfs-server 1>>${log} && echo "NFS service has been added"
	#Create directory for share
	mkdir -p /mnt/storage/CatalogForExport
	#Export configuration
	echo "/mnt/storage/CatalogForExport/ 192.168.100.8(sync)" >> /etc/exports && echo "Export configuration has been added"
	#Export file system
	exportfs -av 1>>${log} && echo "Export file system is working"
	#Permission for NFS service
	firewall-cmd --add-service=nfs 1>>${log} && firewall-cmd --add-service=nfs 1>>${log} && echo "Permissions for NFS have been added"
	#Saving settings
	iptables-save | tail -n4 1>>${log} && echo "NFS settings have been saved"
}

run_ssh
configure_sshd
repo_DVD
configure_RAID_with_LVM
configure_xfs_and_mount
create_nfs
exit 0
