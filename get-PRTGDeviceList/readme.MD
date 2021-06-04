# Script to generate an object of devices and groups

## Example
```powershell
.\get-PRTGDeviceList.ps1 -PRTGCore https://monitor.pihl.local -UserName PersonalUser | ConvertTo-Html -Title Devicelista | Out-File -Path  c:\temp\PRTGDevces.html ; Invoke-Item c:\temp\PRTGDevces.html
```

## Script help get-help .\get-PRTGDeviceList.ps1
```powershell

SYNOPSIS
    Get object of devies and groups from PRTG server


    -------------------------- EXAMPLE 1 --------------------------

    PS C:\>get-PRTGDeviceList -PRTGCore https://monitor.pihl.local -UserName PersonalUser
        PowerShell credential request
        User and password to PRTG web GUI
        Password for user PersonalUser: **********

    PS C:\> get-PRTGDeviceList -PRTGCore https://monitor.pihl.local
        cmdlet get-PRTGDeviceList.ps1 at command pipeline position 1
        Supply values for the following parameters:
        UserName: prtgadmin
        PowerShell credential request
        User and password to PRTG web GUI
        Password for user prtgadmin: **********


-PRTGCore <Uri>
    PRTG core server URL
        Example; https://monitor.pihl.local:8080

    Required?                    true
    Position?                    1
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false


-UserName <String>
    Username on PRTG server

    Required?                    true
    Position?                    2
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false


-UserHash <String>
    Passhash of user, if omitted user can enter credentials
    User can get passhash from "https://$PRTGHost/api/getpasshash.htm?username=myuser&password=mypassword"

    Required?                    false
    Position?                    3
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false



    ```
