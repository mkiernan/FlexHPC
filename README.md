# Flexible Linux VM Scale Set + Head Node && NFS Server
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmkiernan%2FFlexHPC%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fmkiernan%2FFlexHPC%2Fmaster%2FRawANSYSCluster%2Fazuredeploy.json" target="_blank">
<img src="http://armviz.io/visualizebutton.png"/>
</a>
<br><br>

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
