<#
.SYNOPSIS
    Clone on or several sensors o one or several devices.
.DESCRIPTION
    Uses PRTG API to clone sensors.
.EXAMPLE
    PS C:\>.\copy-PRTGSensor.ps1 -PRTGHost 'https://prtg.westeurope.cloudapp.azure.com/' -UserName apiadmin -Passhash 0123456789  -SourceSensorID 8935,8933 -TargetDeviceID 8439,8456 -Verbose
    Returns object with clone result.
.PARAMETER PRTGHost
    URL to PRTG core server
.PARAMETER UserName
    Username of account to use for API calls
.PARAMETER Passhash
    Passhash for account to use for API calls
.PARAMETER SourceSensorID
    Sensor ID as source
.PARAMETER TargetDeviceID
    Device ID as target
.PARAMETER NewName
.OUTPUTS
    Object with sensors, devices and successrate
    SourceSensor                      Success TargetDevice
    ------------                      ------- ------------
    Microsoft Hyper-V Network Adapter    True Server1
    SNMP Traffic                         True Server1
.NOTES
   2020-01-13 Version 1 Klas.Pihl@Atea.se
    Limit of 2500 sensors or devices.
#>
param (
    [CmdletBinding()]
    [Parameter(Mandatory=$true,HelpMessage="URL to PRTG core server, example https://yourserver.com")]
    [uri]$PRTGHost,
    [Parameter(Mandatory=$true,HelpMessage="PRTG username")]
    [string]$UserName,
    [Parameter(Mandatory=$true,HelpMessage="https://yourserver.com/api/getpasshash.htm?username=myuser&password=mypassword")]
    [int]$Passhash,
    [Parameter(Mandatory=$false,HelpMessage="The sensor ID to clone")]
    [int[]]$SourceSensorID,
    [Parameter(Mandatory=$false,HelpMessage="The target device ID for cloned sensor",ValueFromPipeline)]
    [int[]]$TargetDeviceID,
    [Parameter(Mandatory=$false,HelpMessage="The target sensor name")]
    [string]$NewName
)
#region Self signed certificates
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
Write-Verbose "Accepting self signed certificates"
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#endregion Self signed certificates
#region Functions
function get-PRTGAPIData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,HelpMessage="Base url to PRTG core server, like https://prtg01.pihl.local")]
        [uri]$PRTGHost,
        [Parameter(Mandatory=$true,HelpMessage="username=<user>%passhash=<[int]passhash>")]
        [string]$auth,
        [Parameter(Mandatory=$true)]
        [ValidateSet('GetAllDevices','GetDeviceSensor','DuplicateSensor','Resume','Pause')]
        [string]$APIFunction,
        [Parameter(Mandatory=$false,HelpMessage="PRTG sensor ID")]
        [int]$SensorID,
        [Parameter(Mandatory=$false,HelpMessage="PRTG target sensor ID")]
        [int]$TargetID,
        [Parameter(Mandatory=$false,HelpMessage="PRTG sensor new name")]
        [string]$NewName

    )
    
    try {
        $api = $APIkeys.$APIFunction -f $SensorID,$TargetID,$NewName
        
        Write-Verbose  "Api call rewuested $api"
        [uri]$uri = $PRTGHost.ToString()+$api.ToString()+$auth.ToString()
        Write-Verbose "Complete URL: $uri"
        $request = Invoke-WebRequest -Uri $uri  -ErrorAction Stop #-MaximumRedirection 1
        if($request.StatusCode -ne 200) {
            Write-Verbose "Failed respons from uri"
            return $false
        }
        if($request.content -and $APIFunction -like "get*") {
            $PRTG_Result = convertFrom-csv -ErrorAction Stop  ($request.content) -WarningAction SilentlyContinue | Select-Object * -ExcludeProperty *raw*
            return $PRTG_Result
        }
    } catch [System.Net.WebException] {
        throw "Wrong URL, no respons from $PRTGHost`n$($_.Exception)"
        return $false
    } catch {
        throw "Could not get data from PRTG host $PRTGHost`n$($_.Exception)"
        return $false
    }
    return $true
}
#endregion Functions
#region Main
    $Global:APIkeys = [PSCustomObject]@{
        GetAllDevices = 'api/table.xml?content=devices&output=csvtable&columns=objid,device,host&count=2500&id={0}'
        GetDeviceSensor = 'api/table.xml?content=sensors&output=csvtable&columns=objid,device,sensor,status&id={0}'
        DuplicateSensor = 'api/duplicateobject.htm?id={0}&name={2}&targetid={1}' #SourceID, NewName, TargetID
        Resume = 'api/pause.htm?id={0}&action=1'
        Pause = 'api/pause.htm?id={0}&action=0'
    }
    $Auth = "&username={0}&passhash={1}" -f $UserName,$Passhash
    #hämtar device,host och ID
    if(-not $SourceSensorID) {
        Write-Verbose "Quering PRTG core server of all sensors"
        $SelectedSensor = get-PRTGAPIData -PRTGHost $PRTGHost -auth $Auth -APIFunction GetDeviceSensor | Out-GridView -PassThru -Title "Select sensor to clone"  
        [int[]]$SourceSensorID = $SelectedSensor | Select-Object -ExpandProperty id
    } else {
        $AllSensors = get-PRTGAPIData -PRTGHost $PRTGHost -auth $Auth -APIFunction GetDeviceSensor
        $SelectedSensor = $SourceSensorID | ForEach-Object {
            $AllSensors | Where-Object ID -eq $_
        }
    }
    Write-Verbose "SensorID(s)$($SourceSensorID | Out-String)"

    if(-not $TargetDeviceID) {
        Write-Verbose "Quering PRTG core server of all devices"
        $SelectedDevice = get-PRTGAPIData -PRTGHost $PRTGHost -auth $Auth -APIFunction GetAllDevices | Out-GridView -PassThru -Title "Select device target for clone" 
        [int[]]$TargetDeviceID = $SelectedDevice | Select-Object -ExpandProperty id
    } else {
        $AllDevices = get-PRTGAPIData -PRTGHost $PRTGHost -auth $Auth -APIFunction GetAllDevices
        $SelectedDevice = $TargetDeviceID | ForEach-Object {
            $AllDevices | Where-Object ID -eq $_
        }
    }
foreach ($Sensor in $SourceSensorID) {
    Write-Verbose $Sensor
    $SensorExist = [bool]($SelectedSensor | Where-Object ID -eq $Sensor)
    if($SensorExist) {
        $Sensor = $SelectedSensor | Where-Object ID -eq $Sensor
        Write-Verbose $Sensor
        foreach ($Device in $TargetDeviceID) {
            $Device = $SelectedDevice | Where-Object ID -eq $Device
            Write-Verbose "Copying sensor $($Sensor.Sensor) with ID $($Sensor.id) to device $($Device.Device) with ID $($Device.id)"
            if(-not $NewName) {
                $SensorNewName = $Sensor.Sensor
            } else {
                $SensorNewName = $NewName
            }
            $result = get-PRTGAPIData -PRTGHost $PRTGHost -auth $Auth -APIFunction DuplicateSensor -TargetID $Device.ID -SensorID $Sensor.ID -NewName $SensorNewName
            [PSCustomObject]@{
                SourceSensor= $Sensor.Sensor
                Success = $result
                TargetDevice = $Device.Device
            }
        }
    } else {
        Write-Warning "Sensor ID $Sensor not found"
    }
}
#endregion Main