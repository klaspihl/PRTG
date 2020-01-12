<#
.SYNOPSIS
    PRTG sensor 'EXE/Script adnvanced' measuring Time Dispersion between minitored device and PRTG server
.DESCRIPTION
    Get local time of probe server and compares of target system (device)
.EXAMPLE
    PS C:\> get-PRTGTimeDispersion.ps1 -domain '%windowsdomain' -password '%windowspassword' -computer '%host' -Username '%windowsuser'
    Returns XML readable by PRTG
.INPUTS
    Device, i.e. %host, %windowsDomain, %windowsUser, %windowsPassword
.OUTPUTS
    XML output of;
        Timedifference in seconds
.PARAMETER Computername
    Target system IP or Hostname from PRTG placeholder %host
.PARAMETER Username
    Target system credential username from PRTG placeholder %windowsUser
.PARAMETER Domain
    Target system credential Domain from PRTG placeholder %windowsDomain
.PARAMETER Password
    Target system credential Password from PRTG placeholder %windowsPassword
.NOTES
    2020-01-10 Version 1 Klas.Pihl@Atea.se
#>
param (
    [CmdletBinding()]
    [parameter(mandatory=$true)]
    [string]$Username,
    [parameter(mandatory=$true)]
    [string]$Password,
    [parameter(mandatory=$true)]
    [string]$Computername,
    [parameter(mandatory=$false)]
    [string]$Domain
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
            'TimeHours'
            )]
        $unit
    )
    $Value = $Value.Replace(',','.')
    Write-Output '<result>'
    Write-Output ('<channel>{0}</channel>' -f $Channel)
    Write-Output ('<unit>{0}</unit>' -f $unit)
    Write-Output '<showChart>1</showChart>'
    Write-Output '<showTable>1</showTable>'
    Write-Output '<float>1</float>'
    Write-Output ('<value>{0}</value>' -f $Value)
    Write-Output '</result>'
}
if($Domain) {
    $Username = $Domain.trim()+'\'+$Username.trim()
    Write-Verbose "Domain supplied: $Domain, UserName: $username"
}
$ErrorMessage ='Can not calculate time from device: '
try {
    Write-Verbose "Creating secure password string"
    $Passwordecure=$Password | ConvertTo-SecureString -asPlainText -Force -ErrorAction Stop
    Write-Verbose "Creating credential for target system $Computername"
    $credential = New-Object System.Management.Automation.PSCredential($username,$Passwordecure) -ErrorAction Stop
    Write-Verbose "Requesting target system local time"
    $TargetServerTime = Get-WmiObject -Class win32_localtime -ComputerName $Computername -Credential $credential -ErrorAction stop
    $GetTimeParameter = @{
        Day = $TargetServerTime.Day 
        Month = $TargetServerTime.Month 
        Year = $TargetServerTime.Year 
        Minute = $TargetServerTime.Minute 
        Hour = $TargetServerTime.Hour 
        Second = $TargetServerTime.Second
    }
    $TargetServerTime = Get-Date  @GetTimeParameter -ErrorAction Stop
    $SourceServerTime = Get-Date
    [cultureinfo]::CurrentCulture.NumberFormat.NumberDecimalSeparator = "."
    Write-Verbose "Calculating time difference"
    $diff = [math]::Abs((New-TimeSpan -Start $TargetServerTime -End $SourceServerTime | Select-Object -ExpandProperty TotalSeconds))
}
catch {
    Write-Verbose "Error occured"
    $diff = $false
}
$XMLOutput = '<prtg>'
if($diff) {
    Write-Verbose "Creating XML formatted output"
    $XMLOutput += export-PRTGXML -Channel "TimeDifference" -value $diff -unit TimeSeconds
} else {
    $XMLOutput += Write-Output '<error>1</error>'
    $XMLOutput += Write-Output ('<text>{0}</text>' -f ($ErrorMessage +$Error | Out-String))
}
$XMLOutput += '</prtg>'
Write-Verbose -Message "Write formatted result to PRTG"
Format-PrtgXml -xml $XMLOutput

