<#
.SYNOPSIS
    Sync custom advanced sensors between core(default master) and probe servers.
    Mandatory argument is core/source servers FQDN
.DESCRIPTION
    Files in source and target directory is inventoried by an MD5 hash and if change is detected the file is synced.
.EXAMPLE
    PS C:\> . .\prtg_SyncSensors.ps1 -PRTGCore prtg-probe1.pihl.local -TargetPath D:\PRTG\Sensors\
        Sync new or changed files/sensors from probe1 server to local directory on D:
.PARAMETER PRTGCore
    PRTG core server or other repository
.PARAMETER SourcePath
    Local path to files to sync
.PARAMETER TargetPath
    Certificates with Thumbprints to ignored, separated by ';'
.OUTPUTS
    PRTG XML
.NOTES
    2021-01-26 Version 1 NOT TESTED Klas.Pihl@Atea.se


#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,Position=0)]
    [string]$PRTGCore,

    [Parameter(Mandatory=$false,Position=1)]
    [string]$SourcePath = 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML',

    [Parameter(Mandatory=$false,Position=1)]
    [string]$TargetPath = 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML'
)
function Format-PrtgXml([xml]$xml)
{
    $stringWriter = New-Object System.IO.StringWriter
    $xmlWriter = New-Object System.Xml.XmlTextWriter $stringWriter

    $xmlWriter.Formatting = "Indented"
    $xmlWriter.Indentation = 4

    $xml.WriteContentTo($xmlWriter)

    $xmlWriter.Flush()
    $stringWriter.Flush()

    $stringWriter.ToString()
}
function Export-PRTGXML {
    [CmdletBinding()]
    param (
        [Parameter()]
        $Channel,
        [string]$Value,
        [ValidateSet(
            'BytesBandwidth',
            'BytesMemory',
            'BytesDisk',
            'Temperature',
            'Percent',
            'TimeResponse',
            'TimeSeconds',
            'Custom',
            'Count',
            'CPU',
            'BytesFile',
            'SpeedDisk',
            'SpeedNet',
            'TimeHours',
            'Day' #Custom
            )]
        $unit
    )
    $Value = $Value.Replace(',','.')
    Write-Output '<result>'
    Write-Output ('<channel>{0}</channel>' -f $Channel)
    Write-Output ('<CustomUnit>{0}</CustomUnit>' -f $unit)
    Write-Output '<showChart>1</showChart>'
    Write-Output '<showTable>1</showTable>'
    #Write-Output '<float>1</float>'
    Write-Output ('<value>{0}</value>' -f $Value)
    Write-Output ('<LimitMinError>{0}</LimitMinError>' -f $AlarmDaysToExpire)
    Write-Output '<LimitMode>1</LimitMode>'
    Write-Output '</result>'
}
function Write-PRTGError {
    [CmdletBinding()]
    param (
    )
    <#
    .SYNOPSIS
        Write PRTG formatted XML output with error exception and exit script.
    .EXAMPLE
        PS C:\> Write-PRTGError
        write output in PRTG XML and exit script
    .INPUTS
        $global:Error
    .NOTES
       2020-02-24 Version 1 Klas.Pihl@Atea.se
    #>
    $XMLOutput =  '<prtg>'
    $XMLOutput +=  '<error>1</error>'
    $XMLOutput +=  '<text>'
    $XMLOutput +=  $error.Exception.Message
    $XMLOutput +=  '</text>'
    $XMLOutput +=  '</prtg>'
}
$Script:ErrorActionPreference = 'Stop'
try {

    if($SourcePath.Substring(1,1) -eq ':') {
        Write-Verbose "Sensor path source converted to UNC"
        $SourcePath =  $SourcePath.Replace($SourcePath.Substring(0,3),$("\\{0}\{1}`$\" -f $PRTGCore,$SourcePath.Substring(0,1)))
        Write-Verbose "SourcePath: $SourcePath"
    }
    Write-Verbose "Test SMB connection to server $PRTGCore"
    Test-NetConnection -ComputerName  $PRTGCore -CommonTCPPort SMB -ErrorAction Stop | Out-Null

    Write-Verbose "Get sourcefiles and targetfiles"
    $SourceFiles = Get-ChildItem -Path $SourcePath -File -ErrorAction Stop
    $TargetFiles = Get-ChildItem -Path $TargetPath -File -ErrorAction Stop

    Write-Verbose "Calculate checksum of files"
    $FileList =
        foreach ($SourceFile in $SourceFiles) {
            $TargetFile = $TargetFiles | Where-Object Name -eq $SourceFile.Name
            if($TargetFile) {
                $TargetHash = Get-FileHash -ErrorAction Stop -Path $TargetFile.FullName | Select-Object -ExpandProperty Hash
            } else {
                $TargetHash = $null
            }
            [PSCustomObject]@{
                SourceFile = $SourceFile
                TargetFile = $TargetFile
                SourceHash = Get-FileHash -ErrorAction Stop -Path $SourceFile.FullName | Select-Object -ExpandProperty Hash
                TargetHash = $TargetHash
            }
        }

    Write-Verbose "Select files new or changed"
    $NewData = $FileList | Where-Object {
        $PSItem.SourceHash -ne $PSItem.TargetHash
    }
    $OldData = $FileList | Where-Object {
        $PSItem.SourceHash -eq $PSItem.TargetHash
    }

    if($NewData) {
        Write-Verbose "Copying files that is new or changed;"
        $NewData | ForEach-Object {
            $Result = Copy-Item -Path $psitem.SourceFile.FullName -Destination $TargetPath -ErrorAction Stop -Recurse -PassThru
            Write-Verbose "$($Result.FullName) copied successfull"

        }
    } else {
        Write-Verbose "No changes in files found"
    }
    Write-Verbose "Creating XML formatted output"
    $XMLOutput = '<prtg>'
    if($OutputText) {
        $XMLOutput += '<text>'
        $XMLOutput += ($OutputText -join [Environment]::NewLine)
        $XMLOutput += '</text>'
    }

    $XMLOutput += export-PRTGXML -Channel "Sensors synced" -value $NewData.Count -unit Count
    $XMLOutput += export-PRTGXML -Channel "Sensors in sync" -value $OldData.Count -unit Count
    $XMLOutput += '</prtg>'
} catch {
    Write-Verbose "Debugging information if an error occurred"
    Write-PRTGError
}

Write-Verbose -Message "Write formatted result to PRTG"
Format-PrtgXml -xml $XMLOutput
