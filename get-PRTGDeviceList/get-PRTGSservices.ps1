<#
.SYNOPSIS
    Get all services as with startup mode as automatic or automatic delayed start and validate that service is running
    If service(s) not running returns error.
.DESCRIPTION

.NOTES
    2022-06-28 Version 1 Klas.Pihl@Atea.se


    (Get-Uptime) -gt (get-date -f t)
    Get-Service -Include "MapsBroker","LanmanWorkstation" -Exclude LanmanWorkstatio*
.LINK
    Rewrite of https://kb.paessler.com/en/topic/62319-how-do-i-monitor-all-services-on-a-server-set-to-automatic
.EXAMPLE
    get-PRTGServiceces.ps1 -Computer Server1.pihl.local
#>

[CmdletBinding()]
param (
    [Parameter()]
    [TypeName]
    $ParameterName
)