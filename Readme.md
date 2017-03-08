# AAD ADFS Lab
## Creates full AD/CA/ADFS/WAP environment with Azure AD Connect installed
## Quick Start

Description | Link
--- | ---
Full deploy - AD, ADFS, WAP, Client machines | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbretthacker%2FAAD_ADFS_Lab%2Fmaster%2FAAD_ADFS_Lab%2FFullDeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
Full deploy, no Client machines | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbretthacker%2FAAD_ADFS_Lab%2Fmaster%2FAAD_ADFS_Lab%2FNoClientDeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>

(Links are for the master branch - be sure to edit the "Asset Location" if you want dev.)

## Details
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

## Warning
* This template is explicitely designed for a lab environment. A few compromises were made, especially with regards to credential passing to DSC and script automation, that WILL result in clear text passwords being left behind in the DSC package and Azure Log folders on the resulting VM. 

## Bonus
The "deploy.ps1" file above can be downloaded and run locally against this repo, and offers a few additional features. After the deployment completes, it will create a folder on your desktop with the name of the resource group, and create an RDP connectoid for each server and client that was deployed. It will then create an HTTP shortcut to the ADFS WAP endpoint for testing and confirming the deployment.

It has a line that allows you to separate your specific variables from the master file via dot-sourcing. Here's what my dot-sourced variable overrides file looks like:
```powershell
#Login if necessary
$AzureSub = "My Azure Subscription"
try { $ctx=Get-AzureRmContext -ErrorAction Stop }
catch { Login-AzureRmAccount }
if ($ctx.SubscriptionName -ne $AzureSub) { Set-AzureRmContext -SubscriptionName $AzureSub }

#DEPLOYMENT OPTIONS
    $Branch                  = "master"
    $VNetAddrSpace2ndOctet   = "2"
    $RGName                  = "TestRG$VNetAddrSpace2ndOctet"
    $DeployRegion            = "West US 2"
    $userName                = "localAdmin"
    $secpasswd               = "CrazyP@ssword"
    $adDomainName            = "aadpoctest.com"
    $clientsToDeploy         = @("7")
    $clientImageBaseResource = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/ImageRG/providers/Microsoft.Compute/images/"
    $AdfsFarmCount           = "1";
    $AssetLocation           = "https://raw.githubusercontent.com/bretthacker/AAD_ADFS_Lab/$Branch/AAD_ADFS_Lab/"
#END DEPLOYMENT OPTIONS

```

====



