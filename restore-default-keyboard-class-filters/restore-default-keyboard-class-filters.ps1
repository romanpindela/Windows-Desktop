<#
================================================================================
  Script Name : restore-default-keyboard-class-filters.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  GitHub      : https://github.com/romanpindela
  Version     : 1.2.0
  Release Date: 2026-10-12
  License     : MIT
  Repository  : https://github.com/romanpindela/Windows-Desktop

  DESCRIPTION:
    Enterprise automation script to diagnose, audit, back up, and restore default
    Windows Keyboard Class driver filters (UpperFilters / LowerFilters).
    Resolves non-functioning keyboards and Device Manager error codes:
      - Code 19: Registry configuration information incomplete or damaged
      - Code 10: This device cannot start
      - Code 39: Driver corrupt or missing
    Third-party software (macro engines, gaming RGB suites, remote control tools,
    virtualization software, security agents) frequently inject custom filter
    drivers into the keyboard stack. When uninstalled improperly or corrupted,
    the entire driver stack fails to initialize.
    This script creates a timestamped .reg backup, restores UpperFilters to
    'kbdclass', removes invalid LowerFilters, and logs all operations.

================================================================================
.SYNOPSIS
    Audits and restores default Windows keyboard class driver registry filters.

.DESCRIPTION
    restore-default-keyboard-class-filters.ps1 audits and repairs keyboard driver
    filter registrations under HKLM:\SYSTEM\CurrentControlSet\Control\Class.
    Key capabilities:
    - Language-independent administrator elevation using Well-Known SIDs.
    - Non-destructive status audit (-Audit) displaying driver health diagnostics.
    - Automated pre-repair registry backup (.reg) to a designated folder.
    - Restoration of UpperFilters to native Microsoft 'kbdclass' driver.
    - Removal of orphan or rogue LowerFilters entries.
    - Post-repair verification confirming clean configuration.
    - Structured execution logging with timestamps.
    - Safe-by-default execution: displays help menu when run without parameters.

.PARAMETER Repair
    Switch parameter. Initiates the repair workflow: exports registry backup,
    resets UpperFilters to 'kbdclass', and removes LowerFilters.
    Aliases: -Restore, -Fix, -r.

.PARAMETER Audit
    Switch parameter. Performs a read-only audit of keyboard class filters,
    reporting current configuration and detected anomalies without making changes.
    Aliases: -Check, -Verify, -Status, -c.

.PARAMETER BackupOnly
    Switch parameter. Creates a timestamped registry backup (.reg) of the keyboard
    class key without modifying filter values.
    Aliases: -b, -Backup.

.PARAMETER Force
    Switch parameter. Suppresses interactive confirmation prompts before applying
    registry modifications.
    Aliases: -f, -Quiet, -Silent.

.PARAMETER BackupPath
    Custom directory path for storing registry backups.
    Default: C:\RegBackup_Keyboard
    Aliases: -BackupDir, -bd.

.PARAMETER LogPath
    Custom path for the activity log file.
    Default: C:\Logs\<yyyyMMdd_HHmmss>-<ComputerName>-<UserName>-Restore-Default-Keyboard-Class-Filters.txt
    Aliases: -l, -Log.

.PARAMETER Help
    Displays the interactive help menu, parameter guide, version, and author info.
    Alias: -h.

.EXAMPLE
    .\restore-default-keyboard-class-filters.ps1
    Displays the built-in help guide, syntax, and author metadata (default safe behavior).

.EXAMPLE
    .\restore-default-keyboard-class-filters.ps1 -h
    Displays detailed help guide and usage examples.

.EXAMPLE
    .\restore-default-keyboard-class-filters.ps1 -Audit
    Performs a non-destructive audit of current keyboard class filters.

.EXAMPLE
    .\restore-default-keyboard-class-filters.ps1 -Repair
    Prompts for confirmation, exports registry backup, and restores default filters.

.EXAMPLE
    .\restore-default-keyboard-class-filters.ps1 -Repair -Force
    Executes repair silently without interactive confirmation prompt.

.EXAMPLE
    .\restore-default-keyboard-class-filters.ps1 -Repair -BackupPath "D:\Backups\Registry" -LogPath "C:\Logs\KeyboardFix.txt"
    Executes repair using custom backup directory and explicit log file.

.EXAMPLE
    .\restore-default-keyboard-class-filters.ps1 -BackupOnly
    Creates an export (.reg) of the keyboard class key without altering any values.
#>

[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
param (
    [Parameter(ParameterSetName = "Repair")]
    [Alias("r", "Restore", "Fix")]
    [switch]$Repair,

    [Parameter(ParameterSetName = "Audit")]
    [Alias("c", "Check", "Verify", "Status")]
    [switch]$Audit,

    [Parameter(ParameterSetName = "BackupOnly")]
    [Alias("b", "Backup")]
    [switch]$BackupOnly,

    [Parameter(ParameterSetName = "Repair")]
    [Alias("f", "Quiet", "Silent")]
    [switch]$Force,

    [Parameter(ParameterSetName = "Repair")]
    [Parameter(ParameterSetName = "Audit")]
    [Parameter(ParameterSetName = "BackupOnly")]
    [Alias("BackupDir", "bd")]
    [string]$BackupPath = "$env:SystemDrive\RegBackup_Keyboard",

    [Parameter(ParameterSetName = "Repair")]
    [Parameter(ParameterSetName = "Audit")]
    [Parameter(ParameterSetName = "BackupOnly")]
    [Alias("l", "Log")]
    [string]$LogPath,

    [Parameter(ParameterSetName = "Help")]
    [Parameter(ParameterSetName = "Default")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Script Metadata
$SCRIPT_INFO = @{
    Name        = "restore-default-keyboard-class-filters"
    ScriptFile  = "restore-default-keyboard-class-filters.ps1"
    Version     = "1.2.0"
    Author      = "Roman Pindela"
    Contact     = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    Repository  = "https://github.com/romanpindela/Windows-Desktop"
    ReleaseDate = "2026-10-12"
    ClassGuid   = "{4d36e96b-e325-11ce-bfc1-08002be10318}"
    DefaultUpper= "kbdclass"
}

$script:ActiveLogFile = $null

# --- Function: Write-Log ---
function Write-Log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    try { [Console]::CursorLeft = 0 } catch {}
    Write-Host "$Message" -ForegroundColor $Color

    if (-not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
        try {
            $timePrefix = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $cleanLine = "[$timePrefix] $Message`r`n"
            [System.IO.File]::AppendAllText($script:ActiveLogFile, $cleanLine, [System.Text.Encoding]::UTF8)
        }
        catch {}
    }
}

# --- Function: Show-HelpGuide ---
function Show-HelpGuide {
    try { [Console]::CursorLeft = 0 } catch {}
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)
  GitHub: $($SCRIPT_INFO.GitHub)
================================================================================
DESCRIPTION:
  Enterprise diagnostic and repair utility for Windows Keyboard Class driver
  filters (Class GUID: $($SCRIPT_INFO.ClassGuid)).
  Fixes non-responsive physical keyboards, Code 19, Code 10, and Code 39 errors
  caused by corrupt or orphaned third-party UpperFilters/LowerFilters.

USAGE:
  .\$($SCRIPT_INFO.ScriptFile) -Audit [-LogPath <path>]
  .\$($SCRIPT_INFO.ScriptFile) -Repair [-Force] [-BackupPath <dir>] [-LogPath <path>]
  .\$($SCRIPT_INFO.ScriptFile) -BackupOnly [-BackupPath <dir>] [-LogPath <path>]
  .\$($SCRIPT_INFO.ScriptFile) -h | -Help

PARAMETERS:
  -Audit, -c, -Status     : Performs read-only inspection of keyboard filter values.
  -Repair, -r, -Restore   : Creates a .reg backup, sets UpperFilters to 'kbdclass',
                            and removes unauthorized LowerFilters.
  -BackupOnly, -b         : Exports a .reg backup of the keyboard class key only.
  -Force, -f, -Quiet      : Suppresses interactive confirmation prompt during repair.
  -BackupPath, -bd        : Target directory for .reg backups.
                            Default: $env:SystemDrive\RegBackup_Keyboard
  -LogPath, -l, -Log      : Custom activity log path.
                            Default: C:\Logs\<DateTime>-<Host>-<User>-$($SCRIPT_INFO.Name).txt
  -Help, -h               : Displays this help menu, author info, and examples.

IMPORTANT:
  After downloading from GitHub, unblock the script before execution:
    Unblock-File -Path .\$($SCRIPT_INFO.ScriptFile)

EXAMPLES:
  .\$($SCRIPT_INFO.ScriptFile)
  .\$($SCRIPT_INFO.ScriptFile) -h
  .\$($SCRIPT_INFO.ScriptFile) -Audit
  .\$($SCRIPT_INFO.ScriptFile) -Repair
  .\$($SCRIPT_INFO.ScriptFile) -Repair -Force
  .\$($SCRIPT_INFO.ScriptFile) -Repair -BackupPath "D:\RegBackups"
  .\$($SCRIPT_INFO.ScriptFile) -BackupOnly
================================================================================
"@ -ForegroundColor Yellow
}

# --- Function: Assert-SafeInput ---
function Assert-SafeInput {
    param (
        [string]$PathToCheck,
        [string]$ParamName
    )
    if ([string]::IsNullOrWhiteSpace($PathToCheck)) { return }

    $invalidChars = [System.IO.Path]::GetInvalidPathChars()
    foreach ($char in $invalidChars) {
        if ($PathToCheck.Contains([string]$char)) {
            throw "Security Exception: Parameter '$ParamName' contains invalid path characters."
        }
    }

    # Block suspicious injection tokens
    $dangerousTokens = @(";", "|", "`"", "'", "`$", "&", "`n", "`r")
    foreach ($token in $dangerousTokens) {
        if ($PathToCheck.Contains($token)) {
            throw "Security Exception: Parameter '$ParamName' contains potentially unsafe character sequence ('$token')."
        }
    }
}

# --- Function: Test-IsAdmin ---
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
    return $principal.IsInRole($adminSid)
}

# --- Function: Assert-AdministratorElevation ---
function Assert-AdministratorElevation {
    if (-not (Test-IsAdmin)) {
        Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow

        # Reconstruct bound arguments for elevated process
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        foreach ($entry in $PSBoundParameters.GetEnumerator()) {
            if ($entry.Value -is [switch] -and $entry.Value.IsPresent) {
                $argList += "-$($entry.Key)"
            }
            elseif ($entry.Value -isnot [switch]) {
                $argList += "-$($entry.Key)"
                $argList += "`"$($entry.Value)`""
            }
        }

        $argumentsString = $argList -join " "
        try {
            $process = Start-Process powershell.exe -ArgumentList $argumentsString -Verb RunAs -PassThru
            Exit 0
        }
        catch {
            Write-Error "Failed to elevate process: $_"
            Exit 1
        }
    }
}

# --- Function: Initialize-Logging ---
function Initialize-Logging {
    param ([string]$CustomPath)

    if ([string]::IsNullOrWhiteSpace($CustomPath)) {
        $defaultLogDir = "C:\Logs"
        $timeMarker = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $compName   = $env:COMPUTERNAME
        $userName   = $env:USERNAME
        $scriptName = $SCRIPT_INFO.Name
        $logFileName = "${timeMarker}-${compName}-${userName}-${scriptName}.txt"
        $CustomPath  = Join-Path ($defaultLogDir) ($logFileName)
    }

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CustomPath)
    $logDirectory = [System.IO.Path]::GetDirectoryName($resolvedPath)
    if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not [System.IO.Directory]::Exists($logDirectory)) {
        [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null
    }

    $script:ActiveLogFile = $resolvedPath
    return $resolvedPath
}

# --- Function: Get-KeyboardClassStatus ---
function Get-KeyboardClassStatus {
    param (
        [string]$RegPath
    )

    if (-not (Test-Path $RegPath)) {
        throw "Keyboard class registry key not found: $RegPath"
    }

    $item         = Get-Item -Path $RegPath
    $upperFilters = $item.GetValue("UpperFilters")
    $lowerFilters = $item.GetValue("LowerFilters")
    $className    = $item.GetValue("Class")

    # Normalize UpperFilters array
    $upperArray = @()
    if ($null -ne $upperFilters) {
        if ($upperFilters -is [array]) {
            $upperArray = [string[]]$upperFilters
        } else {
            $upperArray = @([string]$upperFilters)
        }
    }

    # Normalize LowerFilters array
    $lowerArray = @()
    if ($null -ne $lowerFilters) {
        if ($lowerFilters -is [array]) {
            $lowerArray = [string[]]$lowerFilters
        } else {
            $lowerArray = @([string]$lowerFilters)
        }
    }

    $isUpperValid = ($upperArray.Count -eq 1 -and $upperArray[0] -eq "kbdclass")
    $hasLower     = ($lowerArray.Count -gt 0)
    $isHealthy    = ($isUpperValid -and -not $hasLower)

    return [PSCustomObject]@{
        RegistryPath        = $RegPath
        ClassName           = $className
        UpperFilters        = $upperArray
        LowerFilters        = $lowerArray
        IsUpperFiltersValid = $isUpperValid
        HasLowerFilters     = $hasLower
        IsHealthy           = $isHealthy
    }
}

# --- Function: Export-RegistryKeyBackup ---
function Export-RegistryKeyBackup {
    param (
        [string]$ClassGuid,
        [string]$TargetDirectory
    )

    if (-not (Test-Path $TargetDirectory)) {
        New-Item -Path $TargetDirectory -ItemType Directory -Force | Out-Null
        Write-Log "    [+] Created backup directory: $TargetDirectory" DarkGray
    }

    $timestamp  = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupFile = Join-Path -Path $TargetDirectory -ChildPath "KeyboardClass_${timestamp}.reg"
    $exportKey  = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\$ClassGuid"

    Write-Log "[*] Exporting registry key backup..." Cyan
    Write-Log "    Source : $exportKey" DarkGray
    Write-Log "    Target : $backupFile" DarkGray

    $regProcess = Start-Process -FilePath "reg.exe" -ArgumentList "export `"$exportKey`" `"$backupFile`" /y" -Wait -NoNewWindow -PassThru

    if ($regProcess.ExitCode -eq 0 -and (Test-Path $backupFile) -and ((Get-Item $backupFile).Length -gt 0)) {
        Write-Log "    [+] Backup created successfully ($((Get-Item $backupFile).Length) bytes)." Green
        return $backupFile
    } else {
        throw "Failed to create registry backup file (reg.exe exited with code $($regProcess.ExitCode))."
    }
}

# --- Main Program Dispatch ---

# Default safe behavior: show help when run without action parameters
if ($Help -or ($PSBoundParameters.Count -eq 0) -or (-not $Repair -and -not $Audit -and -not $BackupOnly)) {
    Show-HelpGuide
    return
}

# Input sanitization
Assert-SafeInput -PathToCheck $BackupPath -ParamName "BackupPath"
Assert-SafeInput -PathToCheck $LogPath -ParamName "LogPath"

# Require administrator elevation for operations that alter system state or export registry keys
if ($Repair -or $BackupOnly) {
    Assert-AdministratorElevation
}

# Initialize logging
$resolvedLog = Initialize-Logging -CustomPath $LogPath

$classGuid = $SCRIPT_INFO.ClassGuid
$regPath   = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classGuid"
$isAdmin   = Test-IsAdmin

try { Clear-Host } catch {}
Write-Log "================================================================================" Cyan
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version)" Cyan
Write-Log "  Author  : $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)" Gray
Write-Log "  GitHub  : $($SCRIPT_INFO.GitHub)" Gray
Write-Log "  Session : $(if ($isAdmin) { 'Administrator (Elevated)' } else { 'Standard User (Non-Elevated)' })" DarkGray
Write-Log "  Log     : $resolvedLog" DarkCyan
Write-Log "================================================================================" Cyan

try {
    # 1. Inspect Current State
    Write-Log "`n[Step 1] Auditing Keyboard Class filters in Windows Registry..." Cyan
    $status = Get-KeyboardClassStatus -RegPath $regPath

    $upperFormatted = if ($status.UpperFilters.Count -gt 0) { $status.UpperFilters -join ", " } else { "<None>" }
    $lowerFormatted = if ($status.LowerFilters.Count -gt 0) { $status.LowerFilters -join ", " } else { "<None>" }

    Write-Log "  Registry Class Key : $regPath" DarkGray
    Write-Log "  Device Class Name  : $($status.ClassName)" DarkGray
    Write-Log "  UpperFilters       : $upperFormatted" $(if ($status.IsUpperFiltersValid) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow })
    Write-Log "  LowerFilters       : $lowerFormatted" $(if (-not $status.HasLowerFilters) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow })

    if ($status.IsHealthy) {
        Write-Log "  Overall Health     : [HEALTHY] Default 'kbdclass' driver stack is configured correctly." Green
    } else {
        Write-Log "  Overall Health     : [ATTENTION REQUIRED] Non-default or corrupted filter stack detected!" Yellow
    }

    # 2. Mode: Audit Only
    if ($Audit) {
        Write-Log "`n[Audit Complete] Diagnostic summary finished. No changes were made." Cyan
        if (-not $status.IsHealthy) {
            Write-Log "RECOMMENDATION: Run with -Repair parameter to restore default filters." Yellow
        }
        return
    }

    # 3. Mode: Backup Only
    if ($BackupOnly) {
        $backupFile = Export-RegistryKeyBackup -ClassGuid $classGuid -TargetDirectory $BackupPath
        Write-Log "`n[Backup Complete] Standalone registry backup completed successfully." Green
        Write-Log "Backup file: $backupFile" Green
        return
    }

    # 4. Mode: Repair
    if ($Repair) {
        if ($status.IsHealthy -and -not $Force) {
            Write-Log "`n[Notice] Registry filters are already in default state ('kbdclass' only, no LowerFilters)." Green
            $reapply = Read-Host "Do you want to force re-apply default configuration anyway? (y/N)"
            if ($reapply -notmatch "^(y|yes)$") {
                Write-Log "Operation canceled by user. No modifications applied." Yellow
                return
            }
        }
        elseif (-not $Force) {
            Write-Log "`n[Confirmation Required] You are about to repair the keyboard class filters." Yellow
            Write-Log "  - UpperFilters will be set to: 'kbdclass'" Yellow
            Write-Log "  - LowerFilters (if present) will be removed" Yellow
            Write-Log "  - An automatic registry backup will be created in: $BackupPath" Yellow
            $confirm = Read-Host "`nProceed with repair? (y/N)"
            if ($confirm -notmatch "^(y|yes)$") {
                Write-Log "Repair canceled by user. No modifications applied." Yellow
                return
            }
        }

        # Backup prior to modification
        Write-Log "`n[Step 2] Creating pre-repair registry backup..." Cyan
        $backupFile = Export-RegistryKeyBackup -ClassGuid $classGuid -TargetDirectory $BackupPath

        # Apply modifications
        Write-Log "`n[Step 3] Restoring default registry filters..." Cyan

        if ($PSCmdlet.ShouldProcess($regPath, "Set UpperFilters to 'kbdclass' (MultiString)")) {
            Set-ItemProperty -Path $regPath -Name "UpperFilters" -Value @("kbdclass") -Type MultiString
            Write-Log "  [+] UpperFilters successfully restored to 'kbdclass' (REG_MULTI_SZ)." Green
        }

        if ($status.HasLowerFilters) {
            if ($PSCmdlet.ShouldProcess($regPath, "Remove LowerFilters")) {
                Remove-ItemProperty -Path $regPath -Name "LowerFilters" -ErrorAction Stop
                Write-Log "  [+] Removed extraneous LowerFilters entry from keyboard class." Green
            }
        } else {
            Write-Log "  [*] LowerFilters key already absent (clean state)." DarkGray
        }

        # Step 4: Verification
        Write-Log "`n[Step 4] Verifying post-repair configuration..." Cyan
        $postStatus = Get-KeyboardClassStatus -RegPath $regPath

        $postUpper = $postStatus.UpperFilters -join ", "
        $postLower = if ($postStatus.LowerFilters.Count -gt 0) { $postStatus.LowerFilters -join ", " } else { "<None>" }

        Write-Log "  Verified UpperFilters : $postUpper" Green
        Write-Log "  Verified LowerFilters : $postLower" Green

        if ($postStatus.IsHealthy) {
            Write-Log "`n================================================================================" Green
            Write-Log "  [+] Keyboard class filters have been successfully restored!" Green
            Write-Log "  [!] IMPORTANT: A SYSTEM REBOOT IS REQUIRED to reload the kernel driver stack." Yellow
            Write-Log "      Please restart your computer for changes to take effect." Yellow
            Write-Log "================================================================================" Green
        } else {
            Write-Log "`n[!] Warning: Post-repair verification did not confirm expected healthy state." Red
        }
    }
}
catch {
    Write-Log "`n[-] Critical Error occurred: $_" Red
    Write-Log "    Exception details: $($_.Exception.Message)" Red
    throw $_
}
finally {
    Write-Log "`nExecution finished at $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))." DarkGray
    Write-Log "Log file location: $resolvedLog" DarkGray
    Write-Log "================================================================================`n" Cyan
}