<#
================================================================================
  Script Name : deploy-WireGuardClient.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  Version     : 1.2.0
  Release Date: 2026-10-18
  License     : MIT
  Repository  : https://github.com/romanpindela

  DESCRIPTION:
    Enterprise-grade PowerShell automation tool for deploying and updating the
    official WireGuard VPN Client (WireGuard.WireGuard) via Windows Package
    Manager (winget) and importing optional WireGuard tunnel configuration
    files (.conf / .conf.dpapi) into the client settings across Windows 10,
    Windows 11, and Windows Server (English and Polish editions).

    Key Capabilities:
    1. Zero-Parameter Interactive Help (-Help / -h):
       Displays complete syntax, parameter documentation, usage examples,
       version, and author details when launched without arguments—without
       triggering an unnecessary UAC prompt.
    2. Automated WireGuard Client Deployment & Update via Winget:
       Verifies winget availability, checks existing WireGuard installations,
       downloads and installs/upgrades the latest official WireGuard client
       (WireGuard.WireGuard), and ensures the WireGuardManager Windows service
       is installed and running.
    3. Optional Configuration Profile Import (-ConfigPath):
       Validates, parses (masking sensitive PrivateKey/PresharedKey values),
       and imports one or more WireGuard tunnel configuration files (.conf)
       into WireGuard's secure configuration store
       (C:\Program Files\WireGuard\Data\Configurations\), where WireGuardManager
       automatically encrypts them via Windows DPAPI (.conf.dpapi) for immediate
       availability in the WireGuard GUI. Optionally activates the VPN tunnel
       service immediately when -ActivateTunnel is specified.
    4. Detailed Step-by-Step Telemetry, Execution Summary & User Guide:
       Displays granular progress for every stage of execution and concludes
       with a structured summary report and a concise end-user quick-start guide.
    5. Input Sanitization & Defensive Validation:
       Protects against command injection, path traversal, and malformed
       configuration files or tunnel names.
    6. Language-Independent UAC Auto-Elevation:
       Verifies Administrator privileges using the well-known Windows SID
       (S-1-5-32-544 / BuiltInAdministratorsSid) for 100% compatibility across
       Polish ("Administratorzy") and English ("Administrators") Windows systems,
       and automatically elevates via UAC while preserving all CLI parameters.
    7. Detailed Audit Logging:
       Logs all operations with UTF-8 timestamps to:
       C:\Logs\<yyyyMMdd_HHmmss>-deploy-WireGuardClient-<ComputerName>-<UserName>.logs
================================================================================
.SYNOPSIS
    Deploys or updates the WireGuard VPN Client via winget and optionally imports
    a WireGuard tunnel configuration file (.conf) into the client settings.

.DESCRIPTION
    Automates the complete lifecycle of deploying the WireGuard VPN Client on
    Windows workstations and servers:
    - Running without parameters or with -Help / -h displays full help, examples,
      version, and author information.
    - Running with -Install (or providing -ConfigPath) checks winget, downloads
      and installs/updates the official WireGuard client (WireGuard.WireGuard),
      initializes the WireGuardManager service, and optionally imports a .conf
      tunnel profile into WireGuard settings (and optionally activates the tunnel).
    - Prints detailed progress for every operation, a final execution summary,
      and a concise quick-start instruction guide for the end user.

.PARAMETER ConfigPath
    Optional path (or array of paths) to a WireGuard configuration file (.conf
    or .conf.dpapi) to be imported into the WireGuard client settings.
    When provided, the script ensures WireGuard is installed/up-to-date and
    imports the configuration into C:\Program Files\WireGuard\Data\Configurations\.
    Aliases: -Config, -ConfigFile, -Path, -File, -c

.PARAMETER Install
    Switch parameter. Deploys or updates the WireGuard client via winget even
    when no -ConfigPath file is provided.
    Aliases: -Deploy, -Setup, -i

.PARAMETER TunnelName
    Optional custom name for the imported WireGuard tunnel (1-32 characters:
    alphanumeric, '_', '=', '+', '.', '-'). Used when importing a single
    configuration file. If omitted, the base filename of the .conf file is used.
    Aliases: -Name

.PARAMETER ActivateTunnel
    Switch parameter. Immediately installs and starts the Windows tunnel service
    (WireGuardTunnel$<TunnelName>) after importing the configuration file so the
    VPN connection becomes active right away.
    Aliases: -Activate, -Connect, -StartTunnel

.PARAMETER LaunchGUI
    Switch parameter. Launches the WireGuard GUI client window after deployment
    completes so the user can immediately view and manage tunnels.
    Aliases: -OpenClient, -ShowGUI

.PARAMETER ForceUpgrade
    Switch parameter. Forces a winget upgrade check/update even if WireGuard is
    already detected on the workstation.
    Aliases: -Upgrade, -Update, -u

.PARAMETER ForceOverwrite
    Switch parameter. Overwrites an existing WireGuard tunnel configuration in
    C:\Program Files\WireGuard\Data\Configurations\ without prompting if a
    tunnel with the same name already exists.
    Aliases: -Overwrite, -Force, -f

.PARAMETER Status
    Switch parameter. Inspects and displays the current WireGuard client version,
    Windows service states (WireGuardManager and WireGuardTunnel$*), imported
    configurations, and active tunnel interfaces without performing installation.
    Aliases: -Check, -Verify, -Info

.PARAMETER PackageId
    Specifies the winget package identifier for the WireGuard client.
    Default: 'WireGuard.WireGuard'

.PARAMETER InstallDir
    Specifies the installation directory of WireGuard on Windows.
    Default: "$env:ProgramFiles\WireGuard"

.PARAMETER DryRun
    Switch parameter. Simulates all deployment, winget, and configuration import
    operations without modifying the operating system.
    Aliases: -Simulate, -Preview

.PARAMETER SkipAdminCheck
    Switch parameter. Skips automatic UAC Administrator privilege elevation check.

.PARAMETER PassThru
    Switch parameter. Returns the structured deployment summary object to the
    PowerShell pipeline.

.PARAMETER LogPath
    Custom file path for the execution log.
    Default: C:\Logs\<yyyyMMdd_HHmmss>-deploy-WireGuardClient-<ComputerName>-<UserName>.logs
    Aliases: -l, -Log

.PARAMETER NoLog
    Switch parameter. Disables writing execution logs to disk.

.PARAMETER Help
    Switch parameter (-Help / -h). Displays this help guide, usage examples,
    author details, and version information.
    Aliases: -h

.EXAMPLE
    .\deploy-WireGuardClient.ps1
    Displays the help screen, usage syntax, parameter reference, examples,
    version, and author details without requiring UAC elevation.

.EXAMPLE
    .\deploy-WireGuardClient.ps1 -Install
    Downloads and installs (or updates) the latest WireGuard client via winget,
    ensures the WireGuardManager service is running, and displays a summary and
    user guide.

.EXAMPLE
    .\deploy-WireGuardClient.ps1 -ConfigPath "C:\VPN\office-vpn.conf"
    Installs/verifies the WireGuard client via winget and imports the
    'office-vpn.conf' configuration file into the WireGuard client settings.

.EXAMPLE
    .\deploy-WireGuardClient.ps1 -ConfigPath "C:\VPN\office-vpn.conf" -ActivateTunnel -LaunchGUI
    Installs/verifies WireGuard, imports 'office-vpn.conf', immediately activates
    the VPN tunnel service (WireGuardTunnel$office-vpn), and opens the WireGuard GUI.

.EXAMPLE
    .\deploy-WireGuardClient.ps1 -ConfigPath "C:\VPN\client01.conf" -TunnelName "Corp-HQ" -ForceOverwrite
    Imports 'client01.conf' under the custom tunnel name 'Corp-HQ', overwriting
    any existing 'Corp-HQ' profile without prompting.

.EXAMPLE
    .\deploy-WireGuardClient.ps1 -Status
    Displays a detailed status report of the installed WireGuard client,
    services, imported profiles, and active VPN interfaces.

.EXAMPLE
    .\deploy-WireGuardClient.ps1 -ConfigPath "C:\VPN\office-vpn.conf" -DryRun
    Simulates installing WireGuard and validating/importing 'office-vpn.conf'
    without making any changes to the system.

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
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("Config", "ConfigFile", "Path", "File", "c")]
    [string[]]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [Alias("Deploy", "Setup", "i")]
    [switch]$Install,

    [Parameter(Mandatory = $false)]
    [Alias("Name")]
    [string]$TunnelName,

    [Parameter(Mandatory = $false)]
    [Alias("Activate", "Connect", "StartTunnel")]
    [switch]$ActivateTunnel,

    [Parameter(Mandatory = $false)]
    [Alias("OpenClient", "ShowGUI")]
    [switch]$LaunchGUI,

    [Parameter(Mandatory = $false)]
    [Alias("Upgrade", "Update", "u")]
    [switch]$ForceUpgrade,

    [Parameter(Mandatory = $false)]
    [Alias("Overwrite", "Force", "f")]
    [switch]$ForceOverwrite,

    [Parameter(Mandatory = $false)]
    [Alias("Check", "Verify", "Info")]
    [switch]$Status,

    [Parameter(Mandatory = $false)]
    [string]$PackageId = "WireGuard.WireGuard",

    [Parameter(Mandatory = $false)]
    [string]$InstallDir = "$env:ProgramFiles\WireGuard",

    [Parameter(Mandatory = $false)]
    [Alias("Simulate", "Preview")]
    [switch]$DryRun,

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
    Name        = "deploy-WireGuardClient"
    FileName    = "deploy-WireGuardClient.ps1"
    Version     = "1.2.0"
    Author      = "Roman Pindela"
    Contact     = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    ReleaseDate = "2026-10-18"
    License     = "MIT"
}

$script:ActiveLogFile = $null
$script:StartTime = Get-Date

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
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "STEP", "HEADER", "DETAIL")]
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
        "DETAIL"  = [ConsoleColor]::Gray
    }

    $effectiveColor = if ($PSBoundParameters.ContainsKey("Color")) {
        $Color
    }
    else {
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
function Protect-FilePathInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw "Validation Error: Parameter '$ParameterName' cannot be empty or whitespace."
    }

    if ($PathValue.Length -gt 260) {
        throw "Validation Error: Parameter '$ParameterName' exceeds maximum path length of 260 characters."
    }

    # Block shell metacharacters and command injection vectors
    if ($PathValue -match '[`$;&|><*?"\r\n]') {
        throw "Security Alert: Parameter '$ParameterName' ('$PathValue') contains illegal or potentially dangerous characters."
    }
}

function Protect-TunnelNameInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$NameValue
    )

    if ([string]::IsNullOrWhiteSpace($NameValue)) {
        throw "Validation Error: Tunnel name cannot be empty or whitespace."
    }

    if ($NameValue.Length -gt 32) {
        throw "Validation Error: WireGuard tunnel name '$NameValue' exceeds the maximum allowed length of 32 characters."
    }

    # WireGuard for Windows allows alphanumeric characters and '_', '=', '+', '.', '-'
    if ($NameValue -notmatch '^[a-zA-Z0-9_=+.\-]+$') {
        throw "Security Alert: Tunnel name '$NameValue' contains invalid characters. Only alphanumeric characters and '_', '=', '+', '.', '-' (max 32 chars) are permitted by WireGuard."
    }
}

function Protect-PackageIdInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IdValue
    )

    if ([string]::IsNullOrWhiteSpace($IdValue) -or $IdValue.Length -gt 100) {
        throw "Validation Error: Invalid PackageId '$IdValue'."
    }

    if ($IdValue -notmatch '^[a-zA-Z0-9._\-]+$') {
        throw "Security Alert: PackageId '$IdValue' contains illegal characters."
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
  Automates the installation and update of the official WireGuard VPN Client
  (WireGuard.WireGuard) via winget, configures the WireGuardManager service,
  and optionally imports WireGuard tunnel configuration files (.conf) into the
  client settings on Windows 10, Windows 11, and Windows Server (EN/PL).

  Core Capabilities:
  1. Zero-Parameter Help (-Help / -h): Displays full usage, examples, version,
     and author information when executed without arguments.
  2. Automated Winget Deployment: Downloads and installs or updates the latest
     WireGuard client via winget and verifies service health.
  3. Optional Configuration Import (-ConfigPath): Validates and imports a
     WireGuard .conf file into C:\Program Files\WireGuard\Data\Configurations\
     (encrypted automatically via Windows DPAPI by WireGuardManager) and
     optionally activates the VPN tunnel immediately (-ActivateTunnel).
  4. Detailed Step-by-Step Progress & End-User Summary: Shows granular details
     of every stage and prints a final summary + quick-start instructions.
  5. Multi-Language UAC Auto-Elevation: Uses Windows SID (S-1-5-32-544) for
     full compatibility with Polish ("Administratorzy") and English
     ("Administrators") Windows systems.
  6. Audit Logging: Automatically writes detailed execution logs to:
     C:\Logs\<yyyyMMdd_HHmmss>-deploy-WireGuardClient-<ComputerName>-<UserName>.logs

SYNTAX:
  # 1. Display Help (Default when run without parameters):
  .\deploy-WireGuardClient.ps1 [-Help | -h]

  # 2. Install / Update WireGuard Client Only (without config file):
  .\deploy-WireGuardClient.ps1 -Install [-ForceUpgrade] [-LaunchGUI] [-DryRun]

  # 3. Install / Update WireGuard Client & Import Configuration File(s):
  .\deploy-WireGuardClient.ps1 [-ConfigPath] <File.conf[]> [-TunnelName <Name>]
      [-ActivateTunnel] [-ForceOverwrite] [-LaunchGUI] [-DryRun]

  # 4. Inspect Installed WireGuard Client, Services & Active Tunnels:
  .\deploy-WireGuardClient.ps1 -Status

PARAMETERS:
  -ConfigPath <String[]>  : Optional path(s) to WireGuard .conf (or .conf.dpapi)
                            configuration file(s) to import into client settings
                            (Aliases: -Config, -ConfigFile, -Path, -File, -c).
  -Install                : Installs or updates the WireGuard client even when
                            no -ConfigPath is specified (Aliases: -Deploy, -i).
  -TunnelName <String>    : Custom tunnel name (max 32 chars) when importing a
                            single .conf file (Default: .conf filename).
  -ActivateTunnel         : Immediately installs and starts the Windows service
                            WireGuardTunnel$<TunnelName> so the VPN connects
                            right away (Aliases: -Activate, -Connect).
  -LaunchGUI              : Opens the WireGuard GUI application after execution
                            (Aliases: -OpenClient, -ShowGUI).
  -ForceUpgrade           : Forces checking and upgrading WireGuard via winget
                            if already installed (Aliases: -Upgrade, -Update, -u).
  -ForceOverwrite         : Overwrites existing tunnel configuration with the
                            same name without prompting (Aliases: -Overwrite, -f).
  -Status                 : Displays current WireGuard version, services, and
                            imported/active tunnels (Aliases: -Check, -Verify).
  -PackageId <String>     : Winget Package ID (Default: 'WireGuard.WireGuard').
  -InstallDir <String>    : WireGuard directory (Default: 'C:\Program Files\WireGuard').
  -DryRun                 : Simulates deployment and config import without
                            making system changes (Aliases: -Simulate, -Preview).
  -LogPath <String>       : Custom log file path (Default: C:\Logs\...).
  -NoLog                  : Disables writing execution logs to disk.
  -Help / -h              : Displays this help guide and exits.

PRACTICAL EXAMPLES:
  1. Display help, author, and version info (zero-parameter run):
     .\deploy-WireGuardClient.ps1

  2. Download and install/update the WireGuard client via winget (no config):
     .\deploy-WireGuardClient.ps1 -Install

  3. Install WireGuard and import a VPN configuration file into settings:
     .\deploy-WireGuardClient.ps1 -ConfigPath "C:\VPN\office-vpn.conf"

  4. Install WireGuard, import config, activate VPN tunnel immediately, and open GUI:
     .\deploy-WireGuardClient.ps1 -ConfigPath "C:\VPN\office-vpn.conf" -ActivateTunnel -LaunchGUI

  5. Import a configuration with a custom tunnel name and overwrite if existing:
     .\deploy-WireGuardClient.ps1 -ConfigPath ".\wg0.conf" -TunnelName "Corp-VPN" -ForceOverwrite

  6. Check current WireGuard installation, services, and tunnel status:
     .\deploy-WireGuardClient.ps1 -Status

  7. Simulate deployment and configuration validation (Dry-Run mode):
     .\deploy-WireGuardClient.ps1 -ConfigPath "C:\VPN\office-vpn.conf" -DryRun

FIRST RUN / UNBLOCKING NOTE:
  After downloading this script from GitHub, unblock it before running:
     Unblock-File -Path .\deploy-WireGuardClient.ps1
================================================================================
"@ -ForegroundColor Yellow
}

# ==============================================================================
# ZERO-PARAMETER & HELP CHECK
# ==============================================================================
$hasConfigFiles = ($null -ne $ConfigPath -and $ConfigPath.Count -gt 0)
$hasActionTrigger = $Install -or $ForceUpgrade -or $Status -or $hasConfigFiles

if ($Help -or (-not $hasActionTrigger)) {
    Show-HelpGuide
    return
}

# ==============================================================================
# VALIDATE & SANITIZE USER INPUTS BEFORE ELEVATION
# ==============================================================================
Protect-PackageIdInput -IdValue $PackageId
Protect-FilePathInput -PathValue $InstallDir -ParameterName "InstallDir"

if (-not [string]::IsNullOrWhiteSpace($TunnelName)) {
    Protect-TunnelNameInput -NameValue $TunnelName
}

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    Protect-FilePathInput -PathValue $LogPath -ParameterName "LogPath"
}

$resolvedConfigFiles = [System.Collections.Generic.List[string]]::new()
if ($hasConfigFiles) {
    foreach ($rawItem in $ConfigPath) {
        if (-not [string]::IsNullOrWhiteSpace($rawItem)) {
            foreach ($splitItem in ($rawItem -split ',')) {
                $trimmed = $splitItem.Trim()
                if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                    Protect-FilePathInput -PathValue $trimmed -ParameterName "ConfigPath"
                    if (-not (Test-Path -LiteralPath $trimmed -PathType Leaf)) {
                        throw "Validation Error: Configuration file does not exist at path: '$trimmed'"
                    }
                    $fullResolved = (Resolve-Path -LiteralPath $trimmed).Path
                    $ext = [System.IO.Path]::GetExtension($fullResolved).ToLowerInvariant()
                    if ($ext -ne ".conf" -and -not $fullResolved.ToLowerInvariant().EndsWith(".conf.dpapi")) {
                        throw "Validation Error: Configuration file '$fullResolved' must have a '.conf' or '.conf.dpapi' extension."
                    }
                    if (-not $resolvedConfigFiles.Contains($fullResolved)) {
                        $resolvedConfigFiles.Add($fullResolved)
                    }
                }
            }
        }
    }

    if ($resolvedConfigFiles.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($TunnelName)) {
        throw "Validation Error: Custom -TunnelName cannot be used when importing multiple configuration files simultaneously."
    }
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

    if ($Install) { $relaunchArgs.Add("-Install") }
    if ($resolvedConfigFiles.Count -gt 0) {
        $joinedConfigs = ($resolvedConfigFiles | ForEach-Object { "`"$_`"" }) -join ","
        $relaunchArgs.Add("-ConfigPath")
        $relaunchArgs.Add($joinedConfigs)
    }
    if (-not [string]::IsNullOrWhiteSpace($TunnelName)) {
        $relaunchArgs.Add("-TunnelName")
        $relaunchArgs.Add("`"$TunnelName`"")
    }
    if ($ActivateTunnel) { $relaunchArgs.Add("-ActivateTunnel") }
    if ($LaunchGUI) { $relaunchArgs.Add("-LaunchGUI") }
    if ($ForceUpgrade) { $relaunchArgs.Add("-ForceUpgrade") }
    if ($ForceOverwrite) { $relaunchArgs.Add("-ForceOverwrite") }
    if ($Status) { $relaunchArgs.Add("-Status") }
    if ($PackageId -ne "WireGuard.WireGuard") {
        $relaunchArgs.Add("-PackageId")
        $relaunchArgs.Add("`"$PackageId`"")
    }
    if ($InstallDir -ne "$env:ProgramFiles\WireGuard") {
        $relaunchArgs.Add("-InstallDir")
        $relaunchArgs.Add("`"$InstallDir`"")
    }
    if ($DryRun) { $relaunchArgs.Add("-DryRun") }
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
$osCaption = if ($osInfo) { "$($osInfo.Caption) (Build $($osInfo.BuildNumber), $($osInfo.OSArchitecture))" } else { [System.Environment]::OSVersion.VersionString }

$operationMode = if ($Status) {
    "Status Inspection"
}
elseif ($resolvedConfigFiles.Count -gt 0) {
    "Client Deployment + Configuration Import ($($resolvedConfigFiles.Count) file(s))"
}
else {
    "Client Deployment / Update Only"
}

Write-Log "================================================================================" -Level HEADER
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) | Author: $($SCRIPT_INFO.Author)" -Level HEADER
Write-Log "  OS Environment : $osCaption" -Level HEADER
Write-Log "  Computer / User: $([System.Environment]::MachineName) \ $([System.Environment]::UserName)" -Level HEADER
Write-Log "  Admin Elevated : $isAdmin (Verified via SID S-1-5-32-544)" -Level HEADER
Write-Log "  Operation Mode : $operationMode $(if ($DryRun) { '[DRY-RUN SIMULATION]' } else { '' })" -Level HEADER
if (-not $NoLog -and $script:ActiveLogFile) {
    Write-Log "  Log File       : $script:ActiveLogFile" -Level HEADER
}
Write-Log "================================================================================" -Level HEADER

# ==============================================================================
# HELPER FUNCTIONS: WIREGUARD INSPECTION, WINGET & CONFIG PARSING
# ==============================================================================
function Refresh-ProcessPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    $combined = "$machinePath;$userPath"
    if (-not [string]::IsNullOrWhiteSpace($InstallDir) -and ($combined -notlike "*$InstallDir*")) {
        $combined = "$combined;$InstallDir"
    }
    $env:Path = $combined
}

function Get-WireGuardCurrentState {
    [CmdletBinding()]
    param (
        [string]$BaseDir = $InstallDir
    )

    $wgGuiExe = Join-Path -Path $BaseDir -ChildPath "wireguard.exe"
    $wgCliExe = Join-Path -Path $BaseDir -ChildPath "wg.exe"
    $configStoreDir = Join-Path -Path $BaseDir -ChildPath "Data\Configurations"

    $isInstalled = Test-Path -LiteralPath $wgGuiExe -PathType Leaf
    $guiVersion = $null
    $cliVersion = $null

    if ($isInstalled) {
        try {
            $guiItem = Get-Item -LiteralPath $wgGuiExe -ErrorAction Stop
            $guiVersion = $guiItem.VersionInfo.FileVersion
        }
        catch {}
    }

    if (Test-Path -LiteralPath $wgCliExe -PathType Leaf) {
        try {
            $cliItem = Get-Item -LiteralPath $wgCliExe -ErrorAction Stop
            $cliVersion = $cliItem.VersionInfo.FileVersion
        }
        catch {}
    }

    # Check Registry Uninstall entries for WireGuard
    $registryVersion = $null
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($regPath in $uninstallPaths) {
        $entry = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
            Where-Object { $_. PSObject.Properties.Name -contains "DisplayName" -and $_.DisplayName -eq "WireGuard" } |
            Select-Object -First 1
        if ($null -ne $entry -and $entry.PSObject.Properties.Name -contains "DisplayVersion") {
            $registryVersion = $entry.DisplayVersion
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($guiVersion) -and -not [string]::IsNullOrWhiteSpace($registryVersion)) {
        $guiVersion = $registryVersion
    }

    $managerSvc = Get-Service -Name "WireGuardManager" -ErrorAction SilentlyContinue
    $tunnelServices = @(Get-Service -Name "WireGuardTunnel`$*" -ErrorAction SilentlyContinue)

    $storedProfiles = [System.Collections.Generic.List[PSCustomObject]]::new()
    try {
        if ([System.IO.Directory]::Exists($configStoreDir)) {
            $files = Get-ChildItem -LiteralPath $configStoreDir -File -ErrorAction Stop
            foreach ($f in $files) {
                if ($f.Name -match '^(.+)\.conf(\.dpapi)?$') {
                    $tName = $Matches[1]
                    $isEncrypted = $f.Name.EndsWith(".dpapi", [System.StringComparison]::OrdinalIgnoreCase)
                    $svcName = "WireGuardTunnel`$$tName"
                    $matchingSvc = $tunnelServices | Where-Object { $_.Name -ieq $svcName } | Select-Object -First 1
                    $storedProfiles.Add([PSCustomObject]@{
                        TunnelName    = $tName
                        FileName      = $f.Name
                        FullPath      = $f.FullName
                        Encrypted     = $isEncrypted
                        SizeBytes     = $f.Length
                        LastModified  = $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                        ServiceStatus = if ($null -ne $matchingSvc) { [string]$matchingSvc.Status } else { "Inactive (On-Demand)" }
                    })
                }
            }
        }
    }
    catch {}

    return [PSCustomObject]@{
        Installed         = $isInstalled
        InstallDir        = $BaseDir
        WireGuardExe      = $wgGuiExe
        WgCliExe          = $wgCliExe
        ConfigStoreDir    = $configStoreDir
        ClientVersion     = if ($guiVersion) { $guiVersion } else { "Not Installed" }
        WgCliVersion      = if ($cliVersion) { $cliVersion } else { "Not Installed" }
        ManagerService    = if ($null -ne $managerSvc) { [string]$managerSvc.Status } else { "Not Installed" }
        ManagerStartType  = if ($null -ne $managerSvc) { [string]$managerSvc.StartType } else { "N/A" }
        ActiveTunnels     = @($tunnelServices | Where-Object { $_.Status -eq 'Running' } | ForEach-Object { $_.Name -replace '^WireGuardTunnel\$', '' })
        AllTunnelServices = $tunnelServices
        StoredProfiles    = $storedProfiles
    }
}

function Resolve-WingetExecutable {
    $cmd = Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue
    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
        return $cmd.Source
    }

    # Fallback check in WindowsApps (useful when running as elevated Admin on some systems)
    $candidatePaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
    )
    foreach ($pattern in $candidatePaths) {
        $found = Get-Item -Path $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -ne $found) {
            return $found.FullName
        }
    }

    return $null
}

function Parse-WireGuardConfigFile {
    <#
    .SYNOPSIS
        Validates a WireGuard .conf file and extracts non-sensitive metadata
        while redacting PrivateKey and PresharedKey values.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$CustomTunnelName
    )

    $fileItem = Get-Item -LiteralPath $FilePath -ErrorAction Stop
    $isDpapi = $fileItem.Name.EndsWith(".conf.dpapi", [System.StringComparison]::OrdinalIgnoreCase)

    $derivedName = if (-not [string]::IsNullOrWhiteSpace($CustomTunnelName)) {
        $CustomTunnelName
    }
    elseif ($isDpapi) {
        $fileItem.Name -replace '(?i)\.conf\.dpapi$', ''
    }
    else {
        [System.IO.Path]::GetFileNameWithoutExtension($fileItem.Name)
    }

    Protect-TunnelNameInput -NameValue $derivedName

    if ($isDpapi) {
        return [PSCustomObject]@{
            SourcePath          = $fileItem.FullName
            FileName            = $fileItem.Name
            TunnelName          = $derivedName
            IsPreEncryptedDpapi = $true
            FileSizeBytes       = $fileItem.Length
            HasInterfaceSection = $true
            HasPrivateKey       = $true
            Addresses           = @("(DPAPI Encrypted)")
            DNSServers          = @("(DPAPI Encrypted)")
            MTU                 = "(DPAPI Encrypted)"
            PeerCount           = 1
            Endpoints           = @("(DPAPI Encrypted)")
            AllowedIPs          = @("(DPAPI Encrypted)")
            Keepalive           = "(DPAPI Encrypted)"
            ValidationWarnings  = @()
        }
    }

    $lines = Get-Content -LiteralPath $fileItem.FullName -Encoding UTF8 -ErrorAction Stop
    $currentSection = ""
    $hasInterface = $false
    $hasPrivateKey = $false
    $peerCount = 0
    $addresses = [System.Collections.Generic.List[string]]::new()
    $dnsList = [System.Collections.Generic.List[string]]::new()
    $mtuValue = "Auto (Default)"
    $endpoints = [System.Collections.Generic.List[string]]::new()
    $allowedIps = [System.Collections.Generic.List[string]]::new()
    $keepalives = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#") -or $line.StartsWith(";")) {
            continue
        }

        if ($line -match '^\[([a-zA-Z0-9_]+)\]$') {
            $currentSection = $Matches[1].ToLowerInvariant()
            if ($currentSection -eq "interface") {
                $hasInterface = $true
            }
            elseif ($currentSection -eq "peer") {
                $peerCount++
            }
            continue
        }

        if ($line -match '^([a-zA-Z0-9_]+)\s*=\s*(.+)$') {
            $key = $Matches[1].Trim().ToLowerInvariant()
            $val = ($Matches[2] -replace '\s+#.*$', '').Trim()

            if ($currentSection -eq "interface") {
                switch ($key) {
                    "privatekey" {
                        if (-not [string]::IsNullOrWhiteSpace($val)) {
                            $hasPrivateKey = $true
                        }
                    }
                    "address" {
                        $addresses.Add($val)
                    }
                    "dns" {
                        $dnsList.Add($val)
                    }
                    "mtu" {
                        $mtuValue = $val
                    }
                }
            }
            elseif ($currentSection -eq "peer") {
                switch ($key) {
                    "endpoint" {
                        $endpoints.Add($val)
                    }
                    "allowedips" {
                        $allowedIps.Add($val)
                    }
                    "persistentkeepalive" {
                        $keepalives.Add("${val}s")
                    }
                }
            }
        }
    }

    if (-not $hasInterface) {
        throw "Configuration Validation Error: File '$($fileItem.FullName)' is missing a required [Interface] section."
    }
    if (-not $hasPrivateKey) {
        $warnings.Add("No 'PrivateKey' entry detected in [Interface] section.")
    }
    if ($peerCount -eq 0) {
        $warnings.Add("No '[Peer]' section detected in configuration file.")
    }

    return [PSCustomObject]@{
        SourcePath          = $fileItem.FullName
        FileName            = $fileItem.Name
        TunnelName          = $derivedName
        IsPreEncryptedDpapi = $false
        FileSizeBytes       = $fileItem.Length
        HasInterfaceSection = $hasInterface
        HasPrivateKey       = $hasPrivateKey
        Addresses           = if ($addresses.Count -gt 0) { $addresses.ToArray() } else { @("Not specified") }
        DNSServers          = if ($dnsList.Count -gt 0) { $dnsList.ToArray() } else { @("None") }
        MTU                 = $mtuValue
        PeerCount           = $peerCount
        Endpoints           = if ($endpoints.Count -gt 0) { $endpoints.ToArray() } else { @("Not specified") }
        AllowedIPs          = if ($allowedIps.Count -gt 0) { $allowedIps.ToArray() } else { @("Not specified") }
        Keepalive           = if ($keepalives.Count -gt 0) { ($keepalives -join ", ") } else { "Default / Disabled" }
        ValidationWarnings  = $warnings.ToArray()
    }
}

function Show-WireGuardStatusReport {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$StateObject
    )

    Write-Log "`n[STATUS] WireGuard Client Environment Overview:" -Level STEP
    Write-Log "  - Installed         : $($StateObject.Installed)" -Level INFO -Color $(if ($StateObject.Installed) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow })
    Write-Log "  - Install Directory : $($StateObject.InstallDir)" -Level DETAIL
    Write-Log "  - Client Version    : $($StateObject.ClientVersion)" -Level INFO
    Write-Log "  - WG CLI Version    : $($StateObject.WgCliVersion)" -Level DETAIL
    Write-Log "  - Manager Service   : WireGuardManager ($($StateObject.ManagerService), StartType: $($StateObject.ManagerStartType))" -Level INFO -Color $(if ($StateObject.ManagerService -eq "Running") { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow })
    Write-Log "  - Config Store Path : $($StateObject.ConfigStoreDir)" -Level DETAIL

    if ($StateObject.StoredProfiles.Count -gt 0) {
        Write-Log "`n  Imported Tunnel Configurations ($($StateObject.StoredProfiles.Count)):" -Level STEP
        foreach ($prof in $StateObject.StoredProfiles) {
            $encBadge = if ($prof.Encrypted) { "DPAPI Encrypted (.conf.dpapi)" } else { "Plaintext (.conf)" }
            $svcColor = if ($prof.ServiceStatus -eq "Running") { [ConsoleColor]::Green } else { [ConsoleColor]::Gray }
            Write-Log "    * Tunnel '$($prof.TunnelName)' | File: $($prof.FileName) ($($prof.SizeBytes) B) | Format: $encBadge | Status: $($prof.ServiceStatus)" -Level INFO -Color $svcColor
        }
    }
    else {
        Write-Log "`n  Imported Tunnel Configurations: None found in $($StateObject.ConfigStoreDir)" -Level DETAIL
    }

    if ($StateObject.Installed -and (Test-Path -LiteralPath $StateObject.WgCliExe -PathType Leaf)) {
        try {
            $wgShowOutput = (& $StateObject.WgCliExe show 2>$null | Out-String).Trim()
            if (-not [string]::IsNullOrWhiteSpace($wgShowOutput)) {
                Write-Log "`n  Active WireGuard Interfaces (wg.exe show):" -Level STEP
                foreach ($line in ($wgShowOutput -split "\r?\n")) {
                    Write-Log "    $line" -Level DETAIL
                }
            }
            else {
                Write-Log "`n  Active WireGuard Interfaces: No active VPN tunnels currently connected." -Level DETAIL
            }
        }
        catch {}
    }
}

# ==============================================================================
# STATUS-ONLY EXECUTION MODE
# ==============================================================================
if ($Status) {
    $currentState = Get-WireGuardCurrentState -BaseDir $InstallDir
    Show-WireGuardStatusReport -StateObject $currentState
    Write-Log "`n================================================================================" -Level HEADER
    if ($PassThru) {
        return $currentState
    }
    return
}

# ==============================================================================
# STEP 1: PRE-FLIGHT SYSTEM & WINGET ENVIRONMENT CHECK
# ==============================================================================
$totalSteps = 5
Write-Log "`n[STEP 1/$totalSteps] Verifying System Prerequisites, Winget & Current WireGuard State..." -Level STEP

$initialState = Get-WireGuardCurrentState -BaseDir $InstallDir
Write-Log "  [i] Initial WireGuard Installed : $($initialState.Installed) (Version: $($initialState.ClientVersion))" -Level DETAIL
Write-Log "  [i] Initial Manager Service     : $($initialState.ManagerService)" -Level DETAIL

$wingetExe = Resolve-WingetExecutable
$wingetVersion = "Not Found"

if ([string]::IsNullOrWhiteSpace($wingetExe)) {
    Write-Log "  [!] Windows Package Manager (winget.exe) was not found in PATH. Attempting repair via Microsoft.WinGet.Client..." -Level WARN
    if (-not $DryRun) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            if (-not (Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.201 -Force | Out-Null
            }
            if (-not (Get-Module -ListAvailable -Name "Microsoft.WinGet.Client")) {
                Install-Module -Name "Microsoft.WinGet.Client" -Force -AllowClobber -Scope AllUsers | Out-Null
            }
            Import-Module -Name "Microsoft.WinGet.Client" -Force
            Repair-WinGetPackageManager -Latest -Force
            Refresh-ProcessPath
            $wingetExe = Resolve-WingetExecutable
        }
        catch {
            throw "Critical Error: winget.exe is not available and automatic repair failed: $($_.Exception.Message)"
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($wingetExe)) {
    try {
        $wingetVersion = (& $wingetExe --version 2>$null | Out-String).Trim()
    }
    catch {
        $wingetVersion = "Unknown"
    }
    Write-Log "  [+] Winget Executable Found     : $wingetExe (Version: $wingetVersion)" -Level SUCCESS
}
elseif ($DryRun) {
    Write-Log "  [DRY-RUN] Would verify or bootstrap winget.exe." -Level WARN
}
else {
    throw "Critical Error: Windows Package Manager (winget.exe) is required to download WireGuard."
}

# Pre-validate all supplied configuration files before starting installation
$parsedConfigs = [System.Collections.Generic.List[PSCustomObject]]::new()
if ($resolvedConfigFiles.Count -gt 0) {
    Write-Log "  [*] Pre-validating $($resolvedConfigFiles.Count) WireGuard configuration file(s)..." -Level INFO
    foreach ($cfgFile in $resolvedConfigFiles) {
        $parsed = Parse-WireGuardConfigFile -FilePath $cfgFile -CustomTunnelName $TunnelName
        $parsedConfigs.Add($parsed)
        Write-Log "      + Validated Config: '$($parsed.FileName)' -> Tunnel Name: '$($parsed.TunnelName)'" -Level SUCCESS
        Write-Log "        Interface Address: $($parsed.Addresses -join ', ') | DNS: $($parsed.DNSServers -join ', ') | MTU: $($parsed.MTU)" -Level DETAIL
        Write-Log "        Peers: $($parsed.PeerCount) | Endpoint(s): $($parsed.Endpoints -join ', ') | AllowedIPs: $($parsed.AllowedIPs -join ', ')" -Level DETAIL
        Write-Log "        PrivateKey: $(if ($parsed.HasPrivateKey) { '[PRESENT - REDACTED FOR SECURITY]' } else { '[MISSING]' })" -Level DETAIL
        foreach ($warnMsg in $parsed.ValidationWarnings) {
            Write-Log "        [!] Warning: $warnMsg" -Level WARN
        }
    }
}
else {
    Write-Log "  [i] Configuration File (-ConfigPath): None provided (Client installation/update only)." -Level DETAIL
}

# ==============================================================================
# STEP 2: DOWNLOAD & INSTALL / UPDATE WIREGUARD CLIENT VIA WINGET
# ==============================================================================
Write-Log "`n[STEP 2/$totalSteps] Downloading & Deploying WireGuard Client ($PackageId) via Winget..." -Level STEP

$wingetActionTaken = "None"
$wingetExitCode = 0

if ($DryRun) {
    if (-not $initialState.Installed) {
        Write-Log "  [DRY-RUN] Would execute: winget install --id `"$PackageId`" --exact --silent --accept-package-agreements --accept-source-agreements" -Level WARN
        $wingetActionTaken = "Simulated Install"
    }
    else {
        Write-Log "  [DRY-RUN] WireGuard v$($initialState.ClientVersion) is installed. Would execute: winget upgrade --id `"$PackageId`" --exact --silent --accept-package-agreements --accept-source-agreements" -Level WARN
        $wingetActionTaken = "Simulated Upgrade Check"
    }
}
else {
    if (-not $initialState.Installed) {
        Write-Log "  [*] WireGuard Client is not currently installed. Downloading and installing '$PackageId' via winget..." -Level INFO
        $wingetArgs = @(
            "install",
            "--id", $PackageId,
            "--exact",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--disable-interactivity"
        )
        Write-Log "  [>] Command: `"$wingetExe`" $($wingetArgs -join ' ')" -Level DETAIL

        $proc = Start-Process -FilePath $wingetExe -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
        $wingetExitCode = $proc.ExitCode

        if ($wingetExitCode -eq 0) {
            $wingetActionTaken = "Fresh Installation Completed"
            Write-Log "  [+] WireGuard Client installed successfully via winget (Exit Code: 0)." -Level SUCCESS
        }
        else {
            throw "Winget installation of '$PackageId' failed with exit code: $wingetExitCode."
        }
    }
    else {
        Write-Log "  [*] WireGuard Client v$($initialState.ClientVersion) is already installed. Checking for updates via winget..." -Level INFO
        $wingetUpgradeArgs = @(
            "upgrade",
            "--id", $PackageId,
            "--exact",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--disable-interactivity"
        )
        Write-Log "  [>] Command: `"$wingetExe`" $($wingetUpgradeArgs -join ' ')" -Level DETAIL

        $proc = Start-Process -FilePath $wingetExe -ArgumentList $wingetUpgradeArgs -Wait -PassThru -NoNewWindow
        $wingetExitCode = $proc.ExitCode

        # -1978335189 (0x8A15002B) = WINGET_CLI_ERROR_UPDATE_NOT_APPLICABLE (No available upgrade found / already latest version)
        if ($wingetExitCode -eq 0) {
            $wingetActionTaken = "Upgraded to Latest Version"
            Write-Log "  [+] WireGuard Client was updated to the latest version via winget (Exit Code: 0)." -Level SUCCESS
        }
        elseif ($wingetExitCode -eq -1978335189) {
            $wingetActionTaken = "Already Up-to-Date (v$($initialState.ClientVersion))"
            Write-Log "  [+] WireGuard Client is already at the latest version (v$($initialState.ClientVersion)). No update required." -Level SUCCESS
        }
        else {
            Write-Log "  [!] Winget upgrade returned exit code $wingetExitCode. Verifying existing installation integrity..." -Level WARN
            $wingetActionTaken = "Verified Existing Installation (v$($initialState.ClientVersion))"
        }
    }

    Refresh-ProcessPath
}

# ==============================================================================
# STEP 3: VERIFY WIREGUARD BINARIES & INITIALIZE WIREGUARDMANAGER SERVICE
# ==============================================================================
Write-Log "`n[STEP 3/$totalSteps] Verifying WireGuard Binaries & Initializing WireGuardManager Service..." -Level STEP

$postInstallState = Get-WireGuardCurrentState -BaseDir $InstallDir

if ($DryRun) {
    Write-Log "  [DRY-RUN] Would verify '$($postInstallState.WireGuardExe)' and ensure 'WireGuardManager' service is installed and running." -Level WARN
}
else {
    if (-not $postInstallState.Installed) {
        throw "Verification Error: WireGuard executable was not found at '$($postInstallState.WireGuardExe)' after winget operation."
    }

    Write-Log "  [+] Verified GUI Executable : $($postInstallState.WireGuardExe) (v$($postInstallState.ClientVersion))" -Level SUCCESS
    Write-Log "  [+] Verified CLI Executable : $($postInstallState.WgCliExe) (v$($postInstallState.WgCliVersion))" -Level SUCCESS

    # Ensure WireGuardManager service is registered and running so it can manage Data\Configurations and GUI tunnels
    $mgrSvc = Get-Service -Name "WireGuardManager" -ErrorAction SilentlyContinue
    if ($null -eq $mgrSvc) {
        Write-Log "  [*] Installing 'WireGuardManager' Windows service (/installmanagerservice)..." -Level INFO
        $mgrProc = Start-Process -FilePath $postInstallState.WireGuardExe -ArgumentList "/installmanagerservice" -Wait -PassThru -NoNewWindow
        Start-Sleep -Seconds 2
        $mgrSvc = Get-Service -Name "WireGuardManager" -ErrorAction SilentlyContinue
    }

    if ($null -ne $mgrSvc) {
        if ($mgrSvc.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
            Write-Log "  [*] Starting 'WireGuardManager' service..." -Level INFO
            Start-Service -Name "WireGuardManager" -ErrorAction Stop
            $mgrSvc.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromSeconds(10))
            $mgrSvc.Refresh()
        }
        Write-Log "  [+] Service 'WireGuardManager' Status: $($mgrSvc.Status) (StartType: $($mgrSvc.StartType))" -Level SUCCESS
    }
    else {
        Write-Log "  [!] Warning: 'WireGuardManager' service was not detected yet; ensuring configuration store directory exists." -Level WARN
    }

    # Ensure Data\Configurations directory exists
    if (-not (Test-Path -LiteralPath $postInstallState.ConfigStoreDir -PathType Container)) {
        Write-Log "  [*] Creating configuration store directory: $($postInstallState.ConfigStoreDir)" -Level INFO
        New-Item -Path $postInstallState.ConfigStoreDir -ItemType Directory -Force | Out-Null
    }
    Write-Log "  [+] Configuration Store Ready : $($postInstallState.ConfigStoreDir)" -Level SUCCESS
}

# ==============================================================================
# STEP 4: IMPORT OPTIONAL CONFIGURATION FILE(S) & OPTIONAL TUNNEL ACTIVATION
# ==============================================================================
Write-Log "`n[STEP 4/$totalSteps] Processing WireGuard Tunnel Configuration Import..." -Level STEP

$importedResults = [System.Collections.Generic.List[PSCustomObject]]::new()

if ($parsedConfigs.Count -eq 0) {
    Write-Log "  [i] No configuration file was specified (-ConfigPath omitted). Skipping profile import." -Level INFO
    Write-Log "      You can import a .conf file anytime via the WireGuard GUI ('Import tunnel(s) from file')" -Level DETAIL
    Write-Log "      or by re-running: .\deploy-WireGuardClient.ps1 -ConfigPath `"C:\Path\To\vpn.conf`"" -Level DETAIL
}
else {
    $configStoreDir = Join-Path -Path $InstallDir -ChildPath "Data\Configurations"

    foreach ($cfg in $parsedConfigs) {
        $tName = $cfg.TunnelName
        $destPlainPath = Join-Path -Path $configStoreDir -ChildPath "$tName.conf"
        $destDpapiPath = Join-Path -Path $configStoreDir -ChildPath "$tName.conf.dpapi"
        $tunnelServiceName = "WireGuardTunnel`$$tName"

        Write-Log "  [*] Importing Tunnel Profile: '$tName' (Source: '$($cfg.SourcePath)')" -Level INFO

        if ($DryRun) {
            Write-Log "      [DRY-RUN] Would copy '$($cfg.SourcePath)' to '$destPlainPath'." -Level WARN
            Write-Log "      [DRY-RUN] WireGuardManager would encrypt '$destPlainPath' -> '$destDpapiPath'." -Level WARN
            if ($ActivateTunnel) {
                Write-Log "      [DRY-RUN] Would activate tunnel service '$tunnelServiceName' via /installtunnelservice." -Level WARN
            }
            $importedResults.Add([PSCustomObject]@{
                TunnelName      = $tName
                SourceFile      = $cfg.SourcePath
                DestinationPath = $destDpapiPath
                EncryptedDpapi  = $true
                ImportStatus    = "Simulated (DryRun)"
                TunnelStatus    = if ($ActivateTunnel) { "Simulated Active" } else { "Simulated Imported (Ready)" }
            })
            continue
        }

        # Check if tunnel configuration already exists
        $existingPlain = Test-Path -LiteralPath $destPlainPath -PathType Leaf
        $existingDpapi = Test-Path -LiteralPath $destDpapiPath -PathType Leaf

        if (($existingPlain -or $existingDpapi) -and -not $ForceOverwrite) {
            Write-Log "      [!] Existing configuration found for tunnel '$tName' in '$configStoreDir'." -Level WARN
            $promptResponse = Read-Host "      Overwrite existing WireGuard configuration '$tName'? [Y/N or T/N]"
            if ($promptResponse -notmatch '^(?i)(y|yes|t|tak)$') {
                Write-Log "      [-] Skipped importing '$tName' (User declined overwrite)." -Level WARN
                $importedResults.Add([PSCustomObject]@{
                    TunnelName      = $tName
                    SourceFile      = $cfg.SourcePath
                    DestinationPath = if ($existingDpapi) { $destDpapiPath } else { $destPlainPath }
                    EncryptedDpapi  = $existingDpapi
                    ImportStatus    = "Skipped (Already Exists)"
                    TunnelStatus    = "Unchanged"
                })
                continue
            }
        }

        # If replacing an existing configuration, remove previous .conf.dpapi first so WireGuardManager cleanly re-encrypts
        if ($existingDpapi -and -not $cfg.IsPreEncryptedDpapi) {
            Write-Log "      [*] Removing previous encrypted profile '$destDpapiPath' before importing updated config..." -Level DETAIL
            Remove-Item -LiteralPath $destDpapiPath -Force -ErrorAction SilentlyContinue
        }

        $targetCopyPath = if ($cfg.IsPreEncryptedDpapi) { $destDpapiPath } else { $destPlainPath }
        Write-Log "      [*] Copying configuration file to: '$targetCopyPath'..." -Level DETAIL
        Copy-Item -LiteralPath $cfg.SourcePath -Destination $targetCopyPath -Force -ErrorAction Stop

        # Wait up to 5 seconds for WireGuardManager to automatically encrypt .conf -> .conf.dpapi
        $isNowEncrypted = $false
        if ($cfg.IsPreEncryptedDpapi) {
            $isNowEncrypted = $true
        }
        else {
            for ($waitIdx = 0; $waitIdx -lt 10; $waitIdx++) {
                if (Test-Path -LiteralPath $destDpapiPath -PathType Leaf) {
                    $isNowEncrypted = $true
                    break
                }
                Start-Sleep -Milliseconds 500
            }
        }

        $effectiveStoredFile = if ($isNowEncrypted) { $destDpapiPath } else { $destPlainPath }
        if ($isNowEncrypted) {
            Write-Log "      [+] Configuration imported & DPAPI-encrypted by WireGuardManager: '$destDpapiPath'" -Level SUCCESS
        }
        else {
            Write-Log "      [+] Configuration staged in WireGuard store: '$destPlainPath'" -Level SUCCESS
        }

        # Optional: Activate the tunnel service immediately if -ActivateTunnel was requested
        $tunnelFinalStatus = "Imported (Ready in GUI)"
        $existingTunnelSvc = Get-Service -Name $tunnelServiceName -ErrorAction SilentlyContinue

        if ($ActivateTunnel) {
            Write-Log "      [*] Activating WireGuard tunnel service '$tunnelServiceName'..." -Level INFO
            if ($null -ne $existingTunnelSvc) {
                if ($existingTunnelSvc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Write-Log "      [*] Restarting existing tunnel service '$tunnelServiceName' to apply updated configuration..." -Level DETAIL
                    Restart-Service -Name $tunnelServiceName -Force -ErrorAction Stop
                }
                else {
                    Start-Service -Name $tunnelServiceName -ErrorAction Stop
                }
            }
            else {
                $installTunnelArgs = @("/installtunnelservice", "`"$effectiveStoredFile`"")
                Write-Log "      [>] Command: `"$($postInstallState.WireGuardExe)`" $($installTunnelArgs -join ' ')" -Level DETAIL
                $tProc = Start-Process -FilePath $postInstallState.WireGuardExe -ArgumentList $installTunnelArgs -Wait -PassThru -NoNewWindow
                Start-Sleep -Seconds 2
            }

            $verifySvc = Get-Service -Name $tunnelServiceName -ErrorAction SilentlyContinue
            if ($null -ne $verifySvc -and $verifySvc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                $tunnelFinalStatus = "Active / Connected ($tunnelServiceName : Running)"
                Write-Log "      [+] Tunnel '$tName' is now ACTIVE ($tunnelServiceName is Running)." -Level SUCCESS
            }
            else {
                $svcStateStr = if ($null -ne $verifySvc) { [string]$verifySvc.Status } else { "Not Created" }
                $tunnelFinalStatus = "Activation Requested (Service State: $svcStateStr)"
                Write-Log "      [!] Tunnel service '$tunnelServiceName' state: $svcStateStr. Check endpoint/keys in WireGuard GUI." -Level WARN
            }
        }
        elseif ($null -ne $existingTunnelSvc -and $existingTunnelSvc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
            $tunnelFinalStatus = "Active ($tunnelServiceName : Running)"
        }

        $importedResults.Add([PSCustomObject]@{
            TunnelName      = $tName
            SourceFile      = $cfg.SourcePath
            DestinationPath = $effectiveStoredFile
            EncryptedDpapi  = $isNowEncrypted
            ImportStatus    = "Imported Successfully"
            TunnelStatus    = $tunnelFinalStatus
        })
    }
}

# ==============================================================================
# STEP 5: POST-DEPLOYMENT VERIFICATION, OPTIONAL GUI LAUNCH & FINAL SUMMARY
# ==============================================================================
Write-Log "`n[STEP 5/$totalSteps] Performing Post-Deployment Verification & Generating Summary..." -Level STEP

$finalState = if ($DryRun) { $initialState } else { Get-WireGuardCurrentState -BaseDir $InstallDir }

if ($LaunchGUI) {
    if ($DryRun) {
        Write-Log "  [DRY-RUN] Would launch WireGuard GUI client: '$($finalState.WireGuardExe)'" -Level WARN
    }
    elseif ($finalState.Installed) {
        Write-Log "  [*] Launching WireGuard GUI Client..." -Level INFO
        Start-Process -FilePath $finalState.WireGuardExe
        Write-Log "  [+] WireGuard GUI Client launched." -Level SUCCESS
    }
}

$elapsed = (Get-Date) - $script:StartTime
$durationFormatted = "{0:mm}m {0:ss}.{0:fff}s" -f $elapsed

Write-Log "`n================================================================================" -Level HEADER
Write-Log "  DEPLOYMENT EXECUTION SUMMARY" -Level HEADER
Write-Log "================================================================================" -Level HEADER
Write-Log "  Script & Version     : $($SCRIPT_INFO.FileName) v$($SCRIPT_INFO.Version)" -Level INFO
Write-Log "  Execution Mode       : $(if ($DryRun) { 'DRY-RUN (Simulation Only)' } else { 'LIVE DEPLOYMENT' })" -Level INFO
Write-Log "  Winget Operation     : $wingetActionTaken" -Level SUCCESS
Write-Log "  WireGuard Version    : $($initialState.ClientVersion) -> $($finalState.ClientVersion)" -Level INFO
Write-Log "  WireGuard CLI (wg)   : $($finalState.WgCliVersion)" -Level DETAIL
Write-Log "  Install Directory    : $($finalState.InstallDir)" -Level DETAIL
Write-Log "  Manager Service      : WireGuardManager ($($finalState.ManagerService))" -Level INFO
Write-Log "  Profiles Imported    : $($importedResults.Count)" -Level INFO

if ($importedResults.Count -gt 0) {
    foreach ($res in $importedResults) {
        Write-Log "    - Tunnel [$($res.TunnelName)] : $($res.ImportStatus) | State: $($res.TunnelStatus)" -Level SUCCESS
        Write-Log "      Stored Config    : $($res.DestinationPath)" -Level DETAIL
    }
}

Write-Log "  Total Duration       : $durationFormatted" -Level DETAIL
if (-not $NoLog -and $script:ActiveLogFile) {
    Write-Log "  Execution Log File   : $script:ActiveLogFile" -Level INFO
}

Write-Log "`n--------------------------------------------------------------------------------" -Level HEADER
Write-Log "  QUICK USER INSTRUCTIONS (END-USER GUIDE)" -Level STEP
Write-Log "--------------------------------------------------------------------------------" -Level HEADER
Write-Log "  1. Open the WireGuard Client:" -Level INFO
Write-Log "     Click the Start Menu and launch 'WireGuard' (or check the system tray icon" -Level DETAIL
Write-Log "     near the clock in the bottom-right corner of the taskbar)." -Level DETAIL
if ($importedResults.Count -gt 0) {
    $tunnelNamesList = ($importedResults | Select-Object -ExpandProperty TunnelName) -join ", "
    Write-Log "  2. Connect / Activate your VPN Tunnel ($tunnelNamesList):" -Level INFO
    Write-Log "     Select the tunnel '$tunnelNamesList' on the left panel and click 'Activate'" -Level DETAIL
    Write-Log "     (Polish UI: 'Aktywuj'). Once connected, the status indicator turns green." -Level DETAIL
}
else {
    Write-Log "  2. Import a VPN Configuration Profile (.conf):" -Level INFO
    Write-Log "     In the WireGuard window, click 'Import tunnel(s) from file' (Polish UI:" -Level DETAIL
    Write-Log "     'Importuj tunele z pliku'), select your '.conf' file, and click 'Activate'" -Level DETAIL
    Write-Log "     ('Aktywuj'), OR run this script again with -ConfigPath `"C:\path\vpn.conf`"." -Level DETAIL
}
Write-Log "  3. Disconnect When Finished:" -Level INFO
Write-Log "     Click 'Deactivate' (Polish UI: 'Dezaktywuj') in the WireGuard window or" -Level DETAIL
Write-Log "     right-click the WireGuard system tray icon to toggle the VPN connection." -Level DETAIL
Write-Log "================================================================================`n" -Level HEADER

if ($PassThru) {
    return [PSCustomObject]@{
        ScriptName         = $SCRIPT_INFO.Name
        ScriptVersion      = $SCRIPT_INFO.Version
        ComputerName       = [System.Environment]::MachineName
        UserName           = [System.Environment]::UserName
        DryRun             = [bool]$DryRun
        WingetAction       = $wingetActionTaken
        PreviousVersion    = $initialState.ClientVersion
        CurrentVersion     = $finalState.ClientVersion
        ManagerService     = $finalState.ManagerService
        ImportedProfiles   = $importedResults.ToArray()
        DurationSeconds    = [math]::Round($elapsed.TotalSeconds, 2)
        LogFile            = $script:ActiveLogFile
    }
}
