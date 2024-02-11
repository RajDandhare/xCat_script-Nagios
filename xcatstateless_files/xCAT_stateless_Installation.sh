#!/bin/bash 
num_computes=2

echo "#################################### Creating Ens.port ###########################################"
perl -pi -e "s/BOOTPROTO=\S+/BOOTPROTO=none/ " /etc/sysconfig/network-scripts/ifcfg-ens$1
perl -pi -e "s/ONBOOT=\S+/ONBOOT=yes/ " /etc/sysconfig/network-scripts/ifcfg-ens$1
echo -e "IPADDR=192.168.1.1\nPREFIX=24\nIPV6_PRIVACY=no" >> /etc/sysconfig/network-scripts/ifcfg-ens$1
systemctl restart network

echo "#################################### Hostname ############################################"
hostnamectl set-hostname master.demo.lab
hostname

echo "#################################### Firewalld ###########################################"
systemctl stop firewalld
systemctl disable firewalld

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
copycds ios_files/CentOS-7-x86_64-DVD-2009.iso

echo "############################### Exporting image #################################"
export CHROOT=/install/netboot/centos7.9/x86_64/compute/rootimg/

echo "################# Genimage ###################"
echo "osimages....."
echo "$(lsdef -t osimage)" > osfile
osi=$(head -2 osfile | tail -1 | cut -d " " -f 1)
genimage $osi

# Adding OpenHPC Componentes
yum-config-manager --installroot=$CHROOT --enable base
cp /etc/yum.repos.d/OpenHPC.repo $CHROOT/etc/yum.repos.d
cp /etc/yum.repos.d/epel.repo $CHROOT/etc/yum.repos.d

# Adding OpenHPC in nodes
cp /etc/yum.repos.d/OpenHPC.repo $CHROOT/etc/yum.repos.d
yum -y --installroot=$CHROOT install perl
yum -y --installroot=$CHROOT install ohpc-base-compute --skip-broken
echo "Pause for 10 seconds to check............."
sleep 10
yum -y --installroot=$CHROOT install ntp kernel lmod-ohpc

# Mounting /home and /opt/ohpc/pub to image om nodes
echo "192.168.1.1:/home /home nfs defaults 0 0" >> $CHROOT/etc/fstab
echo "192.168.1.1:/opt/ohpc/pub /opt/ohpc/pub nfs defaults 0 0" >> $CHROOT/etc/fstab

# Exporting /home and /opt/ohpc/pub to image
echo "/home *(rw,no_subtree_check,fsid=10,no_root_squash)" >> /etc/exports
echo "/opt/ohpc/pub *(ro,no_subtree_check,fsid=11)" >> /etc/exports
exportfs -a
systemctl restart nfs-server && systemctl enable nfs-server && systemctl status nfs-server

# NTP time service on computes
chroot $CHROOT systemctl enable ntpd
echo "server 192.168.1.1" >> $CHROOT/etc/ntp.conf

echo "##################################### Nagios installtion ##########################################"
yum -y install ohpc-nagios
yum -y --installroot=$CHROOT install nagios-plugins-all-ohpc nrpe-ohpc --skip-broken

# Configure NRPE in compute image
chroot $CHROOT systemctl enable nrpe
perl -pi -e "s/^allowed_hosts=/# allowed_hosts=/" $CHROOT/etc/nagios/nrpe.cfg
perl -pi -e "s/pid_file=/pid_file=/var/run/nrpe/nrpe.pid/ " $CHROOT/etc/nagios/nrpe.cfg
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

for ((i=0 ; i < $num_computes ; i++));
do
  n=$(($i+1))
  echo -n "c$n," >> nodenames
done

perl -pi -e "s/members /members $(cat nodenames)/" /etc/nagios/conf.d/hosts.cfg

for ((i=0 ; i < $num_computes ; i++));
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

for ((i=0 ; i < $num_computes ; i++));
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
