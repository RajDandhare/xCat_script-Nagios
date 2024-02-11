# xCat_script-Nagios
This Project is for Boot the Multiple Nodes and make a Cluster with Nagios Monitoring Tool.

#This scripts will only work on Linux.
And only Boot CentOS7.9 in compute nodes.

Master Node system configuration:
RAM - 4GB
Sockets - 2 (you can use one socket too)
Core - 1 (if you use one socket you might need tow cores)

Compute Nodes system configuration:
  For Stateless:
    RAM - 8GB (you will need more RAM because it will boot on RAM without storage disk)
    Sockets - 2 (you can use one socket too)
    Core - 1 (if you use one socket you might need tow cores)
  For Statefull:
    RAM - 4GB
    Sockets - 2 (you can use one socket too)
    Core - 1 (if you use one socket you might need tow cores)

Steps:
1.  run frontend.py file "python3 frontend.py".
2.  it will you to enter the ens port (only work on ens ports currently).
3.  then it will show two options for Stateless and Statefull select one by entering correct option.
4.  thats it!!!!, You will see the script run on the terminal.
5.  when scripting is done you have to start or restart the nodes.

This All Projects is Done in VM.


Reference URL Links:

1.https://github.com/openhpc/ohpc/releases/download/v1.3.9.GA/Install_guide-CentOS7-xCAT-Stateless-SLURM-1.3.9-x86_64.pdf
2.https://github.com/openhpc/ohpc/releases/download/v1.3.9.GA/Install_guide-CentOS7-xCAT-Stateful-SLURM-1.3.9-x86_64.pdf
