# Installs SNMP feature on Windows systems from WMF 5.1

[Install and Configure WMF 5.1](https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/wmf/setup/install-configure?view=powershell-7.2)

## Synopsis

```powershell
<#
.Synopsis
  Adds SNMP-service on Windows systems.
.DESCRIPTION
  Input is array of Hostname, test if server responds to ping and WSMAN
  Accept pipeline from Get-ADComputer

.INPUTS
    Server list

.OUTPUTS
  Global variables
    SNMPOffline, remote systems not available for connection
    SNMPError, errors validating / installing SNMP

.EXAMPLE
  "hybridworker1.pihl.local","arc1.pihl.local" | .\install-SNMPService.ps1 -Credential (Get-Credential) | Select-Object PScomputername,success,exitcode

.EXAMPLE
  Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*'} | .\install-SNMPService.ps1 -Credential (Get-Credential) | Select-Object PScomputername,success,exitcode

.EXAMPLE
  .\install-SNMPService.ps1 -Computer 'server01.pihl.local','server02.pihl.local'

.NOTES
  2019-04-15 Version 1 Klas.Pihl@Atea.se
  2022-06-16 Version 2
    Added support for pipeline from ex. Get-ADComputer, parallel installation of SNMP feature. Support for Whatif and Confirm Klas.Pihl@gmail.com

#>
```
## Examples
```powershell
"offline","arc1.pihl.local" | .\install-SNMPService.ps1  -WhatIf
WARNING: Can not access offline. offline : DNS name does not exist.
What if: Performing the operation "Initiate install SNMP" on target "arc1.pihl.local".
WARNING: No remote systems available
```

```powershell
Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*'} | .\install-SNMPService.ps1 -Credential (Get-Credential) | Select-Object PScomputername,success,exitcode

PowerShell credential request
Enter your credentials.
User: XXXXXXXX
Password for user admin: ***************************

WARNING: Can not access subca1. Could not ping subca1.pihl.local, can not try to validate or install SNMP
...
WARNING: Can not access ras. Could not ping RAS.pihl.local, can not try to validate or install SNMP

PSComputerName Success ExitCode
-------------- ------- --------
ARC1         True NoChangeNeeded
...
DC01         True NoChangeNeeded



$SNMPOffline
subca1
...
RAS
```