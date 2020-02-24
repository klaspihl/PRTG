<#
.SYNOPSIS
    Set a location on a group or device from an CSV input file
.DESCRIPTION
    Uses PRTG API to set location.
    
.EXAMPLE
    PS C:\>
.PARAMETER PRTGHost
    URL to PRTG core server
.PARAMETER UserName
    Username of account to use for API calls
.PARAMETER Passhash
    Passhash for account to use for API calls
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
    [Parameter(Mandatory=$true,HelpMessage="Path to CSV with target devices",ValueFromPipeline)]
    [string]$TargetListCSV

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
<# PS7
Write-Verbose "Adding class for validset"
Class APINames : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        #$APINames = $APIkeys | Get-Member -Type NoteProperty | Select-Object -ExpandProperty Name
        $APINames = 'AddTag','DuplicateDevice','DuplicateGroup','GetAllDevices','GetGroups','Pause','ReSetLocation','Resume','SetLocation'
        return [String[]] $APINames
    }
}
#>
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
function invoke-PRTGAPIData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,HelpMessage="Base url to PRTG core server, like https://prtg01.pihl.local")]
        [uri]$PRTGHost,

        [Parameter(Mandatory=$true,HelpMessage="username=<user>%passhash=<[int]passhash>")]
        [string]$auth,

        [Parameter(Mandatory=$true,HelpMessage="API key /api/function...")]
        <#[ValidateSet('AddTag','DuplicateDevice','DuplicateGroup','GetAllDevices','GetGroups','Pause','ReSetLocation','Resume','SetLocation')] #($APIkeys | Get-Member -Type NoteProperty | Select-Object -ExpandProperty Name ) -join "','"
        #[ValidateSet([APINames])] #PS7
        [Validatescript({
			if (($APIkeys | Get-Member -Type NoteProperty | Select-Object -ExpandProperty Name) -contains $_) {$true}
			else { throw "Valid APIkeys; "+(($APIkeys | Get-Member -Type NoteProperty | Select-Object -ExpandProperty Name) -join ', ')}
            })]
            #>
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
        if($request.StatusCode -eq 200) {
            Write-Verbose "Successfull response"
            $PRTG_Result = convertFrom-csv -ErrorAction Stop  ($request.content) -WarningAction SilentlyContinue | Select-Object * -ExcludeProperty *raw*
            if($PRTG_Result) {
                return $PRTG_Result
            } else {
                return $true
            }
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
        GetAllDevices = 'api/table.xml?content=devices&output=csvtable&columns=objid,device,host,name&count=2500&id={0}'
        DuplicateDevice = 'api/duplicateobject.htm?id={0}&name={1}&host={2}&targetid={3}' #SourceDeviceID, NewName, host/IP, group
        DuplicateGroup = 'api/duplicateobject.htm?id={0}&name={1}&targetid={2}' #TargetGroupID, NewName, LocationGroupID
        Resume = 'api/pause.htm?id={0}&action=1'
        Pause = 'api/pause.htm?id={0}&action=0'
        AddTag = 'api/setobjectproperty.htm?id={0}&name=tags&value={1}' #TargetObject,(tags separated by ',')
        SetLocation = 'api/setlonlat.htm?id={0}&location={1}&lonlat={2}' #objectID, Location address, "longitude,latitude"
        ReSetLocation = 'api/setlonlat.htm?id={0}' #objectID, Location address
        GetGroups = 'api/table.xml?content=groups&output=csvtable&columns=objid,probe,group,name&id={0}' #down from groupID
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
    
    #2020-01-31 All objects
    $APISplat = @{
        PRTGHost = $PRTGHost
        Auth = $Auth
        API = $($APIkeys.GetGroups)
    }
    $AllGroups = invoke-PRTGAPIData @APISplat -Verbose
    $APISplat = @{
        PRTGHost = $PRTGHost
        Auth = $Auth
        API = $($APIkeys.GetAllDevices )
    }
    $AllDevices = invoke-PRTGAPIData @APISplat -Verbose
    
  $AllObjects = ($AllDevices | Select-Object ID,object) +( $AllGroups | Select-Object id,object)
    


#region tests
  #region test location
    $TargetDevice = 8926
    $LocationAddress = 'London'
    $LocationGPS = $null #'-14.92829,13.56812'
  $APISplat = @{
    PRTGHost = $PRTGHost
    Auth = $Auth
    API = $($APIkeys.SetLocation -f $TargetDevice,$LocationAddress,$LocationGPS)    #API = $($APIkeys.SetLocationNoGPS -f $TargetDevice,$LocationAddress,$LocationGPS)
}
invoke-PRTGAPIData @APISplat -Verbose
  #endregion test location
#region test groups
    $TargetGroupID=50
    $APISplat = @{
        PRTGHost = $PRTGHost
        Auth = $Auth
        #API = $($APIkeys.GetGroups -f $TargetGroupID)    #API = $($APIkeys.SetLocationNoGPS -f $TargetDevice,$LocationAddress,$LocationGPS)
        APIFunction = 'GetGroups'
        TargetGroupID = $TargetGroupID
    }
    get-PRTGAPIData @APISplat


    $TargetGroupID=50
    $APISplat = @{
        PRTGHost = $PRTGHost
        Auth = $Auth
        API = $($APIkeys.GetGroups -f $TargetGroupID)    #API = $($APIkeys.SetLocationNoGPS -f $TargetDevice,$LocationAddress,$LocationGPS)
        #APIFunction = 'GetGroups'
        #TargetGroupID = $TargetGroupID
    }
   invoke-PRTGAPIData @APISplat -Verbose
invoke-PRTGAPIData -API 
      #endregion test groups
#region test alldevices
$TargetGroupID=$null #8851
$APISplat = @{
    PRTGHost = $PRTGHost
    Auth = $Auth
    API = $($APIkeys.GetAllDevices -f $TargetGroupID)   
}
invoke-PRTGAPIData @APISplat -Verbose
 #endregion test alldevices
    #endregion tests

#endregion Main