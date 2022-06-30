<#
.SYNOPSIS
    Validates windows services with startup as automatic w/wo delayed start as running.
.DESCRIPTION
    Creates 4 channels and set alert limits higher then 0/0,5 so any service not running is detcted.

    PRTG Sensor settings;
        Example;
        Parameters:         -Computer %host -exclude gpsvc,IntelAudioService,"Intel(R) TPM Provisioning Service"
        Security Context:   Use Windows credentials of parent device

        Sensor runs on probe server with Powershell 5.
        Recommended scanning Interval - 5+ minutes.


.NOTES
    2022-06-28 Version 1 Klas.Pihl@Atea.se
.LINK
    Rewrite of https://kb.paessler.com/en/topic/62319-how-do-i-monitor-all-services-on-a-server-set-to-automatic

.EXAMPLE
    .\get-PRTGServices.ps1 -Computer server1.pihl.local -UptimeGrace 7200 -Exclude IntelAudioService -Verbose

    Validates all service set as automatic* start is running within 7200 seconds after latest restart. IntelAudioService is excluded from validation.

.PARAMETER Computer
    Remote computer to query

.PARAMETER Exclude
    List of services to exclude from validation

.PARAMETER UptimeGrace
    Seconds to wait after a system startup/reboot for service to start that is set to automatic or automatic delayed start.
#>
[CmdletBinding()]
param (
    $Computer,
    $Exclude,
    $UptimeGrace=600,
    [Parameter(DontShow)]
    [string[]]$DefaultExlude = (
        'MapsBroker',
        'GameInput Service',
        'edgeupdate',
        'sppsvc',
        'WbioSrvc',
        'Google Update Service (gupdate)',
        'Google Update',
        'Dell Digital Delivery Service',
        'VNC Server Version 4',
        'Windows Modules Installer',
        'Windows Biometric Service',
        'Software Protection',
        'Microsoft .NET Framework NGEN*',
        'TPM Base Services',
        'Windows Update',
        'Remote Registry',
        'Shell Hardware Detection',
        'GoToAssist*',
        'Performance Logs and Alerts',
        'Windows Licensing Monitoring Service',
        'Shell Hardware Detection',
        'Volume Shadow Copy',
        'Microsoft Exchange Server Extension for Windows Server Backup',
        'Downloaded Maps Manager',
        'Data Protector Telemetry Client Service',
        'Tile Data model server',
        'Background Intelligent Transfer Service',
        'UsbClientService',
        'Connected Devices Platform Service',
        'Microsoft Edge-uppdatering Service (edgeupdate)',
        'Data Protector Inet',
        'Carbon Black',
        'McAfee McShield',
        'McAfee Task Manager',
        'Windows Search'
        )
)
try {
    Write-Verbose "Get all services on $Computer"
    if(-not [string]::IsNullOrEmpty($Exclude)) {
        $DefaultExlude += $Exclude
    }
    $AllServices = Get-Service  -Exclude $DefaultExlude -ComputerName $Computer -Verbose:$VerbosePreference
    #Write-Verbose ($AllServices | Out-String)

    $AllRunning =  $AllServices | Where-Object Status -eq ([System.ServiceProcess.ServiceControllerStatus]::Running)
    $AllAutomatic = $AllServices | Where-Object StartType -eq ([System.ServiceProcess.ServiceStartMode]::Automatic)
    $AutomotaicNotRunning = $AllAutomatic | Where-Object Status -ne ([System.ServiceProcess.ServiceControllerStatus]::Running)
    if((($AutomotaicNotRunning | Measure-Object).count) -ge 1) {
        $AutomotaicNotRunningNames =( ($AutomotaicNotRunning | ForEach-Object {
            "{0} ({1})" -f $PSItem.DisplayName,$PSItem.Name
        }) -join ', ' )
        Write-Verbose "Found service not running that configured as automatic start"
        switch ((Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $Computer -ErrorAction Stop | Select-Object -ExpandProperty LastBootUpTime).addseconds($UptimeGrace) -gt (Get-Date)) {
            $true {
                Write-Verbose "System restarted within last $UptimeGrace seconds, $AutomotaicNotRunningNames still not running"
                $AutomotaicNotRunningWarning = $AutomotaicNotRunning
                $AutomotaicNotRunning = $null
            }
            $false {
                Write-Verbose "$AutomotaicNotRunningNames not running"
            }
        }

    }


    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =  [PSCustomObject]@{
                Channel = "Total services"
                value = ($AllRunning | Measure-Object).count
                Unit = "Count"
            },
            [PSCustomObject]@{
                Channel = "Automatic start"
                value = ($AllAutomatic | Measure-Object).count
                Unit = "Count"
            },
            [PSCustomObject]@{
                Channel = "Not running"
                value = ($AutomotaicNotRunning | Measure-Object).count
                LimitMaxError = "0.5"
                LimitMode = 1
                LimitErrorMsg = "A service set as automatic start is not running"
            },
            [PSCustomObject]@{
                Channel = "Not running within grace period"
                value = ($AutomotaicNotRunningWarning | Measure-Object).count
                LimitMaxWarning = "0.5"
                LimitMode = 1
                LimitErrorMsg = "A service set as automatic start is not running during startup grace period"
            }
        }
    }
    if($AutomotaicNotRunningNames) {
        $Output.PRTG | Add-Member -MemberType NoteProperty -Name 'text'  -Value $AutomotaicNotRunningNames
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