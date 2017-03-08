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

  * AD VM
	* DSC installs AD, CA roles, generates certificate for use by ADFS and WAP
    * Certificate is based on the public IP/DNS of the WAP deployment
    * Split-brain DNS is updated for the ADFS URL
    * The Azure vNet is updated with a custom DNS entry pointing to the DC
    * 5 "test" users are created in the local AD. Fork to your own repo and edit "/DSC/adDSC/Userlist-sn.csv" to change those accounts.
  * ADFS VM
	* DSC installs ADFS Role, pulls and installs cert from DC
    * CustomScriptExtension configures the ADFS farm
    * For unique testing scenarios, multiple distinct farms may be specified
  * WAP VM - one for each ADFS VM
	* DSC installs WAP role
    * CustomScriptExtension copies and installs the cert from the DC and joins the ADFS farm

## Notes
* The NSGs defined are for reference, but they aren't production-ready as holes are also opened for RDP to each VM directly, and public IPs are allocated for each VM as well
* One VM size is specified for all VMs
* Managed disks are used for all VMs, no storage accounts are created for diagnostics
* A template is included for Client creation via MSDN images. You will need to update the URL to point to your images.

====
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/bretthacker/AAD_ADFS_Lab/AAD_ADFS_Lab/Templates/azureDeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/bretthacker/AAD_ADFS_Lab/AAD_ADFS_Lab/Templates/azureDeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

