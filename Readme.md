# AAD ADFS Lab
## Creates full AD/CA/ADFS/WAP environment with Azure AD Connect installed
## Quick Start

Description | Link
--- | ---
Full deploy - AD, ADFS, WAP | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbretthacker%2FAAD_ADFS_Lab%2Fmaster%2FAAD_ADFS_Lab%2FNoClientDeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
Full deploy - AD, ADFS, WAP, _with client machines*_ | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbretthacker%2FAAD_ADFS_Lab%2Fmaster%2FAAD_ADFS_Lab%2FFullDeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>

(Links are for the master branch - copy the URL, update the branch, load it, and then also edit the "Asset Location" in Azure if you want dev.)

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
    * Split-brain DNS on the DC is configured for the ADFS URL
    * The Azure vNet is updated with a custom DNS entry pointing to the DC
    * Test users are created in the local AD by passing in an array. There is an array sample set as the default value in the deployment template.
    * Azure Active Directory Connect is installed and available to configure.
  * ADFS VM
	* DSC installs ADFS Role, pulls and installs cert from CA on the DC
    * CustomScriptExtension configures the ADFS farm
    * For unique testing scenarios, multiple distinct farms may be specified
    * Azure Active Directory Connect is installed and available to configure.
  * WAP VM - one for each ADFS VM
	* DSC installs WAP role
    * CustomScriptExtension copies and installs the cert from the DC and connects to the ADFS farm

## Notes
* _A template is included for Client creation via MSDN images. You will need to update the URL to point to your images. Images must be named "OSImage_Win&lt;version&gt;"._
* The NSGs defined are for reference, but they aren't production-ready as holes are also opened for RDP to each VM directly, and public IPs are allocated for each VM as well
* One VM size is specified for all VMs
* Managed disks are used for all VMs - no storage accounts are created for diagnostics
* The root CA cert is usually updated automatically to domain-joined clients within hours. To accelerate this, an easy workaround is to reboot the client VM.
* In the AD DSC template, there is a commented draft of some code to push the ADFS FQDN out as an "Intranet Zone" site to the client machines - we've punted on that for now, so you will have to do this manually on client VMs in order to get ADFS SSO.

## Caveats
* There is an intermittent bug with regards to the script block that enables RDP access for non-admin (test) users within deployed client VMs (when the client deploy script is used). It doesn't affect the base lab functionality, but if you see an error regarding 'ConfigRDPUsers' during deployment, the AD admin may need to enable non-admin RDP access before a test user can login to one of the client VMs to try client SSO scenarios.

## Warning
* This template is explicitely designed for a lab environment. A few compromises were made, especially with regards to credential passing to DSC and script automation, that WILL result in clear text passwords being left behind in the DSC/scriptextension package folders, and Azure log folders on the resulting VMs. 

## Bonus
The "deploy.ps1" file above can be downloaded and run locally against this repo, and offers a few additional features:
* After the deployment completes, it will create a folder on your desktop with the name of the resource group
* It will then create an RDP connectoid in that folder for each server and client that was deployed.
* It will then create an HTTP shortcut to the ADFS WAP endpoint for testing and confirming the deployment.

The deploy script master has a [line](https://github.com/bretthacker/AAD_ADFS_Lab/blob/master/AAD_ADFS_Lab/deploy.ps1#L43) that allows you to separate your specific variables from the master via dot-sourcing. Here's a sample dot-sourced variable overrides file:
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

    $usersArray              = @(
                                @{ "FName"= "Bob"; "LName"= "Jones"; "SAM"= "bjones" },
                                @{ "FName"= "Bill"; "LName"= "Smith"; "SAM"= "bsmith" },
                                @{ "FName"= "Mary"; "LName"= "Phillips"; "SAM"= "mphillips" },
                                @{ "FName"= "Sue"; "LName"= "Jackson"; "SAM"= "sjackson" }
                            );
    $defaultUserPassword     = "P@ssw0rd"

#END DEPLOYMENT OPTIONS

```

====



