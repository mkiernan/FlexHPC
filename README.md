# Flexible Linux VM Scale Set Combined with a Head Node / NFS Server
<table>
<tr>
<td>
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmkiernan%2FFlexHPC%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
    <figcaption>Deploy Cluster + Head Node</figcaption>
 </td>
 <tr>
</table>
<br><br>
This template deploys a Linux VM Scale Set along with a Head Node (+ NFS server in the same VM) in the same virtual network. You can connect to the headnode via the public IP address, then connect from there to VMs in the scale set via private IP addresses. To ssh into the jumpbox, use the following command:

ssh {username}@{jumpbox-public-ip-address}

To ssh into one of the VMs in the scale set, go to resources.azure.com to find the private IP address of the VM, make sure you are ssh'ed into the jumpbox, then execute the following command:

ssh {username}@{vm-private-ip-address}

You will also find the private IP addresses in /share/home/username/bin/nodeips.txt

Note: VM scaleset overprovisioning is disabled in this version for now. 
