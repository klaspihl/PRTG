<#
.SYNOPSIS
    Search Active directory security groups (neasted/recursive) for users and return a list of unique users grouped by company
    Returns output in PRTG json format
.DESCRIPTION
    Returns error to PRTG if no users found or other error is found.
    Returns data with warning if a user does not have C'Cpompany' attribute set.
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
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,Position=0)]
    $GroupNameFilter = '00R-*-RDS',
    [Parameter(Mandatory=$false,Position=1)]
    $NotDefinedCompanyMessage = 'not defined'
)
#Requires -Modules ActiveDirectory

$ErrorActionPreference = "Stop"
Try {

    Write-Verbose "Searching for all groups of filter $GroupNameFilter"
    $AllRDSFarmSG = Get-ADGroup -Filter {Name -like  $GroupNameFilter}
    [array]$AllUsers += foreach ($Farm in $AllRDSFarmSG) {
        Write-Verbose "Searching for users and groups in $($Farm.Name)"
        $Farm  | Get-ADGroupMember -Recursive
    }
    $AllusersSamaccountname = $AllUsers | Select-Object -Unique -ExpandProperty SamAccountName
    if(-not $AllusersSamaccountname ) {
        Write-Error -message "No Active Directory users accounts found in group(s) with filter $GroupNameFilter"
    }
    $GroupedCompany = $AllusersSamaccountname | Get-ADUser -Properties Company | Group-Object Company

    $Result = foreach ($Company in $GroupedCompany) {
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
    $Total = [PSCustomObject]@{
        Company = 'Total'
        Users = $GroupedCompany | Select-Object -Property Count | Measure-Object -Sum count | Select-Object -ExpandProperty Sum
    }
    Write-Verbose "Adding total sum of users to result as 'Total'"
    $Result += $Total

    [PSCustomObject]@{
        prtg =  [PSCustomObject]@{
            result = foreach ($CompanyID in $Result) {
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
    [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            error = 1
            text = $error[0].Exception.Message
        }
    } | ConvertTo-Json
}
