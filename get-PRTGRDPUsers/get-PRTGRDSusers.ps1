<#
.SYNOPSIS
    Search Active directory security groups (neasted/recursive) for users and return a list of unique users grouped by company
    Returns output in PRTG json format
.DESCRIPTION
    Returns error to PRTG if no users found or other error is found.
    Returns data with warning if a user does not have 'Company' attribute set.
.EXAMPLE
    PS C:\> .\get-PRTGRDSusers.ps1 -Verbose
        Output json formatted file
        {
        "prtg": {
            "result": [
            {
                "channel": "not defined",
                "value": 2,
                "warning": 1
            },
            {
                "channel": "bolag 60",
                "value": 1,
                "warning": 1
            },
            {
                "channel": "bolag 74",
                "value": 1,
                "warning": 1
            },
            {
                "channel": "Total",
                "value": 4.0,
                "warning": 1
            }
            ],
            "text": "User1 User4 dont have property company defined in AD"
        }
        }
.INPUTS
    Active directory domain of PRTG probe

.PARAMETER GroupNameFilter
    Filter wildcard comparison.

.PARAMETER NotDefinedCompanyMessage
    Name to return on company if not found on user object.

.OUTPUTS
    PRTG JSON format
    https://manuals.paessler.com/custom_sensors.htm#advanced_sensors
.NOTES
    2021-06-08 Verson 1 Klas.Pihl@Atea.se
        Developed as customer soulution
    2021-06-23 Version 1.1
        Performance tweeks to;
        - filter unique users
        - find ADuser object
        Verbose logging and progress    /Klas.Pihl@Atea.se
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,Position=0)]
    $GroupNameFilter = '00R-*-RDS',
    [Parameter(Mandatory=$false,Position=1)]
    $NotDefinedCompanyMessage = 'not defined'
)
#Requires -Modules ActiveDirectory
$ProgressPreference = $VerbosePreference
$ErrorActionPreference = "Stop"
Write-Verbose "Total runtime: $(Measure-Command {
Try {

    Write-Verbose "Searching for all groups of filter $GroupNameFilter"
    $AllRDSFarmSG =( Get-ADGroup -Filter {Name -like  $GroupNameFilter})
    $i=0
    [array]$AllUsers += foreach ($Farm in $AllRDSFarmSG) {
        $i++
        Write-Progress -activity "Get all users in security group $($Farm.Name)" -PercentComplete (100*$i/$($AllRDSFarmSG.count)) -SecondsRemaining -1 -status ("{0}/{1}" -f $i,$AllRDSFarmSG.count)
        Write-Verbose "Searching for users and groups in $($Farm.Name)"
        $Farm  | Get-ADGroupMember -Recursive | Where-Object objectClass -eq 'user'
    }
    Write-Verbose "Sort #$($AllUsers.count) user accounts for duplicates found in #$($AllRDSFarmSG.count) security groups"
    $AllusersSID = $AllUsers | Select-Object -ExpandProperty SID | Select-Object -ExpandProperty Value -Unique
    Write-Verbose "Found #$($AllusersSID.count) unique users"

    if(-not $AllusersSID ) {
        Write-Error -message "No Active Directory users accounts found in group(s) with filter $GroupNameFilter"
    }

    $i=0
    $AllDomains = Get-ADForest | Select-Object -ExpandProperty domains
    $AllforestADUsers = ($AllDomains | ForEach-Object {
        $i++
        Write-Progress -activity "Get all users in forest $PSItem" -PercentComplete (100*$i/$($AllDomains.count)) -SecondsRemaining -1 -status ("{0}/{1}" -f $i,$AllDomains.count)
        Get-ADUser -filter * -Server $PSitem -properties Company | Select-Object Company,sAMAccountName,sid
    })
    Write-Verbose "Found total of #$($AllforestADUsers.count) users in entire AD forest"


    #Need to get user attribute 'company' that is not returned from Get-ADGroupMember. Use list of user from whole AD forest in $AllforestADUsers
    $i=0
    $ADuserWithAttribute = foreach ($User in $AllusersSID[0..200]) {
        $i++
        Write-Progress -activity "Map user SID $User with User ADobject " -PercentComplete (100*$i/$($AllusersSID.count)) -SecondsRemaining -1 -status ("{0}/{1}" -f $i,$AllusersSID.count)
        $AllforestADUsers | where-object {$PSItem.SID.value -eq $User} | Select-Object Company,SamAccountName
    }
    Write-Verbose "Group users on 'Company' attribute"
    $GroupedCompany =  $ADuserWithAttribute | Group-Object Company
    #$AllusersADobject | Get-ADUser -Properties Company  | Select-Object Company,SamAccountName | Group-Object Company

    #$GroupedCompany = $AllusersADobject | Get-ADUser -Properties Company  | Select-Object Company,SamAccountName | Group-Object Company

    [array]$Result = foreach ($Company in $GroupedCompany) {
        if(-not $Company.Name) {
            Write-Warning -Message "$($Company.Group.SamAccountName) dont have property company defined in AD" -WarningVariable WarningMessage
        }
        [PSCustomObject]@{
            Company = switch ($Company.Name) {
                {-not $PSItem} { $NotDefinedCompanyMessage }
                Default {$PSItem}
            }
            Users = $Company.Count
        }
    }
    [array]$Total = [PSCustomObject]@{
        Company = 'Total'
        Users = $GroupedCompany | Select-Object -Property Count | Measure-Object -Sum count | Select-Object -ExpandProperty Sum
    }
    Write-Verbose "Adding total sum of users to result as 'Total'"
    $Total += $Result

    $Output = [PSCustomObject]@{
        prtg =  [PSCustomObject]@{
            result = foreach ($CompanyID in $Total) {
                [PSCustomObject]@{
                        channel = $CompanyID.Company
                        value = $CompanyID.Users
                        warning = switch ($WarningMessage) {
                            {$PSItem} {1}
                            Default {0}
                        }
                }
            }
            text = switch ($WarningMessage) {
                {$PSItem} {$WarningMessage.Message}
                Default {"OK"}
            }

    }
} | ConvertTo-Json -Depth 5


} Catch {
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            error = 1
            text = $error[0].Exception.Message
        }
    } | ConvertTo-Json
}
} | Select-Object -ExpandProperty TotalSeconds) seconds"
Write-Output $Output