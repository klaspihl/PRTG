<#
.SYNOPSIS
    Get power reading from smart power meter using the HAN / H1 / P1 port
.DESCRIPTION
    Call from /var/prtg/scriptsxml/get-P1power.sh that just load the powershell script from bash. Uses PRTG 'SSH Script Advanced' sensor
.NOTES
    2022-12-04 Version 1 Klas.Pihl@Gmail.com
    .NET new-Object System.IO.Ports.SerialPort does not get data, use command 'cu' instead.
.LINK
    https://hanporten.se/
.EXAMPLE
cu -l /dev/ttyUSB0 -s 115200 -E% > pwr.log
#>
function get-P1data {
    param (
        $SerialPort = '/dev/ttyUSB0',
        $BaudRate=115200,
        $Parity=0, #'None'
        $StopBits=1, #'One'
        $DataBits =8 ,
        $ByteSize=8,
        $XonXoff=$false,
        $TimeOut = 120
    )
    $Templog = New-TemporaryFile | Select-Object -ExpandProperty FullName
    $Starttime = get-date
    do {

        $CUCommand = [Scriptblock]::Create(("cu -l {0} -s {1} -E% > {2}" -f $SerialPort,$BaudRate,$Templog))

        $JobGetData = Start-Job -ScriptBlock $CUCommand
        while($JobGetData.State -ne 'Completed') {
            Start-Sleep -Milliseconds 100
            Write-Verbose "Waiting to complete"
        }
        $JobGetData |  Remove-Job
        $ResultJob = Get-Content $Templog
        $CurrentTime = Get-Date
        if(($CurrentTime-$Starttime).totalseconds -ge $TimeOut) {
            throw "Timout, could not get a correct reading in $TimeOut seconds"
        }
    } while ($ResultJob.length -le 10) #data is written from power meeter every 10 seconds, sometime the data returned is not complete.
    Remove-Item -Path $Templog -Force

    #Date,0-0:1.0.0
    $Map =
    "metric,register,value,suffix
        Measure,1-0:1.8.0
        Effekt,1-0:1.7.0
        L1,1-0:21.7.0
        L2,1-0:41.7.0
        L3,1-0:61.7.0
        L1A,1-0:31.7.0
        L2A,1-0:51.7.0
        L3A,1-0:71.7.0
    " | ConvertFrom-Csv



    foreach ($Register in $Map) {
        $Match = $ResultJob | Where-Object {$PSitem -match $Register.register} | Select-Object -Last 1
        if($Match) {
            $Value,$Suffix = $Match.Replace($Register.register,'').Split('*').trim('(',')')
            $Register.value = $Value
            $Register.suffix = $Suffix
        }

    }
    Write-Output $Map
}

#Main code
try {
    $Measurements = get-P1data
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =
                $Measurements | ForEach-Object {
                    [PSCustomObject]@{
                        Channel = $PSitem.metric
                        Float = 1
                        Value = $PSitem.value
                        CustomUnit = $PSitem.suffix

                    }
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