<#
.SYNOPSIS
    Get Minimum and Maximum values from a sensor for a time window
.DESCRIPTION
    API can not get more then one channel so if sensor is multi channel create 'Sensor Factory' sensor with desired channel
.NOTES
    2022-12-14 Version 1 Klas.Pihl@gmail.com

.EXAMPLE
    .\get-PRTGMinMax.ps1 -User %windowsuser -Password %windowspassword -SensorID %sensorid -BaseURL https://prtg.pihl.local
#>



[CmdletBinding()]
param (
    $BaseURL='https://prtg.pihl.local',
    $SensorID=9941,
    $Minutes=720, #half day
    $User,
    $Password
)



#Main code
try {

    $EndDate = Get-Date -format "yyyy-MM-dd-HH-mm-ss"
    $StartDate ='{0:yyyy-MM-dd-HH-mm-ss}' -f ((get-date).AddMinutes(-$Minutes))

    $url = '{0}/api/historicdata.json?id={1}&avg=0&sdate={2}&edate={3}&username={4}&password={5}' -f $BaseURL,$SensorID,$StartDate,$EndDate,$User,$Password
    $data = Invoke-WebRequest $url -UseBasicParsing
    $result = $data.Content | ConvertFrom-Json | Select-Object -ExpandProperty histdata | Where-Object coverage_raw -gt 0
    $AllStats = $result.value_raw | Measure-Object -AllStats


    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =
            [PSCustomObject]@{
                Channel = 'Maximum'
                Float = 1
                Value = $AllStats.Maximum
                CustomUnit = 'C'
            },
            [PSCustomObject]@{
                Channel = 'Minimum'
                Float = 1
                Value = $AllStats.Minimum
                CustomUnit = 'C'
            },
            [PSCustomObject]@{
                Channel = 'Average'
                Float = 1
                Value = [math]::Round($AllStats.Average,1)
                CustomUnit = 'C'
            }
        }
    }

} Catch {
    $error
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            error = 1
            text = $error[0].Exception.Message
        }
    }
}
Write-Output ($Output | ConvertTo-Json -depth 5 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($PSItem) })