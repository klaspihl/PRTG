
<#
.SYNOPSIS
    Get devices from group ID
.DESCRIPTION
    Uses API call devices.htm
.NOTES
    2022-11-11 Version 1 Klas.Pihl@Atea.se
.EXAMPLE
    .\get-PRTGevices.ps1 -CoreServer prtg.pihl.local -User admin -PassHash 123456789  -Verbose -SourceGroupID 50
.PARAMETER CoreServer
    PRTG core server FQDN

.PARAMETER SourceGroupID
    Source group ID

.PARAMETER User
    Username

.PARAMETER PassHash
    Request your passhash from; http://yourserver/api/getpasshash.htm?username=myuser&password=mypassword
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [ValidateScript({
        (Test-NetConnection -ComputerName $PSItem -Port 443 | Select-Object -ExpandProperty TcpTestSucceeded)
    })]
    [string]$CoreServer,
    [Parameter(ValueFromPipeline)]
    [int]$SourceGroupID,
    [parameter(Mandatory)]
    [string]$User,
    [parameter(Mandatory)]
    [int]$PassHash

)
process{
    try {
        $uri = ('https://{0}/api/table.json?content=devices&output=json&columns=objid,device,probe,group&id={1}&username={2}&passhash={3}' -f $CoreServer,$SourceGroupID,$User,$PassHash)
        Write-Verbose "API URL $uri"
        $result = Invoke-WebRequest -Uri $uri -Verbose

        switch ($result.StatusCode) {
            200 {
                write-host "Success" -ForegroundColor Green
                Write-Output $result.Content | ConvertFrom-Json | Select-Object -ExpandProperty Devices | Select-Object -ExcludeProperty *_raw
            }
            Default {}
        }
    } catch {
        Write-Error "Could not get devices in group ID $SourceGroupID. $($PSItem.Exception.Message)"
    }
}
end{}


