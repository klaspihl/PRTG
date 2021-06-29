<#
.SYNOPSIS
    Read files from argument.
    Do not validate format other then existence and that file is not empty.
.DESCRIPTION
    Used to read output from powershell scripts invoked by PRTG that run longer then 900 secunds.
    
.EXAMPLE
    In PRTG sensor 'Parameters' add path to file. Ex. "C:\ProgramData\Paessler\PRTG Network Monitor\Logs\rdscal.json"
.INPUTS
    File
.OUTPUTS
    Content of file or error in PRTG json
.NOTES
    2021-06-29 Version 1 Klas.Pihl@Atea.se
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,Position=0)]
    [string]
    $Path
)
$ProgressPreference = $VerbosePreference
$ErrorActionPreference = "Stop"

try {
    Write-Verbose "Read file on $path"
    $Output=Get-Content -Path $Path
    if([string]::IsNullOrEmpty($Output)) {
        Write-Error -Message "File $path is empty"
    }
} Catch {
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            error = 1
            text = $error[0].Exception.Message
        }
    } | ConvertTo-Json | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($PSItem) }
}
Write-Output  $Output
