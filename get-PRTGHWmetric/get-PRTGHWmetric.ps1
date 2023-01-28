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

.PARAMETER Source
    Datasource 
.OUTPUTS
    PRTG advanced json output
.NOTES
    2021-03-27 0.9 Initial code. Limitied error handling /Klas.Pihl@gmail.com
    2023-01-28 1.0 Added;
        Error handling
        Change default data source to LibreHardwareMonitor with option OpenHardwareMonitor
        Added sensortypes;
            Energy (battery)
            Throughput
        Issues, LibreHardwareMonitor do not return correct suffix/unit so use of hard coded units. /Klas.Pihl@gmail.com
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
        "Data",
        "Temperature",
        "Voltage",
        "Level",
        "Energy",
        "Throughput"
        )]
    [string]$Sensortype="Temperature",
    [ValidateSet(
        'OpenHardwareMonitor',
        'LibreHardwareMonitor'
    )]
    $Source='LibreHardwareMonitor'
)

#Main code
try {
    $Measurements = Get-CimInstance -ClassName Sensor -Namespace  ("root/{0}" -f $Source) -CimSession $Computer -ErrorAction Stop | Where-Object SensorType -eq $Sensortype
    if([string]::IsNullOrEmpty($Measurements)) {
        throw "No data returned from Namespace root/$Source"
    }
    $CustomUnit = switch ($Sensortype) {
        "Power" {"W"}
        "Clock" {"MHz"}
        "Load" {"%"}
        "Data" {"GB"}
        "Temperature" {"C"}
        "Voltage" {"V"}
        "Level" {"%"}
        "Energy" {"mWh"}
        "Throughput" {"MB/s"}
        Default {'#'}
    }
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =
                $Measurements | ForEach-Object {
                    [PSCustomObject]@{
                        Channel = $PSitem.Name
                        Float = 1
                        Value = $PSitem.value
                        CustomUnit = $CustomUnit

                    }
                }
        }
    }

} Catch {
    $error
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            error = 1
            text = $error[0].Exception.Message
        }
    }
}
Write-Output ($Output | ConvertTo-Json -depth 5 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($PSItem) })
