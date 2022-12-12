<#
.SYNOPSIS
    Get number of user accounts in different OU's from a Base OU
.DESCRIPTION
    Specific PRTG sensor for customer needing statistics on number of users in different OU's and also that those users have LDAP attributes manager and employeeid filled
.NOTES
    2022-12-09 Version 1 Klas.Pihl@Atea.se
.LINK
    https://github.com/klaspihl/PRTG
.EXAMPLE
    .\get-UsersOU.ps1 -Depth 1 -CanonicalName pihl.local/graveyard
        Get all users and create one channel per OU in OU tree.

.PARAMETER CanonicalName
    Base OU CanonicalName

.PARAMETER Depth
    How channels should be created from OU structure. A depth of 0 only returns the one channel with the base OU name.

    Depth of 100 returns on channel per OU that contains user objects.

#>

[CmdletBinding()]
param (
    [string]$CanonicalName,
    [int]$Depth=1
)
function get-ADUsersOU {
    param (
        $CanonicalName,
        $Depth,
        [ValidateSet('Subtree','Onelevel')]
        $SearchScope = 'Subtree'
    )

    function ConvertFrom-CanonicalOU {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
            [ValidateNotNullOrEmpty()]
            [string]$CanonicalName
        )
        process {
            [array]$obj = $CanonicalName.Split('/') | Where-Object {-not [string]::IsNullOrEmpty($PSItem)}
            if($obj.count -gt 1) {
                [string]$DN = 'OU=' + $obj[$obj.count - 1]
                for ($i = $obj.count - 2; $i -ge 1; $i--) { $DN += ',OU=' + $obj[$i] }
            } else {
                $DN= $null
            }
            $obj[0].split('.') | ForEach-Object {
                $DN += ',DC=' + $PSItem
            }
            return $DN.TrimStart(',')
        }
    }
    $SearchBase = "LDAP://{0}" -f (ConvertFrom-CanonicalOU $CanonicalName)
    if(-not [ADSI]::Exists($SearchBase)) {
        throw "'$CanonicalName' is not valid as a SearchScoop root"
    } else {
        #$SearchCN = ConvertFrom-DN -DN $SearchBase

        $Searcher = New-Object DirectoryServices.DirectorySearcher
        $Searcher.Filter = '(objectCategory=person)'
        $Searcher.SearchScope=$SearchScope
        $Searcher.SearchRoot = $SearchBase
        $Searcher.PropertiesToLoad.Add('canonicalName') | Out-Null
        $Searcher.PropertiesToLoad.Add('employeeid') | Out-Null
        $Searcher.PropertiesToLoad.Add('manager') | Out-Null
        $Allusers = $Searcher.FindAll()

        #region create object of each user with depth and if employeeid is given
        foreach ($User in $Allusers) {
            $LeafCN=$user.properties.canonicalname.replace($CanonicalName,'').TrimStart('/')
            $OUDepth=$LeafCN.split('/').count -1
            if(($OUDepth -eq 0) -or ($Depth -eq 0)) {
                $channelName=$CanonicalName.split('/') | Select-Object -Last 1
            } elseif($OUDepth -gt $Depth ) {
                $channelName=$LeafCN.split('/') | Select-Object -First $Depth | Select-Object -Last 1
            } else {
                $channelName=$LeafCN.split('/') | Select-Object -Last 2 | Select-Object -First 1
            }

            [PSCustomObject]@{
                Depth = $OUDepth
                Manager = [bool]$User.Properties.manager
                employeeID = [string]$User.Properties.employeeid
                channel = $channelName
            }
        }


        #endregion create object of each user with depth and if employeeid is given

    }
}

try {
    if([string]::IsNullOrEmpty($CanonicalName)) {
        throw "Sensor parameter '-CanonicalName' must be included."
    }
    $ADObject = get-ADUsersOU -CanonicalName $CanonicalName.TrimEnd('/') -Depth $Depth -SearchScope 'Subtree'
    [array]$OUReport = [PSCustomObject]@{
        Name = 'EmptyManager'
        Count = $ADObject | Where-Object {-not $PSitem.Manager} | Measure-Object | Select-Object -ExpandProperty Count
    }

    $OUReport += [PSCustomObject]@{
        Name = 'EmptyEmployeeID'
        Count = $ADObject | Where-Object {-not $PSitem.employeeID} | Measure-Object | Select-Object -ExpandProperty Count
    }

    $OUReport += $ADObject | Group-Object channel | Select-Object Name,Count

    #region create output
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            result =
                $OUReport | ForEach-Object {
                    [PSCustomObject]@{
                        Channel = $PSitem.Name
                        Value = $PSitem.Count
                    }
                }
        }
    }
    #endregion create output

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