<#
================================================================================
  Script Name : Manage-WindowsOptionalFeatures.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  Version     : 1.2.0
  Release Date: 2026-10-18
  License     : MIT
  Repository  : https://github.com/romanpindela

  DESCRIPTION:
    Enterprise-grade PowerShell automation tool for inspecting, listing,
    enabling, and disabling Windows Optional Features (DISM / Win32_OptionalFeature)
    across Windows 10, Windows 11, and Windows Server (English and Polish editions).

    Key Capabilities:
    1. Zero-Parameter Interactive Help (-Help / -h):
       Displays complete syntax, parameter documentation, common Windows 10/11
       feature names, usage examples, version, and author details when launched
       without parameters, without triggering an unnecessary UAC prompt.
    2. Enable & Disable Windows Optional Features:
       Enables or disables one or multiple Windows features via the -Action
       parameter ('Enable' / 'Disable' / 'List' / 'Details') or dedicated
       switches (-Enable, -Disable, -List). Automatically resolves parent
       feature dependencies (-All by default when enabling) and manages
       reboot behavior safely (-NoRestart by default, or -Restart when requested).
    3. Comprehensive Feature Details Listing:
       Lists full details for each Windows Optional Feature (FeatureName,
       DisplayName, State, RestartRequired, Description, and CustomProperties)
       both in listing/inspection mode and before/after every Enable or Disable
       operation. Combines DISM (Get-WindowsOptionalFeature) with CIM/WMI
       (Win32_OptionalFeature) so localized DisplayName and Description are
       always populated quickly and accurately.
    4. Input Sanitization & Defensive Validation:
       Protects against command injection, path traversal, and malformed
       feature names or file paths.
    5. Language-Independent UAC Auto-Elevation:
       Verifies Administrator privileges using the well-known Windows SID
       (S-1-5-32-544 / BuiltInAdministratorsSid) for 100% compatibility across
       Polish ("Administratorzy") and English ("Administrators") Windows systems,
       and automatically elevates via UAC while preserving all CLI parameters.
    6. Detailed Audit Logging & Optional CSV/JSON Export:
       Logs all operations with UTF-8 timestamps to:
       C:\Logs\<yyyyMMdd_HHmmss>-Manage-WindowsOptionalFeatures-<ComputerName>-<UserName>.logs
================================================================================
.SYNOPSIS
    Lists details, enables, or disables Windows Optional Features in Windows 10/11.

.DESCRIPTION
    Provides a unified, safe, and standards-compliant command-line interface around
    the DISM PowerShell module (Get-WindowsOptionalFeature, Enable-WindowsOptionalFeature,
    Disable-WindowsOptionalFeature) and CIM (Win32_OptionalFeature).

    Supports:
    - Running without parameters or with -Help / -h to display help, examples,
      version, and author details.
    - Listing all or filtered Windows Optional Features with full details
      (FeatureName, DisplayName, State, RestartRequired, Description).
    - Inspecting deep details of specific features (including CustomProperties).
    - Enabling or disabling single or multiple features (by name, wildcard, or
      text/CSV input file) with dependency resolution (-All), dry-run simulation
      (-DryRun), and export reporting (-ExportPath).

.PARAMETER Action
    Specifies the operation to perform:
      - 'Enable'  : Enables the specified Windows Optional Feature(s).
      - 'Disable' : Disables the specified Windows Optional Feature(s).
      - 'List'    : Lists Windows Optional Features and their details.
      - 'Details' : Displays extended details for each feature.
    Aliases: -Mode, -Operation

.PARAMETER FeatureName
    One or more Windows Optional Feature names or wildcard patterns to target
    (e.g., 'Microsoft-Hyper-V-All', 'TelnetClient', 'NetFx3', '*Sandbox*', '*WSL*').
    When used with -List / -Details, filters the displayed features.
    When used alone without -Action, displays full details for the matching feature(s).
    Aliases: -Name, -Feature, -Features, -f

.PARAMETER Enable
    Switch parameter. Shortcut for -Action Enable.

.PARAMETER Disable
    Switch parameter. Shortcut for -Action Disable.

.PARAMETER List
    Switch parameter. Shortcut for -Action List (lists details of features).
    Aliases: -ShowAll, -Get

.PARAMETER State
    Filters features by their current installation state when listing:
      - 'All'             : Shows all features regardless of state (Default).
      - 'Enabled'         : Shows only enabled features.
      - 'Disabled'        : Shows only disabled features.
      - 'EnablePending'   : Shows features pending reboot to complete enabling.
      - 'DisablePending'  : Shows features pending reboot to complete disabling.
    Aliases: -FilterState, -Status

.PARAMETER Detailed
    Switch parameter. Displays each feature's full multi-line property sheet
    (including full Description and CustomProperties) instead of a compact table
    when listing multiple features.

.PARAMETER IncludeParentFeatures
    Determines whether parent dependencies are automatically enabled when enabling
    a feature (maps to Enable-WindowsOptionalFeature -All). Enabled ($true) by default.

.PARAMETER RemovePayload
    Switch parameter. When disabling a feature, removes its binary payload from
    the Windows Component Store (WinSxS) to free disk space (maps to -Remove).

.PARAMETER Source
    Optional path(s) to offline feature source files (e.g., SxS folder on Windows
    ISO/install media for NetFx3) when enabling features without Windows Update.

.PARAMETER LimitAccess
    Switch parameter. Prevents DISM from contacting Windows Update/WSUS when
    enabling features from a local -Source path.

.PARAMETER InputFile
    Optional path to a .txt or .csv file containing feature names (one per line
    or in a 'FeatureName' column) for bulk enable/disable/inspection.

.PARAMETER Restart
    Switch parameter. Allows Windows to automatically reboot immediately after
    enabling/disabling features if a system restart is required. By default,
    automatic restart is suppressed (-NoRestart).

.PARAMETER ExportPath
    Optional file path (.csv or .json) to export the detailed list or execution
    results of Windows Optional Features.
    Aliases: -ExportCsv, -ReportPath, -OutFile

.PARAMETER DryRun
    Switch parameter. Simulates enabling or disabling the target feature(s) and
    displays current details without modifying the operating system.
    Aliases: -Simulate, -Preview

.PARAMETER Force
    Switch parameter. Bypasses interactive confirmation prompts (Y/N or T/N).

.PARAMETER SkipAdminCheck
    Switch parameter. Skips automatic UAC Administrator privilege elevation check.

.PARAMETER PassThru
    Switch parameter. Returns the detailed feature result objects to the pipeline.

.PARAMETER LogPath
    Custom file path for the execution log.
    Default: C:\Logs\<yyyyMMdd_HHmmss>-Manage-WindowsOptionalFeatures-<ComputerName>-<UserName>.logs
    Aliases: -l, -Log

.PARAMETER NoLog
    Switch parameter. Disables writing execution logs to disk.

.PARAMETER Help
    Switch parameter (-Help / -h). Displays this help guide, usage examples,
    author details, and version information.
    Aliases: -h

.EXAMPLE
    .\Manage-WindowsOptionalFeatures.ps1
    Displays the help screen, usage syntax, common feature names, examples,
    version, and author details.

.EXAMPLE
    .\Manage-WindowsOptionalFeatures.ps1 -List
    Lists all Windows Optional Features on the system along with their State,
    DisplayName, RestartRequired status, and Description.

.EXAMPLE
    .\Manage-WindowsOptionalFeatures.ps1 -List -State Enabled -Detailed
    Lists all currently enabled Windows Optional Features with full detailed
    descriptions and properties for every feature.

.EXAMPLE
    .\Manage-WindowsOptionalFeatures.ps1 -Action Enable -FeatureName "TelnetClient"
    Enables the Telnet Client feature and displays full details of the feature
    before and after the operation.

.EXAMPLE
    .\Manage-WindowsOptionalFeatures.ps1 -Enable -FeatureName "Containers-DisposableClientVM", "Microsoft-Windows-Subsystem-Linux"
    Enables Windows Sandbox and Windows Subsystem for Linux (WSL) in a single run.

.EXAMPLE
    .\Manage-WindowsOptionalFeatures.ps1 -Action Disable -FeatureName "WorkFolders-Client", "Printing-XPSServices-Features" -Force
    Disables Work Folders Client and XPS Services without interactive prompts.

.NOTES
    Author      : Roman Pindela
    Contact     : roman.pindela@gmail.com
    GitHub      : https://github.com/romanpindela
    Version     : 1.2.0
    Compatible  : Windows 10, Windows 11, Windows Server 2016/2019/2022/2025 (EN/PL)
    Privileges  : Requires Administrator privileges (auto-elevates via UAC using SID).
#>

[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias("Mode", "Operation")]
    [ValidateSet("Enable", "Disable", "List", "Details", IgnoreCase = $true)]
    [string]$Action,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("Name", "Feature", "Features", "f")]
    [string[]]$FeatureName,

    [Parameter(Mandatory = $false)]
    [switch]$Enable,

    [Parameter(Mandatory = $false)]
    [switch]$Disable,

    [Parameter(Mandatory = $false)]
    [Alias("ShowAll", "Get")]
    [switch]$List,

    [Parameter(Mandatory = $false)]
    [Alias("FilterState", "Status")]
    [ValidateSet("All", "Enabled", "Disabled", "DisabledWithPayloadRemoved", "EnablePending", "DisablePending", IgnoreCase = $true)]
    [string]$State = "All",

    [Parameter(Mandatory = $false)]
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [bool]$IncludeParentFeatures = $true,

    [Parameter(Mandatory = $false)]
    [switch]$RemovePayload,

    [Parameter(Mandatory = $false)]
    [string[]]$Source,

    [Parameter(Mandatory = $false)]
    [switch]$LimitAccess,

    [Parameter(Mandatory = $false)]
    [Alias("FilePath", "Path")]
    [string]$InputFile,

    [Parameter(Mandatory = $false)]
    [switch]$Restart,

    [Parameter(Mandatory = $false)]
    [Alias("ExportCsv", "ReportPath", "OutFile")]
    [string]$ExportPath,

    [Parameter(Mandatory = $false)]
    [Alias("Simulate", "Preview")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [Alias("l", "Log")]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [switch]$NoLog,

    [Parameter(Mandatory = $false)]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ==============================================================================
# SCRIPT METADATA & CONFIGURATION
# ==============================================================================
$SCRIPT_INFO = @{
    Name        = "Manage-WindowsOptionalFeatures"
    FileName    = "Manage-WindowsOptionalFeatures.ps1"
    Version     = "1.2.0"
    Author      = "Roman Pindela"
    Contact     = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    ReleaseDate = "2026-10-18"
    License     = "MIT"
}

$script:ActiveLogFile = $null

# ==============================================================================
# LOGGING & CONSOLE OUTPUT FUNCTIONS
# ==============================================================================
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "STEP", "HEADER")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    $colorMap = @{
        "INFO"    = [ConsoleColor]::White
        "SUCCESS" = [ConsoleColor]::Green
        "WARN"    = [ConsoleColor]::Yellow
        "ERROR"   = [ConsoleColor]::Red
        "STEP"    = [ConsoleColor]::Cyan
        "HEADER"  = [ConsoleColor]::Cyan
    }

    $effectiveColor = if ($PSBoundParameters.ContainsKey("Color")) {
        $Color
    } else {
        $colorMap[$Level]
    }

    try { [Console]::CursorLeft = 0 } catch {}
    Write-Host $Message -ForegroundColor $effectiveColor

    if (-not $NoLog -and -not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
        try {
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $cleanMessage = $Message -replace "^\r?\n", ""
            $logEntry = "[$timestamp] [$Level] $cleanMessage`r`n"
            [System.IO.File]::AppendAllText($script:ActiveLogFile, $logEntry, [System.Text.Encoding]::UTF8)
        }
        catch {
            # Never abort execution due to log file lock or write failure
        }
    }
}

function Initialize-LogFile {
    if ($NoLog) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $defaultLogDir = "C:\Logs"
        if (-not (Test-Path -Path $defaultLogDir)) {
            try {
                New-Item -Path $defaultLogDir -ItemType Directory -Force | Out-Null
            }
            catch {
                $defaultLogDir = [System.IO.Path]::GetTempPath()
            }
        }
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $computerName = [System.Environment]::MachineName
        $userName = [System.Environment]::UserName
        $script:ActiveLogFile = Join-Path -Path $defaultLogDir -ChildPath "$timestamp-$($SCRIPT_INFO.Name)-$computerName-$userName.logs"
    }
    else {
        $parentDir = [System.IO.Path]::GetDirectoryName($LogPath)
        if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }
        $script:ActiveLogFile = $LogPath
    }
}

# ==============================================================================
# INPUT SANITIZATION & SECURITY VALIDATION
# ==============================================================================
function Protect-FeatureNameInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Validation Error: Feature name cannot be empty or whitespace."
    }

    if ($Value.Length -gt 150) {
        throw "Validation Error: Feature name '$Value' exceeds maximum length of 150 characters."
    }

    # Allow only valid Windows Optional Feature characters (letters, digits, dot, hyphen, underscore, wildcard * and ?)
    if ($Value -notmatch '^[a-zA-Z0-9._\-\*\?]+$') {
        throw "Security Alert: Feature name '$Value' contains illegal or potentially dangerous characters. Only alphanumeric characters, hyphens (-), underscores (_), dots (.), and wildcards (*, ?) are allowed."
    }
}

function Protect-FilePathInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return
    }

    if ($PathValue.Length -gt 260) {
        throw "Validation Error: Parameter '$ParameterName' exceeds maximum path length of 260 characters."
    }

    # Block shell metacharacters and command injection vectors
    if ($PathValue -match '[`$;&|><*?"\r\n]') {
        throw "Security Alert: Parameter '$ParameterName' ('$PathValue') contains illegal or potentially dangerous characters."
    }
}

# ==============================================================================
# HELP & DOCUMENTATION DISPLAY
# ==============================================================================
function Show-HelpGuide {
    try { [Console]::CursorLeft = 0 } catch {}
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Author : $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)
  GitHub : $($SCRIPT_INFO.GitHub)
  Date   : $($SCRIPT_INFO.ReleaseDate) | License: $($SCRIPT_INFO.License)
================================================================================
DESCRIPTION:
  Inspects, lists details, enables, or disables Windows Optional Features in
  Windows 10, Windows 11, and Windows Server (supports English and Polish OS).

  Core Capabilities:
  1. Zero-Parameter Help (-Help / -h): Displays usage, examples, version & author.
  2. Enable / Disable Features: Enables or disables single or multiple Windows
     features via -Action Enable|Disable or switches -Enable / -Disable.
  3. Detailed Feature Inspection: Lists comprehensive details for every feature
     (FeatureName, DisplayName, State, RestartRequired, Description, and
     CustomProperties) during listing and before/after state changes.
  4. Multi-Language UAC Auto-Elevation: Uses Windows SID (S-1-5-32-544) to work
     reliably on both Polish ("Administratorzy") and English ("Administrators")
     Windows editions.
  5. Audit Logging: Automatically writes detailed execution logs to C:\Logs.

SYNTAX:
  # 1. Display Help (Default when run without parameters):
  .\Manage-WindowsOptionalFeatures.ps1 [-Help | -h]

  # 2. List All or Filtered Features with Details:
  .\Manage-WindowsOptionalFeatures.ps1 -List [-FeatureName <Pattern[]>]
      [-State <All|Enabled|Disabled|EnablePending|DisablePending>]
      [-Detailed] [-ExportPath <File.csv|.json>]

  # 3. Enable Windows Optional Feature(s):
  .\Manage-WindowsOptionalFeatures.ps1 -Action Enable -FeatureName <Name[]>
      [-IncludeParentFeatures <$true|$false>] [-Source <Path[]>] [-LimitAccess]
      [-Restart] [-DryRun] [-Force]

  # 4. Disable Windows Optional Feature(s):
  .\Manage-WindowsOptionalFeatures.ps1 -Action Disable -FeatureName <Name[]>
      [-RemovePayload] [-Restart] [-DryRun] [-Force]

PARAMETERS:
  -Action <String>        : Operation: 'Enable', 'Disable', 'List', or 'Details'.
  -FeatureName <String[]> : Feature name(s) or wildcard pattern(s) (Alias: -Name, -f).
  -Enable                 : Switch shortcut for -Action Enable.
  -Disable                : Switch shortcut for -Action Disable.
  -List                   : Switch shortcut for -Action List (lists feature details).
  -State <String>         : Filter state: All (default), Enabled, Disabled,
                            EnablePending, DisablePending.
  -Detailed               : Prints full property cards (with full Description and
                            CustomProperties) for each listed feature.
  -IncludeParentFeatures  : Enables required parent features automatically
                            (Default: $true, maps to DISM -All).
  -RemovePayload          : Removes binary payload from WinSxS when disabling.
  -Source <String[]>      : Offline source path (e.g., D:\sources\sxs for NetFx3).
  -LimitAccess            : Do not contact Windows Update when using -Source.
  -InputFile <String>     : Path to .txt or .csv file with feature names.
  -Restart                : Allows immediate reboot if required (Default: NoRestart).
  -ExportPath <String>    : Exports feature details/results to .csv or .json.
  -DryRun                 : Simulates changes without modifying Windows features.
  -Force                  : Skips confirmation prompts (Y/N or T/N).
  -LogPath <String>       : Custom log file path (Default: C:\Logs\...).
  -NoLog                  : Disables file logging.
  -Help / -h              : Displays this help guide and exits.

COMMON WINDOWS 10 / 11 OPTIONAL FEATURES:
  - TelnetClient                         : Telnet Client
  - NetFx3                               : .NET Framework 3.5 (includes .NET 2.0 & 3.0)
  - Microsoft-Windows-Subsystem-Linux    : Windows Subsystem for Linux (WSL)
  - VirtualMachinePlatform               : Virtual Machine Platform (required for WSL2)
  - Containers-DisposableClientVM        : Windows Sandbox
  - Microsoft-Hyper-V-All                : Hyper-V (All Hypervisor & Management Tools)
  - SMB1Protocol                         : SMB 1.0/CIFS File Sharing Support
  - WorkFolders-Client                   : Work Folders Client
  - Printing-XPSServices-Features        : Microsoft XPS Document Writer

PRACTICAL EXAMPLES:
  1. Display help, author, and version info:
     .\Manage-WindowsOptionalFeatures.ps1

  2. List details of all Windows Optional Features on this computer:
     .\Manage-WindowsOptionalFeatures.ps1 -List

  3. List only Enabled features with full multi-line details:
     .\Manage-WindowsOptionalFeatures.ps1 -List -State Enabled -Detailed

  4. Search and show full details for Hyper-V, WSL, or Sandbox features:
     .\Manage-WindowsOptionalFeatures.ps1 -Action Details -FeatureName "*Hyper-V*", "*Linux*", "*Sandbox*"

  5. Enable Telnet Client:
     .\Manage-WindowsOptionalFeatures.ps1 -Action Enable -FeatureName "TelnetClient"

  6. Enable WSL and Virtual Machine Platform using the -Enable switch:
     .\Manage-WindowsOptionalFeatures.ps1 -Enable -FeatureName "Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform" -Force

  7. Disable XPS Services and SMBv1 Protocol (with DryRun preview first):
     .\Manage-WindowsOptionalFeatures.ps1 -Action Disable -FeatureName "Printing-XPSServices-Features", "SMB1Protocol" -DryRun

  8. Export details of all Windows Optional Features to a CSV report:
     .\Manage-WindowsOptionalFeatures.ps1 -List -ExportPath "C:\Logs\WindowsFeatures_Audit.csv"

FIRST RUN / UNBLOCKING NOTE:
  After downloading this script from GitHub, unblock it before running:
     Unblock-File -Path .\Manage-WindowsOptionalFeatures.ps1
================================================================================
"@ -ForegroundColor Yellow
}

# ==============================================================================
# ZERO-PARAMETER & HELP CHECK
# ==============================================================================
$hasActionOrSwitch = (-not [string]::IsNullOrWhiteSpace($Action)) -or $Enable -or $Disable -or $List
$hasTargetFeatures = ($null -ne $FeatureName -and $FeatureName.Count -gt 0) -or (-not [string]::IsNullOrWhiteSpace($InputFile))

if ($Help -or (-not $hasActionOrSwitch -and -not $hasTargetFeatures)) {
    Show-HelpGuide
    return
}

# Validate mutually exclusive switches
$switchCount = @($Enable, $Disable, $List) | Where-Object { $_ -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
if ($switchCount -gt 1) {
    Write-Host "[-] Validation Error: Parameters -Enable, -Disable, and -List cannot be used together." -ForegroundColor Red
    return
}

# Resolve effective Action
if ([string]::IsNullOrWhiteSpace($Action)) {
    if ($Enable) {
        $Action = "Enable"
    }
    elseif ($Disable) {
        $Action = "Disable"
    }
    elseif ($List) {
        $Action = "List"
    }
    elseif ($hasTargetFeatures) {
        $Action = "Details"
    }
}
else {
    # Normalize casing
    switch ($Action.ToLowerInvariant()) {
        "enable"  { $Action = "Enable" }
        "disable" { $Action = "Disable" }
        "list"    { $Action = "List" }
        "details" { $Action = "Details" }
    }
}

# ==============================================================================
# VALIDATE & SANITIZE USER INPUTS BEFORE ELEVATION
# ==============================================================================
if (-not [string]::IsNullOrWhiteSpace($InputFile)) {
    Protect-FilePathInput -PathValue $InputFile -ParameterName "InputFile"
    if (-not (Test-Path -Path $InputFile -PathType Leaf)) {
        throw "Validation Error: Specified InputFile does not exist: '$InputFile'"
    }
}

if (-not [string]::IsNullOrWhiteSpace($ExportPath)) {
    Protect-FilePathInput -PathValue $ExportPath -ParameterName "ExportPath"
}

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    Protect-FilePathInput -PathValue $LogPath -ParameterName "LogPath"
}

if ($null -ne $Source -and $Source.Count -gt 0) {
    foreach ($src in $Source) {
        Protect-FilePathInput -PathValue $src -ParameterName "Source"
    }
}

# Collect feature names from CLI and optional InputFile
$resolvedFeaturePatterns = [System.Collections.Generic.List[string]]::new()

if ($null -ne $FeatureName) {
    foreach ($item in $FeatureName) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            foreach ($splitItem in ($item -split ',')) {
                $trimmed = $splitItem.Trim()
                if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                    Protect-FeatureNameInput -Value $trimmed
                    if (-not $resolvedFeaturePatterns.Contains($trimmed)) {
                        $resolvedFeaturePatterns.Add($trimmed)
                    }
                }
            }
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($InputFile)) {
    $ext = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
    if ($ext -eq ".csv") {
        $csvRows = Import-Csv -Path $InputFile -Encoding UTF8
        foreach ($row in $csvRows) {
            $candidate = $null
            foreach ($colName in @("FeatureName", "Name", "Feature")) {
                if ($row.PSObject.Properties.Name -contains $colName -and -not [string]::IsNullOrWhiteSpace($row.$colName)) {
                    $candidate = $row.$colName.Trim()
                    break
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                Protect-FeatureNameInput -Value $candidate
                if (-not $resolvedFeaturePatterns.Contains($candidate)) {
                    $resolvedFeaturePatterns.Add($candidate)
                }
            }
        }
    }
    else {
        $lines = Get-Content -Path $InputFile -Encoding UTF8
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
                continue
            }
            Protect-FeatureNameInput -Value $trimmed
            if (-not $resolvedFeaturePatterns.Contains($trimmed)) {
                $resolvedFeaturePatterns.Add($trimmed)
            }
        }
    }
}

if (($Action -in @("Enable", "Disable")) -and $resolvedFeaturePatterns.Count -eq 0) {
    Write-Host "[-] Error: Action '$Action' requires at least one feature specified via -FeatureName or -InputFile." -ForegroundColor Red
    Write-Host "    Tip: Run '.\Manage-WindowsOptionalFeatures.ps1 -List' to see available feature names.`n" -ForegroundColor Yellow
    return
}

# ==============================================================================
# UAC AUTO-ELEVATION (LANGUAGE-INDEPENDENT SID VERIFICATION)
# ==============================================================================
# Check if the script is already running with Administrator privileges using SID (language-independent)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)

$isAdmin = $principal.IsInRole($adminSid)

if (-not $isAdmin -and -not $SkipAdminCheck) {
    # If not running as Admin, prompt for UAC consent and relaunch the script with elevated privileges
    Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow

    $relaunchArgs = [System.Collections.Generic.List[string]]::new()
    $relaunchArgs.Add("-NoProfile")
    $relaunchArgs.Add("-ExecutionPolicy")
    $relaunchArgs.Add("Bypass")
    $relaunchArgs.Add("-File")
    $relaunchArgs.Add("`"$PSCommandPath`"")
    $relaunchArgs.Add("-Action")
    $relaunchArgs.Add("`"$Action`"")

    if ($resolvedFeaturePatterns.Count -gt 0) {
        $joinedFeatures = ($resolvedFeaturePatterns | ForEach-Object { "`"$_`"" }) -join ","
        $relaunchArgs.Add("-FeatureName")
        $relaunchArgs.Add($joinedFeatures)
    }
    if ($State -ne "All") {
        $relaunchArgs.Add("-State")
        $relaunchArgs.Add("`"$State`"")
    }
    if ($Detailed) { $relaunchArgs.Add("-Detailed") }
    if (-not $IncludeParentFeatures) { $relaunchArgs.Add("-IncludeParentFeatures:`$false") }
    if ($RemovePayload) { $relaunchArgs.Add("-RemovePayload") }
    if ($null -ne $Source -and $Source.Count -gt 0) {
        $joinedSources = ($Source | ForEach-Object { "`"$_`"" }) -join ","
        $relaunchArgs.Add("-Source")
        $relaunchArgs.Add($joinedSources)
    }
    if ($LimitAccess) { $relaunchArgs.Add("-LimitAccess") }
    if (-not [string]::IsNullOrWhiteSpace($ExportPath)) {
        $relaunchArgs.Add("-ExportPath")
        $relaunchArgs.Add("`"$ExportPath`"")
    }
    if ($Restart) { $relaunchArgs.Add("-Restart") }
    if ($DryRun) { $relaunchArgs.Add("-DryRun") }
    if ($Force) { $relaunchArgs.Add("-Force") }
    if ($PassThru) { $relaunchArgs.Add("-PassThru") }
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $relaunchArgs.Add("-LogPath")
        $relaunchArgs.Add("`"$LogPath`"")
    }
    if ($NoLog) { $relaunchArgs.Add("-NoLog") }

    try {
        Start-Process powershell.exe -ArgumentList ($relaunchArgs -join " ") -Verb RunAs
    }
    catch {
        Write-Host "[-] Error: UAC elevation was cancelled or failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Exit
}

# ==============================================================================
# INITIALIZE LOGGING & ENVIRONMENT BANNER
# ==============================================================================
Initialize-LogFile

$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
$osCaption = if ($osInfo) { "$($osInfo.Caption) (Build $($osInfo.BuildNumber))" } else { [System.Environment]::OSVersion.VersionString }

Write-Log "================================================================================" -Level HEADER
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) | Author: $($SCRIPT_INFO.Author)" -Level HEADER
Write-Log "  OS Environment : $osCaption" -Level HEADER
Write-Log "  Computer / User: $([System.Environment]::MachineName) \ $([System.Environment]::UserName)" -Level HEADER
Write-Log "  Operation Mode : $Action $(if ($DryRun) { '[DRY-RUN SIMULATION]' } else { '' })" -Level HEADER
if (-not $NoLog -and $script:ActiveLogFile) {
    Write-Log "  Log File       : $script:ActiveLogFile" -Level HEADER
}
Write-Log "================================================================================" -Level HEADER

# ==============================================================================
# HELPER FUNCTIONS: FEATURE METADATA & DETAILS RETRIEVAL
# ==============================================================================
function Get-CimOptionalFeatureMap {
    <#
    .SYNOPSIS
        Retrieves Win32_OptionalFeature instances via CIM in a single fast query
        to populate localized DisplayName (Caption) and Description for all features.
    #>
    $map = @{}
    try {
        $cimFeatures = Get-CimInstance -ClassName Win32_OptionalFeature -ErrorAction SilentlyContinue
        if ($null -ne $cimFeatures) {
            foreach ($cf in $cimFeatures) {
                if (-not [string]::IsNullOrWhiteSpace($cf.Name)) {
                    $map[$cf.Name] = [PSCustomObject]@{
                        DisplayName  = $cf.Caption
                        Description  = $cf.Description
                        InstallState = $cf.InstallState
                    }
                }
            }
        }
    }
    catch {
        # Fallback gracefully if WMI/CIM is unavailable
    }
    return $map
}

function ConvertTo-DetailedFeatureObject {
    <#
    .SYNOPSIS
        Normalizes a DISM FeatureObject + CIM metadata into a rich detailed object.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [object]$DismFeature,

        [Parameter(Mandatory = $false)]
        [hashtable]$CimMap = @{}
    )

    $featName = [string]$DismFeature.FeatureName
    $cimEntry = if ($CimMap.ContainsKey($featName)) { $CimMap[$featName] } else { $null }

    $displayName = $null
    if ($DismFeature.PSObject.Properties.Name -contains "DisplayName" -and -not [string]::IsNullOrWhiteSpace($DismFeature.DisplayName)) {
        $displayName = [string]$DismFeature.DisplayName
    }
    elseif ($null -ne $cimEntry -and -not [string]::IsNullOrWhiteSpace($cimEntry.DisplayName)) {
        $displayName = [string]$cimEntry.DisplayName
    }
    else {
        $displayName = $featName
    }

    $description = $null
    if ($DismFeature.PSObject.Properties.Name -contains "Description" -and -not [string]::IsNullOrWhiteSpace($DismFeature.Description)) {
        $description = [string]$DismFeature.Description
    }
    elseif ($null -ne $cimEntry -and -not [string]::IsNullOrWhiteSpace($cimEntry.Description)) {
        $description = [string]$cimEntry.Description
    }
    else {
        $description = "No additional description provided by Windows Component Store."
    }

    $restartReq = "Possible"
    if ($DismFeature.PSObject.Properties.Name -contains "RestartRequired" -and $null -ne $DismFeature.RestartRequired) {
        $restartReq = [string]$DismFeature.RestartRequired
    }

    $customPropsText = "None"
    if ($DismFeature.PSObject.Properties.Name -contains "CustomProperties" -and $null -ne $DismFeature.CustomProperties) {
        $propsList = @()
        foreach ($cp in $DismFeature.CustomProperties) {
            if ($null -ne $cp -and -not [string]::IsNullOrWhiteSpace($cp.Name)) {
                $propsList += "$($cp.Name)=$($cp.Value)"
            }
        }
        if ($propsList.Count -gt 0) {
            $customPropsText = $propsList -join "; "
        }
    }

    return [PSCustomObject]@{
        FeatureName      = $featName
        DisplayName      = $displayName
        State            = [string]$DismFeature.State
        RestartRequired  = $restartReq
        Description      = ($description -replace "\r?\n", " ").Trim()
        CustomProperties = $customPropsText
        Online           = [bool]$DismFeature.Online
    }
}

function Get-SingleFeatureFullDetails {
    <#
    .SYNOPSIS
        Queries Get-WindowsOptionalFeature -Online -FeatureName <Name> to obtain
        the complete AdvancedFeatureObject (DisplayName, Description, RestartRequired,
        CustomProperties) for a specific feature.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$TargetFeatureName,

        [Parameter(Mandatory = $false)]
        [hashtable]$CimMap = @{}
    )

    $advFeature = Get-WindowsOptionalFeature -Online -FeatureName $TargetFeatureName -ErrorAction SilentlyContinue
    if ($null -eq $advFeature) {
        return $null
    }
    return (ConvertTo-DetailedFeatureObject -DismFeature $advFeature -CimMap $CimMap)
}

function Show-FeatureDetailCard {
    <#
    .SYNOPSIS
        Prints a formatted, color-coded detail card for a Windows Optional Feature.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FeatureDetail,

        [Parameter(Mandatory = $false)]
        [string]$ContextTitle = "FEATURE DETAILS"
    )

    $stateColor = switch ($FeatureDetail.State) {
        "Enabled"                    { [ConsoleColor]::Green }
        "Disabled"                   { [ConsoleColor]::DarkGray }
        "DisabledWithPayloadRemoved" { [ConsoleColor]::DarkYellow }
        "EnablePending"              { [ConsoleColor]::Cyan }
        "DisablePending"             { [ConsoleColor]::Yellow }
        default                      { [ConsoleColor]::White }
    }

    Write-Log "--------------------------------------------------------------------------------" -Color DarkCyan
    Write-Log "  [$ContextTitle] $($FeatureDetail.FeatureName)" -Color Cyan
    Write-Log "--------------------------------------------------------------------------------" -Color DarkCyan
    Write-Log "  Feature Name      : $($FeatureDetail.FeatureName)" -Color White
    Write-Log "  Display Name      : $($FeatureDetail.DisplayName)" -Color White
    Write-Log "  Current State     : $($FeatureDetail.State)" -Color $stateColor
    Write-Log "  Restart Required  : $($FeatureDetail.RestartRequired)" -Color White
    Write-Log "  Description       : $($FeatureDetail.Description)" -Color Gray
    if ($FeatureDetail.CustomProperties -ne "None") {
        Write-Log "  Custom Properties : $($FeatureDetail.CustomProperties)" -Color DarkGray
    }
}

function Request-BilingualConfirmation {
    <#
    .SYNOPSIS
        Prompts the user for confirmation supporting both English (Y/N) and Polish (T/N).
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$PromptMessage
    )

    if ($Force) {
        return $true
    }

    while ($true) {
        Write-Host "`n[?] $PromptMessage [Y/T = Yes/Tak, N = No/Nie]: " -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        if ([string]::IsNullOrWhiteSpace($response)) {
            continue
        }
        $normalized = $response.Trim().ToUpperInvariant()
        if ($normalized -in @("Y", "YES", "T", "TAK")) {
            return $true
        }
        if ($normalized -in @("N", "NO", "NIE")) {
            return $false
        }
        Write-Host "    Please enter Y (Yes) / T (Tak) or N (No / Nie)." -ForegroundColor DarkYellow
    }
}

function Export-FeatureReport {
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Data,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $parent = [System.IO.Path]::GetDirectoryName($DestinationPath)
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $ext = [System.IO.Path]::GetExtension($DestinationPath).ToLowerInvariant()
    if ($ext -eq ".json") {
        $Data | ConvertTo-Json -Depth 5 | Set-Content -Path $DestinationPath -Encoding UTF8
    }
    else {
        $Data | Export-Csv -Path $DestinationPath -NoTypeInformation -Encoding UTF8
    }
    Write-Log "`n[+] Feature report exported successfully to: '$DestinationPath'" -Level SUCCESS
}

# ==============================================================================
# MAIN EXECUTION WORKFLOW
# ==============================================================================
try {
    Write-Log "`n[*] Querying Windows Component Store (DISM & CIM Win32_OptionalFeature)..." -Level STEP
    $cimFeatureMap = Get-CimOptionalFeatureMap
    $allBasicFeatures = @(Get-WindowsOptionalFeature -Online -ErrorAction Stop)
    Write-Log " -> Discovered $($allBasicFeatures.Count) total Windows Optional Features on this system." -Level INFO

    # Resolve matching features if patterns were supplied
    $matchedBasicFeatures = [System.Collections.Generic.List[object]]::new()
    $unmatchedPatterns = [System.Collections.Generic.List[string]]::new()

    if ($resolvedFeaturePatterns.Count -gt 0) {
        foreach ($pattern in $resolvedFeaturePatterns) {
            $hasWildcard = [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($pattern)
            $matchesForPattern = if ($hasWildcard) {
                @($allBasicFeatures | Where-Object {
                    $fn = $_.FeatureName
                    $dn = if ($cimFeatureMap.ContainsKey($fn)) { $cimFeatureMap[$fn].DisplayName } else { "" }
                    ($fn -like $pattern) -or ($dn -like $pattern)
                })
            }
            else {
                @($allBasicFeatures | Where-Object { $_.FeatureName -ieq $pattern })
            }

            if ($matchesForPattern.Count -eq 0) {
                $unmatchedPatterns.Add($pattern)
            }
            else {
                foreach ($m in $matchesForPattern) {
                    if (-not ($matchedBasicFeatures | Where-Object { $_.FeatureName -eq $m.FeatureName })) {
                        $matchedBasicFeatures.Add($m)
                    }
                }
            }
        }
    }
    else {
        foreach ($bf in $allBasicFeatures) {
            $matchedBasicFeatures.Add($bf)
        }
    }

    if ($unmatchedPatterns.Count -gt 0) {
        foreach ($missing in $unmatchedPatterns) {
            Write-Log "[-] Warning: No Windows Optional Feature matched '$missing'." -Level WARN
        }
    }

    # --------------------------------------------------------------------------
    # MODE 1: LIST OR INSPECT FEATURE DETAILS
    # --------------------------------------------------------------------------
    if ($Action -in @("List", "Details")) {
        $filteredFeatures = @($matchedBasicFeatures)
        if ($State -ne "All") {
            $filteredFeatures = @($filteredFeatures | Where-Object { [string]$_.State -ieq $State })
        }

        if ($filteredFeatures.Count -eq 0) {
            Write-Log "`n[!] No Windows Optional Features matched the specified criteria (State: $State)." -Level WARN
            return
        }

        $detailedResults = [System.Collections.Generic.List[PSCustomObject]]::new()
        $useDeepDismLookup = ($Action -eq "Details") -or $Detailed -or ($filteredFeatures.Count -le 25)

        Write-Log "[*] Collecting feature details for $($filteredFeatures.Count) feature(s)..." -Level STEP

        $counter = 0
        foreach ($feat in ($filteredFeatures | Sort-Object FeatureName)) {
            $counter++
            if ($useDeepDismLookup) {
                Write-Progress -Activity "Inspecting Windows Optional Features" `
                    -Status "Reading full DISM metadata for $($feat.FeatureName) ($counter of $($filteredFeatures.Count))" `
                    -PercentComplete ([math]::Min(100, [int](($counter / $filteredFeatures.Count) * 100)))

                $detailObj = Get-SingleFeatureFullDetails -TargetFeatureName $feat.FeatureName -CimMap $cimFeatureMap
                if ($null -eq $detailObj) {
                    $detailObj = ConvertTo-DetailedFeatureObject -DismFeature $feat -CimMap $cimFeatureMap
                }
                $detailedResults.Add($detailObj)
            }
            else {
                $detailObj = ConvertTo-DetailedFeatureObject -DismFeature $feat -CimMap $cimFeatureMap
                $detailedResults.Add($detailObj)
            }
        }
        Write-Progress -Activity "Inspecting Windows Optional Features" -Completed

        # Display results
        Write-Log "`n================================================================================" -Level HEADER
        Write-Log "  WINDOWS OPTIONAL FEATURES - DETAILED CATALOG ($($detailedResults.Count) Features)" -Level HEADER
        Write-Log "================================================================================" -Level HEADER

        if ($Detailed -or $Action -eq "Details" -or $detailedResults.Count -le 10) {
            foreach ($item in $detailedResults) {
                Show-FeatureDetailCard -FeatureDetail $item -ContextTitle "OPTIONAL FEATURE DETAILS"
            }
        }
        else {
            # Display rich table with FeatureName, State, DisplayName, RestartRequired, and Description
            $tableOutput = $detailedResults | Select-Object `
                FeatureName,
                State,
                DisplayName,
                RestartRequired,
                @{ Name = "Description"; Expression = {
                    if ($_.Description.Length -gt 75) { $_.Description.Substring(0, 72) + "..." } else { $_.Description }
                }} | Format-Table -AutoSize -Wrap | Out-String -Width 180

            Write-Host $tableOutput
            Write-Log " [i] Tip: Use '-Detailed' or '-FeatureName <Name>' to view full multi-line descriptions and custom properties." -Color Cyan
        }

        # Summary breakdown by state
        $enabledCount  = @($detailedResults | Where-Object { $_.State -eq "Enabled" }).Count
        $disabledCount = @($detailedResults | Where-Object { $_.State -like "Disabled*" }).Count
        $pendingCount  = @($detailedResults | Where-Object { $_.State -like "*Pending*" }).Count

        Write-Log "`n================================================================================" -Level HEADER
        Write-Log "  SUMMARY: Total Listed: $($detailedResults.Count) | Enabled: $enabledCount | Disabled: $disabledCount | Pending Reboot: $pendingCount" -Level HEADER
        Write-Log "================================================================================" -Level HEADER

        if (-not [string]::IsNullOrWhiteSpace($ExportPath)) {
            Export-FeatureReport -Data $detailedResults -DestinationPath $ExportPath
        }

        if ($PassThru) {
            return $detailedResults
        }
        return
    }

    # --------------------------------------------------------------------------
    # MODE 2: ENABLE OR DISABLE WINDOWS OPTIONAL FEATURES
    # --------------------------------------------------------------------------
    if ($matchedBasicFeatures.Count -eq 0) {
        throw "No matching Windows Optional Features were found for the specified -FeatureName parameter."
    }

    Write-Log "`n[*] Inspecting current state and full details of target feature(s) before '$Action'..." -Level STEP
    $preOperationDetails = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($target in $matchedBasicFeatures) {
        $fullDetail = Get-SingleFeatureFullDetails -TargetFeatureName $target.FeatureName -CimMap $cimFeatureMap
        if ($null -eq $fullDetail) {
            $fullDetail = ConvertTo-DetailedFeatureObject -DismFeature $target -CimMap $cimFeatureMap
        }
        $preOperationDetails.Add($fullDetail)
        Show-FeatureDetailCard -FeatureDetail $fullDetail -ContextTitle "BEFORE $($Action.ToUpperInvariant())"
    }

    if ($DryRun) {
        Write-Log "`n[DRY-RUN] Simulation active (-DryRun). The following operation would be executed:" -Level WARN
        foreach ($item in $preOperationDetails) {
            Write-Log " -> Would $($Action.ToUpperInvariant()) feature '$($item.FeatureName)' ($($item.DisplayName)) [Current State: $($item.State)]" -Level WARN
        }
        if ($PassThru) {
            return $preOperationDetails
        }
        return
    }

    # Ask for confirmation unless -Force is specified
    $targetNamesList = ($preOperationDetails | Select-Object -ExpandProperty FeatureName) -join ", "
    $confirmMsg = "Are you sure you want to $($Action.ToUpperInvariant()) $($preOperationDetails.Count) feature(s): [$targetNamesList]?"
    if (-not (Request-BilingualConfirmation -PromptMessage $confirmMsg)) {
        Write-Log "`n[!] Operation cancelled by user." -Level WARN
        return
    }

    $operationResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $anyRestartNeeded = $false
    $index = 0

    foreach ($featureObj in $preOperationDetails) {
        $index++
        $fname = $featureObj.FeatureName
        $previousState = $featureObj.State

        Write-Progress -Activity "$Action Windows Optional Features" `
            -Status "Processing $fname ($index of $($preOperationDetails.Count))" `
            -PercentComplete ([math]::Min(100, [int](($index / $preOperationDetails.Count) * 100)))

        Write-Log "`n[$index/$($preOperationDetails.Count)] Processing feature '$fname' ($($featureObj.DisplayName))..." -Level STEP

        $statusText = "Unchanged"
        $restartNeededForThis = $false

        try {
            if ($Action -eq "Enable") {
                if ($previousState -eq "Enabled") {
                    Write-Log " -> Feature '$fname' is already Enabled. Skipping state modification." -Level SUCCESS
                    $statusText = "AlreadyEnabled"
                }
                else {
                    $enableParams = @{
                        Online      = $true
                        FeatureName = $fname
                        NoRestart   = $true
                        ErrorAction = "Stop"
                    }
                    if ($IncludeParentFeatures) {
                        $enableParams["All"] = $true
                    }
                    if ($null -ne $Source -and $Source.Count -gt 0) {
                        $enableParams["Source"] = $Source
                    }
                    if ($LimitAccess) {
                        $enableParams["LimitAccess"] = $true
                    }

                    Write-Log " -> Enabling feature '$fname' via DISM (IncludeParentFeatures=$IncludeParentFeatures)..." -Level INFO
                    $dismResult = Enable-WindowsOptionalFeature @enableParams
                    if ($null -ne $dismResult -and $dismResult.RestartNeeded) {
                        $restartNeededForThis = $true
                        $anyRestartNeeded = $true
                    }
                    $statusText = "EnabledSuccessfully"
                    Write-Log " -> Successfully enabled '$fname'." -Level SUCCESS
                }
            }
            elseif ($Action -eq "Disable") {
                if ($previousState -like "Disabled*") {
                    Write-Log " -> Feature '$fname' is already Disabled ($previousState). Skipping state modification." -Level SUCCESS
                    $statusText = "AlreadyDisabled"
                }
                else {
                    $disableParams = @{
                        Online      = $true
                        FeatureName = $fname
                        NoRestart   = $true
                        ErrorAction = "Stop"
                    }
                    if ($RemovePayload) {
                        $disableParams["Remove"] = $true
                    }

                    Write-Log " -> Disabling feature '$fname' via DISM (RemovePayload=$RemovePayload)..." -Level INFO
                    $dismResult = Disable-WindowsOptionalFeature @disableParams
                    if ($null -ne $dismResult -and $dismResult.RestartNeeded) {
                        $restartNeededForThis = $true
                        $anyRestartNeeded = $true
                    }
                    $statusText = "DisabledSuccessfully"
                    Write-Log " -> Successfully disabled '$fname'." -Level SUCCESS
                }
            }
        }
        catch {
            $statusText = "Failed: $($_.Exception.Message)"
            Write-Log " -> [-] Failed to $($Action.ToLowerInvariant()) feature '$fname': $($_.Exception.Message)" -Level ERROR
        }

        # Re-query feature details after the operation to show updated state
        $updatedDetail = Get-SingleFeatureFullDetails -TargetFeatureName $fname -CimMap $cimFeatureMap
        if ($null -eq $updatedDetail) {
            $updatedDetail = $featureObj
        }

        Show-FeatureDetailCard -FeatureDetail $updatedDetail -ContextTitle "AFTER $($Action.ToUpperInvariant())"

        $operationResults.Add([PSCustomObject]@{
            FeatureName      = $updatedDetail.FeatureName
            DisplayName      = $updatedDetail.DisplayName
            Action           = $Action
            PreviousState    = $previousState
            CurrentState     = $updatedDetail.State
            OperationStatus  = $statusText
            RestartNeeded    = $restartNeededForThis
            RestartRequired  = $updatedDetail.RestartRequired
            Description      = $updatedDetail.Description
            CustomProperties = $updatedDetail.CustomProperties
            Timestamp        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        })
    }

    Write-Progress -Activity "$Action Windows Optional Features" -Completed

    # Final Execution Summary
    Write-Log "`n================================================================================" -Level HEADER
    Write-Log "  OPERATION EXECUTION SUMMARY ($Action)" -Level HEADER
    Write-Log "================================================================================" -Level HEADER

    $summaryTable = $operationResults | Select-Object `
        FeatureName,
        DisplayName,
        PreviousState,
        CurrentState,
        OperationStatus,
        RestartNeeded | Format-Table -AutoSize | Out-String -Width 160
    Write-Host $summaryTable

    if (-not [string]::IsNullOrWhiteSpace($ExportPath)) {
        Export-FeatureReport -Data $operationResults -DestinationPath $ExportPath
    }

    if ($anyRestartNeeded) {
        Write-Log "[!] NOTICE: One or more Windows Optional Features require a system restart to complete the changes." -Level WARN
        if ($Restart) {
            Write-Log "[*] -Restart switch was specified. Initiating system restart in 10 seconds..." -Level WARN
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        }
        else {
            Write-Log "    Please reboot this computer at your convenience (or re-run with -Restart)." -Level INFO
        }
    }
    else {
        Write-Log "[+] All operations finished without requiring a system reboot." -Level SUCCESS
    }

    if ($PassThru) {
        return $operationResults
    }
}
catch {
    Write-Log "`n[-] CRITICAL ERROR: $($_.Exception.Message)" -Level ERROR
    throw
}
