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

    PS C:\> get-PRTGDeviceList -PRTGCore https://monitor.pihl.local
        cmdlet get-PRTGDeviceList.ps1 at command pipeline position 1
        Supply values for the following parameters:
        UserName: prtgadmin
        PowerShell credential request
        User and password to PRTG web GUI
        Password for user prtgadmin: **********

.PARAMETER PRTGCore
    PRTG core server URL
        Example; https://monitor.pihl.local:8080

.PARAMETER UserName
    Username on PRTG server

.PARAMETER UserHash
    Passhash of user, if omitted user can enter credentials
    User can get passhash from "https://$PRTGHost/api/getpasshash.htm?username=myuser&password=mypassword"
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
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,HelpMessage="PRTG server URL")]
    [uri]$PRTGCore,
    [Parameter(Mandatory=$true,HelpMessage="User account name")]
    [string]$UserName,
    [Parameter(Mandatory=$false,HelpMessage="User account PRTG hash")]
    [string]$UserHash
)
$ErrorActionPreference = "Stop"
try {
    if(-not $PRTGCore.IsAbsoluteUri -or
    -not (Test-NetConnection -ComputerName $PRTGCore.Host -Port $PRTGCore.port).TcpTestSucceeded
    ) {
        throw "Can not connect to PRTG Core server $($PRTGCore.AbsoluteUri)"
    }
    $PRTGCoreUri = $PRTGCore.AbsoluteUri.trimend('/')
    if( -not ($PSBoundParameters.ContainsKey('UserHash'))) {
        Write-Verbose "No passhash entered as argument, request user credentials and try to get hash from PRTG"

        $Credentials = Get-Credential -Message "User and password to PRTG web GUI" -UserName $Credentials.UserName

        $uriGetHash = "{0}/api/getpasshash.htm?username={1}&password={2}" -f $PRTGCoreUri,$Credentials.UserName,$Credentials.GetNetworkCredential().Password
        $UserHash = Invoke-WebRequest $uriGetHash -verbose:$false | Select-Object -ExpandProperty Content
        if([string]::IsNullOrEmpty($UserHash)) {
            throw "Can not get user hash from PRTG server on user $($Credentials.UserName)"
        }
    }

    $urlAllDevices = "{0}/api/table.xml?content=devices&output=csvtable&columns=objid,group,device,host&id=0&count=2500&username={1}&passhash={2}" -f $PRTGCoreUri,$Credentials.UserName,$UserHash
    $alldevices = Invoke-WebRequest -Uri $urlAllDevices -verbose:$false | ConvertFrom-Csv -Delimiter ','
    Write-Output $alldevices | Select-Object ID,Group,Device,Host | Sort-Object Group
} catch {
    write-error $psitem
}