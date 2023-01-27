<#
.SYNOPSIS
    PRTG sensor for OpenHardwareMonitor
.DESCRIPTION
    Collect all sensors of requested sensortype and returns an PRTG advanced XML sensor
.EXAMPLE
    PS C:\> get-PRTGHWTemp.ps1 -computer $Laptop1 -Sensortype Temperature
        Get all temperature sensors of computer Laptop1
.PARAMETER Computer
    Source system hostname or FQDN

.PARAMETER Sensortype
    Requested data type.
.OUTPUTS
    PRTG advanced XML output
.NOTES
    2021-03-27 0.9 Initial code. Limitied error handling /Klas.Pihl@Gmail.com
#>
[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [string]$Computer,
    [Parameter(Position=1)]
    [ValidateSet(
        "Power",
        "Clock",
        "Load",
        "Load",
        "Data",
        "Temperature",
        "Voltage",
        "Level"
        )]
    [string]$Sensortype="Temperature"
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
    #Write-Output ('<unit>{0}</unit>' -f $unit)
    Write-Output '<showChart>1</showChart>'
    Write-Output '<showTable>1</showTable>'
    Write-Output '<float>1</float>'
    Write-Output ('<value>{0}</value>' -f $Value)
    Write-Output '</result>'
}
try {

    $Data = Get-CimInstance -ClassName Sensor -Namespace  root/OpenHardwareMonitor -CimSession $Computer -ErrorAction Stop | Where-Object SensorType -eq $Sensortype
    $XMLOutput = '<prtg>'
    Write-Verbose "Creating XML formatted output"
    foreach($Sensor in $Data) {
        $Channel = "{0}/{1}" -f $Sensor.Parent,$Sensor.Name
        $XMLOutput += export-PRTGXML -Channel $Channel  -value $Sensor.value # -unit Temperature
    }
    $XMLOutput += '</prtg>'
    Write-Verbose -Message "Write formatted result to PRTG"
    Format-PrtgXml -xml $XMLOutput
} catch {
        $XMLOutput = '<prtg>'
        $XMLOutput += Write-Output '<error>1</error>'
        $XMLOutput += Write-Output ('<text>{0}</text>' -f ($error[0].Exception.Message | Out-String))
        $XMLOutput += '</prtg>'
        Write-Verbose -Message "Error found, exiting"
        Format-PrtgXml -xml $XMLOutput
    exit 1
}