<#
.SYNOPSIS
    Add domain user as permitted DCOM and WMI control user
.DESCRIPTION
    Used for monitoring tools like PRTG over WMI without the need for the user to be local admin on the target system. 
    Run on target system.
.NOTES
    2023-09-31 Version 2 Klas.Pihl@Atea.se
        No validation user already is fully or partially configured for access on local system. Run once
        Demands local security groups have default names.
.EXAMPLE
    . add-WMIuser.ps1 -verbose -UserName pihl\sa_prtgmonitor
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [parameter(Mandatory=$true,HelpMessage="Username")]
    $UserName,
    [parameter(DontShow)]
    $UserGroups = @('Distributed COM Users','Performance Monitor Users')
)
#Requires -RunAsAdministrator

try {

#region add user to local security groups
    $userGroups | ForEach-Object { 
        net localgroup $PSItem $UserName /add | Out-Null
        if($LASTEXITCODE -ne 0 ) {
            throw "The specified account name is already a member of the group"
        }
        Write-Verbose "Added user $UserName to local security group $PSItem"
    }
#endregion add user to local security groups

#region create SecurityIdentifier
    #get user object SID
    $ID = new-object System.Security.Principal.NTAccount($UserName)
    $SID =  $ID.Translate( [System.Security.Principal.SecurityIdentifier] ).toString()


    #security WMI control
    $SDDL = "A;;CCDCWP;;;$SID"
    #security DCOM
    $DCOMSDDL = "A;;CCDCLCRP;;;$SID"

    #Local system name and name space
    $ComputerName = [environment]::MachineName 
    $Reg = [WMIClass]"\\$ComputerName\root\default:StdRegProv"

    #Current  #HKEY_LOCAL_MACHINE (2147483650)
    $security = Get-WmiObject -ComputerName $ComputerName -Namespace root/cimv2 -Class __SystemSecurity
    $DCOM = $Reg.GetBinaryValue(2147483650,"software\microsoft\ole","MachineLaunchRestriction").uValue

    #Format new WMI SDDL
    $converter = new-object system.management.ManagementClass Win32_SecurityDescriptorHelper
    $binarySD = @($null)
    $result = $security.PsBase.InvokeMethod("GetSD",$binarySD)
    $outsddl = $converter.BinarySDToSDDL($binarySD[0])
    $newSDDL = $outsddl.SDDL += "(" + $SDDL + ")"
    $WMIbinarySD = $converter.SDDLToBinarySD($newSDDL)
    $WMIconvertedPermissions = ,$WMIbinarySD.BinarySD

    #Format DCOM SDDL
    $outDCOMSDDL = $converter.BinarySDToSDDL($DCOM)
    $newDCOMSDDL = $outDCOMSDDL.SDDL += "(" + $DCOMSDDL + ")"
    $DCOMbinarySD = $converter.SDDLToBinarySD($newDCOMSDDL)
    $DCOMconvertedPermissions = ,$DCOMbinarySD.BinarySD
#endregion create SecurityIdentifier

#region set security WMI
    #Add user WMI control
    $result = $security.PsBase.InvokeMethod("SetSD",$WMIconvertedPermissions)
    Write-Verbose "Add user $Username to WMI control security"
#endregion set security WMI

#region add DCOM security   
    $result = $Reg.SetBinaryValue(2147483650,"software\microsoft\ole","MachineLaunchRestriction", $DCOMbinarySD.binarySD)
    if($result.ReturnValue -ne 0) {
        throw "Failed adding user to DCOm security"
    }
    Write-Verbose "Added user $Username to DCOM security"
#endregion add DCOM security

Write-Host "Succesfully added $UserName for WMI monitoring on $ComputerName"
} catch {
    Write-Debug $error[0].Exception
    Write-Error "Error adding $UserName permitted user for WMI monitoring"
    
}
