#
# ADSnippets.ps1
#
function ResetWAPTrust
{
	$DomainCreds = Get-Credential
	$File      = Get-ChildItem -Path "c:\temp\*.pfx"
	$Subject   = $File.BaseName

	$cert      = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -eq "CN=$Subject"} -ErrorAction SilentlyContinue

	Install-WebApplicationProxy `
		-FederationServiceTrustCredential $DomainCreds `
		-CertificateThumbprint $cert.Thumbprint `
		-FederationServiceName $Subject
	
	Start-Service -Name appproxysvc
}

function DownloadAADConnect
{
	#download and deploy AAD Connect
	$AADConnectDLUrl="https://download.microsoft.com/download/B/0/0/B00291D0-5A83-4DE7-86F5-980BC00DE05A/AzureADConnect.msi"

	$exe="c:\windows\system32\msiexec.exe"
	$tempfile = [System.IO.Path]::GetTempFileName()
	$folder = [System.IO.Path]::GetDirectoryName($tempfile)
	$webclient = New-Object System.Net.WebClient
	$webclient.DownloadFile($AADConnectDLUrl, $tempfile)
	Rename-Item -Path $tempfile -NewName "AzureADConnect.msi"
	$MSIPath = $folder + "\AzureADConnect.msi"
	Invoke-Expression "& `"$exe`" /i $MSIPath"
}