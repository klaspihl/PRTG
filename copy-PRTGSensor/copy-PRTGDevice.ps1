<#
.SYNOPSIS
    Clone a Device, input CSV.
.DESCRIPTION
    Uses PRTG API to clone devices.
    Create a teamplate Device and record ID or name
    Create an template Group and record ID
.EXAMPLE
    PS C:\>.\copy-PRTGDevice.ps1 -PRTGHost 'https://prtg.westeurope.cloudapp.azure.com/' -UserName apiadmin -Passhash 0123456789  -SourceDeviceID 1234 -TargetListCSV '.\DeviceListcsv' -BaseGroupID 8888 -Verbose
    
.PARAMETER PRTGHost
    URL to PRTG core server
.PARAMETER UserName
    Username of account to use for API calls
.PARAMETER Passhash
    Passhash for account to use for API calls
.PARAMETER SourceDeviceID
    Device ID as source
.PARAMETER TargetListCSV
    CSV list formatted by DeviceName, IP/DNS, Tag, Group

.OUTPUTS
    Object of all cloned Device
.NOTES
   2020-01-15 Version 1 Klas.Pihl@Atea.se
    Limit of 2500 devices.
#>
param (
    [CmdletBinding()]
    [Parameter(Mandatory=$true,HelpMessage="URL to PRTG core server, example https://yourserver.com")]
    [uri]$PRTGHost,
    [Parameter(Mandatory=$true,HelpMessage="PRTG username")]
    [string]$UserName,
    [Parameter(Mandatory=$true,HelpMessage="https://yourserver.com/api/getpasshash.htm?username=myuser&password=mypassword")]
    [int]$Passhash,
    [Parameter(Mandatory=$false,HelpMessage="The sensor ID to clone")]
    [int]$SourceDeviceID,
    [Parameter(Mandatory=$true,HelpMessage="Path to CSV with target devices",ValueFromPipeline)]
    [string]$TargetListCSV,
    [Parameter(Mandatory=$true,HelpMessage="Base group ID for placement")]
    [string]$BaseGroupID
)
#region Self signed certificates
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
Write-Verbose "Accepting self signed certificates"
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#endregion Self signed certificates
#region Functions
function get-PRTGAPIData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,HelpMessage="Base url to PRTG core server, like https://prtg01.pihl.local")]
        [uri]$PRTGHost,

        [Parameter(Mandatory=$true,HelpMessage="username=<user>%passhash=<[int]passhash>")]
        [string]$auth,

        [Parameter(Mandatory=$true)]
        [ValidateSet('GetAllDevices','DuplicateDevice','Resume','Pause','GetGroups')]
        [string]$APIFunction,
        
        [Parameter(Mandatory=$false,HelpMessage="Source device ID")]
        [int]$SourceID,
        
        [Parameter(Mandatory=$false,HelpMessage="FQDN or IP address")]
        [string]$HostAddress,
        
        [Parameter(Mandatory=$false,HelpMessage="Target group ID")]
        [int]$TargetGroupID,

        [Parameter(Mandatory=$false,HelpMessage="PRTG sensor new name")]
        [string]$NewName

    )
    
    try {
        $api = $APIkeys.$APIFunction -f $SourceID,$NewName,$HostAddress,$TargetGroupID
        
        Write-Verbose  "Api call  $api"
        [uri]$uri = $PRTGHost.ToString()+$api.ToString()+$auth.ToString()
        Write-Verbose "Complete URL: $uri"
        $request = Invoke-WebRequest -Uri $uri  -ErrorAction Stop #-MaximumRedirection 1
        if($request.StatusCode -ne 200) {
            Write-Verbose "Failed respons from uri"
            return $false
        }
        if($request.content -and $APIFunction -like "get*") {
            $PRTG_Result = convertFrom-csv -ErrorAction Stop  ($request.content) -WarningAction SilentlyContinue | Select-Object * -ExcludeProperty *raw*
            return $PRTG_Result
        }
    } catch [System.Net.WebException] {
        throw "Wrong URL, no respons from $PRTGHost`n$($_.Exception)"
        return $false
    } catch {
        throw "Could not get data from PRTG host $PRTGHost`n$($_.Exception)"
        return $false
    }
    return $true
}
function add-PRTGAPIData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,HelpMessage="Base url to PRTG core server, like https://prtg01.pihl.local")]
        [uri]$PRTGHost,

        [Parameter(Mandatory=$true,HelpMessage="username=<user>%passhash=<[int]passhash>")]
        [string]$auth,

        [Parameter(Mandatory=$true,HelpMessage="API key /api/function...")]
        [string]$API
    )
    
   
        [uri]$uri = $PRTGHost.ToString()+$api.ToString()+$auth.ToString()
        Write-Verbose "Complete URL: $uri"
        $request = Invoke-WebRequest -Uri $uri -MaximumRedirection 0 -ErrorAction Ignore #-MaximumRedirection 1
        $request | Export-Clixml -Force -Path 'output.xml'
        if($request.StatusCode -eq 302) {
            Write-Verbose "Sucessfully created object"
            return $(($request.RawContent | findstr 'Location').split('=')[1])
            
        }
        if($request.StatusCode -ne 200) {
            Write-Verbose "Failed respons from uri"
            return $false
        }
       
    
    return $true
}
function read-TargetListCSV {
    <#
    .SYNOPSIS
        Reads CSV file from path and returns object
    .DESCRIPTION
        Verify that talbe headers is correct
    .EXAMPLE
    .PARAMETER Path
        File path to CSV   
    .INPUTS
        CSV file path
    .OUTPUTS
        Object with imported CSV or $false
    .NOTES
        2020-01-15 Version 1 Klas.Pihl@Atea.se
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Path
    )
    $script:ErrorActionPreference='Stop'
    $Headers = @(
        'DeviceName', 
        'IP/DNS', 
        'Tag',
        'Group'
    )
    try {
        if(Test-Path -path $Path) {
            Write-Verbose "Importing data from $Path"
            $ImportedData = Import-Csv -Path $Path -ErrorAction Stop
            $ImportedHeaders = $ImportedData | Get-Member -Type NoteProperty | Select-Object -ExpandProperty Name
            Write-Verbose "Imported Headers: $ImportedHeaders"
            if([bool](Compare-Object $ImportedHeaders $Headers )) {
                    Write-Warning "Headers in imported CSV not identical with demand, colums should be; $( $Headers -join ', ' | Out-String)"    
                    return $false
            } else {
                return $ImportedData
            }
        } else {
            Write-Warning "$Path not vaild"
            return $false
        }
    } catch {
        Write-Warning "Can not import data from $path"
        return $false
    }
}
#endregion Functions
#region Main
    $Global:APIkeys = [PSCustomObject]@{
        GetAllDevices = 'api/table.xml?content=devices&output=csvtable&columns=objid,device,host&count=2500&id={0}'
        DuplicateDevice = 'api/duplicateobject.htm?id={0}&name={1}&host={2}&targetid={3}' #SourceDeviceID, NewName, host/IP, group
        DuplicateGroup = 'api/duplicateobject.htm?id={0}&name={1}&targetid={2}' #TargetGroupID, NewName, LocationGroupID
        Resume = 'api/pause.htm?id={0}&action=1'
        Pause = 'api/pause.htm?id={0}&action=0'
        GetGroups = 'api/table.xml?content=groups&output=csvtable&columns=objid,probe,group,name,downsens,partialdownsens,downacksens,upsens,warnsens,pausedsens,unusualsens,undefinedsens'
        AddTag = 'api/setobjectproperty.htm?id={0}&name=tags&value={1}' #TargetObject,(tags separated by ',')
    }
    $Auth = "&username={0}&passhash={1}" -f $UserName,$Passhash
    #hämtar device,host och ID
    if(-not $SourceDeviceID) {
        Write-Verbose "Quering PRTG core server of all devices"
        $SelectedDevice = get-PRTGAPIData -PRTGHost $PRTGHost -auth $Auth -APIFunction GetAllDevices  | Out-GridView -PassThru -Title "Select one device to clone" | Select-Object -First 1
        [int]$SourceDeviceID = $SelectedDevice | Select-Object -ExpandProperty id
    } else {
        $AllSDevices = get-PRTGAPIData -PRTGHost $PRTGHost -auth $Auth  -APIFunction GetAllDevices 
        $SelectedDevice = $SourceDeviceID | ForEach-Object {
            $AllSDevices | Where-Object ID -eq $_
        }
    }
    Write-Verbose "Selected device: $($SelectedDevice | Out-String)"
    
    $TargetDevices = read-TargetListCSV -path $TargetListCSV | Select-Object *,GroupID,DeviceID,TagResult
    $Groups = $TargetDevices | Group-Object Group | Select-Object Name,ID
    Write-Verbose "Verifying group exist and otherwise create group"
    $AllPRTGGroups = get-PRTGAPIData -PRTGHost $PRTGHost -auth $Auth -APIFunction GetGroups
    $BaseGroupIDName = $AllPRTGGroups | Where-Object ID -eq $BaseGroupID
    foreach ($Group in $Groups) {
        Write-Verbose "Find Group ID on $($Group.Name) else create Group under base group: $($BaseGroupIDName.Group), ID: $BaseGroupID"
            $Group.ID = $AllPRTGGroups | Where-Object Group -eq $Group.name | Select-Object -ExpandProperty ID
            if(-not $Group.ID) {
                Write-Verbose "No existing group with name $($Group.Name) found, creating..."
                $APISplat = @{
                    PRTGHost = $PRTGHost
                    Auth = $Auth
                    API = $($APIkeys.DuplicateGroup -f $BaseGroupID,$Group.Name,9016)
                }
                $Group.ID = add-PRTGAPIData @APISplat
                Start-Sleep -Seconds 3 #Data owerflow
            } else {
                Write-Verbose "Group already exists"
            }
    }
   
foreach ($TargetDevice in $TargetDevices) {
    Write-Verbose $TargetDevice
    Write-Verbose "Creating device $($TargetDevice.DeviceName)"
    $TargetDevice.GroupID = $Groups | Where-Object Name -eq $TargetDevice.Group | Select-Object -ExpandProperty ID
    $APISplat = @{
        PRTGHost = $PRTGHost
        Auth = $Auth
        API = $($APIkeys.DuplicateDevice -f $SourceDeviceID,$TargetDevice.DeviceName,$TargetDevice.'IP/DNS',$TargetDevice.GroupID)
    }
    $TargetDevice.DeviceID = add-PRTGAPIData @APISplat
    Write-Verbose "Add tag..."
    $APISplat = @{
        PRTGHost = $PRTGHost
        Auth = $Auth
        API = $($APIkeys.AddTag -f $TargetDevice.DeviceID,$TargetDevice.Tag)
    }
    $TargetDevice.TagResult = add-PRTGAPIData @APISplat
    Start-Sleep -Seconds 3 #Data owerflow
}
if($TargetDevices.GroupID -contains $false) {
    Write-Warning "Some groups could not be created"
}

if($TargetDevices.DeviceID -contains $false) {
    Write-Warning "Devices could not be cloned"
}

if($TargetDevices.TagResult -contains $false) {
    Write-Warning "Some Tags could not be set"
}
Write-Output $TargetDevices
#endregion Main