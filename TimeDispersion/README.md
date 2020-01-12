# Custom sensor to measure time diff between PRTG probe server and remote system

##Powershell SYNOPSIS
![PRTG sensor setting](get-PRTGTimeDispersion_PRTG_setting.png "PRTG sensor setting")

```Powershell
.SYNOPSIS
    PRTG sensor 'EXE/Script adnvanced' measuring Time Dispersion between minitored device and PRTG server
.DESCRIPTION
    Get local time of probe server and compares of target system (device)
.EXAMPLE
    PS C:\> get-PRTGTimeDispersion.ps1 -domain '%windowsdomain' -password '%windowspassword' -computer '%host' -Username '%windowsuser'
    Returns XML readable by PRTG
.INPUTS
    Device parameters; %host, %windowsDomain, %windowsUser, %windowsPassword
.OUTPUTS
    XML output of;
        Timedifference in seconds
.PARAMETER Computername
    Target system IP or Hostname from PRTG placeholder %host
.PARAMETER Username
    Target system credential username from PRTG placeholder %windowsUser
.PARAMETER Domain
    Target system credential Domain from PRTG placeholder %windowsDomain
.PARAMETER Password
    Target system credential Password from PRTG placeholder %windowsPassword
.NOTES
    2020-01-10 Version 1 Klas.Pihl@Atea.se
    ```
