<#
.SYNOPSIS
    Get all certificates under local machine on Windows host and returns XML formatted output for PRTG
.DESCRIPTION
    Optinal parameter 'AlarmDaysToExpire' to define when a message in PRTG should inform properties of certificates about to expire.
    One Channel is created per Cerificate on FriendlyName. If certificate is renewed with same Friendlyname same channel will be used in PRTG. If new friendly name is created a new channel will be created.
    Alarms in PRTG is set on each channel.
.EXAMPLE
    PS C:\> get-PRTGHLMCertificates.ps1 -ComputerName server01 -AlarmDaysToExire 30
        Returns an XML formatted output with one channel per certificate. If Any cerificate is under AlarmDaysToExpire  <text> is added to sensor.
    PS C:\> get-PRTGHLMCertificates.ps1 server01
        Usage default value of 14 days 
.PARAMETER AlarmDaysToExpire
    Days before an alarm text is returned if a certificate is about to expire.
.PARAMETER ComputerName 
    Device to monitor, can be defined as '%host' in PRTG
.PARAMETER IgnoreThumbprint 
    Certificates with Thumbprints to ignored, separated by ';'
.PARAMETER DefinedThumbprint
    Certificates with Thumbprints to monitor, separated by ';'. All other certificates is ignored.
.OUTPUTS
    PRTG XML
.NOTES
    2020-02-21 Version 1 Klas.Pihl@Atea.se
    2020-02-24 Version 1.1 Klas.Pihl@Atea.se
        Added New parameters
        * IgnoreThumbprint - Retrive monitors all certificates except Thumbprints defined in parameter. Separated by ';'
        * DefinedThumbprint - If Parameter is populated only certificates with defined Thumbprints monitored.
        
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,Position=0)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$false,Position=1)]
    [int]$AlarmDaysToExpire=14,
    
    [Parameter(Mandatory=$false)]
    [string]$IgnoreThumbprint,
    
    [Parameter(Mandatory=$false)]
    [string]$DefinedThumbprint
)
function Format-PrtgXml([xml]$xml)
{
    $stringWriter = New-Object System.IO.StringWriter
    $xmlWriter = New-Object System.Xml.XmlTextWriter $stringWriter

    $xmlWriter.Formatting = "Indented"
    $xmlWriter.Indentation = 4

    $xml.WriteContentTo($xmlWriter)

    $xmlWriter.Flush()
    $stringWriter.Flush()

    $stringWriter.ToString()
}
function Export-PRTGXML {
    [CmdletBinding()]
    param (
        [Parameter()]
        $Channel,
        [string]$Value,
        [ValidateSet(
            'BytesBandwidth',
            'BytesMemory',
            'BytesDisk',
            'Temperature',
            'Percent',
            'TimeResponse',
            'TimeSeconds',
            'Custom',
            'Count',
            'CPU',
            'BytesFile',
            'SpeedDisk',
            'SpeedNet',
            'TimeHours',
            'Day' #Custom
            )]
        $unit
    )
    $Value = $Value.Replace(',','.')
    Write-Output '<result>'
    Write-Output ('<channel>{0}</channel>' -f $Channel)
    Write-Output ('<CustomUnit>{0}</CustomUnit>' -f $unit)
    Write-Output '<showChart>1</showChart>'
    Write-Output '<showTable>1</showTable>'
    #Write-Output '<float>1</float>'
    Write-Output ('<value>{0}</value>' -f $Value)
    Write-Output ('<LimitMinError>{0}</LimitMinError>' -f $AlarmDaysToExpire)
    Write-Output '<LimitMode>1</LimitMode>'
    Write-Output '</result>'
}
function Write-PRTGError {
    [CmdletBinding()]
    param (
    )
    <#
    .SYNOPSIS
        Write PRTG formatted XML output with error exception and exit script.
    .EXAMPLE
        PS C:\> Write-PRTGError 
        write output in PRTG XML and exit script
    .INPUTS
        $global:Error
    .NOTES
       2020-02-24 Version 1 Klas.Pihl@Atea.se
    #>
    $XMLOutput = '<prtg>'
    $XMLOutput += Write-Output '<error>1</error>'
    $XMLOutput += Write-Output '<text>'
    $XMLOutput += $error.Exception.Message 
    $XMLOutput += '</text>' 
    $XMLOutput += '</prtg>'
    exit 
}
$Script:ErrorActionPreference = 'Stop'
try {
    Write-Verbose "Collecting all certificates in LocalMachine on target host"
    $AllCerts = Invoke-command -ComputerName $ComputerName -ScriptBlock {Get-ChildItem -Path Cert:\LocalMachine\My\ -ErrorAction Stop} -ErrorAction Stop 
    $Date = Get-Date
    Write-Verbose "Creating formatted object of Certificates"
    $CertList = 
    foreach ($Cert in $AllCerts) {
        [PSCustomObject]@{
            FriendlyName = switch ($Cert.FriendlyName) {
                {$PSItem} {$Cert.FriendlyName  }
                Default {switch ($Cert.issuer) {
                    {$PSItem -match '='} {$Cert.issuer.split('=') | Select-Object -Last 1}
                    Default {$Cert.issuer}
                }}
            }
            NotAfter = $Cert.NotAfter
            DNSNameList = $Cert.DNSNameList.punycode -join ', ' #Covert to string
            Thumbprint = $Cert.Thumbprint
            DaysToExpiration = (Get-Date($Cert.NotAfter)) - $Date | Select-Object -ExpandProperty Days
            Issuer = switch ($Cert.Issuer) {
                {$PSItem -match '='} {$Cert.issuer.split('=') | Select-Object -Last 1}
                Default {$Cert.issuer}
            }
            MessageText = $null
        }
    }
} catch {
    Write-Verbose "Debugging information if an error occurred"
    Write-PRTGError
}

if($IgnoreThumbprint) {
    Write-Verbose "Removing Certificate thumbprints defined in parameter(s)"
    $IgnoreThumbprint = $IgnoreThumbprint -Split('[,;]')
    $CertList = $IgnoreThumbprint | ForEach-Object {
        $CertList | Where-Object Thumbprint -ne $PSItem
    }
    
}
if($DefinedThumbprint) {
    Write-Verbose "Only Certificate thumbprints defined in parameter(s)"
    $DefinedThumbprint = $DefinedThumbprint -Split('[,;]')
    $CertList = $DefinedThumbprint | ForEach-Object {
        $CertList | Where-Object Thumbprint -eq $PSItem
    }
}


Write-Verbose "Creating text message for each Cerificate"
foreach ($Cert in $CertList) {
    $Cert.MessageText = "$($Cert.FriendlyName) issued by $($Cert.Issuer) with Thumbprint $($Cert.Thumbprint) expires in $($Cert.DaysToExpiration) day(s)"
}
Write-Verbose "Creating Textoutput for certificates about to expire within 'AlarmDaysToExpire' parameter, defined at $AlarmDaysToExpire days" 
$OutputText = $CertList | Where-Object DaysToExpiration -le $AlarmDaysToExpire | Select-Object -ExpandProperty MessageText


Write-Verbose "Creating XML formatted output"
$XMLOutput = '<prtg>'
if($OutputText) {
    $XMLOutput += '<text>'
    $XMLOutput += ($OutputText -join [Environment]::NewLine)
    $XMLOutput += '</text>'
}

$CertList | ForEach-Object {
    $XMLOutput += export-PRTGXML -Channel $psitem.FriendlyName -value $psitem.DaysToExpiration -unit Day
}
$XMLOutput += '</prtg>'
Write-Verbose -Message "Write formatted result to PRTG"
Format-PrtgXml -xml $XMLOutput