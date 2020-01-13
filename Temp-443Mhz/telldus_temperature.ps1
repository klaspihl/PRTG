<#
.Synopsis
   Gets data from 433MHz devices and export the data in a format readable from Paessler PRTG
.EXAMPLE
   Get sensor data from channel 215 and returns PRTG XML format. 
   telldus_tempeature.ps1 215
#>
#region Functions
function read-data
{ 
try {$sensoroutput = & 'C:\Program Files (x86)\Telldus\tdtool.exe' --list-sensors}
catch {Write-Error "cant read data";exit}
foreach ($sensor in $sensoroutput)
    {
    $hashSensor = $sensor | ConvertFrom-Csv -Delimiter "`t" -Header 'type','protocol','model','id','temperature','humidity','time','age'
    #clean output
    $properties = Get-Member -InputObject $hashSensor -MemberType NoteProperty
    foreach ($row in $properties.name)
        {
        $hashSensor.$row = $hashSensor.$row.split('=')[-1]
        }
    #change format of numbers
    foreach ($row in $properties.name)
        {
        $hashSensor.$row = $hashSensor.$row.Replace('.',',')
        }
$hashSensor
    }
}

function prtg-output ($temperature,$humidity)
{
if($name.count -gt 1)
    {
    Write-Error "Only one value accepted";exit
    }
Write-Output "<prtg>"
    Write-Output "<result>"
    Write-Output "<channel>Temperature</channel>"
    Write-Output "<showChart>1</showChart>"
    Write-Output "<showTable>1</showTable>"
    Write-Output "<value>$temperature</value>"
    Write-Output "</result>"
       Write-Output "<result>"
    Write-Output "<channel>Humidity</channel>"
    Write-Output "<showChart>1</showChart>"
    Write-Output "<showTable>1</showTable>"
    Write-Output "<value>$humidity</value>"
    Write-Output "</result>"
Write-Output "</prtg>"
}
#endregion
$sensor =read-data | ? id -eq $args[0] #input channel ID from Tellduscenter, example. 215
[int]$temperature = $sensor.temperature
prtg-output -temperature $temperature -humidity $sensor.humidity
