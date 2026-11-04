<#
.SYNOPSIS
    Manages and synchronizes SMB Share and NTFS file system permissions on Windows.

.DESCRIPTION
    Set-SmbShareAccessRule automates access management for Windows SMB network shares
    and their underlying NTFS directory ACLs. It provides unified Grant, Revoke, and Deny
    actions across both security boundaries, verifies account identities independently of
    system language (English/Polish), safeguards existing ACL inheritance, performs
    permission consistency analysis (identifying restrictive mismatches between SMB and NTFS),
    and supports WhatIf simulation and file logging.

.PARAMETER ShareName
    The name of the target SMB network share (e.g., 'RaportyFinansowe', 'Projekty').

.PARAMETER AccountName
    One or more user or group account names to modify (e.g., 'DOMAIN\user', 'BUILTIN\Users', '.\LocalUser').

.PARAMETER Action
    The permission action to execute.
    Valid values: 'Grant', 'Revoke', 'Deny'.

.PARAMETER AccessRight
    The level of access to assign. Defaults to 'Read'.
    Valid values: 'Read', 'Change', 'FullControl'.

.PARAMETER ApplyToNtfs
    Specifies whether the change should also be applied to the folder's NTFS ACL.
    Defaults to $true. Use -ApplyToNtfs:$false to modify SMB permissions only.

.PARAMETER LogPath
    The directory where execution log files will be written. Defaults to 'C:\Logs\'.

.PARAMETER Help
    Displays the help and usage guide. Aliased to -h.

.EXAMPLE
    .\Set-SmbShareAccessRule.ps1 -ShareName "RaportyFinansowe" -AccountName "DOMENA\k.nowak" -Action Grant -AccessRight Read
    Grants Read access to the domain user on both the SMB share and the underlying NTFS directory.

.EXAMPLE
    .\Set-SmbShareAccessRule.ps1 -ShareName "Projekty" -AccountName "EdytorzyProjektow" -Action Grant -AccessRight Change
    Grants Modify (Change) permissions to the specified group on SMB and NTFS.

.EXAMPLE
    .\Set-SmbShareAccessRule.ps1 -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -Action Revoke
    Revokes SMB share access and removes explicit NTFS access rules for the user.

.EXAMPLE
    .\Set-SmbShareAccessRule.ps1 -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -Action Revoke -WhatIf
    Simulates the revocation without applying any actual changes.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Version:      1.0.0
    Requirements: PowerShell 5.1+ / PowerShell 7+, Windows 10/11 or Windows Server 2019+, Administrator privileges
#>

[CmdletBinding(DefaultParameterSetName = 'Help', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [Parameter(ParameterSetName = 'Execute', Mandatory = $true, Position = 0, HelpMessage = 'Name of the SMB share.')]
    [ValidateNotNullOrEmpty()]
    [string]$ShareName,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $true, Position = 1, HelpMessage = 'Target user or group account name(s).')]
    [ValidateNotNullOrEmpty()]
    [string[]]$AccountName,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $true, Position = 2, HelpMessage = 'Action to perform: Grant, Revoke, or Deny.')]
    [ValidateSet('Grant', 'Revoke', 'Deny', IgnoreCase = $true)]
    [string]$Action,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, Position = 3, HelpMessage = 'Permission level: Read, Change, FullControl.')]
    [ValidateSet('Read', 'Change', 'FullControl', IgnoreCase = $true)]
    [string]$AccessRight = 'Read',

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false, HelpMessage = 'Synchronize permission with NTFS system.')]
    [switch]$ApplyToNtfs = $true,

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
    Name        = 'Set-SmbShareAccessRule.ps1'
    Version     = '1.0.0'
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
MANAGE SMB SHARE AND NTFS ACCESS - HELP & USAGE
Author : $($Script:Metadata.Author) ($($Script:Metadata.Email))
Version: $($Script:Metadata.Version)
GitHub : $($Script:Metadata.GitHub)
================================================================================

DESCRIPTION:
    Automates and synchronizes access control across Windows SMB network shares
    and underlying NTFS folder permissions (ACL). Provides safety validation,
    elevation checks, consistency reporting, and simulation via -WhatIf.

SYNTAX:
    .\Set-SmbShareAccessRule.ps1 [-Help | -h]
    .\Set-SmbShareAccessRule.ps1 -ShareName <string> -AccountName <string[]> -Action <Grant|Revoke|Deny>
                                [-AccessRight <Read|Change|FullControl>] [-ApplyToNtfs[:<bool>]]
                                [-LogPath <string>] [-WhatIf] [-Confirm]

PARAMETERS:
    -ShareName <string>
        Name of the existing SMB network share. (Mandatory for Execute)

    -AccountName <string[]>
        One or more local or Active Directory account names (e.g., 'DOMAIN\user', 'BUILTIN\Users').

    -Action <string>
        The security action to take:
          * Grant  : Assigns the specified access level on SMB and NTFS.
          * Revoke : Removes the access entry from SMB and explicit rules from NTFS.
          * Deny   : Explicitly blocks access on SMB and NTFS.

    -AccessRight <string>
        Permission level to assign. Applicable to Grant and Deny.
          * Read        : SMB Read | NTFS ReadAndExecute, Synchronize
          * Change      : SMB Change | NTFS Modify, Synchronize
          * FullControl : SMB Full | NTFS FullControl
        Default: Read

    -ApplyToNtfs [:<bool>]
        Whether to synchronize changes to the physical directory's NTFS ACL.
        Default: `$true. Use -ApplyToNtfs:`$false to update SMB only.

    -LogPath <string>
        Folder where execution logs will be recorded. Default: 'C:\Logs'.

    -Help, -h
        Displays this help information.

EXAMPLES:
    # 1. Grant Read access to a domain account (SMB + NTFS):
    .\Set-SmbShareAccessRule.ps1 -ShareName "RaportyFinansowe" -AccountName "DOMENA\k.nowak" -Action Grant -AccessRight Read

    # 2. Grant Modify (Change) access to a local group:
    .\Set-SmbShareAccessRule.ps1 -ShareName "Projekty" -AccountName "EdytorzyProjektow" -Action Grant -AccessRight Change

    # 3. Revoke access from both SMB and NTFS:
    .\Set-SmbShareAccessRule.ps1 -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -Action Revoke

    # 4. Simulate revocation without making modifications:
    .\Set-SmbShareAccessRule.ps1 -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -Action Revoke -WhatIf

================================================================================
"@ -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 1. Automatic Help Display when invoked without parameters or with -Help / -h
# ------------------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'Help' -or $Help -or (-not $PSBoundParameters.ContainsKey('ShareName'))) {
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

    # Console output color mapping
    $color = switch ($Level) {
        'INFO'  { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'Cyan' }
        Default { 'White' }
    }

    Write-Host $formattedLog -ForegroundColor $color

    # Append to log file if available
    if ($Script:LogFilePath) {
        try {
            Add-Content -Path $Script:LogFilePath -Value $formattedLog -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            # Prevent logging errors from terminating the primary workflow
        }
    }
}

# ==============================================================================
# HELPER FUNCTIONS: IDENTITY RESOLUTION & PERMISSIONS
# ==============================================================================
function Resolve-TargetAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Account
    )

    # 1. Clean input against dangerous characters
    if ($Account -match '[`$;&|<>]') {
        throw "Account name '$Account' contains invalid or disallowed characters."
    }

    # 2. Translate NTAccount to SID (language-independent verification)
    try {
        $ntAccount = New-Object System.Security.Principal.NTAccount($Account)
        $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
        # Translate back to ensure canonical formatted identity name
        $canonicalAccount = $sid.Translate([System.Security.Principal.NTAccount]).Value

        return [PSCustomObject]@{
            OriginalName = $Account
            CanonicalName = $canonicalAccount
            SID          = $sid
            NTAccount    = $ntAccount
        }
    }
    catch {
        throw "Failed to resolve account '$Account' in the local machine or domain directory: $($_.Exception.Message)"
    }
}

function Get-AccountSmbAccessState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Share,

        [Parameter(Mandatory = $true)]
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
        return "Unknown ($($_.Exception.Message))"
    }
}

function Get-AccountNtfsAccessState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [System.Security.Principal.SecurityIdentifier]$Sid
    )

    try {
        $acl = Get-Acl -Path $Path -ErrorAction Stop
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
        return "Unknown ($($_.Exception.Message))"
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

    # Convert textual access state to rank: None(0), Read(1), Change/Modify(2), FullControl(3), Deny(-1)
    function Get-AccessRank ([string]$text) {
        if ($text -match 'Deny') { return -1 }
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
            Note = "Explicit Deny rule active. Access is blocked over network and/or locally."
        }
    }

    if ($smbRank -gt $ntfsRank -and $ntfsRank -gt 0) {
        return @{
            IsConsistent = $false
            Level = 'WARN'
            Note = "SMB permission ($SmbRight) is more permissive than NTFS permission ($NtfsRight). Effective network access is limited by NTFS."
        }
    }
    elseif ($ntfsRank -gt $smbRank -and $smbRank -gt 0) {
        return @{
            IsConsistent = $false
            Level = 'WARN'
            Note = "NTFS permission ($NtfsRight) is more permissive than SMB permission ($SmbRight). Remote network access is throttled by SMB share settings."
        }
    }
    else {
        return @{
            IsConsistent = $true
            Level = 'INFO'
            Note = "Permissions between SMB and NTFS are balanced."
        }
    }
}

# ==============================================================================
# MAIN EXECUTION WORKFLOW
# ==============================================================================
try {
    Initialize-Logging -DestinationDirectory $LogPath

    Write-LogMessage -Message "================================================================================" -Level DEBUG -Component 'Init'
    Write-LogMessage -Message "Executing $($Script:Metadata.Name) v$($Script:Metadata.Version) [ExecutionId: $($Script:Metadata.ExecutionId)]" -Level INFO -Component 'Init'
    Write-LogMessage -Message "Target Share: '$ShareName' | Action: '$Action' | AccessRight: '$AccessRight' | ApplyToNtfs: $ApplyToNtfs" -Level INFO -Component 'Init'

    # 1. Verify existence of the specified SMB Share
    Write-LogMessage -Message "Validating SMB share existence for '$ShareName'..." -Level DEBUG -Component 'ShareValidation'
    $share = Get-SmbShare -Name $ShareName -ErrorAction Stop

    $folderPath = $share.Path
    Write-LogMessage -Message "SMB Share found. Physical directory path: '$folderPath'" -Level INFO -Component 'ShareValidation'

    # 2. Verify physical filesystem directory
    if (-not (Test-Path -Path $folderPath -PathType Container)) {
        throw "Physical path '$folderPath' backing share '$ShareName' does not exist or is not a container directory."
    }

    # 3. Process each specified account
    foreach ($account in $AccountName) {
        Write-LogMessage -Message "--------------------------------------------------------------------------------" -Level DEBUG -Component 'AccountLoop'
        Write-LogMessage -Message "Resolving identity for account input: '$account'..." -Level INFO -Component 'AccountResolution'

        $resolved = Resolve-TargetAccount -Account $account
        $canonical = $resolved.CanonicalName
        $sid = $resolved.SID
        $ntAccount = $resolved.NTAccount

        Write-LogMessage -Message "Identity verified: '$canonical' (SID: $($sid.Value))" -Level INFO -Component 'AccountResolution'

        # Inspect and record initial state (Before)
        $smbStateBefore = Get-AccountSmbAccessState -Share $ShareName -Sid $sid
        $ntfsStateBefore = Get-AccountNtfsAccessState -Path $folderPath -Sid $sid
        Write-LogMessage -Message "[BEFORE] SMB Access: $smbStateBefore | NTFS Access: $ntfsStateBefore" -Level INFO -Component 'StateBefore'

        # ----------------------------------------------------------------------
        # A. SMB Share Permission Modification
        # ----------------------------------------------------------------------
        $smbAccessRight = Get-MappedSmbAccessRight -Right $AccessRight
        $smbTargetDesc = "SMB Share '$ShareName' for account '$canonical'"

        switch ($Action) {
            'Grant' {
                if ($PSCmdlet.ShouldProcess($smbTargetDesc, "Grant SMB Access ($smbAccessRight)")) {
                    Write-LogMessage -Message "Granting SMB share access ($smbAccessRight) to '$canonical'..." -Level INFO -Component 'SmbAction'
                    Grant-SmbShareAccess -Name $ShareName -AccountName $canonical -AccessRight $smbAccessRight -Force -ErrorAction Stop | Out-Null
                    Write-LogMessage -Message "Successfully granted SMB share access." -Level INFO -Component 'SmbAction'
                }
            }
            'Revoke' {
                if ($PSCmdlet.ShouldProcess($smbTargetDesc, "Revoke SMB Access")) {
                    Write-LogMessage -Message "Revoking SMB share access for '$canonical'..." -Level INFO -Component 'SmbAction'
                    Revoke-SmbShareAccess -Name $ShareName -AccountName $canonical -Force -ErrorAction Stop | Out-Null
                    Write-LogMessage -Message "Successfully revoked SMB share access." -Level INFO -Component 'SmbAction'
                }
            }
            'Deny' {
                if ($PSCmdlet.ShouldProcess($smbTargetDesc, "Deny/Block SMB Access")) {
                    Write-LogMessage -Message "Blocking SMB share access for '$canonical'..." -Level WARN -Component 'SmbAction'
                    Block-SmbShareAccess -Name $ShareName -AccountName $canonical -Force -ErrorAction Stop | Out-Null
                    Write-LogMessage -Message "Successfully blocked SMB share access." -Level WARN -Component 'SmbAction'
                }
            }
        }

        # ----------------------------------------------------------------------
        # B. NTFS File System Permission Modification (if ApplyToNtfs is enabled)
        # ----------------------------------------------------------------------
        if ($ApplyToNtfs) {
            $ntfsTargetDesc = "NTFS Directory '$folderPath' for account '$canonical'"

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

                        # SetAccessRule safely updates/replaces explicit rules for this identity while preserving others and inheritance
                        $acl.SetAccessRule($rule)
                        Set-Acl -Path $folderPath -AclObject $acl -ErrorAction Stop
                        Write-LogMessage -Message "Successfully applied NTFS Allow rule: $AccessRight ($fileRights)." -Level INFO -Component 'NtfsAction'
                    }
                    'Revoke' {
                        # Remove only explicit rules for this SID, protecting inherited ACLs
                        $explicitRules = $acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier])
                        $targetRules = $explicitRules | Where-Object { $_.IdentityReference.Value -eq $sid.Value }

                        $removedCount = 0
                        foreach ($ruleToRemove in $targetRules) {
                            $acl.RemoveAccessRuleSpecific($ruleToRemove) | Out-Null
                            $removedCount++
                        }

                        if ($removedCount -gt 0) {
                            Set-Acl -Path $folderPath -AclObject $acl -ErrorAction Stop
                            Write-LogMessage -Message "Removed $removedCount explicit NTFS access rule(s) for '$canonical'." -Level INFO -Component 'NtfsAction'
                        } else {
                            Write-LogMessage -Message "No explicit NTFS rules found to remove for '$canonical'. (Inherited rules remain intact)." -Level INFO -Component 'NtfsAction'
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
                        Write-LogMessage -Message "Successfully applied NTFS Deny rule: $AccessRight." -Level WARN -Component 'NtfsAction'
                    }
                }
            }
        }
        else {
            Write-LogMessage -Message "Skipping NTFS permission update (-ApplyToNtfs:`$false was specified)." -Level INFO -Component 'NtfsAction'
        }

        # ----------------------------------------------------------------------
        # C. Post-Action State Inspection & Consistency Check
        # ----------------------------------------------------------------------
        $smbStateAfter = Get-AccountSmbAccessState -Share $ShareName -Sid $sid
        $ntfsStateAfter = Get-AccountNtfsAccessState -Path $folderPath -Sid $sid
        Write-LogMessage -Message "[AFTER]  SMB Access: $smbStateAfter | NTFS Access: $ntfsStateAfter" -Level INFO -Component 'StateAfter'

        # Check permission consistency
        $consistency = Test-PermissionConsistency -SmbRight $smbStateAfter -NtfsRight $ntfsStateAfter
        if (-not $consistency.IsConsistent) {
            Write-LogMessage -Message "[CONSISTENCY WARNING] $($consistency.Note)" -Level WARN -Component 'Consistency'
        } else {
            Write-LogMessage -Message "[CONSISTENCY OK] $($consistency.Note)" -Level INFO -Component 'Consistency'
        }

        # Formatted console summary card for user
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

    Write-LogMessage -Message "Operation completed successfully." -Level INFO -Component 'Complete'
}
catch {
    $err = $_.Exception.Message
    Write-LogMessage -Message "Fatal error during execution: $err" -Level ERROR -Component 'Execution'
    Write-Error "Execution failed: $err"
}
