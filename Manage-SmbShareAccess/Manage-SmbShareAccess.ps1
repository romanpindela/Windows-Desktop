<#
.SYNOPSIS
    Comprehensive management utility for Windows SMB Network Shares and NTFS permissions.

.DESCRIPTION
    Manage-SmbShareAccess.ps1 is an all-in-one, enterprise-grade PowerShell utility for 
    administering Windows SMB shares and backing file system NTFS ACLs. It automates:
      1. Share Discovery & Inventory (List all or specific shares, session metrics, hidden shares).
      2. Comprehensive Permission Auditing (Show side-by-side SMB and NTFS ACLs with consistency analysis).
      3. Share Lifecycle Management (Create/Enable shares with ABE, Encryption, Caching; Disable/Remove shares safely).
      4. Dual-Layer Access Control (Grant, Revoke, and Deny permissions across both SMB and NTFS simultaneously).

    Features automatic UAC elevation via language-independent SIDs, full bilingual OS support (English/Polish),
    preservation of directory ACL inheritance, simulation through -WhatIf / -Confirm, and centralized logging.

.PARAMETER Action
    The operation to execute:
      * List   : Enumerate SMB network shares with configuration and session metrics.
      * Show   : Display detailed SMB permissions, NTFS directory ACLs, and consistency analysis.
      * Create : Provision a new SMB share on an existing or new folder.
      * Remove : Safely remove/disable an SMB share while preserving the directory on disk.
      * Grant  : Grant specified permissions to target account(s) on SMB and NTFS.
      * Revoke : Revoke permissions for target account(s) from SMB and explicit NTFS ACLs.
      * Deny   : Explicitly block access for target account(s) on SMB and NTFS.

.PARAMETER ShareName
    Name of the SMB network share. Required for Show, Create, Remove, Grant, Revoke, Deny.
    Optional filter for List.

.PARAMETER Path
    Physical local folder path on disk (e.g., 'C:\Shares\Raporty'). Required for Action 'Create'.

.PARAMETER AccountName
    One or more user or group account names (e.g., 'DOMAIN\user', 'BUILTIN\Users', '.\LocalUser').
    Required for Action 'Grant', 'Revoke', 'Deny'.

.PARAMETER AccessRight
    Permission level to assign. Applicable to Grant and Deny.
    Valid values: 'Read', 'Change', 'FullControl'. Default: 'Read'.

.PARAMETER ApplyToNtfs
    Synchronize permission updates with the physical folder's NTFS ACL.
    Default: $true. Pass -ApplyToNtfs:$false to modify SMB share permissions only.

.PARAMETER Description
    Optional descriptive remark for the SMB share when creating it.

.PARAMETER EnableABE
    Enables Access-Based Enumeration (ABE). When enabled, users can only see files and folders
    they have read permissions for. Applicable to Action 'Create'.

.PARAMETER EncryptData
    Enforces end-to-end SMB 3.0+ data encryption over the wire. Applicable to Action 'Create'.

.PARAMETER CachingMode
    Offline file caching policy. Valid values: 'None', 'Manual', 'Programs', 'Documents', 'BranchCache'.
    Default: 'Manual'. Applicable to Action 'Create'.

.PARAMETER ConcurrentUserLimit
    Maximum number of simultaneous user connections allowed (0 = unlimited). Default: 0.

.PARAMETER IncludeHidden
    Include administrative/hidden shares (names ending with '$', e.g., C$, ADMIN$) during Action 'List'.

.PARAMETER LogPath
    Directory where execution logs will be written. Defaults to 'C:\Logs\'.

.PARAMETER Help
    Displays the interactive help and syntax reference. Aliased to -h.

.EXAMPLE
    .\Manage-SmbShareAccess.ps1 -Action List
    Lists all non-hidden SMB shares with path, description, ABE, encryption status, and session counts.

.EXAMPLE
    .\Manage-SmbShareAccess.ps1 -Action Show -ShareName "Raporty"
    Audits and displays SMB permissions and NTFS directory permissions for the 'Raporty' share with consistency analysis.

.EXAMPLE
    .\Manage-SmbShareAccess.ps1 -Action Create -ShareName "Projekty" -Path "D:\Shares\Projekty" -Description "Team Projects" -EnableABE -EncryptData
    Creates a new SMB share on D:\Shares\Projekty with Access-Based Enumeration and SMB Encryption enabled.

.EXAMPLE
    .\Manage-SmbShareAccess.ps1 -Action Remove -ShareName "StaryProjekt"
    Removes the 'StaryProjekt' SMB share while safely leaving the underlying files and folder intact on disk.

.EXAMPLE
    .\Manage-SmbShareAccess.ps1 -Action Grant -ShareName "Raporty" -AccountName "DOMENA\k.nowak" -AccessRight Read
    Grants Read access to the domain user on both the SMB share and underlying NTFS directory.

.EXAMPLE
    .\Manage-SmbShareAccess.ps1 -Action Revoke -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -WhatIf
    Simulates revoking access from SMB and NTFS without applying modifications.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Version:      2.0.0
    Requirements: PowerShell 5.1+ / PowerShell 7+, Windows 10/11 or Windows Server 2019+, Administrator privileges
#>

[CmdletBinding(DefaultParameterSetName = 'Help', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [Parameter(ParameterSetName = 'Execute', Mandatory = $true, Position = 0, HelpMessage = 'Action: List, Show, Create, Remove, Grant, Revoke, Deny.')]
    [ValidateSet('List', 'Show', 'Create', 'Remove', 'Grant', 'Revoke', 'Deny', IgnoreCase = $true)]
    [string]$Action,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, Position = 1, HelpMessage = 'Name of the SMB network share.')]
    [string]$ShareName,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, Position = 2, HelpMessage = 'Physical local folder path on disk.')]
    [string]$Path,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, Position = 3, HelpMessage = 'Target user or group account name(s).')]
    [string[]]$AccountName,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, Position = 4, HelpMessage = 'Permission level: Read, Change, FullControl.')]
    [ValidateSet('Read', 'Change', 'FullControl', IgnoreCase = $true)]
    [string]$AccessRight = 'Read',

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Synchronize permission with NTFS system.')]
    [switch]$ApplyToNtfs = $true,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Share description / remark.')]
    [string]$Description,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Enable Access-Based Enumeration (ABE).')]
    [switch]$EnableABE,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Enable SMB data encryption (SMB 3.0+).')]
    [switch]$EncryptData,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Offline caching mode.')]
    [ValidateSet('None', 'Manual', 'Programs', 'Documents', 'BranchCache', IgnoreCase = $true)]
    [string]$CachingMode = 'Manual',

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Concurrent user limit (0 = unlimited).')]
    [int]$ConcurrentUserLimit = 0,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Include administrative/hidden shares ($) in List action.')]
    [switch]$IncludeHidden,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Target directory path for log files.')]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath = 'C:\Logs',

    [Parameter(ParameterSetName = 'Help', Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ==============================================================================
# SCRIPT METADATA
# ==============================================================================
$Script:Metadata = @{
    Name        = 'Manage-SmbShareAccess.ps1'
    Version     = '2.0.0'
    Author      = 'Roman Pindela'
    Email       = 'roman.pindela@gmail.com'
    GitHub      = 'https://github.com/romanpindela'
    ExecutionId = (Get-Date -Format 'yyyyMMdd_HHmmss')
}

# ==============================================================================
# HELP & USAGE DISPLAY
# ==============================================================================
function Show-ScriptHelp {
    [CmdletBinding()]
    param ()

    Write-Host @"
================================================================================
MANAGE SMB SHARE AND NTFS ACCESS UTILITY - HELP & USAGE
Author : $($Script:Metadata.Author) ($($Script:Metadata.Email))
Version: $($Script:Metadata.Version)
GitHub : $($Script:Metadata.GitHub)
================================================================================

DESCRIPTION:
    Comprehensive, enterprise-grade PowerShell tool to manage every aspect of Windows
    SMB network shares and underlying NTFS folder security:
      1. Discover & Inventory shares (List)
      2. Audit & inspect combined SMB/NTFS permissions with consistency analysis (Show)
      3. Create/Enable shares with advanced settings (ABE, Encryption, Caching) (Create)
      4. Disable/Remove shares safely without deleting folder contents (Remove)
      5. Synchronize access control (Grant, Revoke, Deny) across SMB and NTFS (Grant/Revoke/Deny)

SYNTAX:
    # 1. Display Help:
    .\Manage-SmbShareAccess.ps1 [-Help | -h]

    # 2. List Shares:
    .\Manage-SmbShareAccess.ps1 -Action List [-ShareName <string>] [-IncludeHidden] [-LogPath <string>]

    # 3. Show & Audit Permissions:
    .\Manage-SmbShareAccess.ps1 -Action Show -ShareName <string> [-LogPath <string>]

    # 4. Create / Enable Share:
    .\Manage-SmbShareAccess.ps1 -Action Create -ShareName <string> -Path <string>
                                 [-Description <string>] [-EnableABE] [-EncryptData]
                                 [-CachingMode <None|Manual|Programs|Documents|BranchCache>]
                                 [-ConcurrentUserLimit <int>] [-WhatIf] [-Confirm]

    # 5. Remove / Disable Share:
    .\Manage-SmbShareAccess.ps1 -Action Remove -ShareName <string> [-WhatIf] [-Confirm]

    # 6. Manage Permissions (Grant / Revoke / Deny):
    .\Manage-SmbShareAccess.ps1 -Action <Grant | Revoke | Deny> -ShareName <string>
                                 -AccountName <string[]> [-AccessRight <Read|Change|FullControl>]
                                 [-ApplyToNtfs[:<bool>]] [-WhatIf] [-Confirm]

EXAMPLES:
    # Inventory all non-hidden shares:
    .\Manage-SmbShareAccess.ps1 -Action List

    # Audit permissions and consistency for 'Raporty':
    .\Manage-SmbShareAccess.ps1 -Action Show -ShareName "Raporty"

    # Create new share with Access-Based Enumeration (ABE) and Encryption:
    .\Manage-SmbShareAccess.ps1 -Action Create -ShareName "Projekty" -Path "D:\Shares\Projekty" -EnableABE -EncryptData

    # Grant Read access to domain user across SMB and NTFS:
    .\Manage-SmbShareAccess.ps1 -Action Grant -ShareName "Projekty" -AccountName "DOMENA\k.nowak" -AccessRight Read

    # Grant Modify (Change) access to a local group on SMB only:
    .\Manage-SmbShareAccess.ps1 -Action Grant -ShareName "Projekty" -AccountName "Edytorzy" -AccessRight Change -ApplyToNtfs:`$false

    # Revoke access across SMB and NTFS (simulated):
    .\Manage-SmbShareAccess.ps1 -Action Revoke -ShareName "Projekty" -AccountName "DOMENA\b.kowalski" -WhatIf

    # Disable / Remove an existing share:
    .\Manage-SmbShareAccess.ps1 -Action Remove -ShareName "StaryZasob"

================================================================================
"@ -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 1. Automatic Help Display when invoked without parameters or with -Help / -h
# ------------------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'Help' -or $Help -or [string]::IsNullOrWhiteSpace($Action)) {
    Show-ScriptHelp
    return
}

# ==============================================================================
# ADMINISTRATOR PRIVILEGE VALIDATION & AUTO-ELEVATION (Rule 11)
# ==============================================================================
# Check if the script is already running with Administrator privileges using SID (language-independent)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)

$isAdmin = $principal.IsInRole($adminSid)

if (-not $isAdmin) {
    # If not running as Admin, prompt for UAC consent and relaunch the script with elevated privileges
    Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    catch {
        Write-Error "Failed to request elevation: $($_.Exception.Message). Please execute this script in an elevated Administrator session."
    }
    Exit 1
}

# ==============================================================================
# LOGGING SYSTEM
# ==============================================================================
$Script:LogFilePath = $null

function Initialize-Logging {
    param ([string]$DestinationDirectory)

    try {
        if (-not (Test-Path -Path $DestinationDirectory)) {
            New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null
        }
        $dateStr = Get-Date -Format 'yyyyMMdd'
        $Script:LogFilePath = Join-Path -Path $DestinationDirectory -ChildPath "Manage-SmbShareAccess_$dateStr.log"
    }
    catch {
        Write-Warning "Could not initialize log directory '$DestinationDirectory'. Falling back to console output only. Details: $($_.Exception.Message)"
    }
}

function Write-LogMessage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [string]$Component = 'General'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $formattedLog = "[$timestamp] [$Level] [$Component] $Message"

    $color = switch ($Level) {
        'INFO'  { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'Cyan' }
        Default { 'White' }
    }

    Write-Host $formattedLog -ForegroundColor $color

    if ($Script:LogFilePath) {
        try {
            Add-Content -Path $Script:LogFilePath -Value $formattedLog -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            # Non-blocking logging failure
        }
    }
}

# ==============================================================================
# HELPER FUNCTIONS: IDENTITY RESOLUTION & PERMISSIONS MAPPING
# ==============================================================================
function Resolve-TargetAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Account
    )

    if ($Account -match '[`$;&|<>]') {
        throw "Account name '$Account' contains invalid or disallowed characters."
    }

    try {
        $ntAccount = New-Object System.Security.Principal.NTAccount($Account)
        $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
        $canonicalAccount = $sid.Translate([System.Security.Principal.NTAccount]).Value

        return [PSCustomObject]@{
            OriginalName  = $Account
            CanonicalName = $canonicalAccount
            SID           = $sid
            NTAccount     = $ntAccount
        }
    }
    catch {
        throw "Failed to resolve account '$Account' in the local machine or domain directory: $($_.Exception.Message)"
    }
}

function Get-MappedFileSystemRights {
    param ([string]$Right)

    switch ($Right) {
        'Read' {
            return [System.Security.AccessControl.FileSystemRights](
                [System.Security.AccessControl.FileSystemRights]::ReadAndExecute -bor
                [System.Security.AccessControl.FileSystemRights]::Synchronize
            )
        }
        'Change' {
            return [System.Security.AccessControl.FileSystemRights](
                [System.Security.AccessControl.FileSystemRights]::Modify -bor
                [System.Security.AccessControl.FileSystemRights]::Synchronize
            )
        }
        'FullControl' {
            return [System.Security.AccessControl.FileSystemRights]::FullControl
        }
        Default {
            throw "Unsupported AccessRight '$Right'."
        }
    }
}

function Get-MappedSmbAccessRight {
    param ([string]$Right)

    switch ($Right) {
        'Read'        { return 'Read' }
        'Change'      { return 'Change' }
        'FullControl' { return 'Full' }
        Default       { throw "Unsupported AccessRight '$Right'." }
    }
}

function Test-PermissionConsistency {
    param (
        [string]$SmbRight,
        [string]$NtfsRight
    )

    function Get-AccessRank ([string]$text) {
        if ($text -match 'Deny|Block') { return -1 }
        if ($text -match 'Full') { return 3 }
        if ($text -match 'Modify|Change') { return 2 }
        if ($text -match 'Read') { return 1 }
        return 0
    }

    $smbRank = Get-AccessRank $SmbRight
    $ntfsRank = Get-AccessRank $NtfsRight

    if ($smbRank -eq -1 -or $ntfsRank -eq -1) {
        return @{
            IsConsistent = $true
            Level        = 'INFO'
            Note         = "Explicit Deny rule active. Access is blocked over network or locally."
        }
    }

    if ($smbRank -gt $ntfsRank -and $ntfsRank -gt 0) {
        return @{
            IsConsistent = $false
            Level        = 'WARN'
            Note         = "SMB permission ($SmbRight) is wider than NTFS ($NtfsRight). Effective network access is limited to $NtfsRight by directory ACL."
        }
    }
    elseif ($ntfsRank -gt $smbRank -and $smbRank -gt 0) {
        return @{
            IsConsistent = $false
            Level        = 'WARN'
            Note         = "NTFS permission ($NtfsRight) is wider than SMB ($SmbRight). Remote network access is throttled to $SmbRight by share settings."
        }
    }
    else {
        return @{
            IsConsistent = $true
            Level        = 'INFO'
            Note         = "Permissions between SMB and NTFS are balanced."
        }
    }
}

function Get-AccountSmbAccessState {
    param (
        [string]$Share,
        [System.Security.Principal.SecurityIdentifier]$Sid
    )

    try {
        $currentAccess = Get-SmbShareAccess -Name $Share -ErrorAction Stop
        $match = $currentAccess | Where-Object {
            try {
                $itemSid = (New-Object System.Security.Principal.NTAccount($_.AccountName)).Translate([System.Security.Principal.SecurityIdentifier])
                $itemSid.Value -eq $Sid.Value
            }
            catch {
                $_.AccountName -eq $Sid.Value
            }
        }

        if ($match) {
            return ($match | ForEach-Object { "$($_.AccessControlType):$($_.AccessRight)" }) -join ', '
        }
        return 'None'
    }
    catch {
        return "Unknown"
    }
}

function Get-AccountNtfsAccessState {
    param (
        [string]$FolderPath,
        [System.Security.Principal.SecurityIdentifier]$Sid
    )

    try {
        $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
        $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
        $matching = $rules | Where-Object { $_.IdentityReference.Value -eq $Sid.Value }

        if ($matching) {
            $summaries = foreach ($r in $matching) {
                $source = if ($r.IsInherited) { "Inherited" } else { "Explicit" }
                "$($r.AccessControlType):$($r.FileSystemRights) ($source)"
            }
            return ($summaries -join '; ')
        }
        return 'None'
    }
    catch {
        return "Unknown"
    }
}

# ==============================================================================
# ACTION HANDLERS
# ==============================================================================

function Invoke-ListShares {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "Querying SMB network shares on local machine..." -Level INFO -Component 'List'

    $allShares = Get-SmbShare -ErrorAction Stop
    $filtered = $allShares | Where-Object {
        if (-not $IncludeHidden -and $_.Name -match '\$$') { return $false }
        if ($ShareName -and $_.Name -notlike "*$ShareName*") { return $false }
        return $true
    }

    if (-not $filtered -or $filtered.Count -eq 0) {
        Write-LogMessage -Message "No matching SMB shares found." -Level WARN -Component 'List'
        return
    }

    # Query active SMB sessions for connection statistics
    $sessions = Get-SmbSession -ErrorAction SilentlyContinue

    $results = foreach ($s in $filtered) {
        $activeClientCount = 0
        if ($sessions) {
            $matchingSessions = $sessions | Where-Object {
                try {
                    $openFiles = Get-SmbOpenFile -SessionId $_.SessionId -ErrorAction SilentlyContinue
                    $openFiles | Where-Object { $_.ShareRelativePath -or $_.Path -like "*$($s.Path)*" }
                } catch { $false }
            }
            $activeClientCount = ($matchingSessions | Measure-Object).Count
        }

        [PSCustomObject]@{
            ShareName      = $s.Name
            Path           = $s.Path
            Description    = if ([string]::IsNullOrWhiteSpace($s.Description)) { '-' } else { $s.Description }
            ABE_Enabled    = ($s.FolderEnumerationMode -eq 'AccessBased')
            Encryption     = $s.EncryptData
            CachingMode    = $s.CachingMode
            Special_Hidden = ($s.Special -or $s.Name -match '\$$')
        }
    }

    Write-Host "`n=== SMB Network Shares Inventory ($($results.Count) found) ===" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
    Write-LogMessage -Message "Successfully listed $($results.Count) share(s)." -Level INFO -Component 'List'
}

function Invoke-ShowPermissions {
    [CmdletBinding()]
    param ()

    if ([string]::IsNullOrWhiteSpace($ShareName)) {
        throw "Parameter -ShareName is required for Action 'Show'."
    }

    Write-LogMessage -Message "Auditing permissions for SMB share '$ShareName'..." -Level INFO -Component 'Show'
    $share = Get-SmbShare -Name $ShareName -ErrorAction Stop
    $folderPath = $share.Path

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "SHARE AUDIT REPORT: $ShareName" -ForegroundColor Cyan
    Write-Host "Physical Directory : $folderPath" -ForegroundColor White
    Write-Host "ABE (Access-Based) : $($share.FolderEnumerationMode)" -ForegroundColor White
    Write-Host "Data Encryption    : $($share.EncryptData)" -ForegroundColor White
    Write-Host "Caching Mode       : $($share.CachingMode)" -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan

    # 1. SMB Share Permissions
    Write-Host "`n--- 1. SMB Share Permissions (Network Boundary) ---" -ForegroundColor Yellow
    $smbAccess = Get-SmbShareAccess -Name $ShareName -ErrorAction Stop
    $smbRows = foreach ($sa in $smbAccess) {
        [PSCustomObject]@{
            AccountName = $sa.AccountName
            AccessType  = $sa.AccessControlType
            AccessRight = $sa.AccessRight
        }
    }
    $smbRows | Format-Table -AutoSize

    # 2. NTFS Directory Permissions
    Write-Host "--- 2. NTFS Folder Permissions (File System Boundary) ---" -ForegroundColor Yellow
    if (-not (Test-Path -Path $folderPath)) {
        Write-LogMessage -Message "Target folder '$folderPath' does not exist on disk." -Level ERROR -Component 'Show'
        return
    }

    $acl = Get-Acl -Path $folderPath -ErrorAction Stop
    $ntfsRules = $acl.GetAccessRules($true, $true, [System.Security.Principal.NTAccount])
    $ntfsRows = foreach ($rule in $ntfsRules) {
        [PSCustomObject]@{
            IdentityReference = $rule.IdentityReference.Value
            AccessType        = $rule.AccessControlType
            FileSystemRights  = $rule.FileSystemRights
            IsInherited       = $rule.IsInherited
            InheritanceFlags  = $rule.InheritanceFlags
        }
    }
    $ntfsRows | Format-Table -AutoSize

    # 3. Consistency Analysis
    Write-Host "--- 3. Effective Permission Consistency Analysis ---" -ForegroundColor Yellow
    $auditAccounts = @($smbRows.AccountName | Select-Object -Unique)

    $analysisRows = foreach ($accName in $auditAccounts) {
        try {
            $resolved = Resolve-TargetAccount -Account $accName
            $sid = $resolved.SID
            $canonical = $resolved.CanonicalName
            $smbState = Get-AccountSmbAccessState -Share $ShareName -Sid $sid
            $ntfsState = Get-AccountNtfsAccessState -FolderPath $folderPath -Sid $sid
            $check = Test-PermissionConsistency -SmbRight $smbState -NtfsRight $ntfsState

            [PSCustomObject]@{
                Account          = $canonical
                SMB_Access       = $smbState
                NTFS_Access      = $ntfsState
                Status           = if ($check.IsConsistent) { "BALANCED" } else { "MISMATCH" }
                AnalysisNote     = $check.Note
            }
        }
        catch {
            [PSCustomObject]@{
                Account      = $accName
                SMB_Access   = 'Unknown'
                NTFS_Access  = 'Unknown'
                Status       = 'UNRESOLVED'
                AnalysisNote = "Could not resolve identity: $($_.Exception.Message)"
            }
        }
    }

    $analysisRows | Format-Table -AutoSize
    Write-LogMessage -Message "Audit complete for share '$ShareName'." -Level INFO -Component 'Show'
}

function Invoke-CreateShare {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    if ([string]::IsNullOrWhiteSpace($ShareName)) {
        throw "Parameter -ShareName is mandatory for Action 'Create'."
    }
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Parameter -Path is mandatory for Action 'Create'."
    }

    Write-LogMessage -Message "Preparing to create SMB share '$ShareName' -> '$Path'..." -Level INFO -Component 'Create'

    # Check for existing share
    $existing = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    if ($existing) {
        throw "An SMB share named '$ShareName' already exists pointing to '$($existing.Path)'."
    }

    # Ensure backing folder exists
    if (-not (Test-Path -Path $Path)) {
        if ($PSCmdlet.ShouldProcess($Path, "Create Physical Directory")) {
            Write-LogMessage -Message "Directory '$Path' does not exist. Creating..." -Level INFO -Component 'Create'
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-LogMessage -Message "Directory created successfully." -Level INFO -Component 'Create'
        }
    }

    # Build New-SmbShare parameters
    $shareParams = @{
        Name                   = $ShareName
        Path                   = $Path
        FolderEnumerationMode  = if ($EnableABE) { 'AccessBased' } else { 'Unrestricted' }
        EncryptData            = [bool]$EncryptData
        CachingMode            = $CachingMode
        Force                  = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $shareParams['Description'] = $Description
    }
    if ($ConcurrentUserLimit -gt 0) {
        $shareParams['ConcurrentUserLimit'] = $ConcurrentUserLimit
    }

    $targetDesc = "SMB Share '$ShareName' on '$Path' (ABE: $EnableABE, Encrypt: $EncryptData, Caching: $CachingMode)"
    if ($PSCmdlet.ShouldProcess($targetDesc, "Create SMB Share")) {
        New-SmbShare @shareParams -ErrorAction Stop | Out-Null
        Write-LogMessage -Message "SMB Share '$ShareName' created successfully." -Level INFO -Component 'Create'

        Write-Host "`n=== Newly Created Share Configuration ===" -ForegroundColor Green
        Get-SmbShare -Name $ShareName | Format-List Name, Path, Description, FolderEnumerationMode, EncryptData, CachingMode
    }
}

function Invoke-RemoveShare {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    if ([string]::IsNullOrWhiteSpace($ShareName)) {
        throw "Parameter -ShareName is mandatory for Action 'Remove'."
    }

    Write-LogMessage -Message "Preparing to disable/remove SMB share '$ShareName'..." -Level INFO -Component 'Remove'

    $share = Get-SmbShare -Name $ShareName -ErrorAction Stop
    $folderPath = $share.Path

    # Check for active connected sessions
    try {
        $sessions = Get-SmbSession -ErrorAction SilentlyContinue
        $openFiles = Get-SmbOpenFile -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*$folderPath*" }
        if ($openFiles) {
            Write-LogMessage -Message "Warning: There are currently $($openFiles.Count) open file handle(s) on share '$ShareName'." -Level WARN -Component 'Remove'
        }
    }
    catch {
        # Non-critical warning probe
    }

    $targetDesc = "SMB Share '$ShareName' (backing folder '$folderPath' will NOT be deleted)"
    if ($PSCmdlet.ShouldProcess($targetDesc, "Remove SMB Share")) {
        Remove-SmbShare -Name $ShareName -Force -ErrorAction Stop | Out-Null
        Write-LogMessage -Message "SMB Share '$ShareName' was successfully removed. Physical directory '$folderPath' remains intact." -Level INFO -Component 'Remove'
        Write-Host "Success: SMB Share '$ShareName' disabled/removed." -ForegroundColor Green
    }
}

function Invoke-ManagePermissions {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    if ([string]::IsNullOrWhiteSpace($ShareName)) {
        throw "Parameter -ShareName is mandatory for Action '$Action'."
    }
    if (-not $AccountName -or $AccountName.Count -eq 0) {
        throw "Parameter -AccountName is mandatory for Action '$Action'."
    }

    Write-LogMessage -Message "Validating SMB share '$ShareName'..." -Level DEBUG -Component 'Permissions'
    $share = Get-SmbShare -Name $ShareName -ErrorAction Stop
    $folderPath = $share.Path

    if (-not (Test-Path -Path $folderPath -PathType Container)) {
        throw "Backing folder '$folderPath' for share '$ShareName' does not exist."
    }

    foreach ($account in $AccountName) {
        Write-LogMessage -Message "Processing account: '$account'..." -Level INFO -Component 'Permissions'
        $resolved = Resolve-TargetAccount -Account $account
        $canonical = $resolved.CanonicalName
        $sid = $resolved.SID
        $ntAccount = $resolved.NTAccount

        # State BEFORE
        $smbStateBefore = Get-AccountSmbAccessState -Share $ShareName -Sid $sid
        $ntfsStateBefore = Get-AccountNtfsAccessState -FolderPath $folderPath -Sid $sid
        Write-LogMessage -Message "[BEFORE] SMB: $smbStateBefore | NTFS: $ntfsStateBefore" -Level INFO -Component 'StateBefore'

        # ----------------------------------------------------------------------
        # A. SMB Share Permission Action
        # ----------------------------------------------------------------------
        $smbAccessRight = Get-MappedSmbAccessRight -Right $AccessRight
        $smbTargetDesc = "SMB Share '$ShareName' for account '$canonical'"

        switch ($Action) {
            'Grant' {
                if ($PSCmdlet.ShouldProcess($smbTargetDesc, "Grant SMB Access ($smbAccessRight)")) {
                    Write-LogMessage -Message "Granting SMB share access ($smbAccessRight) to '$canonical'..." -Level INFO -Component 'SmbAction'
                    Grant-SmbShareAccess -Name $ShareName -AccountName $canonical -AccessRight $smbAccessRight -Force -ErrorAction Stop | Out-Null
                }
            }
            'Revoke' {
                if ($PSCmdlet.ShouldProcess($smbTargetDesc, "Revoke SMB Access")) {
                    Write-LogMessage -Message "Revoking SMB share access for '$canonical'..." -Level INFO -Component 'SmbAction'
                    Revoke-SmbShareAccess -Name $ShareName -AccountName $canonical -Force -ErrorAction Stop | Out-Null
                }
            }
            'Deny' {
                if ($PSCmdlet.ShouldProcess($smbTargetDesc, "Block/Deny SMB Access")) {
                    Write-LogMessage -Message "Blocking SMB share access for '$canonical'..." -Level WARN -Component 'SmbAction'
                    Block-SmbShareAccess -Name $ShareName -AccountName $canonical -Force -ErrorAction Stop | Out-Null
                }
            }
        }

        # ----------------------------------------------------------------------
        # B. NTFS Folder Permission Action
        # ----------------------------------------------------------------------
        if ($ApplyToNtfs) {
            $ntfsTargetDesc = "NTFS Folder '$folderPath' for account '$canonical'"

            if ($PSCmdlet.ShouldProcess($ntfsTargetDesc, "$Action NTFS Permissions ($AccessRight)")) {
                Write-LogMessage -Message "Updating NTFS ACL on directory '$folderPath'..." -Level INFO -Component 'NtfsAction'
                $acl = Get-Acl -Path $folderPath -ErrorAction Stop

                $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags](
                    [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
                    [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
                )
                $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None

                switch ($Action) {
                    'Grant' {
                        $fileRights = Get-MappedFileSystemRights -Right $AccessRight
                        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            $ntAccount,
                            $fileRights,
                            $inheritanceFlags,
                            $propagationFlags,
                            [System.Security.AccessControl.AccessControlType]::Allow
                        )
                        $acl.SetAccessRule($rule)
                        Set-Acl -Path $folderPath -AclObject $acl -ErrorAction Stop
                        Write-LogMessage -Message "Applied NTFS Allow rule: $AccessRight ($fileRights)." -Level INFO -Component 'NtfsAction'
                    }
                    'Revoke' {
                        $explicitRules = $acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier])
                        $targetRules = $explicitRules | Where-Object { $_.IdentityReference.Value -eq $sid.Value }

                        $removedCount = 0
                        foreach ($ruleToRemove in $targetRules) {
                            $acl.RemoveAccessRuleSpecific($ruleToRemove) | Out-Null
                            $removedCount++
                        }

                        if ($removedCount -gt 0) {
                            Set-Acl -Path $folderPath -AclObject $acl -ErrorAction Stop
                            Write-LogMessage -Message "Removed $removedCount explicit NTFS rule(s) for '$canonical'." -Level INFO -Component 'NtfsAction'
                        } else {
                            Write-LogMessage -Message "No explicit NTFS rules found to remove for '$canonical'. (Inherited rules preserved)." -Level INFO -Component 'NtfsAction'
                        }
                    }
                    'Deny' {
                        $fileRights = Get-MappedFileSystemRights -Right $AccessRight
                        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                            $ntAccount,
                            $fileRights,
                            $inheritanceFlags,
                            $propagationFlags,
                            [System.Security.AccessControl.AccessControlType]::Deny
                        )
                        $acl.AddAccessRule($rule)
                        Set-Acl -Path $folderPath -AclObject $acl -ErrorAction Stop
                        Write-LogMessage -Message "Applied NTFS Deny rule: $AccessRight." -Level WARN -Component 'NtfsAction'
                    }
                }
            }
        }
        else {
            Write-LogMessage -Message "Skipped NTFS update (-ApplyToNtfs:`$false was specified)." -Level INFO -Component 'NtfsAction'
        }

        # State AFTER & Consistency Check
        $smbStateAfter = Get-AccountSmbAccessState -Share $ShareName -Sid $sid
        $ntfsStateAfter = Get-AccountNtfsAccessState -FolderPath $folderPath -Sid $sid
        Write-LogMessage -Message "[AFTER]  SMB: $smbStateAfter | NTFS: $ntfsStateAfter" -Level INFO -Component 'StateAfter'

        $consistency = Test-PermissionConsistency -SmbRight $smbStateAfter -NtfsRight $ntfsStateAfter
        if (-not $consistency.IsConsistent) {
            Write-LogMessage -Message "[CONSISTENCY WARNING] $($consistency.Note)" -Level WARN -Component 'Consistency'
        } else {
            Write-LogMessage -Message "[CONSISTENCY OK] $($consistency.Note)" -Level INFO -Component 'Consistency'
        }

        # Summary card
        Write-Host "`n--- Summary: $canonical ---" -ForegroundColor Cyan
        [PSCustomObject]@{
            Account          = $canonical
            ActionApplied    = $Action
            SMB_Before       = $smbStateBefore
            SMB_After        = $smbStateAfter
            NTFS_Before      = $ntfsStateBefore
            NTFS_After       = $ntfsStateAfter
            ConsistencyCheck = $consistency.Note
        } | Format-List
    }
}

# ==============================================================================
# MAIN ROUTING CONTROLLER
# ==============================================================================
try {
    Initialize-Logging -DestinationDirectory $LogPath

    Write-LogMessage -Message "================================================================================" -Level DEBUG -Component 'Init'
    Write-LogMessage -Message "Executing $($Script:Metadata.Name) v$($Script:Metadata.Version) [Action: $Action] [ExecutionId: $($Script:Metadata.ExecutionId)]" -Level INFO -Component 'Init'

    switch ($Action) {
        'List'   { Invoke-ListShares }
        'Show'   { Invoke-ShowPermissions }
        'Create' { Invoke-CreateShare }
        'Remove' { Invoke-RemoveShare }
        { $_ -in 'Grant', 'Revoke', 'Deny' } { Invoke-ManagePermissions }
        Default  { throw "Unrecognized Action '$Action'." }
    }

    Write-LogMessage -Message "Action '$Action' finished successfully." -Level INFO -Component 'Complete'
}
catch {
    $err = $_.Exception.Message
    Write-LogMessage -Message "Execution error: $err" -Level ERROR -Component 'Execution'
    Write-Error "Execution failed: $err"
}
