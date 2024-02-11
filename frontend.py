#!/usr/bin/python3

import os

ensp = int(input("Enter the ENS port number: "))

opt = int(input("Select the Booting Process\n\t1. xCAT Stateless\n\t2. xCAT Statefull\n\t-> "))

if opt == 1:
	os.system(f"bash xcatstateless_files/xCAT_stateless_Installation.sh {ensp}")
elif opt == 2:
	os.system(f"bash xcatstatefull_files/xCAT_statefull_Installation.sh {ensp}")
else:
	print("Please Enter the Given Options.....")
