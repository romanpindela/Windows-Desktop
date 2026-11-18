<#
.SYNOPSIS
    Comprehensive inventory and interactive drill-down inspector for local, network, and cloud storage drives.

.DESCRIPTION
    Get-DriveInventory.ps1 correlates Windows storage, networking, and cloud sync subsystems into a unified,
    color-coded summary table and an interactive deep-inspection drill-down view.

    Supported storage tiers and sources:
      1. Local & Attached Storage (Get-Volume, Get-Partition, Get-Disk, Get-PhysicalDisk, Win32_Volume, Win32_LogicalDisk):
         - Internal fixed disks (NVMe, SATA, SAS, RAID, SCSI)
         - External USB drives & Removable Flash/SD media (distinguishing USB-attached Fixed disks from internal drives)
         - Optical drives (CD/DVD/ISO)
         - Virtual disks (VHD/VHDX, Storage Spaces, File Backed Virtual) and SUBST virtual drives
         - Optional unlettered system/EFI/Recovery volumes (-IncludeSystemVolumes)
      2. Network Shares (Get-SmbMapping, Win32_LogicalDisk, Win32_NetworkConnection, Get-SmbConnection):
         - Mapped network drives and unlettered/disconnected UNC mappings
         - Protocol & dialect classification: SMB (v2/v3), CIFS (SMB1), WebDAV, NFS
         - Encryption, signing, persistence, connection state, and remote UNC target
      3. Cloud Storage & Sync Mounts (Registry, Win32_Volume, JSON sync metadata):
         - Microsoft OneDrive Personal & OneDrive for Business
         - Microsoft SharePoint synced document libraries (ScopeIdToMountPointPathCache)
         - Google Drive for Desktop (virtual drive letter or folder streaming mount)
         - Dropbox (Personal & Business via info.json)

    Executes cleanly as a standard User so user-session mapped SMB drives and HKCU cloud sync profiles remain
    visible, while gracefully enriching Administrator-only metrics (BitLocker, SMART Reliability Counters,
    and Get-SmbConnection dialect/encryption) whenever elevated.

.PARAMETER Interactive
    Displays the detailed summary table and launches an interactive prompt to select any drive for deep inspection.
    Aliases: -i, -Menu, -Browse

.PARAMETER List
    Displays the detailed summary table in the console without entering the interactive prompt.
    Aliases: -Summary, -Scan, -All

.PARAMETER Drive
    Filters output to one or more Drive Letters or Drive IDs (e.g., C, F, M, OD1, SP1) and displays deep details.
    Aliases: -DriveLetter, -Id, -Target

.PARAMETER DriveType
    Filters the inventory by storage category: All, Local, Removable, Network, Cloud, Virtual, Optical.
    Aliases: -Category, -Type

.PARAMETER Detailed
    Displays full multi-section deep-inspection panels for all matching drives non-interactively.
    Aliases: -Full

.PARAMETER IncludeSystemVolumes
    Includes unlettered system partitions/volumes (e.g., EFI System Partition, Recovery) in the inventory.
    Aliases: -IncludeUnlettered

.PARAMETER PassThru
    Emits structured PSCustomObject records to the PowerShell pipeline for downstream filtering or export.

.PARAMETER ExportCsv
    Exports the collected drive inventory to a CSV file in LogDirectory (or CsvPath).

.PARAMETER CsvPath
    Specifies a custom file path or directory for CSV export.

.PARAMETER ExportJson
    Exports the collected drive inventory to a JSON file in LogDirectory (or JsonPath).

.PARAMETER JsonPath
    Specifies a custom file path or directory for JSON export.

.PARAMETER GenerateHtmlReport
    Generates a standalone, responsive HTML storage inventory report.
    Aliases: -ExportHtml

.PARAMETER ReportPath
    Specifies a custom file path or directory for the HTML report.
    Aliases: -ExportPath

.PARAMETER EnableLogging
    Enables structured execution logging to C:\Logs (with automatic fallback to $env:TEMP\Logs).
    Aliases: -Log

.PARAMETER LogDirectory
    Specifies the target directory for logs and default exports. Default: C:\Logs.

.PARAMETER Help
    Displays the interactive console help screen and exits cleanly.
    Aliases: -h

.EXAMPLE
    .\Get-DriveInventory.ps1 -Help
    Displays syntax, parameter documentation, category legend, and usage examples.

.EXAMPLE
    .\Get-DriveInventory.ps1 -Interactive
    Displays the full storage summary table and lets you select any drive for deep inspection.

.EXAMPLE
    .\Get-DriveInventory.ps1 -List
    Displays the detailed summary table for all local, network, and cloud drives.

.EXAMPLE
    .\Get-DriveInventory.ps1 -Drive C, F
    Displays summary and deep inspection details specifically for drives C: and F:.

.EXAMPLE
    .\Get-DriveInventory.ps1 -DriveType Network, Cloud -List
    Lists only network shares (SMB/CIFS/WebDAV) and cloud mounts (OneDrive/SharePoint/Google Drive).

.EXAMPLE
    .\Get-DriveInventory.ps1 -List -PassThru | Where-Object { $_.FreePercent -lt 20 }
    Pipes structured drive inventory objects to filter drives with less than 20% free space.

.EXAMPLE
    .\Get-DriveInventory.ps1 -List -GenerateHtmlReport -ExportCsv
    Audits all drives, displays the summary table, and saves HTML and CSV reports.

.EXAMPLE
    .\Invoke-GitHubScript.ps1 -UrlToDownload "https://github.com/romanpindela/Windows-Desktop/blob/main/Get-DriveInventory/Get-DriveInventory.ps1" -ScriptArgs "-Help"
    Downloads and displays help for Get-DriveInventory.ps1 directly from GitHub using Invoke-GitHubScript.ps1.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Date:         2026-11-18
    Requires:     Windows 10/11 / Windows Server, PowerShell 5.1+ or PowerShell 7+
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param (
    [Parameter(Mandatory = $false)]
    [Alias('i', 'Menu', 'Browse')]
    [switch]$Interactive,

    [Parameter(Mandatory = $false)]
    [Alias('Summary', 'Scan', 'All')]
    [switch]$List,

    [Parameter(Mandatory = $false)]
    [Alias('DriveLetter', 'Id', 'Target')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Drive,

    [Parameter(Mandatory = $false)]
    [Alias('Category', 'Type')]
    [ValidateSet('All', 'Local', 'Removable', 'Network', 'Cloud', 'Virtual', 'Optical')]
    [string[]]$DriveType = @('All'),

    [Parameter(Mandatory = $false)]
    [Alias('Full')]
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [Alias('IncludeUnlettered')]
    [switch]$IncludeSystemVolumes,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$ExportCsv,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$CsvPath,

    [Parameter(Mandatory = $false)]
    [switch]$ExportJson,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$JsonPath,

    [Parameter(Mandatory = $false)]
    [Alias('ExportHtml')]
    [switch]$GenerateHtmlReport,

    [Parameter(Mandatory = $false)]
    [Alias('ExportPath')]
    [ValidateNotNullOrEmpty()]
    [string]$ReportPath,

    [Parameter(Mandatory = $false)]
    [Alias('Log')]
    [switch]$EnableLogging,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $script:ScriptVersion    = '1.0.0'
    $script:SessionTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFilePath      = $null
    $script:IsElevated       = $false

    # --------------------------------------------------------------------------
    # Helper: Help Screen
    # --------------------------------------------------------------------------
    function Show-ScriptHelp {
        [CmdletBinding()]
        param()

        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host " Get-DriveInventory.ps1 v$($script:ScriptVersion) - Local, Network & Cloud Storage Inspector" -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Author: Roman Pindela | Email: roman.pindela@gmail.com | GitHub: romanpindela`n" -ForegroundColor DarkGray

        Write-Host "DESCRIPTION:" -ForegroundColor Green
        Write-Host "  Inspects local physical/logical disks (NVMe/SATA/USB/VHD/SUBST), network shares"
        Write-Host "  (SMB/CIFS/WebDAV/NFS), and cloud storage sync roots (OneDrive, SharePoint,"
        Write-Host "  Google Drive, Dropbox) in a rich console table with interactive drill-down.`n"

        Write-Host "PARAMETERS & SWITCHES:" -ForegroundColor Green
        Write-Host "  -Interactive (-i, -Menu)    Displays summary table and opens interactive drive selector."
        Write-Host "  -List (-Summary, -Scan)     Displays detailed summary table and exits."
        Write-Host "  -Drive <string[]>           Filters by Drive Letter or ID (e.g. C, F, M, OD1, SP1)"
        Write-Host "                              and displays full deep inspection for selected drives."
        Write-Host "  -DriveType <string[]>       Filter: All, Local, Removable, Network, Cloud, Virtual, Optical."
        Write-Host "  -Detailed (-Full)           Displays deep inspection panels for all matching drives."
        Write-Host "  -IncludeSystemVolumes       Includes unlettered EFI / Recovery / Reserved volumes."
        Write-Host "  -PassThru                   Emits structured PSCustomObject records to the pipeline."
        Write-Host "  -ExportCsv / -CsvPath       Exports inventory table to CSV."
        Write-Host "  -ExportJson / -JsonPath     Exports full inventory objects to JSON."
        Write-Host "  -GenerateHtmlReport         Generates a standalone responsive HTML storage report."
        Write-Host "  -EnableLogging (-Log)       Writes audit logs to C:\Logs (or %TEMP%\Logs fallback)."
        Write-Host "  -WhatIf / -Confirm          Standard PowerShell confirmation for export/log writes."
        Write-Host "  -Help (-h)                  Displays this help screen and exits.`n"

        Write-Host "USAGE EXAMPLES:" -ForegroundColor Green
        Write-Host "  .\Get-DriveInventory.ps1 -Interactive"
        Write-Host "  .\Get-DriveInventory.ps1 -List"
        Write-Host "  .\Get-DriveInventory.ps1 -Drive C, F"
        Write-Host "  .\Get-DriveInventory.ps1 -DriveType Network, Cloud -List"
        Write-Host "  .\Get-DriveInventory.ps1 -List -GenerateHtmlReport -ExportCsv"
        Write-Host "  .\Get-DriveInventory.ps1 -List -PassThru | Where-Object { `$_.FreePercent -lt 15 }`n"
    }

    # --------------------------------------------------------------------------
    # Helper: Language-Independent Elevation Check (SID S-1-5-32-544)
    # --------------------------------------------------------------------------
    function Test-IsElevated {
        [CmdletBinding()]
        param()

        try {
            $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            $adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
            return $principal.IsInRole($adminSid)
        }
        catch {
            return $false
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Logging Initialization & Writer
    # --------------------------------------------------------------------------
    function Initialize-LogDirectory {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$DirectoryPath
        )

        $targetDir = $DirectoryPath
        try {
            if (-not (Test-Path -Path $targetDir -PathType Container)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }
            $probeFile = Join-Path -Path $targetDir -ChildPath ".write_probe_$PID"
            [System.IO.File]::WriteAllText($probeFile, 'ok')
            Remove-Item -Path $probeFile -Force -ErrorAction SilentlyContinue
        }
        catch {
            $fallback = Join-Path -Path $env:TEMP -ChildPath 'Logs'
            if (-not (Test-Path -Path $fallback -PathType Container)) {
                New-Item -Path $fallback -ItemType Directory -Force | Out-Null
            }
            $targetDir = $fallback
        }

        $logFileName = "$($script:SessionTimestamp)-Get-DriveInventory-$($env:COMPUTERNAME)-$($env:USERNAME).log"
        $script:LogFilePath = Join-Path -Path $targetDir -ChildPath $logFileName
        return $targetDir
    }

    function Write-ScriptLog {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'DEBUG')]
            [string]$Level = 'INFO'
        )

        Write-Verbose "[$Level] $Message"
        if (-not [string]::IsNullOrWhiteSpace($script:LogFilePath)) {
            $line = "[{0}] [{1,-7}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
            try {
                Add-Content -Path $script:LogFilePath -Value $line -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                # Ignore non-fatal log write failures to preserve read-only console flow
            }
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Safe Property Access & Formatting
    # --------------------------------------------------------------------------
    function Get-SafeProp {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [object]$InputObject,

            [Parameter(Mandatory = $true)]
            [string]$PropertyName,

            [Parameter(Mandatory = $false)]
            [object]$DefaultValue = $null
        )

        if ($null -eq $InputObject) {
            return $DefaultValue
        }

        $prop = $InputObject.PSObject.Properties[$PropertyName]
        if ($null -ne $prop -and $null -ne $prop.Value) {
            return $prop.Value
        }
        return $DefaultValue
    }

    function ConvertTo-SizeGB {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [object]$Bytes
        )

        if ($null -eq $Bytes -or $Bytes -eq '') {
            return $null
        }
        try {
            $numeric = [double]$Bytes
            if ($numeric -lt 0) {
                return $null
            }
            return [math]::Round(($numeric / 1GB), 2)
        }
        catch {
            return $null
        }
    }

    function Format-SizeText {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [object]$Bytes
        )

        if ($null -eq $Bytes -or $Bytes -eq '') {
            return 'N/A'
        }
        try {
            $b = [double]$Bytes
            if ($b -ge 1TB) {
                return ('{0:N2} TB ({1:N2} GB)' -f ($b / 1TB), ($b / 1GB))
            }
            elseif ($b -ge 1GB) {
                return ('{0:N2} GB' -f ($b / 1GB))
            }
            elseif ($b -ge 1MB) {
                return ('{0:N2} MB' -f ($b / 1MB))
            }
            else {
                return ('{0:N0} Bytes' -f $b)
            }
        }
        catch {
            return 'N/A'
        }
    }

    function ConvertTo-ShortText {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [string]$Text,

            [Parameter(Mandatory = $true)]
            [int]$MaxLength
        )

        if ([string]::IsNullOrEmpty($Text)) {
            return ''
        }
        if ($Text.Length -le $MaxLength) {
            return $Text
        }
        if ($MaxLength -le 3) {
            return $Text.Substring(0, $MaxLength)
        }
        return ($Text.Substring(0, $MaxLength - 3) + '...')
    }

    function Get-NormalizedDriveToken {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Token
        )

        $clean = $Token.Trim().TrimEnd('\', '/').TrimEnd(':')
        return $clean.ToUpperInvariant()
    }

    # --------------------------------------------------------------------------
    # Helper: SUBST Virtual Drives Lookup
    # --------------------------------------------------------------------------
    function Get-SubstMappingLookup {
        [CmdletBinding()]
        param()

        $map = @{}
        try {
            $substOutput = & subst.exe 2>$null
            foreach ($line in $substOutput) {
                if ($line -match '^([A-Za-z]):\\\s*=>\s*(.+)$') {
                    $letter = $Matches[1].ToUpperInvariant()
                    $target = $Matches[2].Trim()
                    $map[$letter] = $target
                }
            }
        }
        catch {
            Write-ScriptLog -Message "SUBST enumeration skipped: $($_.Exception.Message)" -Level 'DEBUG'
        }
        return $map
    }

    # --------------------------------------------------------------------------
    # Helper: BitLocker Status Lookup (Graceful Non-Admin Fallback)
    # --------------------------------------------------------------------------
    function Get-BitLockerLookup {
        [CmdletBinding()]
        param()

        $lookup = @{}
        if (-not $script:IsElevated) {
            return $lookup
        }

        try {
            $blVolumes = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName 'Win32_EncryptableVolume' -ErrorAction Stop
            foreach ($vol in $blVolumes) {
                $dl = Get-SafeProp -InputObject $vol -PropertyName 'DriveLetter' -DefaultValue ''
                if (-not [string]::IsNullOrWhiteSpace($dl)) {
                    $key = $dl.TrimEnd(':').ToUpperInvariant()
                    $prot = Get-SafeProp -InputObject $vol -PropertyName 'ProtectionStatus' -DefaultValue $null
                    $conv = Get-SafeProp -InputObject $vol -PropertyName 'ConversionStatus' -DefaultValue $null
                    $protText = switch ($prot) {
                        0 { 'Protection Off' }
                        1 { 'Protected (On)' }
                        2 { 'Protection Unknown' }
                        default { 'Unknown' }
                    }
                    $convText = switch ($conv) {
                        0 { 'Fully Decrypted' }
                        1 { 'Fully Encrypted' }
                        2 { 'Encryption In Progress' }
                        3 { 'Decryption In Progress' }
                        4 { 'Encryption Paused' }
                        5 { 'Decryption Paused' }
                        default { '' }
                    }
                    $lookup[$key] = if ($convText) { "$protText ($convText)" } else { $protText }
                }
            }
        }
        catch {
            Write-ScriptLog -Message "BitLocker CIM query unavailable: $($_.Exception.Message)" -Level 'DEBUG'
        }
        return $lookup
    }

    # --------------------------------------------------------------------------
    # Collector 1: Local, USB, Optical, Virtual & SUBST Volumes
    # --------------------------------------------------------------------------
    function Get-LocalDriveInventory {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [switch]$IncludeSystem
        )

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        $substMap      = Get-SubstMappingLookup
        $bitlockerMap  = Get-BitLockerLookup

        $volumes       = @()
        $partitions    = @()
        $disks         = @()
        $physicalDisks = @()
        $win32Volumes  = @()
        $logicalDisks  = @()

        try { $volumes = @(Get-Volume -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Get-Volume warning: $($_.Exception.Message)" -Level 'WARN' }
        try { $partitions = @(Get-Partition -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Get-Partition warning: $($_.Exception.Message)" -Level 'WARN' }
        try { $disks = @(Get-Disk -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Get-Disk warning: $($_.Exception.Message)" -Level 'WARN' }
        try { $physicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Get-PhysicalDisk warning: $($_.Exception.Message)" -Level 'WARN' }
        try { $win32Volumes = @(Get-CimInstance -ClassName 'Win32_Volume' -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Win32_Volume warning: $($_.Exception.Message)" -Level 'WARN' }
        try { $logicalDisks = @(Get-CimInstance -ClassName 'Win32_LogicalDisk' -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Win32_LogicalDisk warning: $($_.Exception.Message)" -Level 'WARN' }

        # Index Disks by Number
        $diskByNumber = @{}
        foreach ($d in $disks) {
            $num = Get-SafeProp -InputObject $d -PropertyName 'Number'
            if ($null -ne $num) { $diskByNumber[[string]$num] = $d }
        }

        # Index PhysicalDisks by DeviceId and FriendlyName
        $physById = @{}
        foreach ($pd in $physicalDisks) {
            $id = Get-SafeProp -InputObject $pd -PropertyName 'DeviceId'
            if ($null -ne $id) { $physById[[string]$id] = $pd }
        }

        # Index Win32_Volume by DriveLetter and DeviceID
        $w32VolByLetter = @{}
        $w32VolByGuid   = @{}
        foreach ($wv in $win32Volumes) {
            $dl = Get-SafeProp -InputObject $wv -PropertyName 'DriveLetter' -DefaultValue ''
            $dev = Get-SafeProp -InputObject $wv -PropertyName 'DeviceID' -DefaultValue ''
            if (-not [string]::IsNullOrWhiteSpace($dl)) {
                $w32VolByLetter[$dl.TrimEnd(':').ToUpperInvariant()] = $wv
            }
            if (-not [string]::IsNullOrWhiteSpace($dev)) {
                $w32VolByGuid[$dev] = $wv
            }
        }

        # Index Win32_LogicalDisk by DeviceID (without colon)
        $logicalByLetter = @{}
        foreach ($ld in $logicalDisks) {
            $dev = Get-SafeProp -InputObject $ld -PropertyName 'DeviceID' -DefaultValue ''
            if (-not [string]::IsNullOrWhiteSpace($dev)) {
                $logicalByLetter[$dev.TrimEnd(':').ToUpperInvariant()] = $ld
            }
        }

        # Index Partitions by DriveLetter and AccessPaths
        $partByLetter = @{}
        foreach ($p in $partitions) {
            $dl = Get-SafeProp -InputObject $p -PropertyName 'DriveLetter'
            if ($null -ne $dl -and [string]$dl -match '^[A-Za-z]$') {
                $partByLetter[([string]$dl).ToUpperInvariant()] = $p
            }
        }

        $processedLetters = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $sysIndex = 0

        foreach ($vol in $volumes) {
            $rawLetter = Get-SafeProp -InputObject $vol -PropertyName 'DriveLetter'
            $letterStr = if ($null -ne $rawLetter -and [string]$rawLetter -match '^[A-Za-z]$') { ([string]$rawLetter).ToUpperInvariant() } else { '' }
            $volUniqueId = Get-SafeProp -InputObject $vol -PropertyName 'UniqueId' -DefaultValue ''
            $volPath     = Get-SafeProp -InputObject $vol -PropertyName 'Path' -DefaultValue ''
            $volLabel    = Get-SafeProp -InputObject $vol -PropertyName 'FileSystemLabel' -DefaultValue ''
            $volFs       = Get-SafeProp -InputObject $vol -PropertyName 'FileSystem' -DefaultValue 'Unknown'
            $volType     = [string](Get-SafeProp -InputObject $vol -PropertyName 'DriveType' -DefaultValue 'Unknown')
            $volHealth   = [string](Get-SafeProp -InputObject $vol -PropertyName 'HealthStatus' -DefaultValue 'Unknown')
            $volOpStatus = [string](Get-SafeProp -InputObject $vol -PropertyName 'OperationalStatus' -DefaultValue 'Unknown')
            $sizeBytes   = Get-SafeProp -InputObject $vol -PropertyName 'Size'
            $freeBytes   = Get-SafeProp -InputObject $vol -PropertyName 'SizeRemaining'

            # Skip unlettered system/EFI/Recovery partitions unless explicitly requested
            if ([string]::IsNullOrWhiteSpace($letterStr)) {
                if (-not $IncludeSystem) {
                    continue
                }
                # Check if this unlettered volume is actually Google Drive streaming mount
                if ($volLabel -like '*Google Drive*') {
                    continue
                }
                $sysIndex++
                $driveId = "SYS$sysIndex"
                $displayPath = if ($volPath) { $volPath } else { $volUniqueId }
            }
            else {
                $null = $processedLetters.Add($letterStr)
                $driveId = "${letterStr}:"
                $displayPath = "${letterStr}:\"
            }

            $w32v = if ($letterStr -and $w32VolByLetter.ContainsKey($letterStr)) { $w32VolByLetter[$letterStr] } elseif ($volPath -and $w32VolByGuid.ContainsKey($volPath)) { $w32VolByGuid[$volPath] } else { $null }
            $ld   = if ($letterStr -and $logicalByLetter.ContainsKey($letterStr)) { $logicalByLetter[$letterStr] } else { $null }
            $part = if ($letterStr -and $partByLetter.ContainsKey($letterStr)) { $partByLetter[$letterStr] } else { $null }

            # Fallback partition match via AccessPaths for unlettered volumes
            if ($null -eq $part -and $volPath) {
                $part = $partitions | Where-Object {
                    $ap = Get-SafeProp -InputObject $_ -PropertyName 'AccessPaths'
                    $ap -and ($ap -contains $volPath)
                } | Select-Object -First 1
            }

            $disk = $null
            $phys = $null
            $diskNumber = $null
            if ($null -ne $part) {
                $diskNumber = Get-SafeProp -InputObject $part -PropertyName 'DiskNumber'
                if ($null -ne $diskNumber -and $diskByNumber.ContainsKey([string]$diskNumber)) {
                    $disk = $diskByNumber[[string]$diskNumber]
                }
                if ($null -ne $diskNumber -and $physById.ContainsKey([string]$diskNumber)) {
                    $phys = $physById[[string]$diskNumber]
                }
            }

            $busType        = [string](Get-SafeProp -InputObject $disk -PropertyName 'BusType' -DefaultValue '')
            if ([string]::IsNullOrWhiteSpace($busType)) {
                $busType = [string](Get-SafeProp -InputObject $phys -PropertyName 'BusType' -DefaultValue '')
            }
            $mediaType      = [string](Get-SafeProp -InputObject $phys -PropertyName 'MediaType' -DefaultValue '')
            $diskModel      = [string](Get-SafeProp -InputObject $disk -PropertyName 'FriendlyName' -DefaultValue '')
            $diskSerial     = [string](Get-SafeProp -InputObject $disk -PropertyName 'SerialNumber' -DefaultValue '')
            $diskFirmware   = [string](Get-SafeProp -InputObject $disk -PropertyName 'FirmwareVersion' -DefaultValue '')
            $partStyle      = [string](Get-SafeProp -InputObject $disk -PropertyName 'PartitionStyle' -DefaultValue '')
            $diskLocation   = [string](Get-SafeProp -InputObject $disk -PropertyName 'Location' -DefaultValue '')
            $blockSize      = Get-SafeProp -InputObject $w32v -PropertyName 'BlockSize'
            $allocUnit      = Get-SafeProp -InputObject $vol -PropertyName 'AllocationUnitSize'
            if ($null -eq $blockSize -and $null -ne $allocUnit) { $blockSize = $allocUnit }

            # Detect Google Drive mapped as drive letter
            $isGoogleDriveLetter = ($volLabel -like '*Google Drive*')
            $isSubstDrive = ($letterStr -and $substMap.ContainsKey($letterStr))

            # Determine precise Category & FilterGroup
            $category = 'Local Fixed'
            $filterGroup = 'Local'
            if ($isGoogleDriveLetter) {
                $category = 'Cloud GoogleDrive'
                $filterGroup = 'Cloud'
                if ([string]::IsNullOrWhiteSpace($busType)) { $busType = 'DriveFS' }
                if ([string]::IsNullOrWhiteSpace($mediaType)) { $mediaType = 'Cloud' }
            }
            elseif ($isSubstDrive) {
                $category = 'Virtual SUBST'
                $filterGroup = 'Virtual'
                $busType = 'SUBST'
                $mediaType = 'Virtual'
                $displayPath = $substMap[$letterStr]
            }
            elseif ($volType -eq 'CD-ROM') {
                $category = 'Optical (CD/DVD)'
                $filterGroup = 'Optical'
                if ([string]::IsNullOrWhiteSpace($busType)) { $busType = 'ATAPI/USB' }
                if ([string]::IsNullOrWhiteSpace($mediaType)) { $mediaType = 'Optical' }
            }
            elseif ($busType -in @('File Backed Virtual', 'Spaces', 'Virtual')) {
                $category = 'Virtual / VHD'
                $filterGroup = 'Virtual'
                if ([string]::IsNullOrWhiteSpace($mediaType)) { $mediaType = 'Virtual' }
            }
            elseif ($volType -eq 'Removable') {
                $category = 'Removable'
                $filterGroup = 'Removable'
                if ([string]::IsNullOrWhiteSpace($mediaType) -or $mediaType -eq 'Unspecified') { $mediaType = 'Flash/Removable' }
            }
            elseif ($busType -eq 'USB') {
                $category = 'External USB'
                $filterGroup = 'Removable'
                if ([string]::IsNullOrWhiteSpace($mediaType) -or $mediaType -eq 'Unspecified') { $mediaType = 'External USB' }
            }
            elseif ([string]::IsNullOrWhiteSpace($letterStr)) {
                $category = 'System / Unlettered'
                $filterGroup = 'Local'
            }
            else {
                $category = 'Local Fixed'
                $filterGroup = 'Local'
            }

            # Optional SMART / Reliability Counters (only when elevated & physical disk exists)
            $smartInfo = $null
            if ($script:IsElevated -and $null -ne $phys) {
                try {
                    $rel = $phys | Get-StorageReliabilityCounter -ErrorAction Stop
                    if ($null -ne $rel) {
                        $smartInfo = [PSCustomObject]@{
                            TemperatureC   = Get-SafeProp -InputObject $rel -PropertyName 'Temperature'
                            WearPercent    = Get-SafeProp -InputObject $rel -PropertyName 'Wear'
                            ReadErrors     = Get-SafeProp -InputObject $rel -PropertyName 'ReadErrorsTotal'
                            WriteErrors    = Get-SafeProp -InputObject $rel -PropertyName 'WriteErrorsTotal'
                            PowerOnHours   = Get-SafeProp -InputObject $rel -PropertyName 'PowerOnHours'
                        }
                    }
                }
                catch {
                    Write-ScriptLog -Message "StorageReliabilityCounter unavailable for Disk $diskNumber`: $($_.Exception.Message)" -Level 'DEBUG'
                }
            }

            $totalGB = ConvertTo-SizeGB -Bytes $sizeBytes
            $freeGB  = ConvertTo-SizeGB -Bytes $freeBytes
            $usedBytes = if ($null -ne $sizeBytes -and $null -ne $freeBytes) { [double]$sizeBytes - [double]$freeBytes } else { $null }
            $usedGB  = ConvertTo-SizeGB -Bytes $usedBytes
            $freePct = if ($null -ne $sizeBytes -and [double]$sizeBytes -gt 0 -and $null -ne $freeBytes) {
                [math]::Round(([double]$freeBytes / [double]$sizeBytes) * 100, 1)
            } else { $null }
            $usedPct = if ($null -ne $freePct) { [math]::Round(100 - $freePct, 1) } else { $null }

            $bitlockerStatus = if (-not $script:IsElevated) {
                'Requires Admin to query'
            } elseif ($letterStr -and $bitlockerMap.ContainsKey($letterStr)) {
                $bitlockerMap[$letterStr]
            } else {
                'Not Applicable / Unencrypted'
            }

            $displayLabel = if (-not [string]::IsNullOrWhiteSpace($volLabel)) {
                $volLabel
            } elseif ($letterStr -eq 'C') {
                'Windows System'
            } elseif ($part) {
                [string](Get-SafeProp -InputObject $part -PropertyName 'Type' -DefaultValue 'Unlabeled')
            } else {
                'Unlabeled'
            }

            $details = [ordered]@{
                VolumeGuid        = $volUniqueId
                VolumePath        = $volPath
                VolumeType        = $volType
                OperationalStatus = $volOpStatus
                ClusterSizeBytes  = $blockSize
                Compressed        = Get-SafeProp -InputObject $w32v -PropertyName 'Compressed'
                IndexingEnabled   = Get-SafeProp -InputObject $w32v -PropertyName 'IndexingEnabled'
                DeduplicationMode = [string](Get-SafeProp -InputObject $vol -PropertyName 'DedupMode' -DefaultValue 'Disabled')
                BitLockerStatus   = $bitlockerStatus
                DiskNumber        = $diskNumber
                DiskModel         = $diskModel
                DiskSerialNumber  = if ($diskSerial) { $diskSerial.Trim() } else { '' }
                DiskFirmware      = $diskFirmware
                DiskLocation      = $diskLocation
                PartitionNumber   = Get-SafeProp -InputObject $part -PropertyName 'PartitionNumber'
                PartitionStyle    = $partStyle
                PartitionType     = Get-SafeProp -InputObject $part -PropertyName 'Type'
                IsBoot            = Get-SafeProp -InputObject $part -PropertyName 'IsBoot'
                IsSystem          = Get-SafeProp -InputObject $part -PropertyName 'IsSystem'
                IsActive          = Get-SafeProp -InputObject $part -PropertyName 'IsActive'
                SubstTarget       = if ($isSubstDrive) { $substMap[$letterStr] } else { $null }
                SmartCounters     = $smartInfo
            }

            $results.Add([PSCustomObject]@{
                PSTypeName       = 'WindowsDesktop.DriveInventoryItem'
                Id               = $driveId
                DriveLetter      = $letterStr
                Category         = $category
                FilterGroup      = $filterGroup
                Label            = $displayLabel
                FileSystem       = if ($volFs) { $volFs } else { 'N/A' }
                Interface        = if ($busType) { $busType } else { 'Local' }
                MediaType        = if ($mediaType) { $mediaType } else { 'N/A' }
                TotalBytes       = $sizeBytes
                FreeBytes        = $freeBytes
                UsedBytes        = $usedBytes
                TotalGB          = $totalGB
                UsedGB           = $usedGB
                FreeGB           = $freeGB
                FreePercent      = $freePct
                UsedPercent      = $usedPct
                Status           = $volHealth
                TargetPath       = $displayPath
                Details          = [PSCustomObject]$details
            })
        }

        # Catch SUBST drives that may not surface in Get-Volume
        foreach ($subKey in $substMap.Keys) {
            if (-not $processedLetters.Contains($subKey)) {
                $targetPath = $substMap[$subKey]
                $ld = if ($logicalByLetter.ContainsKey($subKey)) { $logicalByLetter[$subKey] } else { $null }
                $sizeBytes = Get-SafeProp -InputObject $ld -PropertyName 'Size'
                $freeBytes = Get-SafeProp -InputObject $ld -PropertyName 'FreeSpace'
                $totalGB   = ConvertTo-SizeGB -Bytes $sizeBytes
                $freeGB    = ConvertTo-SizeGB -Bytes $freeBytes
                $usedBytes = if ($null -ne $sizeBytes -and $null -ne $freeBytes) { [double]$sizeBytes - [double]$freeBytes } else { $null }
                $usedGB    = ConvertTo-SizeGB -Bytes $usedBytes
                $freePct   = if ($null -ne $sizeBytes -and [double]$sizeBytes -gt 0 -and $null -ne $freeBytes) { [math]::Round(([double]$freeBytes / [double]$sizeBytes) * 100, 1) } else { $null }
                $usedPct   = if ($null -ne $freePct) { [math]::Round(100 - $freePct, 1) } else { $null }

                $results.Add([PSCustomObject]@{
                    PSTypeName  = 'WindowsDesktop.DriveInventoryItem'
                    Id          = "${subKey}:"
                    DriveLetter = $subKey
                    Category    = 'Virtual SUBST'
                    FilterGroup = 'Virtual'
                    Label       = (Split-Path -Path $targetPath -Leaf)
                    FileSystem  = [string](Get-SafeProp -InputObject $ld -PropertyName 'FileSystem' -DefaultValue 'NTFS')
                    Interface   = 'SUBST'
                    MediaType   = 'Virtual'
                    TotalBytes  = $sizeBytes
                    FreeBytes   = $freeBytes
                    UsedBytes   = $usedBytes
                    TotalGB     = $totalGB
                    UsedGB      = $usedGB
                    FreeGB      = $freeGB
                    FreePercent = $freePct
                    UsedPercent = $usedPct
                    Status      = if (Test-Path -Path $targetPath) { 'Healthy' } else { 'Broken Target' }
                    TargetPath  = $targetPath
                    Details     = [PSCustomObject]@{
                        SubstTarget = $targetPath
                        MappedDrive = "${subKey}:"
                    }
                })
            }
        }

        return $results
    }

    # --------------------------------------------------------------------------
    # Collector 2: Network Drives (SMB, CIFS, WebDAV, NFS, UNC Mappings)
    # --------------------------------------------------------------------------
    function Get-NetworkDriveInventory {
        [CmdletBinding()]
        param()

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        $smbMappings = @()
        $netLogical  = @()
        $netConns    = @()
        $smbConns    = @()
        $smbConnErr  = $null

        try { $smbMappings = @(Get-SmbMapping -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Get-SmbMapping warning: $($_.Exception.Message)" -Level 'WARN' }
        try { $netLogical = @(Get-CimInstance -ClassName 'Win32_LogicalDisk' -Filter 'DriveType = 4' -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Win32_LogicalDisk(4) warning: $($_.Exception.Message)" -Level 'WARN' }
        try { $netConns = @(Get-CimInstance -ClassName 'Win32_NetworkConnection' -ErrorAction SilentlyContinue) } catch { Write-ScriptLog -Message "Win32_NetworkConnection warning: $($_.Exception.Message)" -Level 'WARN' }
        try {
            $smbConns = @(Get-SmbConnection -ErrorAction Stop)
        }
        catch {
            $smbConnErr = 'Requires Admin for SMB Dialect/Encryption'
            Write-ScriptLog -Message "Get-SmbConnection skipped: $($_.Exception.Message)" -Level 'DEBUG'
        }

        # Index Win32_LogicalDisk(4) by DeviceID
        $logicalNetMap = @{}
        foreach ($ld in $netLogical) {
            $dev = [string](Get-SafeProp -InputObject $ld -PropertyName 'DeviceID' -DefaultValue '')
            if (-not [string]::IsNullOrWhiteSpace($dev)) {
                $logicalNetMap[$dev.ToUpperInvariant()] = $ld
            }
        }

        # Index Win32_NetworkConnection by LocalName or RemoteName
        $connByLocal  = @{}
        $connByRemote = @{}
        foreach ($nc in $netConns) {
            $ln = [string](Get-SafeProp -InputObject $nc -PropertyName 'LocalName' -DefaultValue '')
            $rn = [string](Get-SafeProp -InputObject $nc -PropertyName 'RemoteName' -DefaultValue '')
            if (-not [string]::IsNullOrWhiteSpace($ln)) { $connByLocal[$ln.ToUpperInvariant()] = $nc }
            if (-not [string]::IsNullOrWhiteSpace($rn)) { $connByRemote[$rn.ToLowerInvariant()] = $nc }
        }

        # Index Get-SmbConnection by ServerName\ShareName
        $smbConnMap = @{}
        foreach ($sc in $smbConns) {
            $srv = [string](Get-SafeProp -InputObject $sc -PropertyName 'ServerName' -DefaultValue '')
            $shr = [string](Get-SafeProp -InputObject $sc -PropertyName 'ShareName' -DefaultValue '')
            if ($srv -and $shr) {
                $smbConnMap[("\\$srv\$shr").ToLowerInvariant()] = $sc
            }
        }

        # Build unified unique entries from SmbMapping + Win32_LogicalDisk(4) + Win32_NetworkConnection
        $seenKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $entries  = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($m in $smbMappings) {
            $lp = [string](Get-SafeProp -InputObject $m -PropertyName 'LocalPath' -DefaultValue '')
            $rp = [string](Get-SafeProp -InputObject $m -PropertyName 'RemotePath' -DefaultValue '')
            $st = [string](Get-SafeProp -InputObject $m -PropertyName 'Status' -DefaultValue 'Unknown')
            $key = if ($lp) { $lp.ToUpperInvariant() } else { $rp.ToLowerInvariant() }
            if ($key -and $seenKeys.Add($key)) {
                $entries.Add(@{ LocalPath = $lp; RemotePath = $rp; Status = $st })
            }
        }

        foreach ($ld in $netLogical) {
            $lp = [string](Get-SafeProp -InputObject $ld -PropertyName 'DeviceID' -DefaultValue '')
            $rp = [string](Get-SafeProp -InputObject $ld -PropertyName 'ProviderName' -DefaultValue '')
            $key = if ($lp) { $lp.ToUpperInvariant() } else { $rp.ToLowerInvariant() }
            if ($key -and $seenKeys.Add($key)) {
                $entries.Add(@{ LocalPath = $lp; RemotePath = $rp; Status = 'Connected' })
            }
        }

        foreach ($nc in $netConns) {
            $lp = [string](Get-SafeProp -InputObject $nc -PropertyName 'LocalName' -DefaultValue '')
            $rp = [string](Get-SafeProp -InputObject $nc -PropertyName 'RemoteName' -DefaultValue '')
            $st = [string](Get-SafeProp -InputObject $nc -PropertyName 'ConnectionState' -DefaultValue 'Unknown')
            $key = if ($lp) { $lp.ToUpperInvariant() } else { $rp.ToLowerInvariant() }
            if ($key -and $seenKeys.Add($key)) {
                $entries.Add(@{ LocalPath = $lp; RemotePath = $rp; Status = $st })
            }
        }

        $uncIndex = 0
        foreach ($entry in $entries) {
            $localPath  = $entry.LocalPath
            $remotePath = $entry.RemotePath
            $connStatus = $entry.Status

            $ld = if ($localPath -and $logicalNetMap.ContainsKey($localPath.ToUpperInvariant())) { $logicalNetMap[$localPath.ToUpperInvariant()] } else { $null }
            $nc = if ($localPath -and $connByLocal.ContainsKey($localPath.ToUpperInvariant())) {
                $connByLocal[$localPath.ToUpperInvariant()]
            } elseif ($remotePath -and $connByRemote.ContainsKey($remotePath.ToLowerInvariant())) {
                $connByRemote[$remotePath.ToLowerInvariant()]
            } else { $null }

            $providerName = [string](Get-SafeProp -InputObject $nc -PropertyName 'ProviderName' -DefaultValue 'Microsoft Windows Network')
            $persistent   = Get-SafeProp -InputObject $nc -PropertyName 'Persistent'
            $userName     = [string](Get-SafeProp -InputObject $nc -PropertyName 'UserName' -DefaultValue '')

            $sc = if ($remotePath -and $smbConnMap.ContainsKey($remotePath.ToLowerInvariant())) { $smbConnMap[$remotePath.ToLowerInvariant()] } else { $null }
            $dialect   = [string](Get-SafeProp -InputObject $sc -PropertyName 'Dialect' -DefaultValue '')
            $encrypted = Get-SafeProp -InputObject $sc -PropertyName 'Encrypted'
            $signed    = Get-SafeProp -InputObject $sc -PropertyName 'Signed'

            # Classify Network Protocol (SMB vs CIFS vs WebDAV vs NFS)
            $category  = 'Network SMB'
            $interface = 'SMB'
            if ($providerName -like '*Web Client*' -or $remotePath -match 'DavWWWRoot|@SSL|^https?://') {
                $category  = 'Network WebDAV'
                $interface = 'WebDAV/HTTPS'
            }
            elseif ($providerName -like '*NFS*') {
                $category  = 'Network NFS'
                $interface = 'NFS'
            }
            elseif ($dialect -match '^1\.' -or $dialect -eq 'NT LM 0.12') {
                $category  = 'Network CIFS'
                $interface = "CIFS ($dialect)"
            }
            elseif ($dialect) {
                $category  = 'Network SMB'
                $interface = "SMB $dialect"
            }

            if ([string]::IsNullOrWhiteSpace($localPath)) {
                $uncIndex++
                $driveId = "NET$uncIndex"
                $letterOnly = ''
            }
            else {
                $driveId = $localPath.ToUpperInvariant()
                $letterOnly = $driveId.TrimEnd(':')
            }

            $sizeBytes = Get-SafeProp -InputObject $ld -PropertyName 'Size'
            $freeBytes = Get-SafeProp -InputObject $ld -PropertyName 'FreeSpace'
            $fsName    = [string](Get-SafeProp -InputObject $ld -PropertyName 'FileSystem' -DefaultValue 'SMB/Remote')
            $volName   = [string](Get-SafeProp -InputObject $ld -PropertyName 'VolumeName' -DefaultValue '')

            if ([string]::IsNullOrWhiteSpace($volName) -and $remotePath) {
                $volName = ($remotePath.TrimEnd('\') -split '\\')[-1]
            }

            $totalGB   = ConvertTo-SizeGB -Bytes $sizeBytes
            $freeGB    = ConvertTo-SizeGB -Bytes $freeBytes
            $usedBytes = if ($null -ne $sizeBytes -and $null -ne $freeBytes) { [double]$sizeBytes - [double]$freeBytes } else { $null }
            $usedGB    = ConvertTo-SizeGB -Bytes $usedBytes
            $freePct   = if ($null -ne $sizeBytes -and [double]$sizeBytes -gt 0 -and $null -ne $freeBytes) { [math]::Round(([double]$freeBytes / [double]$sizeBytes) * 100, 1) } else { $null }
            $usedPct   = if ($null -ne $freePct) { [math]::Round(100 - $freePct, 1) } else { $null }

            $serverName = ''
            $shareName  = ''
            if ($remotePath -match '^\\\\([^\\]+)\\(.+)$') {
                $serverName = $Matches[1]
                $shareName  = $Matches[2]
            }

            $details = [ordered]@{
                RemoteUncPath   = $remotePath
                ServerName      = $serverName
                ShareName       = $shareName
                ProviderName    = $providerName
                ConnectionState = $connStatus
                Persistent      = $persistent
                SmbDialect      = if ($dialect) { $dialect } elseif ($smbConnErr) { $smbConnErr } else { 'N/A' }
                SmbEncrypted    = if ($null -ne $encrypted) { $encrypted } elseif ($smbConnErr) { $smbConnErr } else { 'N/A' }
                SmbSigned       = if ($null -ne $signed) { $signed } elseif ($smbConnErr) { $smbConnErr } else { 'N/A' }
                MappedUser      = $userName
            }

            $results.Add([PSCustomObject]@{
                PSTypeName  = 'WindowsDesktop.DriveInventoryItem'
                Id          = $driveId
                DriveLetter = $letterOnly
                Category    = $category
                FilterGroup = 'Network'
                Label       = if ($volName) { $volName } else { 'Network Share' }
                FileSystem  = $fsName
                Interface   = $interface
                MediaType   = 'Network'
                TotalBytes  = $sizeBytes
                FreeBytes   = $freeBytes
                UsedBytes   = $usedBytes
                TotalGB     = $totalGB
                UsedGB      = $usedGB
                FreeGB      = $freeGB
                FreePercent = $freePct
                UsedPercent = $usedPct
                Status      = $connStatus
                TargetPath  = $remotePath
                Details     = [PSCustomObject]$details
            })
        }

        return $results
    }

    # --------------------------------------------------------------------------
    # Collector 3: Cloud Storage & Sync Mounts (OneDrive, SharePoint, Google Drive, Dropbox)
    # --------------------------------------------------------------------------
    function Get-CloudDriveInventory {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [object[]]$ExistingVolumes = @()
        )

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $hostVolByLetter = @{}
        foreach ($ev in $ExistingVolumes) {
            if ($ev.DriveLetter) {
                $hostVolByLetter[$ev.DriveLetter.ToUpperInvariant()] = $ev
            }
        }

        $odIndex = 0
        $spIndex = 0
        $gdIndex = 0
        $dbIndex = 0

        $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        # 1. OneDrive & SharePoint from HKCU:\Software\Microsoft\OneDrive\Accounts
        $odRegRoot = 'HKCU:\Software\Microsoft\OneDrive\Accounts'
        if (Test-Path -Path $odRegRoot) {
            $accounts = @(Get-ChildItem -Path $odRegRoot -ErrorAction SilentlyContinue)
            foreach ($acc in $accounts) {
                $props = Get-ItemProperty -Path $acc.PSPath -ErrorAction SilentlyContinue
                $userFolder = [string](Get-SafeProp -InputObject $props -PropertyName 'UserFolder' -DefaultValue '')
                if ([string]::IsNullOrWhiteSpace($userFolder)) {
                    continue
                }

                $displayName = [string](Get-SafeProp -InputObject $props -PropertyName 'DisplayName' -DefaultValue $acc.PSChildName)
                $userEmail   = [string](Get-SafeProp -InputObject $props -PropertyName 'UserEmail' -DefaultValue '')
                $endpointUri = [string](Get-SafeProp -InputObject $props -PropertyName 'ServiceEndpointUri' -DefaultValue '')
                $isBusiness  = [bool](Get-SafeProp -InputObject $props -PropertyName 'Business' -DefaultValue 0)

                if ($seenPaths.Add($userFolder)) {
                    $odIndex++
                    $hostLetter = if ($userFolder -match '^([A-Za-z]):') { $Matches[1].ToUpperInvariant() } else { '' }
                    $hostVol    = if ($hostLetter -and $hostVolByLetter.ContainsKey($hostLetter)) { $hostVolByLetter[$hostLetter] } else { $null }
                    $exists     = Test-Path -Path $userFolder

                    $results.Add([PSCustomObject]@{
                        PSTypeName  = 'WindowsDesktop.DriveInventoryItem'
                        Id          = "OD$odIndex"
                        DriveLetter = ''
                        Category    = if ($isBusiness) { 'Cloud OneDrive Biz' } else { 'Cloud OneDrive' }
                        FilterGroup = 'Cloud'
                        Label       = if ($displayName) { $displayName } else { $acc.PSChildName }
                        FileSystem  = 'CloudFilter (NTFS)'
                        Interface   = 'OneDrive Sync'
                        MediaType   = 'Cloud'
                        TotalBytes  = if ($hostVol) { $hostVol.TotalBytes } else { $null }
                        FreeBytes   = if ($hostVol) { $hostVol.FreeBytes } else { $null }
                        UsedBytes   = if ($hostVol) { $hostVol.UsedBytes } else { $null }
                        TotalGB     = if ($hostVol) { $hostVol.TotalGB } else { $null }
                        UsedGB      = if ($hostVol) { $hostVol.UsedGB } else { $null }
                        FreeGB      = if ($hostVol) { $hostVol.FreeGB } else { $null }
                        FreePercent = if ($hostVol) { $hostVol.FreePercent } else { $null }
                        UsedPercent = if ($hostVol) { $hostVol.UsedPercent } else { $null }
                        Status      = if ($exists) { 'Synced / Ready' } else { 'Path Missing' }
                        TargetPath  = $userFolder
                        Details     = [PSCustomObject]@{
                            CloudProvider      = if ($isBusiness) { 'Microsoft OneDrive for Business' } else { 'Microsoft OneDrive Personal' }
                            AccountKey         = $acc.PSChildName
                            Organization       = $displayName
                            UserEmail          = $userEmail
                            ServiceEndpointUri = $endpointUri
                            LocalSyncPath      = $userFolder
                            HostVolume         = if ($hostLetter) { "${hostLetter}:" } else { 'Unknown' }
                            CapacityNote       = 'Displays underlying local host volume capacity (cloud quota requires Graph API).'
                        }
                    })
                }

                # Check SharePoint Libraries synced under this OneDrive Business account
                $scopePath = Join-Path -Path $acc.PSPath -ChildPath 'ScopeIdToMountPointPathCache'
                if (Test-Path -Path $scopePath) {
                    $scopeProps = Get-ItemProperty -Path $scopePath -ErrorAction SilentlyContinue
                    foreach ($spProp in $scopeProps.PSObject.Properties) {
                        if ($spProp.Name -like 'PS*') { continue }
                        $mountPath = [string]$spProp.Value
                        if ([string]::IsNullOrWhiteSpace($mountPath)) { continue }
                        if (-not $seenPaths.Add($mountPath)) { continue }

                        $spIndex++
                        $hostLetter = if ($mountPath -match '^([A-Za-z]):') { $Matches[1].ToUpperInvariant() } else { '' }
                        $hostVol    = if ($hostLetter -and $hostVolByLetter.ContainsKey($hostLetter)) { $hostVolByLetter[$hostLetter] } else { $null }
                        $exists     = Test-Path -Path $mountPath
                        $libName    = Split-Path -Path $mountPath -Leaf

                        $results.Add([PSCustomObject]@{
                            PSTypeName  = 'WindowsDesktop.DriveInventoryItem'
                            Id          = "SP$spIndex"
                            DriveLetter = ''
                            Category    = 'Cloud SharePoint'
                            FilterGroup = 'Cloud'
                            Label       = $libName
                            FileSystem  = 'CloudFilter (NTFS)'
                            Interface   = 'SharePoint Sync'
                            MediaType   = 'Cloud'
                            TotalBytes  = if ($hostVol) { $hostVol.TotalBytes } else { $null }
                            FreeBytes   = if ($hostVol) { $hostVol.FreeBytes } else { $null }
                            UsedBytes   = if ($hostVol) { $hostVol.UsedBytes } else { $null }
                            TotalGB     = if ($hostVol) { $hostVol.TotalGB } else { $null }
                            UsedGB      = if ($hostVol) { $hostVol.UsedGB } else { $null }
                            FreeGB      = if ($hostVol) { $hostVol.FreeGB } else { $null }
                            FreePercent = if ($hostVol) { $hostVol.FreePercent } else { $null }
                            UsedPercent = if ($hostVol) { $hostVol.UsedPercent } else { $null }
                            Status      = if ($exists) { 'Synced / Ready' } else { 'Path Missing' }
                            TargetPath  = $mountPath
                            Details     = [PSCustomObject]@{
                                CloudProvider      = 'Microsoft SharePoint Online Document Library'
                                AccountKey         = $acc.PSChildName
                                Organization       = $displayName
                                UserEmail          = $userEmail
                                ScopeId            = $spProp.Name
                                ServiceEndpointUri = $endpointUri
                                LocalSyncPath      = $mountPath
                                HostVolume         = if ($hostLetter) { "${hostLetter}:" } else { 'Unknown' }
                                CapacityNote       = 'Displays underlying local host volume capacity.'
                            }
                        })
                    }
                }
            }
        }

        # 2. Google Drive Streaming Folder Mounts (via Win32_Volume where DriveLetter is null)
        try {
            $gdVolumes = @(Get-CimInstance -ClassName 'Win32_Volume' -ErrorAction SilentlyContinue | Where-Object {
                ($_.Label -like '*Google Drive*' -or $_.Name -like '*Google Drive*') -and [string]::IsNullOrWhiteSpace($_.DriveLetter)
            })
            foreach ($gv in $gdVolumes) {
                $mountName = ([string](Get-SafeProp -InputObject $gv -PropertyName 'Name' -DefaultValue '')).TrimEnd('\')
                if ([string]::IsNullOrWhiteSpace($mountName)) { continue }
                if (-not $seenPaths.Add($mountName)) { continue }

                $gdIndex++
                $sizeBytes = Get-SafeProp -InputObject $gv -PropertyName 'Capacity'
                $freeBytes = Get-SafeProp -InputObject $gv -PropertyName 'FreeSpace'
                $totalGB   = ConvertTo-SizeGB -Bytes $sizeBytes
                $freeGB    = ConvertTo-SizeGB -Bytes $freeBytes
                $usedBytes = if ($null -ne $sizeBytes -and $null -ne $freeBytes) { [double]$sizeBytes - [double]$freeBytes } else { $null }
                $usedGB    = ConvertTo-SizeGB -Bytes $usedBytes
                $freePct   = if ($null -ne $sizeBytes -and [double]$sizeBytes -gt 0 -and $null -ne $freeBytes) { [math]::Round(([double]$freeBytes / [double]$sizeBytes) * 100, 1) } else { $null }
                $usedPct   = if ($null -ne $freePct) { [math]::Round(100 - $freePct, 1) } else { $null }

                $results.Add([PSCustomObject]@{
                    PSTypeName  = 'WindowsDesktop.DriveInventoryItem'
                    Id          = "GD$gdIndex"
                    DriveLetter = ''
                    Category    = 'Cloud GoogleDrive'
                    FilterGroup = 'Cloud'
                    Label       = [string](Get-SafeProp -InputObject $gv -PropertyName 'Label' -DefaultValue 'Google Drive')
                    FileSystem  = [string](Get-SafeProp -InputObject $gv -PropertyName 'FileSystem' -DefaultValue 'FAT32')
                    Interface   = 'Google DriveFS'
                    MediaType   = 'Cloud'
                    TotalBytes  = $sizeBytes
                    FreeBytes   = $freeBytes
                    UsedBytes   = $usedBytes
                    TotalGB     = $totalGB
                    UsedGB      = $usedGB
                    FreeGB      = $freeGB
                    FreePercent = $freePct
                    UsedPercent = $usedPct
                    Status      = if (Test-Path -Path $mountName) { 'Mounted / Ready' } else { 'Offline' }
                    TargetPath  = $mountName
                    Details     = [PSCustomObject]@{
                        CloudProvider = 'Google Drive for Desktop (Streaming Virtual Mount)'
                        VolumeGuid    = Get-SafeProp -InputObject $gv -PropertyName 'DeviceID'
                        BlockSize     = Get-SafeProp -InputObject $gv -PropertyName 'BlockSize'
                        LocalSyncPath = $mountName
                    }
                })
            }
        }
        catch {
            Write-ScriptLog -Message "Google Drive Win32_Volume check warning: $($_.Exception.Message)" -Level 'DEBUG'
        }

        # 3. Dropbox Sync Roots (via %APPDATA%\Dropbox\info.json or %LOCALAPPDATA%\Dropbox\info.json)
        $dropboxCandidates = @(
            (Join-Path -Path $env:APPDATA -ChildPath 'Dropbox\info.json'),
            (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Dropbox\info.json')
        )
        foreach ($dbJson in $dropboxCandidates) {
            if (Test-Path -Path $dbJson -PathType Leaf) {
                try {
                    $dbInfo = Get-Content -Path $dbJson -Raw -Encoding UTF8 | ConvertFrom-Json
                    foreach ($tier in @('personal', 'business')) {
                        $tierObj = Get-SafeProp -InputObject $dbInfo -PropertyName $tier
                        $dbPath  = [string](Get-SafeProp -InputObject $tierObj -PropertyName 'path' -DefaultValue '')
                        if (-not [string]::IsNullOrWhiteSpace($dbPath) -and $seenPaths.Add($dbPath)) {
                            $dbIndex++
                            $hostLetter = if ($dbPath -match '^([A-Za-z]):') { $Matches[1].ToUpperInvariant() } else { '' }
                            $hostVol    = if ($hostLetter -and $hostVolByLetter.ContainsKey($hostLetter)) { $hostVolByLetter[$hostLetter] } else { $null }

                            $results.Add([PSCustomObject]@{
                                PSTypeName  = 'WindowsDesktop.DriveInventoryItem'
                                Id          = "DB$dbIndex"
                                DriveLetter = ''
                                Category    = "Cloud Dropbox ($tier)"
                                FilterGroup = 'Cloud'
                                Label       = "Dropbox ($tier)"
                                FileSystem  = 'Local Sync (NTFS)'
                                Interface   = 'Dropbox Sync'
                                MediaType   = 'Cloud'
                                TotalBytes  = if ($hostVol) { $hostVol.TotalBytes } else { $null }
                                FreeBytes   = if ($hostVol) { $hostVol.FreeBytes } else { $null }
                                UsedBytes   = if ($hostVol) { $hostVol.UsedBytes } else { $null }
                                TotalGB     = if ($hostVol) { $hostVol.TotalGB } else { $null }
                                UsedGB      = if ($hostVol) { $hostVol.UsedGB } else { $null }
                                FreeGB      = if ($hostVol) { $hostVol.FreeGB } else { $null }
                                FreePercent = if ($hostVol) { $hostVol.FreePercent } else { $null }
                                UsedPercent = if ($hostVol) { $hostVol.UsedPercent } else { $null }
                                Status      = if (Test-Path -Path $dbPath) { 'Synced / Ready' } else { 'Path Missing' }
                                TargetPath  = $dbPath
                                Details     = [PSCustomObject]@{
                                    CloudProvider = "Dropbox ($tier)"
                                    LocalSyncPath = $dbPath
                                    HostVolume    = if ($hostLetter) { "${hostLetter}:" } else { 'Unknown' }
                                }
                            })
                        }
                    }
                }
                catch {
                    Write-ScriptLog -Message "Dropbox info.json parse warning: $($_.Exception.Message)" -Level 'DEBUG'
                }
            }
        }

        return $results
    }

    # --------------------------------------------------------------------------
    # Presentation: Color-Coded Console Summary Table
    # --------------------------------------------------------------------------
    function Show-DriveSummaryTable {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [object[]]$Items
        )

        $elevLabel = if ($script:IsElevated) { 'Elevated (Admin)' } else { 'Standard User (User-mapped SMB & HKCU Cloud visible)' }
        Write-Host "`n========================================================================================================================" -ForegroundColor Cyan
        Write-Host (" STORAGE & DRIVE INVENTORY  |  Host: {0}  |  User: {1}  |  Mode: {2}" -f $env:COMPUTERNAME, $env:USERNAME, $elevLabel) -ForegroundColor Yellow
        Write-Host "========================================================================================================================" -ForegroundColor Cyan

        if ($Items.Count -eq 0) {
            Write-Host "  [!] No drives matched the specified filter criteria." -ForegroundColor Yellow
            return
        }

        $header = "{0,-3} {1,-5} {2,-19} {3,-18} {4,-16} {5,-13} {6,9} {7,9} {8,9} {9,7} {10,-15} {11}" -f `
            '#', 'ID', 'Category', 'Label / Name', 'FileSystem', 'Interface', 'Total(GB)', 'Used(GB)', 'Free(GB)', 'Free%', 'Status', 'Target / Path'
        Write-Host $header -ForegroundColor White
        Write-Host ('-' * 140) -ForegroundColor DarkGray

        $idx = 0
        foreach ($item in $Items) {
            $idx++
            $totTxt  = if ($null -ne $item.TotalGB) { '{0,9:N2}' -f $item.TotalGB } else { '      N/A' }
            $usedTxt = if ($null -ne $item.UsedGB) { '{0,9:N2}' -f $item.UsedGB } else { '      N/A' }
            $freeTxt = if ($null -ne $item.FreeGB) { '{0,9:N2}' -f $item.FreeGB } else { '      N/A' }
            $pctTxt  = if ($null -ne $item.FreePercent) { '{0,6:N1}%' -f $item.FreePercent } else { '    N/A' }

            $rowColor = switch ($item.FilterGroup) {
                'Local'     { 'Gray' }
                'Removable' { 'Yellow' }
                'Network'   { 'Cyan' }
                'Cloud'     { 'Magenta' }
                'Virtual'   { 'DarkCyan' }
                'Optical'   { 'DarkGray' }
                default     { 'White' }
            }

            if ($item.Status -in @('Disconnected', 'Path Missing', 'Offline', 'Broken Target', 'Unhealthy')) {
                $rowColor = 'Red'
            }
            elseif ($null -ne $item.FreePercent -and $item.FreePercent -lt 10 -and $item.FilterGroup -in @('Local', 'Network')) {
                $rowColor = 'DarkYellow'
            }

            $line = "{0,-3} {1,-5} {2,-19} {3,-18} {4,-16} {5,-13} {6} {7} {8} {9} {10,-15} {11}" -f `
                $idx,
                (ConvertTo-ShortText -Text $item.Id -MaxLength 5),
                (ConvertTo-ShortText -Text $item.Category -MaxLength 19),
                (ConvertTo-ShortText -Text $item.Label -MaxLength 18),
                (ConvertTo-ShortText -Text $item.FileSystem -MaxLength 16),
                (ConvertTo-ShortText -Text $item.Interface -MaxLength 13),
                $totTxt,
                $usedTxt,
                $freeTxt,
                $pctTxt,
                (ConvertTo-ShortText -Text $item.Status -MaxLength 15),
                (ConvertTo-ShortText -Text $item.TargetPath -MaxLength 48)

            Write-Host $line -ForegroundColor $rowColor
        }

        Write-Host ('-' * 140) -ForegroundColor DarkGray
        $localCount   = @($Items | Where-Object { $_.FilterGroup -eq 'Local' }).Count
        $remCount     = @($Items | Where-Object { $_.FilterGroup -eq 'Removable' }).Count
        $netCount     = @($Items | Where-Object { $_.FilterGroup -eq 'Network' }).Count
        $cloudCount   = @($Items | Where-Object { $_.FilterGroup -eq 'Cloud' }).Count
        $virtualCount = @($Items | Where-Object { $_.FilterGroup -in @('Virtual', 'Optical') }).Count
        Write-Host (" Summary: Total={0} | Local={1} | Removable/USB={2} | Network={3} | Cloud={4} | Virtual/Optical={5}" -f `
            $Items.Count, $localCount, $remCount, $netCount, $cloudCount, $virtualCount) -ForegroundColor DarkCyan
    }

    # --------------------------------------------------------------------------
    # Presentation: Deep Inspection View for Selected Drive
    # --------------------------------------------------------------------------
    function Show-DriveDetailView {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Item
        )

        Write-Host "`n================================================================================" -ForegroundColor Yellow
        Write-Host (" DEEP DRIVE INSPECTION : [{0}] {1} ({2})" -f $Item.Id, $Item.Label, $Item.Category) -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Yellow

        # Section 1: Identity & Overview
        Write-Host "`n[1] GENERAL & CAPACITY" -ForegroundColor Green
        Write-Host ("  Drive ID / Letter  : {0}" -f $Item.Id)
        Write-Host ("  Category / Group   : {0} ({1})" -f $Item.Category, $Item.FilterGroup)
        Write-Host ("  Volume Label       : {0}" -f $Item.Label)
        Write-Host ("  File System        : {0}" -f $Item.FileSystem)
        Write-Host ("  Interface / Bus    : {0}" -f $Item.Interface)
        Write-Host ("  Media Type         : {0}" -f $Item.MediaType)
        Write-Host ("  Operational Status : {0}" -f $Item.Status)
        Write-Host ("  Target / Path      : {0}" -f $Item.TargetPath)
        Write-Host ("  Total Capacity     : {0}" -f (Format-SizeText -Bytes $Item.TotalBytes))
        Write-Host ("  Used Space         : {0}" -f (Format-SizeText -Bytes $Item.UsedBytes))
        Write-Host ("  Free Space         : {0}" -f (Format-SizeText -Bytes $Item.FreeBytes))

        if ($null -ne $Item.UsedPercent) {
            $barWidth = 30
            $filled = [math]::Min($barWidth, [math]::Max(0, [math]::Round(($Item.UsedPercent / 100) * $barWidth)))
            $empty  = $barWidth - $filled
            $bar    = ('#' * $filled) + ('-' * $empty)
            $barColor = if ($Item.UsedPercent -ge 90) { 'Red' } elseif ($Item.UsedPercent -ge 75) { 'Yellow' } else { 'Green' }
            Write-Host -NoNewline "  Usage Gauge        : ["
            Write-Host -NoNewline $bar -ForegroundColor $barColor
            Write-Host ("] {0:N1}% Used ({1:N1}% Free)" -f $Item.UsedPercent, $Item.FreePercent)
        }

        $d = $Item.Details
        if ($null -eq $d) { return }

        # Section 2: Local Hardware / Volume / Partition / SMART
        if ($Item.FilterGroup -in @('Local', 'Removable', 'Virtual', 'Optical')) {
            Write-Host "`n[2] VOLUME, PARTITION & SECURITY" -ForegroundColor Green
            Write-Host ("  Volume GUID        : {0}" -f (Get-SafeProp $d 'VolumeGuid' 'N/A'))
            Write-Host ("  Cluster Size       : {0} Bytes" -f (Get-SafeProp $d 'ClusterSizeBytes' 'N/A'))
            Write-Host ("  Compressed         : {0}" -f (Get-SafeProp $d 'Compressed' 'N/A'))
            Write-Host ("  Search Indexing    : {0}" -f (Get-SafeProp $d 'IndexingEnabled' 'N/A'))
            Write-Host ("  Deduplication      : {0}" -f (Get-SafeProp $d 'DeduplicationMode' 'N/A'))
            Write-Host ("  BitLocker Status   : {0}" -f (Get-SafeProp $d 'BitLockerStatus' 'N/A'))

            if ($null -ne (Get-SafeProp $d 'DiskNumber')) {
                Write-Host "`n[3] PHYSICAL DISK & HARDWARE TOPOLOGY" -ForegroundColor Green
                Write-Host ("  Disk Number        : {0}" -f $d.DiskNumber)
                Write-Host ("  Disk Model         : {0}" -f (Get-SafeProp $d 'DiskModel' 'N/A'))
                Write-Host ("  Serial Number      : {0}" -f (Get-SafeProp $d 'DiskSerialNumber' 'N/A'))
                Write-Host ("  Firmware Version   : {0}" -f (Get-SafeProp $d 'DiskFirmware' 'N/A'))
                Write-Host ("  Partition Style    : {0}" -f (Get-SafeProp $d 'PartitionStyle' 'N/A'))
                Write-Host ("  Partition # / Type : {0} / {1}" -f (Get-SafeProp $d 'PartitionNumber' 'N/A'), (Get-SafeProp $d 'PartitionType' 'N/A'))
                Write-Host ("  Flags              : Boot={0} | System={1} | Active={2}" -f (Get-SafeProp $d 'IsBoot' $false), (Get-SafeProp $d 'IsSystem' $false), (Get-SafeProp $d 'IsActive' $false))
                Write-Host ("  Hardware Location  : {0}" -f (Get-SafeProp $d 'DiskLocation' 'N/A'))
            }

            $smart = Get-SafeProp $d 'SmartCounters'
            if ($null -ne $smart) {
                Write-Host "`n[4] SMART / STORAGE RELIABILITY COUNTERS" -ForegroundColor Green
                Write-Host ("  Temperature        : {0} C" -f (Get-SafeProp $smart 'TemperatureC' 'N/A'))
                Write-Host ("  Wear Level         : {0} %" -f (Get-SafeProp $smart 'WearPercent' 'N/A'))
                Write-Host ("  Read Errors        : {0}" -f (Get-SafeProp $smart 'ReadErrors' 'N/A'))
                Write-Host ("  Write Errors       : {0}" -f (Get-SafeProp $smart 'WriteErrors' 'N/A'))
                Write-Host ("  Power-On Hours     : {0}" -f (Get-SafeProp $smart 'PowerOnHours' 'N/A'))
            }
            elseif (-not $script:IsElevated) {
                Write-Host "`n[4] SMART & BITLOCKER NOTE" -ForegroundColor DarkYellow
                Write-Host "  Run PowerShell as Administrator to inspect SMART Reliability Counters and BitLocker status." -ForegroundColor DarkGray
            }
        }

        # Section 3: Network Session Details
        if ($Item.FilterGroup -eq 'Network') {
            Write-Host "`n[2] NETWORK SHARE & PROTOCOL TELEMETRY" -ForegroundColor Green
            Write-Host ("  Remote UNC Path    : {0}" -f (Get-SafeProp $d 'RemoteUncPath' 'N/A'))
            Write-Host ("  Remote Server      : {0}" -f (Get-SafeProp $d 'ServerName' 'N/A'))
            Write-Host ("  Share Name         : {0}" -f (Get-SafeProp $d 'ShareName' 'N/A'))
            Write-Host ("  Network Provider   : {0}" -f (Get-SafeProp $d 'ProviderName' 'N/A'))
            Write-Host ("  Connection State   : {0}" -f (Get-SafeProp $d 'ConnectionState' 'N/A'))
            Write-Host ("  Persistent Mapping : {0}" -f (Get-SafeProp $d 'Persistent' 'N/A'))
            Write-Host ("  SMB Dialect        : {0}" -f (Get-SafeProp $d 'SmbDialect' 'N/A'))
            Write-Host ("  SMB Encrypted      : {0}" -f (Get-SafeProp $d 'SmbEncrypted' 'N/A'))
            Write-Host ("  SMB Signed         : {0}" -f (Get-SafeProp $d 'SmbSigned' 'N/A'))
            Write-Host ("  Mapped User        : {0}" -f (Get-SafeProp $d 'MappedUser' 'Current Session'))
        }

        # Section 4: Cloud Sync Details
        if ($Item.FilterGroup -eq 'Cloud') {
            Write-Host "`n[2] CLOUD PROVIDER & SYNC METADATA" -ForegroundColor Green
            foreach ($prop in $d.PSObject.Properties) {
                Write-Host ("  {0,-19}: {1}" -f $prop.Name, $prop.Value)
            }
        }

        Write-Host "`n================================================================================`n" -ForegroundColor Yellow
    }

    # --------------------------------------------------------------------------
    # Export Functions (CSV / JSON / HTML)
    # --------------------------------------------------------------------------
    function Resolve-ExportFilePath {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [string]$CustomPath,

            [Parameter(Mandatory = $true)]
            [string]$DefaultDir,

            [Parameter(Mandatory = $true)]
            [string]$Extension
        )

        $fileName = "$($script:SessionTimestamp)-Get-DriveInventory-$($env:COMPUTERNAME).$Extension"
        if ([string]::IsNullOrWhiteSpace($CustomPath)) {
            if (-not (Test-Path -Path $DefaultDir -PathType Container)) {
                try { New-Item -Path $DefaultDir -ItemType Directory -Force | Out-Null } catch { $DefaultDir = Join-Path $env:TEMP 'Logs'; New-Item -Path $DefaultDir -ItemType Directory -Force | Out-Null }
            }
            return (Join-Path -Path $DefaultDir -ChildPath $fileName)
        }

        if (Test-Path -Path $CustomPath -PathType Container) {
            return (Join-Path -Path $CustomPath -ChildPath $fileName)
        }

        $parent = Split-Path -Path $CustomPath -Parent
        if ($parent -and -not (Test-Path -Path $parent -PathType Container)) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }
        return $CustomPath
    }

    function Export-InventoryData {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [object[]]$Items,

            [Parameter(Mandatory = $true)]
            [ValidateSet('CSV', 'JSON', 'HTML')]
            [string]$Format,

            [Parameter(Mandatory = $true)]
            [string]$TargetPath
        )

        if (-not $PSCmdlet.ShouldProcess($TargetPath, "Export drive inventory as $Format")) {
            return
        }

        if ($Format -eq 'CSV') {
            $Items | Select-Object Id, DriveLetter, Category, FilterGroup, Label, FileSystem, Interface, MediaType, TotalGB, UsedGB, FreeGB, FreePercent, UsedPercent, Status, TargetPath |
                Export-Csv -Path $TargetPath -NoTypeInformation -Encoding UTF8
        }
        elseif ($Format -eq 'JSON') {
            $Items | ConvertTo-Json -Depth 6 | Set-Content -Path $TargetPath -Encoding UTF8
        }
        elseif ($Format -eq 'HTML') {
            $rows = foreach ($i in $Items) {
                $tot  = if ($null -ne $i.TotalGB) { '{0:N2} GB' -f $i.TotalGB } else { 'N/A' }
                $used = if ($null -ne $i.UsedGB) { '{0:N2} GB' -f $i.UsedGB } else { 'N/A' }
                $free = if ($null -ne $i.FreeGB) { '{0:N2} GB' -f $i.FreeGB } else { 'N/A' }
                $pct  = if ($null -ne $i.FreePercent) { '{0:N1}%' -f $i.FreePercent } else { 'N/A' }
                "<tr><td><strong>$([System.Net.WebUtility]::HtmlEncode($i.Id))</strong></td><td>$([System.Net.WebUtility]::HtmlEncode($i.Category))</td><td>$([System.Net.WebUtility]::HtmlEncode($i.Label))</td><td>$([System.Net.WebUtility]::HtmlEncode($i.FileSystem))</td><td>$([System.Net.WebUtility]::HtmlEncode($i.Interface))</td><td>$tot</td><td>$used</td><td>$free</td><td>$pct</td><td>$([System.Net.WebUtility]::HtmlEncode($i.Status))</td><td><code>$([System.Net.WebUtility]::HtmlEncode($i.TargetPath))</code></td></tr>"
            }
            $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Drive Inventory Report - $($env:COMPUTERNAME)</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #e2e8f0; margin: 24px; }
  h1 { color: #38bdf8; margin-bottom: 4px; }
  .meta { color: #94a3b8; margin-bottom: 20px; font-size: 0.9rem; }
  table { width: 100%; border-collapse: collapse; background: #1e293b; border-radius: 8px; overflow: hidden; }
  th, td { padding: 10px 12px; border-bottom: 1px solid #334155; text-align: left; font-size: 0.9rem; }
  th { background: #0284c7; color: #ffffff; }
  tr:hover { background: #26354d; }
  code { color: #a5f3fc; }
</style>
</head>
<body>
<h1>Storage &amp; Drive Inventory Report</h1>
<div class="meta">Host: <strong>$($env:COMPUTERNAME)</strong> | User: <strong>$($env:USERNAME)</strong> | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Version: $($script:ScriptVersion)</div>
<table>
  <thead>
    <tr><th>ID</th><th>Category</th><th>Label</th><th>FileSystem</th><th>Interface</th><th>Total</th><th>Used</th><th>Free</th><th>Free %</th><th>Status</th><th>Target / Path</th></tr>
  </thead>
  <tbody>
    $($rows -join "`n    ")
  </tbody>
</table>
</body>
</html>
"@
            Set-Content -Path $TargetPath -Value $html -Encoding UTF8
        }

        Write-Host "[+] Exported $Format report to: $TargetPath" -ForegroundColor Green
        Write-ScriptLog -Message "Exported $Format report to $TargetPath" -Level 'SUCCESS'
    }

    # --------------------------------------------------------------------------
    # Interactive Selector Loop
    # --------------------------------------------------------------------------
    function Invoke-InteractiveBrowser {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [object[]]$InitialItems,

            [Parameter(Mandatory = $true)]
            [string]$EffectiveLogDir
        )

        $currentItems = @($InitialItems)
        Show-DriveSummaryTable -Items $currentItems

        while ($true) {
            Write-Host "`nInteractive Actions: " -NoNewline -ForegroundColor Cyan
            Write-Host "[Drive ID / #] Inspect Details | [R] Refresh | [T] Table | [E] Export CSV/HTML | [Q] Quit" -ForegroundColor White
            $choice = (Read-Host -Prompt 'Select option or Drive ID (e.g. C, F, M, OD1, 1)').Trim()

            if ([string]::IsNullOrWhiteSpace($choice)) {
                continue
            }

            switch -Regex ($choice.ToUpperInvariant()) {
                '^(Q|QUIT|EXIT)$' {
                    Write-Host "[i] Exiting interactive drive browser." -ForegroundColor DarkGray
                    return
                }
                '^(R|REFRESH)$' {
                    $local   = @(Get-LocalDriveInventory -IncludeSystem:$IncludeSystemVolumes)
                    $network = @(Get-NetworkDriveInventory)
                    $cloud   = @(Get-CloudDriveInventory -ExistingVolumes $local)
                    $currentItems = @($local + $network + $cloud)
                    Show-DriveSummaryTable -Items $currentItems
                }
                '^(T|TABLE|LIST)$' {
                    Show-DriveSummaryTable -Items $currentItems
                }
                '^(E|EXPORT)$' {
                    $csvOut  = Resolve-ExportFilePath -CustomPath $CsvPath -DefaultDir $EffectiveLogDir -Extension 'csv'
                    $htmlOut = Resolve-ExportFilePath -CustomPath $ReportPath -DefaultDir $EffectiveLogDir -Extension 'html'
                    Export-InventoryData -Items $currentItems -Format 'CSV' -TargetPath $csvOut
                    Export-InventoryData -Items $currentItems -Format 'HTML' -TargetPath $htmlOut
                }
                default {
                    $selected = $null
                    $rowNum = 0
                    if ([int]::TryParse($choice, [ref]$rowNum)) {
                        if ($rowNum -ge 1 -and $rowNum -le $currentItems.Count) {
                            $selected = $currentItems[$rowNum - 1]
                        }
                    }
                    else {
                        $norm = Get-NormalizedDriveToken -Token $choice
                        $selected = $currentItems | Where-Object {
                            (Get-NormalizedDriveToken -Token $_.Id) -eq $norm -or
                            ($_.DriveLetter -and $_.DriveLetter.ToUpperInvariant() -eq $norm)
                        } | Select-Object -First 1
                    }

                    if ($null -ne $selected) {
                        Show-DriveDetailView -Item $selected
                    }
                    else {
                        Write-Host "[!] Drive '$choice' was not found. Enter a valid row number (#) or Drive ID (e.g. C, M, OD1)." -ForegroundColor Red
                    }
                }
            }
        }
    }
}

process {
    # Zero-Parameter or -Help/-h Standard Guard
    if ($Help -or $PSBoundParameters.Count -eq 0) {
        Show-ScriptHelp
        exit 0
    }

    $script:IsElevated = Test-IsElevated
    $effectiveLogDir = $LogDirectory

    if ($EnableLogging) {
        if ($PSCmdlet.ShouldProcess($LogDirectory, 'Initialize log directory')) {
            $effectiveLogDir = Initialize-LogDirectory -DirectoryPath $LogDirectory
            Write-ScriptLog -Message "Get-DriveInventory v$($script:ScriptVersion) started by $($env:USERNAME) on $($env:COMPUTERNAME) (Elevated=$($script:IsElevated))." -Level 'INFO'
        }
    }

    try {
        # Collect all storage tiers
        $localItems   = @(Get-LocalDriveInventory -IncludeSystem:$IncludeSystemVolumes)
        $networkItems = @(Get-NetworkDriveInventory)
        $cloudItems   = @(Get-CloudDriveInventory -ExistingVolumes $localItems)

        $allItems = @($localItems + $networkItems + $cloudItems)

        # Apply -DriveType category filter
        if ($DriveType -and ($DriveType -notcontains 'All')) {
            $allItems = @($allItems | Where-Object { $DriveType -contains $_.FilterGroup })
        }

        # Apply -Drive letter/ID filter
        if ($Drive -and $Drive.Count -gt 0) {
            $normTokens = @($Drive | ForEach-Object { Get-NormalizedDriveToken -Token $_ })
            $allItems = @($allItems | Where-Object {
                $idNorm = Get-NormalizedDriveToken -Token $_.Id
                $dlNorm = if ($_.DriveLetter) { $_.DriveLetter.ToUpperInvariant() } else { '' }
                ($normTokens -contains $idNorm) -or ($dlNorm -and ($normTokens -contains $dlNorm))
            })
        }

        Write-ScriptLog -Message "Inventory collected $($allItems.Count) matching drive entries." -Level 'INFO'

        # Exports
        if ($ExportCsv -or (-not [string]::IsNullOrWhiteSpace($CsvPath))) {
            $targetCsv = Resolve-ExportFilePath -CustomPath $CsvPath -DefaultDir $effectiveLogDir -Extension 'csv'
            Export-InventoryData -Items $allItems -Format 'CSV' -TargetPath $targetCsv
        }
        if ($ExportJson -or (-not [string]::IsNullOrWhiteSpace($JsonPath))) {
            $targetJson = Resolve-ExportFilePath -CustomPath $JsonPath -DefaultDir $effectiveLogDir -Extension 'json'
            Export-InventoryData -Items $allItems -Format 'JSON' -TargetPath $targetJson
        }
        if ($GenerateHtmlReport -or (-not [string]::IsNullOrWhiteSpace($ReportPath))) {
            $targetHtml = Resolve-ExportFilePath -CustomPath $ReportPath -DefaultDir $effectiveLogDir -Extension 'html'
            Export-InventoryData -Items $allItems -Format 'HTML' -TargetPath $targetHtml
        }

        # Display / Interaction Routing
        if ($Interactive) {
            Invoke-InteractiveBrowser -InitialItems $allItems -EffectiveLogDir $effectiveLogDir
        }
        else {
            if (-not $PassThru -or $List -or $Detailed -or ($Drive -and $Drive.Count -gt 0)) {
                Show-DriveSummaryTable -Items $allItems
            }

            if ($Detailed -or ($Drive -and $Drive.Count -gt 0)) {
                foreach ($item in $allItems) {
                    Show-DriveDetailView -Item $item
                }
            }
        }

        if ($PassThru) {
            $allItems
        }
    }
    catch {
        Write-ScriptLog -Message "Fatal error during drive inventory: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

end {
    Write-ScriptLog -Message 'Get-DriveInventory execution completed.' -Level 'INFO'
}
