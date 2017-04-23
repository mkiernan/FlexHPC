# Flexible HPC Cluster

Modular Microsoft Azure HPC infrastructure deployment ARM template.

<b>Key Features of this ARM template collection</b>
* Choose between multiple CentOS, Ubuntu, SUSE or RedHat Linux Images, or use your own image.
* RDMA (FDR, QDR Infinband), GPU (NVIDIA K80) and CPU only compute nodes are all supported. 
* All appropriate hardware drivers are installed and configured for you via the installation scripts. 
* NFS Server with up to 32TB of Standard_LRS storage attached (defaults to 10TB) built with <a href="https://azure.microsoft.com/en-us/services/managed-disks/">azure managed disks</a>
* Dynamically scalable/shrinkable cluster build with <a href="https://azure.microsoft.com/en-us/services/virtual-machine-scale-sets/">azure scale sets</a>.
* Add Head nodes or fat nodes to your cluster(s), or simply build standalone nodes.
* Append your own scripts to install applications or customize the nodes further. 
<br><br>
<i>
If you find a problem, please report it <a href="https://github.com/mkiernan/FlexHPC/issues/new">here.</a>
</i>

***
## 1. Deploy a Complete Cluster with Head Node & NFS Server. 
This template deploys a complete cluster composed of a head node + nfs server (combined on the same VM), and a cluster of a selectable number of nodes (1-100), built as a scale-set. 
<br><br>
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmkiernan%2FFlexHPC%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<br>
<i>
* Deployment takes around 12 minutes. Login is disabled during deployment to prevent conflicts. Patience is a virtue. 
* Head node & Compute nodes will be the same VM type (use the below modular template if you don't want this)
</i>

***

## 2. Modular Step-by-Step Deployment 
This section allows you to deploy the cluster infrastructure step-by-step. You will need to deploy the components of your infrastructure into the same VNET in order for them to connect to each other. 

Example usage of this is so that you can setup a "permanent" NFS server & Head node with your application software and data stored safely, and then tear-up and down compute nodes (Fat Nodes & Scale Sets) as you require. 
### 2a. Deploy a Standalone Linux NFS Server
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmkiernan%2FFlexHPC%2Fmaster%2Fnfsserver.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

### 2b. Deploy a Scale Set of Linux Compute Nodes

Deploy a scale set with N nodes into the same existing VNET as your NFS Server + Head Node. 
<br>

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmkiernan%2FFlexHPC%2Fmaster%2Fscaleset.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<br>

<i>
* Ensure your NFS server is deployed first as per the step 2a above. 
* The scale set install scripts will mount the home directory and other shares from the NFS server automatically. 
* The NFS server is currently assumed to be 10.0.0.4. 
* The scale set instances will record their hostnames and IP addresses into the /clustermap mount on the NFS server.
* VM scaleset overprovisioning is disabled in this version for now to keep things predictable. 
</i>

### 2c. Deploy Standalone Head Node (No NFS Server)
TBD

### 2d. Deploy Fat Node(s) VM(s) with optional storage attached. 
TBD

***

## 3. Cluster Access Instructions

* To ssh into the headnode or NFS server after deployment: **ssh username@headnode-public-ip-address**
* **username** is the username you entered into the template when you deployed. 
* The ssh keys are stored for your user in /share/home/username/.ssh. 
* The homedirectory is NFS automounted from the headnode onto all the compute nodes in the scale set.
* You will  find the private IP addresses for the scaleset nodes in /share/clustermap/hosts (head nodes) or /clustermap/hosts (compute nodes).

***

## Linux Image Support Matrix

You can mix and match VM sku types & linux versions on your head node, NFS server, scaleset compute nodes and fat nodes. 
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

***

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




<i>Credit: Taylor Newill, Xavier Pillons & Thomas Varlet for original base templates.</i>
