$DscWorkingFolder = $PSScriptRoot

configuration DomainController
{
   param
   (
        [Parameter(Mandatory)]
        [String]$Subject,
 
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [String]$ADFSIPAddress,

		[Parameter(Mandatory)]
		[Object]$usersArray,

		[Parameter(Mandatory)]
		[System.Management.Automation.PSCredential]$UserCreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )
    
    $wmiDomain      = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
    $shortDomain    = $wmiDomain.DomainName
    $DomainName     = $wmidomain.DnsForestName
    $ComputerName   = $wmiDomain.PSComputerName
    $CARootName     = "$($shortDomain.ToLower())-$($ComputerName.ToUpper())-CA"
    $CAServerFQDN   = "$ComputerName.$DomainName"

    $CertPw         = $AdminCreds.Password
    $ClearPw        = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertPw))
	$ClearDefUserPw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($UserCreds.Password))

    Import-DscResource -ModuleName xComputerManagement,xNetworking,xSmbShare,xAdcsDeployment,xCertificate,PSDesiredStateConfiguration

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${shortDomain}\$($Admincreds.UserName)", $Admincreds.Password)
    
    Node 'localhost'
    {
        LocalConfigurationManager
        {
            DebugMode = 'All'
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADCS-Cert-Authority
        {
            Ensure = 'Present'
            Name = 'ADCS-Cert-Authority'
        }

        WindowsFeature RSAT-ADCS-Mgmt
        {
            Ensure = 'Present'
            Name = 'RSAT-ADCS-Mgmt'
        }

        File SrcFolder
        {
            DestinationPath = "C:\src"
            Type = "Directory"
            Ensure = "Present"
        }

        xSmbShare SrcShare
        {
            Ensure = "Present"
            Name = "src"
            Path = "C:\src"
            FullAccess = @("Domain Admins","Domain Computers")
            ReadAccess = "Authenticated Users"
            DependsOn = "[File]SrcFolder"
        }

        xADCSCertificationAuthority ADCS
        {
            Ensure = 'Present'
            Credential = $DomainCreds
            CAType = 'EnterpriseRootCA'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority'             
        }

        WindowsFeature ADCS-Web-Enrollment
        {
            Ensure = 'Present'
            Name = 'ADCS-Web-Enrollment'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority','[WindowsFeature]ADCS-Cert-Authority'
        }

        xADCSWebEnrollment CertSrv
        {
            Ensure = 'Present'
            IsSingleInstance = 'Yes'
            Credential = $DomainCreds
            DependsOn = '[WindowsFeature]ADCS-Web-Enrollment','[xADCSCertificationAuthority]ADCS'
        }

        xCertReq SSLCert
        {
            CARootName                = "$CARootName"
            CAServerFQDN              = "$ComputerName.$DomainName"
            Subject                   = "$Subject"
            KeyLength                 = 2048
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = 'WebServer'
            AutoRenew                 = $true
            Credential                = $DomainCreds
            DependsOn                 = '[xADCSWebEnrollment]CertSrv'
        }

        Script SaveCert
        {
            SetScript  = {
                             $s=$using:subject;
                             write-verbose "subject = $s";
                             $cert = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -eq "CN=$s"}
                             Export-PfxCertificate -FilePath "c:\src\$s.pfx" -Cert $cert -Password (ConvertTo-SecureString $Using:ClearPw -AsPlainText -Force)

                             $arr       = $($using:DomainName).split('.')
                             $d         = $($using:shortDomain).ToLower()
                             $c         = $($using:ComputerName).ToUpper()
                             $shortname = "$d-$c-CA"
                             $rootName  = "CN=$shortname, DC=$($arr[0]), DC=$($arr[1])"

                             $rootcert  = Get-ChildItem Cert:\LocalMachine\CA | where {$_.Subject -eq "$rootName"}
                             if($rootcert -eq $null) {
                                Write-Verbose "ERROR: ROOT CERT `"$rootName`" NOT FOUND, cancelling cert export"
                             } else {
                                 $root      = if ($rootcert.GetType().BaseType.Name -eq "Array") {$rootCert[0]} else {$rootCert}
                                 Export-Certificate -FilePath "c:\src\$shortname.cer" -Cert $root
                             }
                         }

            GetScript  = { @{ Result = (Get-Content "C:\src\$($using:subject).pfx") } }
            TestScript = { return Test-Path "C:\src\$($using:subject).pfx" }
            DependsOn  = '[xCertReq]SSLCert'
        }

        Script InstallAADConnect
        {
            SetScript = {
                $AADConnectDLUrl="https://download.microsoft.com/download/B/0/0/B00291D0-5A83-4DE7-86F5-980BC00DE05A/AzureADConnect.msi"
                $exe="$env:SystemRoot\system32\msiexec.exe"

                $tempfile = [System.IO.Path]::GetTempFileName()
                $folder = [System.IO.Path]::GetDirectoryName($tempfile)

                $webclient = New-Object System.Net.WebClient
                $webclient.DownloadFile($AADConnectDLUrl, $tempfile)

                Rename-Item -Path $tempfile -NewName "AzureADConnect.msi"
                $MSIPath = $folder + "\AzureADConnect.msi"

                Invoke-Expression "& `"$exe`" /i $MSIPath /qn /passive /forcerestart"
            }

            GetScript =  { @{} }
            TestScript = { 
                return Test-Path "$env:TEMP\AzureADConnect.msi" 
            }
        }

        Script CreateOU
        {
            SetScript = {
                $wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
                $DC1=$wmiDomain.DnsForestName.Split('.')[0]
                $DC2=$wmiDomain.DnsForestName.Split('.')[1]
                $OU="OU=OrgUsers,DC=$DC1,DC=$DC2"
                New-ADOrganizationalUnit -Name "OrgUsers" -Path "DC=$DC1,DC=$DC2"
            }
            GetScript =  { @{} }
            TestScript = { 
                $test=Get-ADOrganizationalUnit -Filter 'Name -like "OrgUsers"' -ErrorAction SilentlyContinue
                return ($test -ine $null)
            }
        }

        Script AddTestUsers
        {
            SetScript = {
                $wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
                $mailDomain=$wmiDomain.DnsForestName
                $DC1=$wmiDomain.DnsForestName.Split('.')[0]
                $DC2=$wmiDomain.DnsForestName.Split('.')[1]
                $server="$($wmiDomain.PSComputerName).$($wmiDomain.DnsForestName)"
                $OU="OU=OrgUsers,DC=$DC1,DC=$DC2"
                $folder=$using:DscWorkingFolder

				$clearPw = $using:ClearDefUserPw
				$Users = $using:usersArray

                foreach ($User in $Users)
                {
                    $Displayname = $User.'FName' + " " + $User.'LName'
                    $UserFirstname = $User.'FName'
                    $UserLastname = $User.'LName'
                    $SAM = $User.'SAM'
                    $UPN = $User.'FName' + "." + $User.'LName' + "@" + $Maildomain
                    #$Password = $User.'Password'
                    $Password = $clearPw
                    "$DisplayName, $Password, $SAM"
                    New-ADUser `
                        -Name "$Displayname" `
                        -DisplayName "$Displayname" `
                        -SamAccountName $SAM `
                        -UserPrincipalName $UPN `
                        -GivenName "$UserFirstname" `
                        -Surname "$UserLastname" `
                        -Description "$Description" `
                        -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
                        -Enabled $true `
                        -Path "$OU" `
                        -ChangePasswordAtLogon $false `
                        –PasswordNeverExpires $true `
                        -server $server `
                        -EmailAddress $UPN
                }
            }
            GetScript =  { @{} }
            TestScript = { 
				$Users = $using:usersArray
                $samname=$Users[0].'SAM'
                $user = get-aduser -filter {SamAccountName -eq $samname} -ErrorAction SilentlyContinue
                return ($user -ine $null)
            }
            DependsOn  = '[Script]CreateOU'
        }

        Script UpdateDNS
        {
            SetScript  = {
                            $IPAddress=$using:ADFSIPAddress
                            $ZoneName=$using:Subject
                            $Zone = Add-DnsServerPrimaryZone -Name $ZoneName -ReplicationScope Forest -PassThru
                            $rec = Add-DnsServerResourceRecordA -ZoneName $ZoneName -Name "@" -AllowUpdateAny -IPv4Address $IPAddress
                         }

            GetScript =  { @{} }
            TestScript = { 
                $ZoneName=$using:Subject
                $Zone = Get-DnsServerZone -Name $ZoneName -ErrorAction SilentlyContinue
                return ($Zone -ine $null)
            }
        }

        Script SetKDCRoot
        {
            SetScript  = {
                            Add-KdsRootKey –EffectiveImmediately
                         }

            GetScript =  { @{} }
            TestScript = { 
                $key=Get-KdsRootKey -ErrorAction SilentlyContinue
                return ($key -ine $null)
            }
            #Credential = $DomainCreds
            #PsDscRunAsCredential = $DomainCreds

            DependsOn = '[xADCSWebEnrollment]CertSrv'
        }

        <#
        Script UpdateAdfsSiteGPO
        {
            SetScript = {
                $SiteName = $using:Subject
                $TargetGPO = Get-GPO -Name "Default Domain Policy"
                $ZoneName = '1'
                $TargetHive = 'HKEY_LOCAL_MACHINE'
                $BaseKey = 'Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings'
                $Key = "$($TargetHive)\$($BaseKey)\ZoneMapKey"

                Set-GPRegistryValue -Guid $TargetGPO.Id -Additive -Key $Key -ValueName $SiteName -Type "String" -Value "1" | Out-Null
            }
            GetScript =  { @{} }
            TestScript = { 
                $CurrKey = Get-GPRegistryValue -Guid $TargetGPO.Id -Key $Key -ValueName $SiteName -ErrorAction SilentlyContinue
                return ($CurrKey -ine $null)
            }
        }
        #>
    }
}