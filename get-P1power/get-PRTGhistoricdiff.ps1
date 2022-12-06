<#
.SYNOPSIS
    Get differense from sensor since last n minutes
.DESCRIPTION
    If historic data is less then argument minutes an correcting scale is calculated.
    Historic data API can not select datachannel so only a sensor with one channel should be used. If sensor is multichannel create a 'sensor factory'
    sensor with only desired channel.
.NOTES
    2022-12-06 Version 1 Klas.Pihl@gmail.com
        Used to get the daily power consumption from API historicdata.
        No error handling

.EXAMPLE
    .\get-PRTGhistoricdiff.ps1 -User %windowsuser -Password %windowspassword -SensorID %sensorid -BaseURL https://prtg.pihl.local
#>



[CmdletBinding()]
param (
    $BaseURL='https://prtg.pihl.local',
    $SensorID=9950,
    $Minutes=1440,
    $User,
    $Password
)
$EndDate = Get-Date -format "yyyy-MM-dd-HH-mm-ss"
$StartDate ='{0:yyyy-MM-dd-HH-mm-ss}' -f ((get-date).AddMinutes(-$Minutes))

$url = '{0}/api/historicdata.json?id={1}&avg=0&sdate={2}&edate={3}&username={4}&password={5}' -f $BaseURL,$SensorID,$StartDate,$EndDate,$User,$Password
$data = Invoke-WebRequest $url -UseBasicParsing
$result = $data.Content | ConvertFrom-Json | Select-Object -ExpandProperty histdata | Where-Object coverage_raw -gt 0
$ResultValue = $result[-1].value_raw-$result[0].value_raw

[datetime]$TimeAdjustStart = $result[0].datetime
[datetime]$TimeAdjustEnd = $result[-1].datetime
$TimeDiff = $TimeAdjustEnd - $TimeAdjustStart
if($TimeDiff.TotalMinutes -lt $Minutes) {
    Write-Verbose "Date is from smaller interval then scope, adjusting"
    $Factor = $Minutes / $TimeDiff.TotalMinutes
    $ResultValue = $ResultValue* $Factor
}

Write-Output ("{0}:{0}" -f (([string]([math]::Round($ResultValue,1))).Replace(',',',')))

