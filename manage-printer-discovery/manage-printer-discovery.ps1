<#
================================================================================
  Script Name : manage-printer-discovery.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  Version     : 1.0.0
  Release Date: 2026-10-11
  License     : MIT
  Repository  : https://github.com/romanpindela

  DESCRIPTION:
    Controls automatic discovery and background mapping of network printers in
    local networks on Windows 10, Windows 11, and Windows Server (x64/ARM64).
    
    When disabled, Windows ceases silent, unsolicited background installation
    of broadcasted network printers (WSD/mDNS/UPnP) via the Network Connected
    Devices Auto-Setup subsystem (NcdAutoSetup), preventing printer queue clutter.
    Manual addition of network printers remains fully operational: users can
    still manually search, discover, and install network printers via Settings
    or the Control Panel Add Printer wizard.
    
    When enabled, Windows restores default plug-and-play auto-discovery and
    automatic mapping for local network-connected devices.

    Running without parameters displays the help menu with author, version,
    syntax, and practical usage examples.

================================================================================
.SYNOPSIS
    Enables or disables automatic network printer discovery and mapping on Windows.

.DESCRIPTION
    Configures the Windows Network Connected Devices Auto-Setup (NcdAutoSetup)
    subsystem and registry policies to enable or disable automatic discovery and
    background installation of network printers. Manual printer addition via the
    Windows UI remains available when automatic discovery is disabled.

.PARAMETER Action
    Specifies the desired operation:
    - 'Enable'  : Enables automatic discovery and background mapping of network printers.
    - 'Disable' : Disables automatic discovery and background mapping of network printers.
    - 'Status'  : Audits and displays current registry and service configuration without changes.
    - 'Help'    : Displays the help guide and author information.

.PARAMETER Enable
    Switch parameter to enable automatic printer discovery and mapping.

.PARAMETER Disable
    Switch parameter to disable automatic printer discovery and mapping.

.PARAMETER Status
    Switch parameter to check current autodiscovery and mapping status.

.PARAMETER Help
    Switch parameter (-h, -Help) to display the help and syntax menu.

.PARAMETER LogPath
    Optional path to a custom execution log file.
    Default: C:\Logs\<yyyyMMdd_HHmmss>-<ComputerName>-<UserName>-Manage-Printer-Discovery.txt

.EXAMPLE
    .\manage-printer-discovery.ps1
    Displays the help guide, author information, and syntax overview.

.EXAMPLE
    .\manage-printer-discovery.ps1 -Help
    Displays detailed help and parameter usage.

.EXAMPLE
    .\manage-printer-discovery.ps1 disable
    Disables automatic discovery and mapping of network printers.

.EXAMPLE
    .\manage-printer-discovery.ps1 enable
    Enables automatic discovery and mapping of network printers.

.EXAMPLE
    .\manage-printer-discovery.ps1 -Action Status
    Audits the current discovery configuration without making modifications.

.EXAMPLE
    .\manage-printer-discovery.ps1 -Disable -LogPath "C:\Logs\printer_config.txt"
    Disables autodiscovery and writes execution details to a custom log file.

.NOTES
    Author      : Roman Pindela
    Contact     : roman.pindela@gmail.com
    GitHub      : https://github.com/romanpindela
    Version     : 1.0.0
    Compatible  : Windows 10, Windows 11, Windows Server 2016/2019/2022/2025
    Privileges  : Requires Administrator privileges for Enable/Disable actions
                  (automatically prompts for elevation via UAC if needed).
#>

[CmdletBinding(DefaultParameterSetName = "Default")]
param (
    [Parameter(Position = 0, Mandatory = $false, ParameterSetName = "ActionSet")]
    [ValidateSet("Enable", "Disable", "Status", "Help", IgnoreCase = $true)]
    [string]$Action,

    [Parameter(Mandatory = $false, ParameterSetName = "EnableSwitch")]
    [Alias("e")]
    [switch]$Enable,

    [Parameter(Mandatory = $false, ParameterSetName = "DisableSwitch")]
    [Alias("d")]
    [switch]$Disable,

    [Parameter(Mandatory = $false, ParameterSetName = "StatusSwitch")]
    [Alias("s")]
    [switch]$Status,

    [Parameter(Mandatory = $false, ParameterSetName = "HelpSwitch")]
    [Parameter(Mandatory = $false, ParameterSetName = "Default")]
    [Alias("h")]
    [switch]$Help,

    [Parameter(Mandatory = $false)]
    [Alias("l", "Log")]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ==============================================================================
# SCRIPT METADATA & GLOBALS
# ==============================================================================
$SCRIPT_INFO = @{
    Name        = "Manage-Printer-Discovery"
    FileName    = "manage-printer-discovery.ps1"
    Version     = "1.0.0"
    Author      = "Roman Pindela"
    Contact     = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    ReleaseDate = "2026-10-11"
}

$script:ActiveLogFile = $null

# Registry configuration constants
$REG_BASE_PATH   = "SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup"
$REG_PRIVATE_KEY = "Private"
$REG_VALUE_NAME  = "AutoSetup"
$SERVICE_NAME    = "NcdAutoSetup"

# ==============================================================================
# LOGGING & OUTPUT FUNCTIONS
# ==============================================================================
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    try { [Console]::CursorLeft = 0 } catch {}
    Write-Host "$Message" -ForegroundColor $Color

    if (-not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
        try {
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $logLine = "[$timestamp] $Message`r`n"
            [System.IO.File]::AppendAllText($script:ActiveLogFile, $logLine, [System.Text.Encoding]::UTF8)
        }
        catch {
            # Suppress logging failure so main logic is never interrupted
        }
    }
}

# ==============================================================================
# INPUT SANITIZATION & VALIDATION
# ==============================================================================
function Protect-InputPath {
    param ([string]$PathToValidate)

    if ([string]::IsNullOrWhiteSpace($PathToValidate)) {
        return
    }

    # Defend against malicious command injection or control sequences
    if ($PathToValidate -match '[`$;&|><*?"\r\n]') {
        throw "Security Alert: Invalid or potentially dangerous characters detected in log path parameter."
    }

    if ($PathToValidate.Length -gt 260) {
        throw "Validation Error: Specified path exceeds maximum allowed path length (260 characters)."
    }
}

# ==============================================================================
# HELP MENU
# ==============================================================================
function Show-HelpGuide {
    try { [Console]::CursorLeft = 0 } catch {}
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)
  GitHub: $($SCRIPT_INFO.GitHub)
================================================================================
DESCRIPTION:
  Automates the configuration of Windows network printer autodiscovery and
  automatic mapping subsystem (Network Connected Devices Auto-Setup / NcdAutoSetup).

  - DISABLE: Stops Windows from automatically detecting and silently mapping
             unsolicited network printers in local networks (preventing queue bloat).
             Manual printer addition remains completely operational: users can still
             search and add network printers on demand via Windows Settings or Control Panel.
  - ENABLE : Restores default Windows behavior where qualified network-connected
             devices and printers are automatically discovered and set up.
  - STATUS : Audits and reports the current registry policy and service state.

USAGE:
  .\manage-printer-discovery.ps1 enable [-LogPath <path_to_log.txt>]
  .\manage-printer-discovery.ps1 disable [-LogPath <path_to_log.txt>]
  .\manage-printer-discovery.ps1 status
  .\manage-printer-discovery.ps1 -Action <Enable|Disable|Status|Help>
  .\manage-printer-discovery.ps1 -Enable | -Disable | -Status
  .\manage-printer-discovery.ps1 -h | -Help

PARAMETERS:
  Action                  : Desired action: 'Enable', 'Disable', 'Status', or 'Help'.
                            Can be supplied positionally (e.g., .\manage-printer-discovery.ps1 disable).
  -Enable, -e             : Enables automatic network printer discovery and mapping.
  -Disable, -d            : Disables automatic network printer discovery and mapping.
  -Status, -s             : Checks current configuration without making any changes.
  -LogPath, -l, -Log      : [Optional] Custom path to text log file.
                            Default: C:\Logs\<DateTime>-<Host>-<User>-Manage-Printer-Discovery.txt
  -Help, -h               : Displays this help menu, author information, and examples.

EXAMPLES:
  # 1. Display help and info:
  .\manage-printer-discovery.ps1
  .\manage-printer-discovery.ps1 -h

  # 2. Disable automatic discovery and mapping (positional or switch):
  .\manage-printer-discovery.ps1 disable
  .\manage-printer-discovery.ps1 -Disable

  # 3. Enable automatic discovery and mapping:
  .\manage-printer-discovery.ps1 enable
  .\manage-printer-discovery.ps1 -Enable

  # 4. Check current status:
  .\manage-printer-discovery.ps1 status
  .\manage-printer-discovery.ps1 -Status

  # 5. Disable autodiscovery with custom logging:
  .\manage-printer-discovery.ps1 disable -LogPath "C:\Logs\PrinterDiscoverySetup.txt"

SECURITY & REQUIREMENTS:
  - Administrator privileges are required for 'Enable' and 'Disable' actions.
    If not elevated, the script automatically prompts for UAC elevation.
  - Supports both Polish and English editions of Windows (Desktop and Server).
  - Unblock downloaded script if needed:
    Unblock-File -Path .\manage-printer-discovery.ps1
================================================================================
"@ -ForegroundColor Yellow
}

# ==============================================================================
# RESOLVE REQUESTED ACTION
# ==============================================================================
# Determine effective action
$effectiveAction = $null

if ($Help -or ($PSBoundParameters.ContainsKey("Help"))) {
    $effectiveAction = "Help"
}
elseif ($Enable -or ($Action -eq "Enable")) {
    $effectiveAction = "Enable"
}
elseif ($Disable -or ($Action -eq "Disable")) {
    $effectiveAction = "Disable"
}
elseif ($Status -or ($Action -eq "Status")) {
    $effectiveAction = "Status"
}
elseif (-not [string]::IsNullOrWhiteSpace($Action)) {
    # If action was provided as string
    switch ($Action.ToLowerInvariant()) {
        "enable"  { $effectiveAction = "Enable" }
        "disable" { $effectiveAction = "Disable" }
        "status"  { $effectiveAction = "Status" }
        "help"    { $effectiveAction = "Help" }
        default   {
            Write-Host "[-] Invalid action: '$Action'. Valid actions: Enable, Disable, Status, Help." -ForegroundColor Red
            Show-HelpGuide
            return
        }
    }
}

# If executed without parameters or Help requested, display guide and exit cleanly
if ($null -eq $effectiveAction -or $effectiveAction -eq "Help") {
    Show-HelpGuide
    return
}

# Validate custom log path if provided
if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    Protect-InputPath -PathToValidate $LogPath
}

# ==============================================================================
# UAC ELEVATION VALIDATION (SID-BASED / MULTI-LANGUAGE SAFE)
# ==============================================================================
function Test-IsAdminElevated {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)

    return $principal.IsInRole($adminSid)
}

# Elevation required for state modification (Enable / Disable)
if ($effectiveAction -in @("Enable", "Disable")) {
    if (-not (Test-IsAdminElevated)) {
        Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow

        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action $effectiveAction"
        if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
            $argList += " -LogPath `"$LogPath`""
        }

        try {
            Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
        }
        catch {
            Write-Host "[-] UAC elevation was rejected or failed: $_" -ForegroundColor Red
        }
        Exit
    }
}

# ==============================================================================
# LOG INITIALIZATION
# ==============================================================================
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $defaultLogDir = "C:\Logs"
    $timeMarker    = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $compName      = $env:COMPUTERNAME
    $userName      = $env:USERNAME
    $scriptName    = $SCRIPT_INFO.Name
    $logFileName   = "${timeMarker}-${compName}-${userName}-${scriptName}.txt"
    $LogPath       = Join-Path ($defaultLogDir) ($logFileName)
}

try {
    $resolvedLogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath)
    $logDirectory = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
    if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not [System.IO.Directory]::Exists($logDirectory)) {
        [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null
    }
    $script:ActiveLogFile = $resolvedLogPath
}
catch {
    $script:ActiveLogFile = $null
}

# ==============================================================================
# REGISTRY & SERVICE MANAGEMENT LOGIC
# ==============================================================================

function Get-DiscoveryConfigStatus {
    [CmdletBinding()]
    param ()

    $statusResult = [PSCustomObject]@{
        RegistryPath        = "HKLM:\$REG_BASE_PATH\$REG_PRIVATE_KEY"
        AutoSetupValue      = $null
        AutoSetupDefined    = $false
        AutoDiscoveryState  = "UNKNOWN"
        ServiceName         = $SERVICE_NAME
        ServiceStatus       = "Not Found"
        ServiceStartupType  = "Unknown"
    }

    # Inspect 64-bit Registry Hive
    $baseKey = $null
    $subKey  = $null
    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        $fullSubKeyPath = "$REG_BASE_PATH\$REG_PRIVATE_KEY"
        $subKey = $baseKey.OpenSubKey($fullSubKeyPath, $false)

        if ($null -ne $subKey) {
            $val = $subKey.GetValue($REG_VALUE_NAME)
            if ($null -ne $val) {
                $statusResult.AutoSetupValue   = [int]$val
                $statusResult.AutoSetupDefined = $true
            }
        }
    }
    catch {
        Write-Log "    [-] Warning: Unable to read registry key: $_" Yellow
    }
    finally {
        if ($null -ne $subKey)  { $subKey.Close() }
        if ($null -ne $baseKey) { $baseKey.Close() }
    }

    # Interpret registry state
    if ($statusResult.AutoSetupDefined) {
        if ($statusResult.AutoSetupValue -eq 0) {
            $statusResult.AutoDiscoveryState = "DISABLED (Manual Discovery Only)"
        }
        else {
            $statusResult.AutoDiscoveryState = "ENABLED (Automatic Mapping Active)"
        }
    }
    else {
        # Default Windows behavior when AutoSetup registry value is absent
        $statusResult.AutoDiscoveryState = "ENABLED (Default Windows Behavior)"
    }

    # Inspect NcdAutoSetup Service
    try {
        $svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($null -ne $svc) {
            $statusResult.ServiceStatus = $svc.Status.ToString()
            $statusResult.ServiceStartupType = $svc.StartType.ToString()
        }
    }
    catch {}

    return $statusResult
}

function Set-DiscoveryRegistryPolicy {
    param (
        [Parameter(Mandatory = $true)]
        [int]$TargetValue
    )

    $actionName = if ($TargetValue -eq 0) { "0 (Disabled)" } else { "1 (Enabled)" }
    Write-Log "[1/3] Configuring HKLM Registry policy: AutoSetup = $actionName..." Cyan

    $fullSubKeyPath = "$REG_BASE_PATH\$REG_PRIVATE_KEY"
    $baseKey = $null
    $subKey  = $null

    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        $subKey  = $baseKey.OpenSubKey($fullSubKeyPath, $true)

        if ($null -eq $subKey) {
            Write-Log "    [*] Creating missing Private registry subkey under NcdAutoSetup..." DarkGray
            $subKey = $baseKey.CreateSubKey($fullSubKeyPath)
        }

        $currentVal = $subKey.GetValue($REG_VALUE_NAME)
        if ($null -ne $currentVal -and [int]$currentVal -eq $TargetValue) {
            Write-Log "    [V] Skipped: AutoSetup registry value already set to $TargetValue." Green
        }
        else {
            $subKey.SetValue($REG_VALUE_NAME, $TargetValue, [Microsoft.Win32.RegistryValueKind]::DWord)
            Write-Log "    [+] Success: Set HKLM:\$fullSubKeyPath\$REG_VALUE_NAME = $TargetValue (DWORD)." Green
        }
    }
    catch {
        Write-Log "    [-] Registry modification error: $_" Red
        throw $_
    }
    finally {
        if ($null -ne $subKey)  { $subKey.Close() }
        if ($null -ne $baseKey) { $baseKey.Close() }
    }
}

function Configure-AutoSetupService {
    param (
        [Parameter(Mandatory = $true)]
        [bool]$Enable
    )

    $targetAction = if ($Enable) { "Restoring trigger-start" } else { "Stopping and disabling" }
    Write-Log "[2/3] $targetAction for service: $SERVICE_NAME..." Cyan

    try {
        $svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            Write-Log "    [*] Service '$SERVICE_NAME' not registered on this system. Skipping service configuration." DarkGray
            return
        }

        if (-not $Enable) {
            # Disabling: Stop service if running and set startup to Disabled
            if ($svc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                Write-Log "    [*] Stopping running $SERVICE_NAME service..." DarkGray
                Stop-Service -Name $SERVICE_NAME -Force -ErrorAction Stop
                Write-Log "    [+] Service $SERVICE_NAME stopped successfully." Green
            }

            Set-Service -Name $SERVICE_NAME -StartupType Disabled -ErrorAction Stop
            Write-Log "    [+] Service $SERVICE_NAME StartupType configured to 'Disabled'." Green
        }
        else {
            # Enabling: Restore startup type to Manual (Windows trigger-start default)
            Set-Service -Name $SERVICE_NAME -StartupType Manual -ErrorAction Stop
            Write-Log "    [+] Service $SERVICE_NAME StartupType restored to 'Manual' (Trigger Start)." Green
        }
    }
    catch {
        Write-Log "    [-] Service configuration warning: $_" Yellow
    }
}

function Show-ExecutionSummary {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CurrentAction
    )

    Write-Log "[3/3] Auditing final system configuration..." Cyan
    $auditResult = Get-DiscoveryConfigStatus

    Write-Log "    ----------------------------------------------------------------" DarkGray
    Write-Log "    CONFIGURATION AUDIT REPORT:" DarkCyan
    Write-Log "      * Autodiscovery & Mapping State : $($auditResult.AutoDiscoveryState)" $(if ($auditResult.AutoSetupValue -eq 0) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Green })
    Write-Log "      * Registry Value (AutoSetup)    : $(if ($auditResult.AutoSetupDefined) { $auditResult.AutoSetupValue } else { "Not set (Default)" })" Gray
    Write-Log "      * Registry Path                 : $($auditResult.RegistryPath)" Gray
    Write-Log "      * Service Name                  : $($auditResult.ServiceName)" Gray
    Write-Log "      * Service Status / StartType    : $($auditResult.ServiceStatus) / $($auditResult.ServiceStartupType)" Gray
    Write-Log "    ----------------------------------------------------------------" DarkGray

    if ($CurrentAction -eq "Disable") {
        Write-Log "    [NOTE] Windows will no longer automatically discover and install network printers." Cyan
        Write-Log "           Manual printer addition remains available via Windows Settings or Control Panel." Cyan
    }
    elseif ($CurrentAction -eq "Enable") {
        Write-Log "    [NOTE] Windows automatic network printer discovery and mapping is now ENABLED." Cyan
    }
}

# ==============================================================================
# MAIN WORKFLOW
# ==============================================================================

try { Clear-Host } catch {}

Write-Log "================================================================================" Cyan
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - Action: $effectiveAction" Cyan
Write-Log "  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)" Gray
if (-not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
    Write-Log "  Log File: $script:ActiveLogFile" DarkCyan
}
Write-Log "================================================================================" Cyan

try {
    switch ($effectiveAction) {
        "Status" {
            Write-Log "Auditing current network printer autodiscovery settings..." Cyan
            $cfgState = Get-DiscoveryConfigStatus

            Write-Log "`n--- CURRENT CONFIGURATION STATUS ---" DarkCyan
            Write-Log "  State              : $($cfgState.AutoDiscoveryState)" $(if ($cfgState.AutoSetupValue -eq 0) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Green })
            Write-Log "  Registry Value     : AutoSetup = $(if ($cfgState.AutoSetupDefined) { $cfgState.AutoSetupValue } else { "Not Defined (Default)" })" Gray
            Write-Log "  Registry Target    : $($cfgState.RegistryPath)" Gray
            Write-Log "  Service Name       : $($cfgState.ServiceName)" Gray
            Write-Log "  Service Status     : $($cfgState.ServiceStatus)" Gray
            Write-Log "  Service StartType  : $($cfgState.ServiceStartupType)" Gray
            Write-Log "------------------------------------`n" DarkCyan

            if ($cfgState.AutoSetupValue -eq 0) {
                Write-Log "[INFO] Autodiscovery is currently DISABLED. Network printers are not mapped automatically." Yellow
                Write-Log "       Users can still manually add network printers on demand." Yellow
            }
            else {
                Write-Log "[INFO] Autodiscovery is currently ENABLED. Windows automatically discovers and maps network printers." Green
            }
        }

        "Disable" {
            Set-DiscoveryRegistryPolicy -TargetValue 0
            Configure-AutoSetupService -Enable $false
            Show-ExecutionSummary -CurrentAction "Disable"
        }

        "Enable" {
            Set-DiscoveryRegistryPolicy -TargetValue 1
            Configure-AutoSetupService -Enable $true
            Show-ExecutionSummary -CurrentAction "Enable"
        }
    }

    Write-Log "`n================================================================================" Green
    Write-Log "  [+] Action '$effectiveAction' finished successfully." Green
    if (-not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
        Write-Log "  [+] Execution log saved to: $script:ActiveLogFile" Green
    }
    Write-Log "================================================================================" Green
    Write-Log "Author contact: $($SCRIPT_INFO.Contact) | GitHub: $($SCRIPT_INFO.GitHub)`n" Gray
}
catch {
    Write-Log "`n[-] Execution failed with error: $_" Red
    Write-Log "[-] StackTrace: $($_.ScriptStackTrace)" DarkGray
    exit 1
}
