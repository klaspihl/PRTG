<#
.SYNOPSIS
    Use WSL on Windows together with Bredbandskollens's binary to measure internet speed
    

.DESCRIPTION
    Use WSL on Windows together with Bredbandskollens's binary to measure internet speed
    Output 4 PRTG channels

    WSL and Linux distro must be accessable from the user session that is invoked by the custom sensor (PRTG Security context). 

    Environment use PRTG placeholders;
        $env:prtg_username, 
        $env:prtg_password, 
        $env:prtg_host  

.NOTES
    2023-04-11 Version 1 Klas.Pihl@gmail.com
.LINK
    https://www.bredbandskollen.se/om/mer-om-bbk/bredbandskollen-cli/
.EXAMPLE
    . .\measure-bbk.ps1 -Duration 2 -Logfile "c:\temp\bbk.log" -Verbose

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
    [scriptblock]$command = {
        if (-not $using:Logfile) {
            $Logfile = New-TemporaryFile 
        } else {
            $Logfile = Get-Item -Path $using:Logfile
        }
        Set-Location $Logfile.Directory

        if ($using:Duration) {
            $Duration = "--duration={0}" -f $using:Duration
        }
        else {
            $Duration = $null
        }

        $command = 'wsl bbk_cli --out={0} --quiet {1}' -f $Logfile.Name, $Duration
        Invoke-Expression $command
        $Latency, $Download, $Upload, $null = (Get-Content $Logfile.FullName -Last 1) -split (' ')
        [PSCustomObject]@{
            Latency       = [int][math]::Round($Latency,0)
            Download      = [int][math]::Round($Download,0)
            Upload        = [int][math]::Round($Upload,0)
            ExecutionTime = [int][math]::Round($ExecutionTime.TotalMilliseconds,0)
        }
    }
    Write-Verbose ($command | Out-String)
    $ExecutionTime = Measure-Command {
        #Invoke-Expression $command
        [securestring]$Password = ConvertTo-SecureString $env:prtg_windowspassword -AsPlainText -Force
        [pscredential]$Credential = New-Object System.Management.Automation.PSCredential ($env:prtg_windowsuser, $Password)
        $Result = Invoke-Command -ComputerName $Computer -ScriptBlock $command -Credential $Credential
    }
    


#region PRTG output
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =
                [PSCustomObject]@{
                    Channel = 'Download'
                    Float = 0
                    Value = $Result.Download
                    LimitMode = 1
                    LimitMinError = "100"
                    CustomUnit = 'MB/s'
                },
                [PSCustomObject]@{
                    Channel = 'Upload'
                    Float = 0
                    Value = $Result.Upload
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
                    Value = $Result.Latency
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