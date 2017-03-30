# Simple deployment of a VM Scale Set of Linux VMs with a jumpbox
<table>
<tr>
<td>
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftanewill%2F5clickTemplates%2Fmaster%2FRawClusterV2%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
    <figcaption>Deploy to a new VNet</figcaption>
    </td>
  <td>
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftanewill%2F5clickTemplates%2Fmaster%2FRawClusterV2%2Fazuredeploy_existingvnet.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
    <figcaption>Deploy to an existing VNet</figcaption>
    </td>
    </tr>
    </table>
<br><br>
This template allows you to deploy a simple VM Scale Set of Linux VMs using the latest HPC version of CentOS 7.1. This template also deploys a jumpbox with a public IP address in the same virtual network. You can connect to the jumpbox via this public IP address, then connect from there to VMs in the scale set via private IP addresses. To ssh into the jumpbox, you could use the following command:

ssh {username}@{jumpbox-public-ip-address}

To ssh into one of the VMs in the scale set, go to resources.azure.com to find the private IP address of the VM, make sure you are ssh'ed into the jumpbox, then execute the following command:

ssh {username}@{vm-private-ip-address}

PARAMETER RESTRICTIONS
======================

vmssName must be 3-61 characters in length. It should also be globally unique across all of Azure. If it isn't globally unique, it is possible that this template will still deploy properly, but we don't recommend relying on this pseudo-probabilistic behavior.
instanceCount must be 100 or less.
