# azure-adfs-template
## Deploys Infrastructure Required for Running ADFS in Microsoft Azure
* Deploys the following infrastructure:
 * Storage Account
 * Virtual Network
  * Site-to-Site VPN
    * Local Gateway
    * Public IP for Azure Gateway
    * Azure Gateway
    * Gateway Connection
  * 3 subnets: AD, Internal, DMZ
  * 3 Network Security Groups:
    * AD - permits AD traffic, RDP incoming to network; limits DMZ access
    * Internal - permissive; restricts traffic to DMZ
    * DMZ - restrictive; permits 443 traffic to Internal, RDP from internal, very limited traffic from Internal, no traffic to Internet or Internal
  * Public IP Address
  * 2 Load Balancers
    * Internal - to be used to access AD FS Servers
    * External - to be used to access Web Application Proxy servers (via PublicIP)

  _Note: only one VM Size is specified (at this time)_

  _Note: Network Cards and Availability Sets are provisioned for VMs_

  * AD VMs - 2 VMs of size specified
	* DSC to install ADDS Role
  * AD FS VMs - Number to be specified of size specified
	* DSC to install ADFS Role
  * WAP VMs - Number to be specified (same as AD FS VMs)
	* DSC to install Windows Application Proxy Role

## Things to be aware of/Feature Backlog
* There are no RDP Endpoints created on the VMs. If you cannot access the VPNs using the VPN created with the deployment, you'll have to add a Public IP to one of the ADFS or AD VMs and take it from there.
* Domain Join, ADFS farm join/creation, and WAP farm join are not supported
* I haven't actually tested the VPN capability!
* T-shirt sizing - ability to select from:
   * non-redundant (i.e. service only to be utilized if primary on-site server goes down)
   * redundant (as-built)
   * geo-redundant (deploy twice; load balance with Traffic Manager)
   * non-redundant, geo-load balanced
 

====
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/bretthacker/AAD_ADFS_Azure_Deploy_ARM/tree/dev/ADFSAzureDeploy/Templates/azureDeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/bretthacker/AAD_ADFS_Azure_Deploy_ARM/tree/dev/ADFSAzureDeploy/Templates/azureDeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

