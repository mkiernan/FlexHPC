# Flexible HPC Cluster

Modular HPC deployment template, with options for standalone NFS server, Fat nodes and additional scale sets. 

<b>Key Features</b>
<li>Choice of CentOS, Ubuntu, SUSE or RedHat Linux Images of various versions</li>
<li>RDMA (FDR, QDR Infinband) and GPU (K80) compute nodes supported. 
<li>NFS Server with 10TB of Standard_LRS storage attached</li>
<li>Azure <a href="https://azure.microsoft.com/en-us/services/virtual-machine-scale-sets/">scale sets</a></li>
<li>Azure <a href="https://azure.microsoft.com/en-us/services/managed-disks/">managed disks</a></li></li>
<br>
## 1. Deploy Complete Cluster
This will deploy the complete cluster with Head Node + NFS Server Combined, and a Scale Set cluster. 
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmkiernan%2FFlexHPC%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
NOTES: 
Deployment takes around 12 minutes. Login is disable during deployment. 
Beware: CentOS 6.5 can take upwards of 30 minutes as mkfs is very slow for the NFS server. 
===

Everything below here is work in progress. 

## 2. Module Deployment 
This section allows you to deploy the cluster step-by-step so you can have the NFS server & Head node permanently deployed and then tear-up and down compute nodes (Fat Nodes & Scale Sets) as you require. 
  a. Deploy Standalone NFS Server
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmkiernan%2FFlexHPC%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
===
  b. Deploy Standalone Head Node
===
  c. Deploy Combined NFS Server + Head Node
===
  d. Deploy Scale Set
===
  e. Deploy Fat Node(s) with optional storage attached. 
===

<br><br>
## Image Support Matrix

It is recommended to use the same node type & linux version on your head node & scalesets. The NFS server and Fat/standalone nodes however, can run different hardware or linux versions than your head node & scalesets. 
<br>
The table below documents the hardware support with the various Linux distributions & versions. YES means the relevant RDMA or GPU drivers are included in the image or added dynamically during deployment by this template.
<br>
<table>
	<tr>
	<th>OS Image</th>
	<th>RDMA Support</th>
	<th>GPU Support</th>
	</tr>
	<tr><td>Canonical:UbuntuServer:16.04-LTS</td><td>NO</td><td>YES*</td></tr>
	<tr><td>Canonical:UbuntuServer:16.10</td><td>NO</td><td>YES*</td></tr>
	<tr><td>OpenLogic:CentOS-HPC:6.5</td><td>YES</td><td>TBD</td></tr>
	<tr><td>OpenLogic:CentOS:6.8</td><td>YES</td><td>TBD</td></tr>
	<tr><td>OpenLogic:CentOS-HPC:7.1</td><td>YES</td><td>TBD</td></tr>
	<tr><td>OpenLogic:CentOS:7.2</td><td>YES</td><td>TBD</td></tr>
	<tr><td>OpenLogic:CentOS:7.3</td><td>YES</td><td>TBD</td></tr>
	<tr><td>RedHat:RHEL:7.3</td><td>TBD</td><td>TBD</td></tr>
	<tr><td>SUSE:SLES-HPC:12-SP2</td><td>YES</td><td>TBD</td></tr>
</table>

(*added by the installation scripts from this template at time of deployment)

<b>Quickstart</b>

	1) Deploy the ARM Template: 
		a. Click on the "Deploy to Azure" button above.
		b. Select the region to deploy (check where HPC Resources are available <a href="https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/">here.</a>
		c. Name your Resource Group - one per cluster is advisable. 
		d. Select VM size (eg: H16m/H16mr or A8/A9) and quantity (make sure to have quota for it)
		e. Name your user account - this is the account you will login and run jobs with.
		f. Click "Purchase" and wait for deployment (typically around 5 minutes). 
		g. Manually upload and configure your data + software on /share/data 
		h. Configure any license server required. 
		i. Run your Job
	2) Customize the Template for Your Own Application / Requirements:
		a. Clone this template into your own github. 
		b. Edit the cn-setup.sh to install any additional software you need. 

<b>Architecture</b>

<img src="https://github.com/tanewill/5clickTemplates/blob/master/images/hpc_vmss_architecture.png"  align="middle" width="395" height="274"  alt="hpc_vmss_architecture" border="1"/> <br></br>

This skeleton template deploys a Linux VM Scale Set (VMSS) along with a Head Node (+ NFS server in the same VM) in the same virtual network. No HPC applications are installed. You can connect to the headnode via the public IP address (look into the resource group in the portal and look for the VM called "flexheadnode"), then connect from there to VMs in the scale set via private IP addresses. To ssh into the headnode, use the following command:

ssh {username}@{headnode-public-ip-address}

The ssh keys are stored for your user in /share/home/username/.ssh. The homedirectory is NFS mounted from the headnode onto all the compute nodes in the scale set.

To ssh into one of the VMs in the scale set, go to resources.azure.com to find the private IP address of the VM, make sure you are ssh'ed into the headnode, then execute the following command:

ssh {username}@{vm-private-ip-address}

You will also find the private IP addresses in /share/home/username/bin/nodeips.txt

Notes:
a. VM scaleset overprovisioning is disabled in this version for now to keep things predictable. 
b. To prevent configuration conflicts, the user account is locked out from ssh access until the configuration script has terminated. Patience is a virtue. 

<b>Adding & Removing Nodes</b>

TBD. 

<i>Credit: Taylor Newill & Xavier Pillons for original base templates.</i>
