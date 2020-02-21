# PRTG Cusom XML sensor - get-PRTGHLMCertificates.ps1
Get all certificates under LocalMachine on the Device the sensor is deployed to
## Needed;
-	[PRTG](https://www.paessler.com/download/prtg-download)
-	Windows Host with Powershell 5.1+
 
## Result
![Screen 1](get-PRTGHLMCertificates.png)


## Instructions
In sensor settings define parameter AlarmDaysToExpire (default value 14 days)
```
-AlarmDaysToExpire '14'
```
## Tested on
- PRTG version 20.1.55.1775
- Windows server 2016
- Windows server 2019

![Screen 2](get-PRTGHLMCertificates-settings.png)
## Error handling
YES! 


