<#
.SYNOPSIS
    Get time since scheduled task last ran.
.DESCRIPTION
    Channels;
        TaskName - time in seconds since last runtime
        ExcecutionTime - time in ms for the sensor to run

    PRTG settings;
        [x] Use Windows credentials of parent device
        [x] Set placeholders as environment values

.PARAMETER TaskName
    Name of scheduled task(s) to check

.PARAMETER Computer
    Computer to check scheduled task on
    Default PRTG Set placeholders %host

.PARAMETER Timeout
    Timeout in milliseconds for default alarm level

.NOTES
    2023-04-02 Version 1 Klas.Pihl@Atea.se

.OUTPUTS
    PRTG formatted in JSON    
    If errors text/message report exit code of task / error message
    

.EXAMPLE
    get-PRTGScheduledTask -TaskName 'Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan',
        'Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance',
        'Microsoft\Windows\Windows Defender\Windows Defender Verification'

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)]
    [string[]]$TaskName,
    $Computer = $env:prtg_host,
    [parameter(DontShow)]
    $Timeout = 5000
)
try {
    $Date = Get-Date
    Write-Verbose "Get scheduled task info on: $($TaskName -join ', ')"
    $RunTime = Measure-Command  {
        [array]$ScheduledTask = Get-ScheduledTask -CimSession $Computer -TaskName $TaskName -ErrorAction $ErrorActionPreference | Get-ScheduledTaskInfo -ErrorAction $ErrorActionPreference
    }
    [array]$Result = ($ScheduledTask | ForEach-Object {
        ([PSCustomObject]@{
            Channel = $PSItem.TaskName
            Float = 0
            Value = [math]::round((($Date - (Get-Date($PSItem.LastRunTime))).TotalSeconds))
            CustomUnit = 's'
        })
    })
    $Result += [PSCustomObject]@{
        Channel = "Execution time" 
        Float = 0
        Value = ([math]::round($RunTime.TotalMilliseconds))
        CustomUnit = 'ms'
        LimitMode = 1
        LimitMaxError = $Timeout
    }

    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =
                ($Result | ForEach-Object {
                    ([PSCustomObject]@{
                        Channel = $PSItem.Channel
                        Float = $PSItem.Float
                        Value = $PSItem.Value
                        CustomUnit = $PSItem.CustomUnit
                    })
                })
            text = ("Tasks: {0}" -f ($TaskName -join ', '))
        }
    }
    
    } Catch {
        $Output = [PSCustomObject]@{
            prtg = [PSCustomObject]@{
                error = 1
                text = $error[0].Exception.Message
            }
        }
    }
    Write-Output ($Output | ConvertTo-Json -depth 5 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($PSItem) })  
