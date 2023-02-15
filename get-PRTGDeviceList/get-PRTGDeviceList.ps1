<#
.SYNOPSIS
    Get object of devies and groups from PRTG server
.DESCRIPTION
    Uses PRTG API, the user must have sufficient access to PRTG API

    Lmitation is first 2500 devices.
.EXAMPLE
    PS C:\> get-PRTGDeviceList -PRTGCore https://monitor.pihl.local -UserName PersonalUser
        PowerShell credential request
        User and password to PRTG web GUI
        Password for user PersonalUser: **********
.EXAMPLE 
    PS C:\> get-PRTGDeviceList -PRTGCore https://monitor.pihl.local
        cmdlet get-PRTGDeviceList.ps1 at command pipeline position 1
        Supply values for the following parameters:
        UserName: prtgadmin
        PowerShell credential request
        User and password to PRTG web GUI
        Password for user prtgadmin: **********

.EXAMPLE
   PS C:\>  .\get-PRTGDeviceList.ps1 -PRTGServer "https://prtg.pihl.local/"  -DeviceFQDN pi3w.pihl.local -APIkey 4TZNQQ...DNSA======
    Get object data like ID from device with hostname pi3w.pihl.local

.PARAMETER PRTGCore
    PRTG core server URL
        Example; https://monitor.pihl.local:8080

.PARAMETER UserName
    Username on PRTG server

.PARAMETER UserHash
    Passhash of user, if omitted user can enter credentials
    User can get passhash from "https://$PRTGHost/api/getpasshash.htm?username=myuser&password=mypassword"

.PARAMETER APIkey
    PRTG User API key
    If a valid path is entered file content is loaded as API Key

.OUTPUTS
    Object of devices grouped on PRTG goups
    ID - ID of device
    Group - PRTG group of device
    Device - Device name
    Host - Device IPv4 Address/DNS Name

    Example;
    ID   Group                  Device                                 Host
    --   -----                  ------                                 ----
    7646 Network resources      se.pool.ntp.org                        se.pool.ntp.org
    9532 Wifi                   UniFi controller                       unifi.pihl.local
    9567 Azure                  SubCA1                                 pihl-subca1.pihl.local
    9297 Azure                  10.253.3.5 (PiHole)                    10.253.3.5
    9558 Lab                    pi3.pihl.local (pi3) [Linux/Unix]      pi3.pihl.local
.NOTES
    Version 1 2021-06-04 Klas.Pihl@Atea.se
    Version 2.0 2023-02-15 Add support for API token key and more general usage. /Klas.Pihl@Atea.se
#>
[CmdletBinding()]
param (
    [Parameter(
        Mandatory=$true,
        HelpMessage="PRTG server URL"
        )]
    [Alias("PRTGServer")]
    [uri]$PRTGCore,

    [Parameter(
        Mandatory=$false,
        HelpMessage="User account name",
        ParameterSetName = 'User'
        )]
    [string]$UserName,

    [Parameter(
        Mandatory=$false,
        HelpMessage="User account PRTG hash",
        ParameterSetName = 'User'
        )]
    [string]$UserHash,

    [Parameter(
        Mandatory=$false,
        HelpMessage="API Key path or key",
        ParameterSetName = 'APIKey'
        )]
    [string]$APIkey='.\apikey.sec',

    [Parameter(
        Mandatory=$false,
        HelpMessage="Device name FQDN"
        )]
    [string]$DeviceFQDN
)
$ErrorActionPreference = "Stop"
try {
    if(Test-Path $APIkey) {
        Write-Verbose "Parameter APIKey is a valid file path, try to load API key from $APIKey"
        $APIkey = Get-Content $APIkey -ErrorAction Stop
    }
    if(-not $PRTGCore.IsAbsoluteUri -or
    -not (Test-NetConnection -ComputerName $PRTGCore.Host -Port $PRTGCore.port).TcpTestSucceeded
    ) {
        throw "Can not connect to PRTG Core server $($PRTGCore.AbsoluteUri)"
    }
    $PRTGCoreUri = $PRTGCore.AbsoluteUri.trimend('/')

    if($PSBoundParameters.ContainsKey('APIKey')) {
        $urlAllDevices = "{0}/api/table.json?content=devices&output=json&columns=objid,group,device,host&id=0&count=2500&apitoken={1}" -f $PRTGCoreUri,$APIkey

    } else {
        if( -not ($PSBoundParameters.ContainsKey('UserHash'))) {
            Write-Verbose "No passhash entered as argument, request user credentials and try to get hash from PRTG"
    
            $Credentials = Get-Credential -Message "User and password to PRTG web GUI" -UserName $UserName
    
            $uriGetHash = "{0}/api/getpasshash.htm?username={1}&password={2}" -f $PRTGCoreUri,$Credentials.UserName,$Credentials.GetNetworkCredential().Password
            $UserHash = Invoke-WebRequest $uriGetHash -verbose:$false | Select-Object -ExpandProperty Content
            if([string]::IsNullOrEmpty($UserHash)) {
                throw "Can not get user hash from PRTG server on user $($Credentials.UserName)"
            }
        }
        $urlAllDevices = "{0}/api/table.json?content=devices&output=json&columns=objid,group,device,host&id=0&count=2500&username={1}&passhash={2}" -f $PRTGCoreUri,$UserName,$UserHash

    }
    $alldevices = Invoke-WebRequest -Uri $urlAllDevices -verbose:$false | ConvertFrom-Json | Select-Object -ExpandProperty devices
    if($alldevices.count -ge 2499) {
        Write-Warning "Number of devices exceed default limit of 2500 devices, might need special care"
    }
    if($PSBoundParameters.ContainsKey('DeviceFQDN')) {
        Write-Output $alldevices | Select-Object objid,Group,Device,Host | Where-Object Host -eq $DeviceFQDN
    } else {
        Write-Output $alldevices | Select-Object objid,Group,Device,Host | Sort-Object Group
    }
} catch {
    write-error $psitem
}