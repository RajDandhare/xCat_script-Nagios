#!/usr/bin/python3

import subprocess

with open(r"ip_file", 'r') as fp:
    ip_c = len(fp.readlines())

with open(r"mac_file", 'r') as fp:
    mac_c = len(fp.readlines())

if ip_c == mac_c:
	
	nfs = input("Do you have external disk connected to master for NFS? [y/n]").lower()
	if nfs == 'y' or nfs == 'yes':
		subprocess.run(['bash','nfs.sh'])

	ensp = int(input("Enter the ENS port number: "))
	osf = int(input("Select IOS file:\n\t1.CentOS-7\n\t-> "))
	
	opt = int(input("Select the Booting Process\n\t1. xCAT Stateless\n\t2. xCAT Statefull\n\t-> "))
	if opt == 1:
		subprocess.run(['bash','xcatstateless_files/xCAT_stateless_Installtion.sh',f'{ensp}',f'{mac_c}',f'{osf}',f'{nfs}'])
	elif opt == 2:
		subprocess.run(['bash','xcatstateless_files/xCAT_stateless_Installtion.sh',f'{ensp}',f'{mac_c}',f'{osf}',f'{nfs}'])
	else:
		print("Please Enter the Given Options.....")
else:
	print("ERROR: count of ip and mac addresses are not same!!!! Check the ip_file and mac_file. ")
