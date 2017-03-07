param (
    [Parameter(Mandatory)]
    [string]$DCFQDN,

    [Parameter(Mandatory)]
    [string]$adminuser,

    [Parameter(Mandatory)]
    [string]$password
)

$ErrorActionPreference = "Stop"
$arr = $DCFQDN.split('.')
$DomainName = $arr[1]
$SecPW=ConvertTo-SecureString $password -AsPlainText -Force
$File=$null
$Subject=$null

[System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($adminuser)", $SecPW)

$completeFile="c:\temp\prereqsComplete"
if (!(Test-Path -Path "c:\temp")) {
    md "c:\temp"
}

if (!(Test-Path -Path "$($completeFile)0")) {
    $PathToCert="\\$DCFQDN\src"
    net use "\\$DCFQDN\src" $password /USER:$adminuser
    Copy-Item -Path "$PathToCert\*.pfx" -Destination "c:\temp\" -Recurse -Force
    Copy-Item -Path "$PathToCert\*.cer" -Destination "c:\temp\" -Recurse -Force
    #record that we got this far
    New-Item -ItemType file "$($completeFile)0"
}

if (!(Test-Path -Path "$($completeFile)1")) {
    $CertFile  = Get-ChildItem -Path "c:\temp\*.pfx"
    $Subject   = $CertFile.BaseName
    $CertPath  = $CertFile.FullName
    $RootFile  = Get-ChildItem -Path "c:\temp\*.cer"
    #$CAName    = $RootFile.BaseName
    $RootPath  = $RootFile.FullName

    #install the certificate that will be used for ADFS Service
    $cert      = Import-PfxCertificate -Exportable -Password $SecPW -CertStoreLocation cert:\localmachine\my -FilePath $CertPath
    $rootCert  = Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root -FilePath $RootPath

    #record that we got this far
    New-Item -ItemType file "$($completeFile)1"
}

if (!(Test-Path -Path "$($completeFile)2")) {
    $File      = Get-ChildItem -Path "c:\temp\*.pfx"
    $Subject   = $File.BaseName

    $cert      = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -eq "CN=$Subject"} -ErrorAction SilentlyContinue

    Install-WebApplicationProxy `
        -FederationServiceTrustCredential $DomainCreds `
        -CertificateThumbprint $cert.Thumbprint`
        -FederationServiceName $Subject

    #record that we got this far
    New-Item -ItemType file "$($completeFile)2"
}