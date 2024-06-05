# xCat_script-Nagios
This Project is for Boot the Multiple Nodes and make a Cluster with Nagios Monitoring Tool.

Currently only Stateless script have Nagios monitoring tool and Slurm available.

This All Projects is Done in using VMs.<br />
#This scripts will only work on Linux.<br />
And only Boot CentOS7.9 in compute nodes.<br />
#You might need to edit the script for IPs and ens port names (Default IP:192.168.1.1 portName:ens)

> [!NOTE]
> below system configuration are seleted by us. [minimum requirements]

### Master Node system configuration:<br />
RAM - 4GB<br />
Sockets - 2 (you can use one socket too)<br />
Core - 1 (if you use one socket you might need tow cores)<br />
Network Adapters - Two Adapter one for NAT and other for hostonly<br />
Hard Disk - 100GB(SCSI)

### Compute Nodes system configuration:<br />
  Network Adapters - one Adapter hostonly<br /><br />
  `For Stateless`:<br />
    RAM - 8GB (you will need more RAM because it will boot on RAM without storage disk)<br />
    Sockets - 2 (you can use one socket too)<br />
    Core - 1 (if you use one socket you might need tow cores)<br /><br />
  `For Statefull`:<br />
    RAM - 4GB<br />
    Sockets - 2 (you can use one socket too)<br />
    Core - 1 (if you use one socket you might need tow cores)<br />

First you need to create a folder name "osimage" and copy the CentOS7 ios file in there.<br />
link or CentOS7 ios file : https://mirrors.nxtgen.com/centos-mirror/7.9.2009/isos/x86_64/CentOS-7-x86_64-DVD-2207-02.iso

> Steps:
> 1.  Run frontend.py file "python3 frontend.py".
> 2.  If you have a secondry disk and want to make it NFS directory for all nodes enter 'y'.
> 3.  It will you to enter the ens port (only work on ens ports currently).
> 4.  Then it will show two options for Stateless and Statefull select one by entering correct option.
> 5.  Thats it!!!!, You will see the script run on the terminal.
> 6.  When scripting is done you have to start or restart the nodes.
> 7.  After the nodes started you might need to restart slurmctld service.

Common or share directory for all nodes are '/home' and '/opt/ohpc/pub' by using NFS.


Reference URL Links:

> 1. https://github.com/openhpc/ohpc/releases/download/v1.3.9.GA/Install_guide-CentOS7-xCAT-Stateless-SLURM-1.3.9-x86_64.pdf
> 2. https://github.com/openhpc/ohpc/releases/download/v1.3.9.GA/Install_guide-CentOS7-xCAT-Stateful-SLURM-1.3.9-x86_64.pdf
> 3. https://github.com/Artlands/Install-Slurm
