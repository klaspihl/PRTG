<#
.SYNOPSIS
    PRTG sensor for measuring hardware statistics on Rasbian OS on Raspberry
.DESCRIPTION
    Uses 'vcgencmd' to get data on temperature, clockspeed and cpu voltage.
    Call from /var/prtg/scriptsxml/hwdata.sh that just load the powershell script from bash. Uses PRTG 'SSH Script Advanced' sensor
        #!/bin/bash
        pwsh -file /var/prtg/scriptsxml/hwdata.ps1
.EXAMPLE
    pwsh -file /var/prtg/scriptsxml/hwdata.ps1
.PARAMETER ValidChars
    Regex to filter output from program
.PARAMETER Program
    binary to use for loading data
.PARAMETER Data
    Measurements entitys
.OUTPUTS
    PRTG advanced XML output
.NOTES
    2021-04-28 0.9 Initial code to get some data /Klas.Pihl@Gmail.com
#>

[CmdletBinding()]
param (
[regex]$ValidChars='[^0-9.,/ ]', #Write-Output ($CleanedName -Replace($ValidChars,''))
$Program ='vcgencmd',
[array]$Data = (
    'measure_temp',
    'measure_clock arm',
    'measure_clock core',
    'measure_volts core')
)
function Format-PrtgXml([xml]$xml) {
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

$ReturnData = $Data | ForEach-Object {
    $Command = "{0} {1}" -f $Program,$PSItem
    $DataRespons = Invoke-Expression $command -ErrorAction Stop
    [PSCustomObject]@{
        Channel = $PSItem
        Name = $DataRespons -split '=' | Select-Object -First 1
        Value = ($DataRespons -split '=' | Select-Object -Last 1 ) -Replace($ValidChars,'')
    }
}
$XMLOutput = '<prtg>'
Write-Verbose "Creating XML formatted output"
    foreach($Sensor in $ReturnData) {
        $Channel = $Sensor.Channel
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
