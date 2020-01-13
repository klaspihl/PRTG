# Temperature and humidity to PRTG by 443 MHz
A private project to get temperature and humidity readings to [PRTG](https://www.paessler.com/download/prtg-download).
## Needed;
-	Telldus (Duo) 
-	Temperature sensors, I used  cheep Telldus [termo and humidity sensors]( https://telldus.com/se/produkt/klimatsensorer-3-pack-telldus-433mhz/), 3 pack at ~400 SEK 
## Dependencys
1.	Install TelldusCenter
2.	Find out channel ID of the sensors.

## Screenshots
![Screen 1](/PRTG%20temperature%20443.png)
![Screen 2](/PRTG%20temperature%20443%20bathroom.png)

## Instructions
Install and start Tellduscenter to find out the channel ID of the sensor you want to read and import to PRTG.
A Powershell script start the x86 program to export all the sensors to a a string for each sensor. The script filters the output and returns the reading in a PRTG XML syntax. 

```powershell
Write-Output "<prtg>"
    Write-Output "<result>"
    Write-Output "<channel>Temperature</channel>"
    Write-Output "<showChart>1</showChart>"
    Write-Output "<showTable>1</showTable>"
    Write-Output "<value>$temperature</value>"
    Write-Output "</result>"
    Write-Output "<result>"
    Write-Output "<channel>Humidity</channel>"
    Write-Output "<showChart>1</showChart>"
    Write-Output "<showTable>1</showTable>"
    Write-Output "<value>$humidity</value>"
    Write-Output "</result>"
Write-Output "</prtg>"
```

You can chose to run the script directly from the PRTG probe server or as I do in this home environment a call the script localy on the machine that has the physical Telldus duo installed by ```powershell invoke-command```

## Error handling
NO :see_no_evil:
