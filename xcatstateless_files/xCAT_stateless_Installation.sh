#!/bin/bash 

echo "#################################### Creating Ens.port ###########################################"
perl -pi -e "s/BOOTPROTO=\S+/BOOTPROTO=none/ " /etc/sysconfig/network-scripts/ifcfg-ens$1
perl -pi -e "s/ONBOOT=\S+/ONBOOT=yes/ " /etc/sysconfig/network-scripts/ifcfg-ens$1
echo -e "IPADDR=192.168.1.1\nPREFIX=24\nIPV6_PRIVACY=no" >> /etc/sysconfig/network-scripts/ifcfg-ens$1
systemctl restart network

echo "#################################### Hostname ############################################"
hostnamectl set-hostname master.demo.lab && hostname

echo "#################################### Firewalld ###########################################"
systemctl stop firewalld && systemctl disable firewalld

echo "#################################### Selinux #############################################"
perl -pi -e "s/SELINUX=\S+/SELINUX=disabled/" /etc/selinux/config
setenforce 0
echo 0 > /sys/fs/selinux/enforce

echo "######################################### install from http rpm file ##############################################"
yum -y install http://build.openhpc.community/OpenHPC:/1.3/CentOS_7/x86_64/ohpc-release-1.3-1.el7.x86_64.rpm

echo "#################################### installing yum-utils ##############################################"
yum -y install yum-utils

echo "############################### xCat repositorys #####################################"
wget -P /etc/yum.repos.d https://xcat.org/files/xcat/repos/yum/latest/xcat-core/xcat-core.repo --no-check-certificate
wget -P /etc/yum.repos.d https://xcat.org/files/xcat/repos/yum/xcat-dep/rh7/x86_64/xcat-dep.repo --no-check-certificate

echo "######################### install ohpc & xCat #####################################"
yum -y install ohpc-base xCAT && . /etc/profile.d/xcat.sh

echo "################################# ntpd&chronyd service #########################"
systemctl enable ntpd.service
echo "server 192.168.1.1 iburst" >> /etc/ntp.conf
systemctl restart ntpd && systemctl status ntpd

echo "server 192.168.1.1 iburst" >> /etc/chrony.conf
echo "local stratum 10" >> /etc/chrony.conf
systemctl start chronyd.service && systemctl status chronyd.service

echo "################################# basic xcat setup #########################"
ifconfig ens$1 192.168.1.1 netmask 255.255.255.0 up
chdef -t site dhcpinterfaces="xcatmn|ens$1"

echo "########################### copy iso image ##################################"
copycds ios_files/$(ls ios_files | cut -d "" -f 1 | head -$3 | tail -1)

# Creating osimages names 
echo "osimages....."
echo "$(lsdef -t osimage)" > osfile							    #lsdef -t osimage
osi=$(head -2 osfile | tail -1 | cut -d " " -f 1)

echo "################# Genimage ###################"
genimage $osi

echo "############################### Exporting image #################################"
export CHROOT=/install/netboot/$(echo "$osi" | cut -d "-" -f 1)/x86_64/compute/rootimg/

# Adding OpenHPC Componentes
yum-config-manager --installroot=$CHROOT --enable base
cp /etc/yum.repos.d/OpenHPC.repo $CHROOT/etc/yum.repos.d
cp /etc/yum.repos.d/epel.repo $CHROOT/etc/yum.repos.d

# Adding OpenHPC in nodes
cp /etc/yum.repos.d/OpenHPC.repo $CHROOT/etc/yum.repos.d
yum -y --installroot=$CHROOT install perl
yum -y --installroot=$CHROOT install ntp kernel lmod-ohpc

# Mounting /home and /opt/ohpc/pub to image om nodes
echo "192.168.1.1:/home /home nfs defaults 0 0" >> $CHROOT/etc/fstab
echo "192.168.1.1:/opt/ohpc/pub /opt/ohpc/pub nfs defaults 0 0" >> $CHROOT/etc/fstab

# Exporting /home and /opt/ohpc/pub to image
echo "/home *(rw,no_subtree_check,fsid=10,no_root_squash)" >> /etc/exports
echo "/opt/ohpc/pub *(ro,no_subtree_check,fsid=11)" >> /etc/exports

# Common HardDisk using NFS '/nfs' mounted disk for all compute nodes
if [ $4 == 'y' ] || [ $4 == 'yes' ];
then
  echo "192.168.1.1:/nfs /nfs nfs defaults 0 0" >> $CHROOT/etc/fstab
  echo "/nfs *(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
fi
exportfs -a
systemctl restart nfs-server && systemctl enable nfs-server && systemctl status nfs-server

# NTP time service on computes
chroot $CHROOT systemctl enable ntpd
echo "server 192.168.1.1" >> $CHROOT/etc/ntp.conf

echo "########################### Slurm_Installation_Process ##################################"
# Munge configureation
export MUNGEUSER=991
groupadd -g $MUNGEUSER munge
useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge  -s /sbin/nologin munge
export SLURMUSER=992
groupadd -g $SLURMUSER slurm
useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm  -s /bin/bash slurm


yum install epel-release munge munge-libs munge-devel -y
yum -y --installroot=$CHROOT install epel-release munge munge-libs munge-devel

yum install rng-tools -y
rngd -r /dev/urandom
/usr/sbin/create-munge-key -r
dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
chown -R munge: /etc/munge/ /var/log/munge/
chmod 0700 /etc/munge/ /var/log/munge/

cp /etc/munge/munge.key $CHROOT/etc/munge

systemctl enable munge && systemctl start munge
chroot $CHROOT systemctl enable munge
#Test munge.
munge -n
munge -n | munge

echo "###################################### Slurm confirigation ############################"

yum install openssl openssl-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad gcc mariadb-server mariadb-devel -y

wget -P /opt https://download.schedmd.com/slurm/slurm-21.08.8.tar.bz2

yum -y install rpm-build
rpmbuild -ta /opt/slurm-21.08.8.tar.bz2

# For Master
yum -y install rpm-build
cd /root/rpmbuild/RPMS/x86_64/ && yum -y --nogpgcheck localinstall * && cd -

# For Nodes
yum -y --installroot=$CHROOT install rpm-build
cp -r /root/rpmbuild $CHROOT/
cd $CHROOT/rpmbuild/RPMS/x86_64/ && yum -y --installroot=$CHROOT --nogpgcheck localinstall * && cd -

#Edit the slurm.conf file
cp /etc/slurm/slurm.conf.example /etc/slurm/slurm.conf
perl -pi -e "s/SlurmctldHost=\S+/SlurmctldHost=master.demo.lab/" /etc/slurm/slurm.conf
perl -pi -e "s/SlurmUser=\S+/SlurmUser=root/" /etc/slurm/slurm.conf
perl -pi -e "s/#SlurmdUser=root/SlurmdUser=root/" /etc/slurm/slurm.conf
perl -pi -e "s/NodeName=linux\[1-32\] CPUs=1 State=UNKNOWN/NodeName=c\[1-2\] CPUs=1 State=UNKNOWN/" /etc/slurm/slurm.conf

cp /etc/slurm/cgroup.conf.example /etc/slurm/cgroup.conf

# Database conf.
cp /etc/slurm/slurmdbd.conf.example /etc/slurm/slurmdbd.conf
perl -pi -e "s/StoragePass=\S+/#StoragePass=/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/StorageUser=\S+/StorageUser=root/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/#StorageLoc=\S+/StorageLoc=slurm_acct_db/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/SlurmUser=\S+/SlurmUser=root/" /etc/slurm/slurmdbd.conf

#node
cp /etc/slurm/slurm.conf $CHROOT/etc/slurm/
cp /etc/slurm/cgroup.conf $CHROOT/etc/slurm/
echo "/etc/slurm/slurm.conf -> /etc/slurm/slurm.conf " >> /install/custom/netboot/compute.synclist
echo "/etc/munge/munge.key -> /etc/munge/munge.key " >> /install/custom/netboot/compute.synclist
chroot $CHROOT systemctl enable slurmd.service

#master
mkdir /var/spool/slurm
chown root: /var/spool/slurm/
chmod 755 /var/spool/slurm/
touch /var/log/slurmctld.log
chown root: /var/log/slurmctld.log
touch /var/log/slurm_jobacct.log
chown root: /var/log/slurm_jobacct.log

#nodes
mkdir $CHROOT/var/spool/slurm
chown root: $CHROOT/var/spool/slurm
chmod 755 $CHROOT/var/spool/slurm
mkdir $CHROOT/var/log/slurm
touch $CHROOT/var/log/slurm/slurmd.log
chown root: $CHROOT/var/log/slurm/slurmd.log

chroot $CHROOT systemctl start slurmd.service

# mysql database
systemctl enable mariadb
systemctl start mariadb
systemctl status mariadb

mysql -e "CREATE DATABASE slurm_acct_db"

# Changinf ownership
chown root: /etc/slurm/slurmdbd.conf
chmod 600 /etc/slurm/slurmdbd.conf
touch /var/log/slurmdbd.log
chown root: /var/log/slurmdbd.log

#Slurmdbd service
systemctl enable slurmdbd
systemctl start slurmdbd
systemctl status slurmdbd

# Slurmctld service
systemctl enable slurmctld.service
systemctl start slurmctld.service
systemctl status slurmctld.service

echo "##################################### Nagios installtion ##########################################"
yum -y install ohpc-nagios
yum -y --installroot=$CHROOT install nagios-plugins-all-ohpc nrpe-ohpc --skip-broken

# Configure NRPE in compute image
chroot $CHROOT systemctl enable nrpe
perl -pi -e "s/^allowed_hosts=/# allowed_hosts=/" $CHROOT/etc/nagios/nrpe.cfg
perl -pi -e "s/pid_file=\S+/pid_file=\/var\/run\/nrpe\/nrpe.pid/ " $CHROOT/etc/nagios/nrpe.cfg

echo "nrpe 5666/tcp #NRPE" >> $CHROOT/etc/services
echo "nrpe: 192.168.1.1 : ALLOW" >> $CHROOT/etc/hosts.allow
echo "nrpe : ALL : DENY" >> $CHROOT/etc/hosts.allow
chroot $CHROOT /usr/sbin/useradd -c "NRPEuserfortheNRPEservice" -d /var/run/nrpe -r -g nrpe -s /sbin/nologin nrpe
chroot $CHROOT /usr/sbin/groupadd -r nrpe

# Remote services
mv /etc/nagios/conf.d/services.cfg.example /etc/nagios/conf.d/services.cfg

# Adding nodes name and ip-address in /etc/nagios/conf.d/hosts.cfg(path)

echo '''## Linux Host Template ##
define host{
        name linux-box ; Name of this template
        use generic-host ; Inherit default values
        check_period 24x7
        check_interval 5
        retry_interval 1
        max_check_attempts 10
        check_command check-host-alive
        notification_period 24x7
        notification_interval 30
        notification_options d,r
        contact_groups admins
        register 0 ; DONT REGISTER THIS - ITS A TEMPLATE
}

define hostgroup {
        hostgroup_name compute
        alias compute nodes
        members 
} 
# example configuration of 4 remote linux systems
''' > /etc/nagios/conf.d/hosts.cfg

for ((i=0 ; i < $2 ; i++));
do
  n=$(($i+1))
  echo -n "c$n," >> nodenames
done

perl -pi -e "s/members /members $(cat nodenames)/" /etc/nagios/conf.d/hosts.cfg

for ((i=0 ; i < $2 ; i++));
do
  n=$(($i+1))
  echo -e "\ndefine host {\n use linux-box\n host_name c$n\n alias c$n\n address $(head -$n ./ip_file | tail -1)   ; IP address of Remote Linux host\n}"  >> /etc/nagios/conf.d/hosts.cfg
done

# location of mail for alert 
perl -pi -e "s/ \/bin\/mail/ \/usr\/bin\/mailx/g" /etc/nagios/objects/commands.cfg

#update email address
perl -pi -e "s/nagios\@localhost/root\@hostname.demo.lab/" /etc/nagios/objects/contacts.cfg

# check-ssh for hosts
echo command[check_ssh]=/usr/lib64/nagios/plugins/check_ssh localhost  >> $CHROOT/etc/nagios/nrpe.cfg

# Setting Passwords
htpasswd -bc /etc/nagios/passwd nagiosadmin "root"

# Configureing nagios on master
chkconfig nagios on
systemctl start nagios
systemctl status nagios
chmod u+s `which ping`
# UserName = nagiosadmin 
# ---------------------------------------------------------------------------------------------------------

# Path for xCAT synclist 
mkdir -p /install/custom/netboot
chdef -t osimage -o centos7.9-x86_64-netboot-compute synclists="/install/custom/netboot/compute.synclist"

# credential files
echo "/etc/passwd -> /etc/passwd" > /install/custom/netboot/compute.synclist
echo "/etc/group -> /etc/group" >> /install/custom/netboot/compute.synclist
echo "/etc/shadow -> /etc/shadow" >> /install/custom/netboot/compute.synclist

echo "########################### Createig node #################################"

for ((i=0 ; i < $2 ; i++));
do
  n=$(($i+1))
  mkdef -t node c$n groups=compute,all ip=$(head -$n ./ip_file | tail -1) mac=$(head -$n ./mac_file | tail -1) netboot=xnba arch=x86_64
done

chdef -t site domain="master.demo.lab"
chdef -t site master="192.168.1.1"
chdef -t site forwarders="192.168.1.1"
chdef -t site nameservces="192.168.1.1"
chtab key=system passwd.username=root passwd.password=root

echo "#################### packimage ###################"
packimage $osi

makehosts
makenetworks
makedhcp -a
makedhcp -n
makedns -a
makedns -n

echo "################# Checking is everything good[ok] #####################"
xcatprobe xcatmn -i ens$1
sleep 5

echo "########################### Nodeset provisioning image ###############################"
nodeset compute osimage=$osi
