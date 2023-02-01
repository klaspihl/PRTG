<#
.SYNOPSIS
    MS SQL query with multiple arguments.
.DESCRIPTION
    Customer specific sensor
    PRTG sensor 'Microsoft SQL v2 Sensor' can define one (1) imput parameter. 
    Uses module SqlServer
.NOTES
    2023-03-01 Version 1 Klas.Pihl@Atea.se
.LINK
    https://github.com/klaspihl/PRTG/
    https://stackoverflow.com/a/38981021

.PARAMETER ServerInstance
    SQL server instance, defaults device placeholders

.PARAMETER GroupID
    GroupID of batch job

.PARAMETER DATAAREAID
    DATAAREAID of batch job

.PARAMETER Age
    Age i minutes since started

.PARAMETER DatabaseName
    Name of database

.PARAMETER TableName
    Name of table

.EXAMPLE 
    get-PRTGSQLBatchJob.ps1 -GroupID 123 -DATAAREAID 789 -Age 60 -DatabaseName ERP1 -TableName Batch
        Uses PRTGs 'Set placeholders as environment values'

.EXAMPLE 
    get-PRTGSQLBatchJob.ps1 -ServerInstance SQLServer1 -GroupID 123 -DATAAREAID 789 -Age 60 -DatabaseName ERP1 -TableName Batch
        Run query on other sql-server then device.
#>
[CmdletBinding()]
param (
    [string]$ServerInstance=$env:prtg_host,
    [string]$GroupID,
    [string]$DATAAREAID,
    [int]$Age,
    [string]$DatabaseName,
    [string]$TableName

)
#############################################################################
#If Powershell is running the 32-bit version on a 64-bit machine, we 
#need to force powershell to run in 64-bit mode .
#############################################################################
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    if ($myInvocation.Line) {
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
    }else{
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
    }
exit $lastexitcode
}
#############################################################################

#Main code
try {
    import-module SqlServer -ErrorAction Stop
   
    $Query = "SELECT * FROM {0}.dbo.{1}
            WHERE Status = 1
            AND (GroupID = '{2}')
            AND DATEDIFF(mi,DATEADD(ss, StartTime, StartDate),GETDATE()) > {3}
            AND (EndDate = '1900-01-01' AND EndTime = 0)
            AND DATAAREAID = '{4}'" -f $DatabaseName,$TableName,$GroupID,$Age,$DATAAREAID

    $RunTime = Measure-Command  {$BatchJob = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $Query -ErrorAction Stop} 

    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =
                [PSCustomObject]@{
                    Channel = 'Jobs'
                    Float = 0
                    Value = $BatchJob.count
                    LimitMode = 1
                    LimitMaxError = "0.5"
                },
                [PSCustomObject]@{
                    Channel = "Execution time" 
                    Float = 0
                    Value = ([math]::round($RunTime.TotalMilliseconds))
                    CustomUnit = 'ms'
                    LimitMode = 1
                    LimitMaxError = 5000
                }
            text = ("{0} jobs in {1}.dbo.{2} older then {3} minutes" -f $BatchJob.count,$DatabaseName,$TableName,$Age)
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