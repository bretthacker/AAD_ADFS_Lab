# AAD ADFS Lab
## Creates full AD/CA/ADFS/WAP environment with Azure AD Connect installed
* Deploys the following infrastructure:
 * Virtual Network
  * 3 subnets: AD, DMZ, Client
  * 3 Network Security Groups:
    * AD - permits AD traffic, RDP incoming to network; limits DMZ access
    * Client - permissive; restricts traffic to DMZ
    * DMZ - restrictive; permits 443 traffic to Internal, RDP from internal, very limited traffic from Internal, no traffic to Internet or Internal
  * Public IP Address for each node

  _Note: only one VM Size is specified (at this time)_

  _Note: Network Cards are provisioned for VMs_

  * AD VMs - 2 VMs of size specified
	* DSC installs AAD, CA roles, generates certificate for use by ADFS and WAP
    * Certificate is based on the public IP/DNS of the WAP deployment
    * Split-brain DNS is updated for the ADFS URL
  * AD FS VM
	* DSC installs ADFS Role, pulls and installs cert from DC
    * CustomScriptExtension configures the ADFS farm
    * For unique testing scenarios, multiple distinct farms may be specified
  * WAP VM - one for each ADFS VM
	* DSC installs WAP role

## Things to be aware of/Feature Backlog
* The NSGs defined are for reference, but they aren't production-ready as holes are also opened for RDP to each VM directly, and public IPs are allocated for each VM as well

====
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/bretthacker/AAD_ADFS_Lab/AAD_ADFS_Lab/Templates/azureDeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/bretthacker/AAD_ADFS_Lab/AAD_ADFS_Lab/Templates/azureDeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

