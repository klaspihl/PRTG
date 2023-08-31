<#
.SYNOPSIS
    Use container together with Bredbandskollens's binary to measure internet speed
    

.DESCRIPTION
    Use docker container that package bbk cli and returns a json object.

    WSL and Linux distro must be accessable from the user session that is invoked by the custom sensor (PRTG Security context). 

    Environment use PRTG placeholders;
        $env:prtg_username, 
        $env:prtg_password, 
        $env:prtg_host  

.NOTES
    2023-04-11 Version 1 Klas.Pihl@gmail.com
    2023-08-31 Version 2 using docker as application /Klas.Pihl@gmail.com
.LINK
    https://www.bredbandskollen.se/om/mer-om-bbk/bredbandskollen-cli/
.EXAMPLE
    . .\measure-bbk.ps1

.PARAMETER Duration
    Duration in seconds to measure

.PARAMETER Logfile
    Output file to write to. If not specified, a temporary file will be created and deleted after the script has run.

.OUTPUTS
    PRTG output
    {
    "prtg": {
        "result": [
        {
            "Channel": "Download",
            "Float": 0,
            "Value": 135,
            "LimitMode": 1,
            "LimitMinError": "100",
            "CustomUnit": "MB/s"
        },
        {
            "Channel": "Upload",
            "Float": 0,
            "Value": 138,
            "LimitMode": 1,
            "LimitMinError": "100",
            "CustomUnit": "MB/s"
        },
        {
            "Channel": "Execution time",
            "Float": 0,
            "Value": 4934,
            "CustomUnit": "ms",
            "LimitMode": 1,
            "LimitMaxError": 15000
        },
        {
            "Channel": "Latency",
            "Float": 0,
            "Value": 15,
            "CustomUnit": "ms",
            "LimitMode": 1,
            "LimitMaxError": 50
        }
        ],
        "text": "UL: 135, DL: 138"
    }
    }
#>

[CmdletBinding()]
param (
    $Computer= $env:prtg_host,
    $Duration=10,
    $Logfile
)
$script:ErrorActionPreference='Stop'
try {
    $ExecutionTime = Measure-Command {
        $Result = Invoke-Command -ComputerName $Computer -command {docker run --rm --name prtg_bbk klaspihl/bbk_json:latest} | ConvertFrom-Json | Select-Object *,ExecutionTime
    }
    $Result.ExecutionTime=[int][math]::Round($ExecutionTime.TotalMilliseconds,0)

write-verbose $result
#region PRTG output
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =
                [PSCustomObject]@{
                    Channel = 'Download'
                    Float = 0
                    Value = [int][math]::Round($Result.Download,0)
                    LimitMode = 1
                    LimitMinError = "100"
                    CustomUnit = 'MB/s'
                },
                [PSCustomObject]@{
                    Channel = 'Upload'
                    Float = 0
                    Value = [int][math]::Round($Result.Upload,0)
                    LimitMode = 1
                    LimitMinError = "100"
                    CustomUnit = 'MB/s'
                },
                [PSCustomObject]@{
                    Channel = "Execution time" 
                    Float = 0
                    Value = $Result.ExecutionTime
                    CustomUnit = 'ms'
                    LimitMode = 1
                    LimitMaxError = 15000
                },
                [PSCustomObject]@{
                    Channel = "Latency"
                    Float = 0
                    Value = [int][math]::Round($Result.Latency,0)
                    CustomUnit = 'ms'
                    LimitMode = 1
                    LimitMaxError = 50
                }
                
            text = ("UL: {0}, DL: {1}" -f $Result.Download, $Result.Upload)
        }
    }
#endregion PRTG output
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