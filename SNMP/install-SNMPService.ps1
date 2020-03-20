<#
.Synopsis
  Adds SNMP-service on Windows systems.
.DESCRIPTION
   Input is array of FQDN, test if server responds to ping and WSMAN
.EXAMPLE
   .\prtg_install_snmp.ps1 -ServerList 'server01.pihl.local','server02.pihl.local'
.INPUTS
    Server list, FQDN
.NOTES 2019-04-15 Version 1 Klas.Pihl@Atea.se
#>

param (
  [Parameter(ValueFromPipeline,Mandatory=$true,HelpMessage="FQDN only, example: server01.corp.local")]
  $ServerList
)
function test-online ($fqdn)
{
    try{$result = Test-Connection -ComputerName $fqdn -Count 1 -Quiet}
    catch {Write-Warning "$fqdn  no ping reply"}
    if($result)
        {
        try {$resultwsman = Test-WSMan -ComputerName $fqdn -ErrorAction Ignore}
        catch {Write-Warning "$fqdn no WINRM reply"}
        if($resultwsman){return $result }
        }
        if(!$result) {Write-Warning "$fqdn  no reply"}
         if(!$resultwsman) {Write-Warning "$fqdn  no WMI reply"}
}
foreach  ($server in $ServerList)
    {
    if(test-online -fqdn $server)
        {
        Invoke-Command -ComputerName $fqdn -ScriptBlock {add-WindowsFeature snmp-service -Restart:$false}
        }
    }
