
<#
.SYNOPSIS
    Move device to group
.DESCRIPTION
    Uses API call moveobject.htm
.NOTES
    2022-11-11 Version 1 Klas.Pihl@Atea.se
.EXAMPLE
    9558 | .\move-PRTGDevice.ps1 -CoreServer prtg.pihl.local -TargetGroupID 8851 -User admin -PassHash 12345678  -Verbose
.PARAMETER CoreServer
    PRTG core server FQDN

.PARAMETER SourceObjectID
    Device ID

.PARAMETER TargetGroupID
    Destination group ID

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
    [int]$SourceObjectID,
    [parameter(Mandatory)]
    [int]$TargetGroupID,
    [parameter(Mandatory)]
    [string]$User,
    [parameter(Mandatory)]
    [int]$PassHash

)
process{
    try {
        $uri = ('https://{0}/api/moveobject.htm?id={1}&targetid={2}&username={3}&passhash={4}' -f $CoreServer,$SourceObjectID,$TargetGroupID,$User,$PassHash)
        Write-Verbose "API URL $uri"
        $result = Invoke-WebRequest -Uri $uri -Verbose
        #Write-Output $result
        switch ($result.StatusCode) {
            200 { write-host "Success: Moved $SourceObjectID to group $TargetGroupID" -ForegroundColor Green}
            Default {}
        }
    } catch {
        Write-Error "Object $SourceObjectID was not able to move. $($PSItem.Exception.Message)"
    }
}
end{}


