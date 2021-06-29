<#
.SYNOPSIS
    Search Active directory security groups (neasted/recursive) for users and return a list of unique users grouped by company
    Returns output in PRTG json format
.DESCRIPTION
    Returns error to PRTG if no users found or other error is found.
    Returns data with warning if a user does not have 'Company' attribute set.

    On large environments the 900 second limit in PRTG migt fail the sensor. Then create a Create Windows scheduled task that run
        powershell.exe with argument: -command "& 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\get-PRTGRDSusers.ps1' > 'C:\ProgramData\Paessler\PRTG Network Monitor\Logs\rdscal.json'"
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
    2021-06-29 Version 1.2
        - Format Json output on Powershell 5
        - Remove international chars from Company name. /Klas.Pihl@Atea.se
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,Position=0)]
    $GroupNameFilter = '00R-*-RDS',
    [Parameter(Mandatory=$false,Position=1)]
    $NotDefinedCompanyMessage = 'not defined'
)
#Requires -Modules ActiveDirectory

function convertfrom-InternationalChars {
    <#
    .SYNOPSIS
        Removes special international chars from name/string
    .DESCRIPTION
        From Ascii 8-bit definition at https://www.ascii-code.com/ all international chars is replaced with a..z, if not found in translation char is removed
    .EXAMPLE
        PS C:\>  convertfrom-InternationalChars -Name "Åke Öster"
        returns: Ake Oster
    .PARAMETER Name
        String to be converted from international chars

    .NOTES
        2018-12-xx Version 1
        2021-01-15 Version 2
            Added more chars to be converted and removal of unknown chars. /Klas.Pihl@Atea.se
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Name,
        [regex]$ValidChars='[^a-zA-Z0-9/ ]'

    )
[string]$CleanedName = -join  ($Name.ToCharArray() | ForEach-Object { [int][char]$PSItem } | ForEach-Object {
        #Write-host -ForegroundColor Green $_
        switch([int]$PSItem){
            192 { "A" } #Latin capital letter A with grave À
            193 { "A" } #Latin capital letter A with acute Á
            194 { "A" } #Latin capital letter A with circumflex Â
            195 { "A" } #Latin capital letter A with tilde Ã
            196 { "A" } #Latin capital letter A with diaeresis Ä
            197 { "A" } #Latin capital letter A with ring above Å
            198 { "AE" } #Latin capital letter AE Æ
            199 { "C" } #Latin capital letter C with cedilla Ç
            200 { "E" } #Latin capital letter E with grave È
            201 { "E" } #Latin capital letter E with acute É
            202 { "E" } #Latin capital letter E with circumflex Ê
            203 { "E" } #Latin capital letter E with diaeresis Ë
            204 { "I" } #Latin capital letter I with grave Ì
            205 { "I" } #Latin capital letter I with acute Í
            206 { "I" } #Latin capital letter I with circumflex Î
            207 { "I" } #Latin capital letter I with diaeresis Ï
            208 { "D" } #Latin capital letter ETH Ð
            209 { "N" } #Latin capital letter N with tilde Ñ
            210 { "O" } #Latin capital letter O with grave Ò
            211 { "O" } #Latin capital letter O with acute Ó
            212 { "O" } #Latin capital letter O with circumflex Ô
            213 { "O" } #Latin capital letter O with tilde Õ
            214 { "O" } #Latin capital letter O with diaeresis Ö
            216 { "O" } #Latin capital letter O with slash Ø
            217 { "U" } #Latin capital letter U with grave Ù
            218 { "U" } #Latin capital letter U with acute Ú
            219 { "U" } #Latin capital letter U with circumflex Û
            220 { "U" } #Latin capital letter U with diaeresis Ü
            221 { "Y" } #Latin capital letter Y with acute Ý
            223 { "s" } #Latin small letter sharp s - ess-zed ß
            224 { "a" } #Latin small letter a with grave à
            225 { "a" } #Latin small letter a with acute á
            226 { "a" } #Latin small letter a with circumflex â
            227 { "a" } #Latin small letter a with tilde ã
            228 { "a" } #Latin small letter a with diaeresis ä
            229 { "a" } #Latin small letter a with ring above å
            230 { "ae" } #Latin small letter ae æ
            231 { "c" } #Latin small letter c with cedilla ç
            232 { "e" } #Latin small letter e with grave è
            233 { "e" } #Latin small letter e with acute é
            234 { "e" } #Latin small letter e with circumflex ê
            235 { "e" } #Latin small letter e with diaeresis ë
            236 { "i" } #Latin small letter i with grave ì
            237 { "i" } #Latin small letter i with acute í
            238 { "i" } #Latin small letter i with circumflex î
            239 { "i" } #Latin small letter i with diaeresis ï
            241 { "n" } #Latin small letter n with tilde ñ
            242 { "o" } #Latin small letter o with grave ò
            243 { "o" } #Latin small letter o with acute ó
            244 { "o" } #Latin small letter o with circumflex ô
            245 { "o" } #Latin small letter o with tilde õ
            246 { "o" } #Latin small letter o with diaeresis ö
            248 { "o" } #Latin small letter o with slash ø
            249 { "u" } #Latin small letter u with grave ù
            250 { "u" } #Latin small letter u with acute ú
            251 { "u" } #Latin small letter u with circumflex û
            252 { "u" } #Latin small letter u with diaeresis ü
            253 { "y" } #Latin small letter y with acute ý
            254 { "p" } #Latin small letter thorn þ
            255 { "y" } #Latin small letter y with diaeresis ÿ

            default { [char]$PSITEM }    # no change
        }
    })
Write-Output ($CleanedName -Replace($ValidChars,''))
}
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
        Write-Verbose ("Searching for users and groups in $($Farm.Name)")
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
                        channel = convertfrom-InternationalChars $CompanyID.Company
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
} | ConvertTo-Json -Depth 5 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($PSItem) }


} Catch {
    $Output = [PSCustomObject]@{
        prtg = [PSCustomObject]@{
            error = 1
            text = $error[0].Exception.Message
        }
    } | ConvertTo-Json | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($PSItem) }
}
} | Select-Object -ExpandProperty TotalSeconds) seconds"
Write-Output $Output