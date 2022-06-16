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
#requirements version 5
[cmdletbinding(SupportsShouldProcess = $True)]
param (
  [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $true, Mandatory = $true, HelpMessage = "Target server name")]
  [Alias('Computer')]
  [string[]]$Name,
  [PSCredential]$Credential,
  [parameter(DontShow)]
  $JobName = 'InstallSNMP',
  [parameter(DontShow)]
  $TimeOut = 120
)

begin {
  $global:SNMPOffline = @()
  function test-online {
    <#
    .SYNOPSIS
      Validate basic access to target system
    .DESCRIPTION
      Try to resolv, ping and test ws-man. If successfull returns true otherwise false
    .NOTES
      2022-06-16 Revrite from original code from 2020-03-26 /Klas.Pihl@gmail.com
    .LINK
      https://github.com/KlasPihl/PRTG/blob/master/SNMP/install-SNMPService.ps1

    #>

    param (
      [string]$RemoteHost
    )
    try {
      $FQDN = Resolve-DnsName $RemoteHost -ErrorAction Stop | Select-Object -ExpandProperty Name

      if (Test-Connection -ComputerName $FQDN -Count 1 -Quiet) {
        Write-Verbose "Ping successful, try WSNan"
        if (Test-WSMan -ComputerName $FQDN -ErrorAction Stop) {
          Write-Verbose "Test-WSMan successfull"
        } else {
          throw "Can not access $FQDN by WinRM"
        }
      } else {
        throw "Could not ping $FQDN, can not try to validate or install SNMP"
      }
    } catch {
      Write-Warning "Can not access $RemoteHost. $($error[0].Exception.Message)"
      $global:SNMPOffline += $RemoteHost
      return $false
    }
    return $True
  }
}
process {
  foreach ($server in $Name) {
    Write-Verbose "Test $server"
    if ((test-online -RemoteHost $server)) {
      if ($PSCmdlet.ShouldProcess(
          $server,
          "Initiate install SNMP")) {
        $CommandSplatt = @{
          ComputerName = $server
          ScriptBlock  = { Add-WindowsFeature snmp-service -Restart:$false -WhatIf; Start-Sleep -Seconds 5 }
        }
        if ($PSBoundParameters.ContainsKey("Credential")) {
          $CommandSplatt.Add("Cred", $Credential)
        }
        $StartedJobs = Invoke-Command @CommandSplatt -JobName $JobName
      }
    }
  }
}
end {
  if ($StartedJobs) {
    $Counter = 1
    $Jobs = Get-Job -Name $JobName
    do {
      Write-Verbose "Wating for job to finish $Counter/$TimeOut"
      Start-Sleep -Seconds 1
      $Counter++
      $WaitingJob = ($Jobs | Where-Object State -EQ 'Running' | Select-Object -ExpandProperty Location) -join ', '
      Write-Progress -PercentComplete ($Counter / $TimeOut * 100) -Activity "Waiting for SNMP to install" -Status "In progress: $WaitingJob"
    } while (($Jobs.state -contains 'Running') -or $Counter -ge $TimeOut)
    $Result = Receive-Job $JobName
    $SNMPError = $Result | Where-Object State -EQ 'Failed'
    if ($SNMPError) {
      Write-Error $SNMPError
    }
    Remove-Job -Name $JobName -Confirm:$false
    Write-Output $Result
  } else {
    Write-Warning "No remote systems available"
  }
}