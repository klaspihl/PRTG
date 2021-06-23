<#
.SYNOPSIS
    Inventory templates PRTG template files and create output object
.DESCRIPTION
    -
.EXAMPLE
    PS C:\> get-PRTGtemplates.ps1 -Filter "custom*"

.PARAMETER Path
    Path for devicetemplates

.PARAMETER Filter
    Template file name filter

.INPUTS
    -
.OUTPUTS

.NOTES
    2021-06-23 Version 1 Klas.Pihl@Atea.se
#>
[CmdletBinding()]
param (
    [Parameter()]
    $Path = 'C:\Program Files (x86)\PRTG Network Monitor\devicetemplates',
    $Filter = "*.odt"
)
$Alltemplate = Get-ChildItem -Path $Path -Filter $Filter
if(-not $Alltemplate) {
    Write-Error "No template files found in $path"
}
$Result =
foreach ($template in $Alltemplate) {
    $SensorsOutput = $null
    Write-Verbose "####################################"
    Write-Verbose "Reading: $($template.FullName)"
    [xml]$Content = $template | Get-Content
    $TemplateName = $Content.devicetemplate.name
    #$Sensors = $Content.devicetemplate.check
    $SensorsOutput += foreach ($Sensor in $Content.devicetemplate.create) {
        $SensorName = $Sensor.kind
        Write-Verbose "Formatting: $SensorName"
        $Interval = switch ($Sensor.createdata.interval) {
            {-not [string]::IsNullOrEmpty($psitem.cell)} {
                Write-Verbose "Found 'cell'"
                ($psitem.cell.innertext | Select-Object -Last 1).trim()
            }
            {[string]::IsNullOrEmpty($psitem.cell)} {
                Write-Verbose "Found 'data'"
                if($psitem) {
                    $psitem.trim()
                } else {
                    Write-Verbose "No (inner) Interval data found"
                }
            }
            Default {
                Write-Verbose "No Interval data found"
                Write-Output $null
            }
        }
        [PSCustomObject]@{
            SensorName = $SensorName
            Interval = $Interval
        }
    }
    [PSCustomObject]@{
        TemplateName = $TemplateName
        Sensors = $SensorsOutput
    }
}

Write-Output $Result