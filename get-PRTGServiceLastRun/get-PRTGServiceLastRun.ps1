<#
.SYNOPSIS
    Paessler PRTG EXE sensor to validate if a service have started or is running for the last x minutes or n seconds.
.DESCRIPTION
    Primary use might be a scheduled task that calls for dependent service
.NOTES
    2022-06-30 Version 1 Klas.Pihl@Atea.se
.LINK

.EXAMPLE
    . get-PRTGServiceLastRun.ps1 -Computer server1 -Service LogParser
        Validates that service LogParser is running or have been runing the last (default) 600 seconds.
#>

[CmdletBinding(DefaultParameterSetName = 'seconds')]
param (
    [Parameter(ParameterSetName = 'minutes')]
    [Parameter(ParameterSetName = 'seconds')]
    $Computer,
    [Parameter(ParameterSetName = 'minutes')]
    [Parameter(ParameterSetName = 'seconds')]
    $Service,
    [Parameter(ParameterSetName = 'minutes')]
    $minutes,
    [Parameter(ParameterSetName = 'seconds')]
    $seconds=600
)
if($PSBoundParameters.ContainsKey("minutes")) {
    $seconds = $minutes*60
}
try {
    Write-Verbose "Test if service '$Service' is running on remote computer $Computer"
    $result = Invoke-Command -ComputerName $Computer -ScriptBlock {Get-Service $using:Service -ErrorAction SilentlyContinue} -ErrorAction SilentlyContinue | Where-Object Status -eq "Running"
    if([string]::IsNullOrEmpty($result)) {
        Write-Verbose "Service not running, validating if service has been stared last $seconds seconds"
        $result = Invoke-Command -ComputerName $Computer -ScriptBlock {$start=(get-date).AddSeconds(-$using:seconds);Get-WinEvent -FilterHashtable @{Logname='system';StartTime=$start;ProviderName ="Service Control Manager";ID=7036} -ErrorAction SilentlyContinue| Where-Object Message -like ("The {0} service entered the running state*" -f $using:Service) }
        Write-Verbose $result.message
    }
    if([string]::IsNullOrEmpty($result)) {
        throw "Service $service not running or started within last $seconds seconds"
    } else {
        Write-Output ("{0}:OK" -f ($result | Measure-Object).Count)
    }

} Catch {
    Write-Output ("2:{0}" -f $error.Exception)
    exit 2
}
