param (
    [Parameter(Mandatory)]
    [string]$Acct,

    [Parameter(Mandatory)]
    [string]$PW
)

$wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
$DCName = $wmiDomain.DomainControllerName
$ComputerName = $wmiDomain.PSComputerName
$DomainName=$wmiDomain.DomainName
$DomainNetbiosName = $DomainName.split('.')[0]
$SecPw = ConvertTo-SecureString $PW -AsPlainText -Force
[System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Acct)", $SecPW)

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()  
$principal = new-object Security.Principal.WindowsPrincipal $identity 
$elevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)  

if (-not $elevated) {
    $a = $PSBoundParameters
    $cl = "-Acct $($a.Acct) -PW $($a.PW)"
    $arglist = (@("-file", (join-path $psscriptroot $myinvocation.mycommand)) + $args + $cl)
    Write-host "Not elevated, restarting as admin..."
    Start-Process cmd.exe -Credential $DomainCreds -NoNewWindow -ArgumentList “/c powershell.exe $arglist”
} else {
    Write-Host "Elevated, continuing..." -Verbose

    #Configure ADFS Farm
    Import-Module ADFS
    $wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
    $DCName = $wmiDomain.DomainControllerName
    $ComputerName = $wmiDomain.PSComputerName
    $DomainName=$wmiDomain.DomainName
    $DomainNetbiosName = $DomainName.split('.')[0]
    $SecPw = ConvertTo-SecureString $PW -AsPlainText -Force

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Acct)", $SecPW)

    $Index = $ComputerName.Substring($ComputerName.Length-1,1)
    $ADFSSvcName = "AdfsSvc$($Index)`$"

    $PathToCert="$DCName\src\*.pfx"
    $File = Get-ChildItem -Path $PathToCert
    $Subject=$File.BaseName

    #get thumbprint of certificate
    $cert = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -eq "CN=$Subject"}

    $props = Get-ADfsProperties -ErrorAction SilentlyContinue
 
    if (-not $props) {
        Install-AdfsFarm `
            -Credential $DomainCreds `
            -CertificateThumbprint $cert.thumbprint `
            -FederationServiceName $Subject `
            -FederationServiceDisplayName "ADFS $Index" `
            -ServiceAccountCredential $DomainCreds `
            -OverwriteConfiguration

        Write-Host "Farm configured" -Verbose
    } else {
        Write-Host "Farm already configured" -Verbose
    }
}

