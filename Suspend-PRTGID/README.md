# Suspend PRTG object

Object might be a group, sensor or device. 

Used for scheduled system restarts like Windows update or nightly maintenence work

## Function
* Pause indefinitely
* Pause for n minutes, resumes automaticly
* Resume

## API Key
[PRTG manual](https://www.paessler.com/manuals/prtg/api_keys)

Suggestion is to create a specific user account for automatic jobs like scheduled pause etc.

## PARAMETERS
```powershell
    -APIkey <String>
        PRTG User API key
        If a valid path is entered file content is loaded as API Key
        
        Required?                    false
        Position?                    named
        Default value                .\apikey.sec
        Accept pipeline input?       false
        Accept wildcard characters?  false
        
    -ID <Int32>
        PRTG Object ID
        
        Required?                    false
        Position?                    named
        Default value                0
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -PRTGServer <String>
        URL including HTTPs:// to PRTG core server

        Required?                    false
        Position?                    named
        Default value                https://prtg.pihl.local
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -PauseFor <Int32>
        Automaticly pauses PRTG object for n minutes then resumes

        Required?                    false
        Position?                    named
        Default value                0
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Resume [<SwitchParameter>]
        Manually resumes PRTG object

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Pause [<SwitchParameter>]
        Manually pause PRTG object

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Comment <String>
        Comment to pause

        Required?                    false
        Position?                    named
        Default value                "Automatic pause by $($MyInvocation.MyCommand.Name)"
        Accept pipeline input?       false
        Accept wildcard characters?  false
```

## Example 1
```powershell
.\suspend-PRTGID.ps1 -ID 1234 -APIkey .\apikey.sec -PauseFor 15
```

## Example 2
```powershell
.\suspend-PRTGID.ps1 -ID 1234 -APIkey "5j3l2n...5l3n==#kdkw" -Resume
```