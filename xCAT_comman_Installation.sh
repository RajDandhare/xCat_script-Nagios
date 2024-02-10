#!/bin/bash

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
echo -e "SELINUX=disabled\nSELINUXTYPE=targeted" > /etc/selinux/config
setenforce 0
echo 0 > /sys/fs/selinux/enforce
#init 6
