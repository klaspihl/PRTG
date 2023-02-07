<#
.SYNOPSIS
    Pauses object in PRTG by object ID
.DESCRIPTION
    Used for scheduled system restarts like Windows update or nightly maintenence work
.NOTES
    2023-02-07 Version 1 Klas.Pihl@Atea.se
.LINK
    https://github.com/klaspihl/PRTG
.EXAMPLE
    ./Suspend-PRTGID.ps1 -APIkey (read-host) -ID 1234 -Comment "Windows update" -Pause
        Uses APIKey from user and pauses object with comment

.EXAMPLE
     .\suspend-PRTGID.ps1 -ID 1234 -APIkey .\apikey.sec -PauseFor 15
        Get APIKey from file and pauses object for 15 minutes, then automaticly resume.

.PARAMETER APIkey
    PRTG User API key
    If a valid path is entered file content is loaded as API Key

.PARAMETER ID
    PRTG Object ID

.PARAMETER PRTGServer
    URL including HTTPs:// to PRTG core server

.PARAMETER PauseFor
    Automaticly pauses PRTG object for n minutes then resumes

.PARAMETER Pause
    Manually pause PRTG object

.PARAMETER Resume
    Manually resumes PRTG object

.PARAMETER Comment
    Comment to pause
#>
[CmdletBinding()]
param (
    [string]$APIkey='.\apikey.sec',
    [int]$ID,
    [string]$PRTGServer = 'https://prtg.pihl.local',
    [Parameter(ParameterSetName = 'PauseFor')]
    [int]$PauseFor,
    [Parameter(ParameterSetName = 'Resume')]
    [switch]$Resume,
    [Parameter(ParameterSetName = 'Pause')]
    [switch]$Pause,
    [Parameter(ParameterSetName = 'Pause')]
    [Parameter(ParameterSetName = 'PauseFor')]
    [string]$Comment = "Automatic pause by $($MyInvocation.MyCommand.Name)"
)
try {
    if(Test-Path $APIkey) {
        Write-Verbose "Parameter APIKey is a valid file path, try to load API key from $APIKey"
        $APIkey = Get-Content $APIkey -ErrorAction Stop
    }

   switch ($PSBoundParameters.Keys) {
        'PauseFor' {
            $APIURL = '/api/pauseobjectfor.htm?id={0}&pausemsg={1}&duration={2}&apitoken={3}' -f $ID,$Comment,$PauseFor,$APIkey 
            $Action = 'Paused for {0} minutes' -f $PauseFor
        }
        'Resume' {
            $APIURL = '/api/pause.htm?id={0}&action=1&apitoken={1}' -f $ID,$APIkey 
            $Action = 'Resumed'
        }
        'Pause' { 
            $APIURL = '/api/pause.htm?id={0}&action=0&apitoken={1}' -f $ID,$APIkey 
            $Action = 'Paused'
        }
        Default {}
    }
    $result = Invoke-WebRequest ("{0}{1}" -f $PRTGServer.TrimEnd('/'),$APIURL) -ErrorAction Stop

    switch ($result.StatusCode) {
        200 {
            Write-Output ([PSCustomObject]@{
                ID = $ID
                Action = $Action
                Status = "OK"
            })
        }
        400 { throw 'Bad Request' }
        401 { throw 'Unauthorized' }
        403 { throw 'Forbidden' }
        404 { throw 'Not Found' }
        408 { throw 'Request Timeout' }
        409 { throw 'Conflict' }
        500 { throw 'Internal Server Error' }
        502 { throw 'Bad Gateway' }
        503 { throw 'Service Unavailable' }
        504 { throw 'Gateway Timeout' }
        Default {throw $PSItem}
    }
    
} catch {
    Write-Error $error[0].exception.message
}