<#
================================================================================
  Script Name : Uninstall-Applications.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  GitHub      : https://github.com/romanpindela
  Version     : 1.0.0
  Release Date: 2026-10-12
  License     : MIT

  DESCRIPTION:
    Enterprise automation tool for searching, auditing, and uninstalling
    workstation applications on Windows (x64 / x86 architectures).
    Combines high-performance native .NET Registry inspection with the
    Windows Package Manager (WinGet) and Windows Installer (MSI) engines.
    Provides detailed progress tracking, post-uninstallation verification,
    cross-language Windows support (English/Polish), seamless Exchange Online
    administrator connection, and structured activity logging.

================================================================================
.SYNOPSIS
    Audits, filters, and uninstalls software packages using WinGet, MSI, and native uninstallers.

.DESCRIPTION
    Uninstall-Applications.ps1 automates software removal across enterprise workstations.
    Key capabilities include:
    - Interactive & automated Exchange Online administrator session connectivity.
    - Fast in-memory .NET Registry scanning across 64-bit, 32-bit, and CurrentUser hives.
    - WinGet catalog integration for identifying package IDs and performing silent removals.
    - Pattern-based application search (-Filter) by Name, Package ID, or Publisher.
    - Multi-package silent uninstallation (-Uninstall) with real-time progress indicators.
    - Post-removal state verification to confirm successful uninstallation.
    - Full telemetry and structured execution logging to default or custom log files.
    - Language-independent administrator elevation using Well-Known SIDs.

.PARAMETER Filter
    Pattern or keyword used to filter installed applications by Display Name, Package ID,
    or Publisher (e.g. "Microsoft", "Teams", "Chrome", "Adobe").
    Aliases: -Search, -Pattern, -Query, -s.

.PARAMETER List
    Switch parameter. Displays a structured table of installed applications matching the
    optional -Filter pattern, showing the exact identifier to use for uninstallation.
    Aliases: -l, -ShowInstalled.

.PARAMETER Uninstall
    One or more package IDs or application names to uninstall. Supports string arrays
    and pipeline input (e.g. -Uninstall "Microsoft.Teams", "Mozilla.Firefox").
    Aliases: -Name, -PackageId, -Package, -Id, -App.

.PARAMETER Force
    Suppresses user confirmation prompts prior to executing uninstallation.
    Aliases: -f, -Quiet, -Silent.

.PARAMETER WhatIf
    Simulates uninstallation actions without executing uninstall commands (Dry Run).

.PARAMETER LogPath
    Custom path for the log file. If omitted, defaults to C:\Logs\<Timestamp>-<Computer>-<User>-Uninstall-Applications.txt.
    Aliases: -Log, -ReportPath.

.PARAMETER AdminUserPrincipalName
    Optional administrator UPN used for explicit authentication with Exchange Online.
    Alias: -AdminUPN.

.PARAMETER SkipExchangeConnection
    Bypasses connecting to Exchange Online for purely offline or local execution.
    Aliases: -NoExchange, -SkipExchange.

.PARAMETER Help
    Displays the interactive help menu, usage examples, version, and author info.
    Alias: -h.

.EXAMPLE
    .\Uninstall-Applications.ps1 -Help
    Displays comprehensive help, parameter descriptions, and usage examples.

.EXAMPLE
    .\Uninstall-Applications.ps1 -Filter "Microsoft"
    Searches and lists all installed programs containing "Microsoft" in their name, ID, or publisher.

.EXAMPLE
    .\Uninstall-Applications.ps1 -List -Filter "Teams"
    Lists installed packages matching "Teams" with their exact uninstallation identifiers.

.EXAMPLE
    .\Uninstall-Applications.ps1 -Uninstall "Microsoft.Teams"
    Uninstalls Microsoft Teams using WinGet or MSI, showing detailed progress and verification.

.EXAMPLE
    .\Uninstall-Applications.ps1 -Uninstall "Microsoft.Teams", "Mozilla.Firefox" -Force
    Uninstalls multiple applications silently without interactive confirmation prompts.

.EXAMPLE
    .\Uninstall-Applications.ps1 -Uninstall "Google.Chrome" -WhatIf
    Simulates uninstallation of Google Chrome without modifying the workstation.

.EXAMPLE
    "Microsoft.Teams", "7-Zip" | .\Uninstall-Applications.ps1 -Force
    Uninstalls packages supplied via the PowerShell pipeline.

.EXAMPLE
    .\Uninstall-Applications.ps1 -Filter "Office" -AdminUserPrincipalName "admin@contoso.onmicrosoft.com"
    Connects to Exchange Online as the specified admin and lists installed Office applications.

.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.0.0
#>

[CmdletBinding(DefaultParameterSetName = "Default")]
param (
    # --- Mode: List & Search ---
    [Parameter(ParameterSetName = "List")]
    [Alias("l", "ShowInstalled")]
    [switch]$List,

    [Parameter(ParameterSetName = "List", Position = 0)]
    [Parameter(ParameterSetName = "Default", Position = 0)]
    [Alias("Search", "Pattern", "Query", "s")]
    [string]$Filter,

    # --- Mode: Uninstall ---
    [Parameter(ParameterSetName = "Uninstall", Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [Alias("Name", "PackageId", "Package", "Id", "App")]
    [string[]]$Uninstall,

    [Parameter(ParameterSetName = "Uninstall")]
    [Alias("f", "Quiet", "Silent")]
    [switch]$Force,

    [Parameter(ParameterSetName = "Uninstall")]
    [switch]$WhatIf,

    # --- Global & Environmental Settings ---
    [Parameter(ParameterSetName = "List")]
    [Parameter(ParameterSetName = "Uninstall")]
    [Parameter(ParameterSetName = "Default")]
    [Alias("Log", "ReportPath")]
    [string]$LogPath,

    [Parameter(ParameterSetName = "List")]
    [Parameter(ParameterSetName = "Uninstall")]
    [Parameter(ParameterSetName = "Default")]
    [Alias("ExchangeOnline", "Exchange")]
    [switch]$ConnectExchange,

    [Parameter(ParameterSetName = "List")]
    [Parameter(ParameterSetName = "Uninstall")]
    [Parameter(ParameterSetName = "Default")]
    [Alias("AdminUPN", "AdminEmail")]
    [string]$AdminUserPrincipalName,

    [Parameter(ParameterSetName = "List")]
    [Parameter(ParameterSetName = "Uninstall")]
    [Parameter(ParameterSetName = "Default")]
    [Alias("NoExchange", "SkipExchange")]
    [switch]$SkipExchangeConnection,

    # --- Help Mode ---
    [Parameter(ParameterSetName = "Help")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Script Metadata ---
$SCRIPT_INFO = @{
    Name        = "Uninstall-Applications"
    Version     = "1.0.0"
    Author      = "Roman Pindela"
    Email       = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    ReleaseDate = "2026-10-12"
    License     = "MIT"
}

# Global variable holding active log file path
$script:ActiveLogFile = $null

# ------------------------------------------------------------------------------
# Help Guide Display
# ------------------------------------------------------------------------------
function Show-HelpGuide {
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Author: $($SCRIPT_INFO.Author) | Email: $($SCRIPT_INFO.Email)
  GitHub: $($SCRIPT_INFO.GitHub)
================================================================================
DESCRIPTION:
  Automates the discovery, auditing, and uninstallation of software on Windows
  workstations. Combines high-speed in-memory registry queries with WinGet and
  MSI engines. Features step-by-step uninstallation progress, verification,
  Exchange Online administrator connectivity, and comprehensive activity logging.

AUTHENTICATION & PREREQUISITES:
  - Local Workstation: Administrator privileges (automatic UAC elevation included).
  - WinGet: Windows Package Manager (v1.7+ recommended for package ID resolution).
  - Exchange Online: Optional. Use -ConnectExchange (or -AdminUserPrincipalName) if you
    wish to authenticate with Microsoft 365 Exchange Online during management tasks.

USAGE:
  # 1. Search and list local installed applications matching a pattern:
  .\Uninstall-Applications.ps1 -Filter <keyword>
  .\Uninstall-Applications.ps1 -List [-Filter <keyword>]

  # 2. Uninstall specified package(s):
  .\Uninstall-Applications.ps1 -Uninstall <PackageId_or_Name> [-Force] [-WhatIf]
  .\Uninstall-Applications.ps1 -Uninstall "<Id1>", "<Id2>" [-Force]

  # 3. Pipeline uninstallation:
  "<PackageId1>", "<PackageId2>" | .\Uninstall-Applications.ps1 -Force

  # 4. Connect to Exchange Online (Optional):
  .\Uninstall-Applications.ps1 -Filter "Office" -ConnectExchange [-AdminUserPrincipalName "admin@domain.com"]

  # 5. Display help guide:
  .\Uninstall-Applications.ps1 -Help | -h

PARAMETERS:
  -Filter, -Search, -s      : Keyword to filter apps by name, ID, or publisher.
  -List, -l                 : Displays formatted table of matching installed apps.
  -Uninstall, -Name, -Id    : One or more package IDs or application names to uninstall.
  -Force, -f                : Suppresses interactive confirmation prompts.
  -WhatIf                   : Simulates uninstallation without executing commands.
  -LogPath, -Log            : Custom log file path (defaults to C:\Logs\...).
  -ConnectExchange, -Exchange : [Optional] Connects to Microsoft 365 Exchange Online.
  -AdminUserPrincipalName   : Administrator UPN for Exchange Online login.
  -SkipExchangeConnection   : Explicitly skips Exchange Online connection.
  -Help, -h                 : Displays this help documentation.

EXAMPLES:
  # Display help menu
  .\Uninstall-Applications.ps1 -h

  # List all Microsoft packages
  .\Uninstall-Applications.ps1 -Filter "Microsoft"

  # List packages matching Teams and skip Exchange connection
  .\Uninstall-Applications.ps1 -List -Filter "Teams" -SkipExchangeConnection

  # Uninstall Microsoft Teams silently
  .\Uninstall-Applications.ps1 -Uninstall "Microsoft.Teams" -Force

  # Uninstall multiple programs with confirmation
  .\Uninstall-Applications.ps1 -Uninstall "Microsoft.Teams", "Mozilla.Firefox"

  # Dry-run uninstallation
  .\Uninstall-Applications.ps1 -Uninstall "Google.Chrome" -WhatIf

SECURITY & UNBLOCKING:
  If downloaded from GitHub, remember to unblock the script before execution:
  Unblock-File -Path .\Uninstall-Applications.ps1
================================================================================
"@ -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# Check for No Parameters or -Help Request
# ------------------------------------------------------------------------------
if ($Help -or ($PSBoundParameters.Count -eq 0)) {
    Show-HelpGuide
    exit 0
}

# ------------------------------------------------------------------------------
# Language-Independent Administrator Verification & Automatic UAC Elevation
# (Enforced when performing software uninstallation, allowing list/search to run)
# ------------------------------------------------------------------------------
if ($PSBoundParameters.ContainsKey('Uninstall') -and -not $WhatIf) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
    $isAdmin = $principal.IsInRole($adminSid)

    if (-not $isAdmin) {
        Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow

        $argumentsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Value -is [switch]) {
                if ($param.Value.IsPresent) {
                    $argumentsList += "-$($param.Key)"
                }
            } elseif ($param.Value -is [array]) {
                $argumentsList += "-$($param.Key)"
                $argumentsList += ($param.Value | ForEach-Object { "`"$_`"" }) -join ','
            } else {
                $argumentsList += "-$($param.Key)"
                $argumentsList += "`"$($param.Value)`""
            }
        }

        try {
            Start-Process powershell.exe -ArgumentList ($argumentsList -join ' ') -Verb RunAs
            exit 0
        }
        catch {
            Write-Error "Administrative privileges are required to perform uninstallation. Please run PowerShell as Administrator."
            exit 1
        }
    }
}

# ------------------------------------------------------------------------------
# Logging Engine
# ------------------------------------------------------------------------------
function Initialize-Logging {
    param ([string]$CustomPath)

    if ([string]::IsNullOrWhiteSpace($CustomPath)) {
        $defaultLogDir = "C:\Logs"
        $timeMarker = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $compName   = $env:COMPUTERNAME
        $userName   = $env:USERNAME
        $scriptName = $SCRIPT_INFO.Name
        $logFileName = "${timeMarker}-${compName}-${userName}-${scriptName}.txt"
        $CustomPath = Join-Path $defaultLogDir $logFileName
    }

    $resolvedLogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CustomPath)
    $logDirectory = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
    if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not [System.IO.Directory]::Exists($logDirectory)) {
        [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null
    }

    $script:ActiveLogFile = $resolvedLogPath
}

function Write-Log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    try {
        if ([System.Environment]::UserInteractive -and -not [Console]::IsOutputRedirected) {
            [Console]::CursorLeft = 0
        }
    } catch {}

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

# Initialize logging
Initialize-Logging -CustomPath $LogPath

Write-Log "================================================================================" Cyan
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - Execution Initialized" Cyan
Write-Log "  Author: $($SCRIPT_INFO.Author) | Email: $($SCRIPT_INFO.Email)" Gray
Write-Log "  Log File: $script:ActiveLogFile" DarkCyan
Write-Log "================================================================================" Cyan

# ------------------------------------------------------------------------------
# Input Validation & Sanitization (CleanCode & Security Protection)
# ------------------------------------------------------------------------------
$forbiddenCharsRegex = '[\$`;&|><\r\n]'

if (-not [string]::IsNullOrWhiteSpace($Filter)) {
    $Filter = $Filter.Trim()
    if ($Filter -match $forbiddenCharsRegex) {
        Write-Log "[-] Invalid characters detected in -Filter. Disallowed: $;&|><`$`r`n" Red
        exit 1
    }
}

if (-not [string]::IsNullOrWhiteSpace($AdminUserPrincipalName)) {
    $AdminUserPrincipalName = $AdminUserPrincipalName.Trim()
    $emailPattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    if ($AdminUserPrincipalName -notmatch $emailPattern) {
        Write-Log "[-] Invalid format for -AdminUserPrincipalName. Provide a valid email address." Red
        exit 1
    }
}

if ($Uninstall -and $Uninstall.Count -gt 0) {
    for ($i = 0; $i -lt $Uninstall.Count; $i++) {
        $Uninstall[$i] = $Uninstall[$i].Trim()
        if ($Uninstall[$i] -match '[\$`;&|><\r\n]') {
            Write-Log "[-] Invalid characters detected in uninstallation target '$($Uninstall[$i])'." Red
            exit 1
        }
    }
}

# ------------------------------------------------------------------------------
# Exchange Online Connection (Optional)
# ------------------------------------------------------------------------------
function Connect-ExchangeEnvironment {
    param (
        [string]$AdminUPN
    )

    Write-Log "[*] Checking Exchange Online connectivity..." Cyan

    if (-not (Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
        Write-Log "[!] ExchangeOnlineManagement module not installed. Attempting installation..." Yellow
        try {
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Log "[+] ExchangeOnlineManagement module successfully installed." Green
        } catch {
            Write-Log "[-] Warning: Could not install ExchangeOnlineManagement module: $_" Yellow
            Write-Log "    Proceeding with local workstation management." Gray
            return
        }
    }

    # Check for existing session
    $sessionActive = $false
    try {
        if (Get-Command -Name "Get-OrganizationConfig" -ErrorAction SilentlyContinue) {
            $orgConfig = Get-OrganizationConfig -ErrorAction Stop
            Write-Log "[+] Active Exchange Online session detected (Organization: $($orgConfig.DisplayName))." Green
            $sessionActive = $true
        }
    } catch {
        $sessionActive = $false
    }

    if (-not $sessionActive) {
        Write-Log "[*] Initiating administrator login to Exchange Online..." Cyan
        try {
            $connectParams = @{
                ShowBanner  = $false
                ErrorAction = 'Stop'
            }
            if (-not [string]::IsNullOrWhiteSpace($AdminUPN)) {
                $connectParams['UserPrincipalName'] = $AdminUPN
            }
            Connect-ExchangeOnline @connectParams
            Write-Log "[+] Successfully connected to Exchange Online." Green
        } catch {
            Write-Log "[-] Exchange Online connection failed or was cancelled: $_" Yellow
            Write-Log "    Continuing with local uninstallation operations..." Gray
        }
    }
}

# Connect to Exchange Online ONLY when explicitly requested via -ConnectExchange or -AdminUserPrincipalName
if (($ConnectExchange -or -not [string]::IsNullOrWhiteSpace($AdminUserPrincipalName)) -and -not $SkipExchangeConnection) {
    Connect-ExchangeEnvironment -AdminUPN $AdminUserPrincipalName
}

# ------------------------------------------------------------------------------
# WinGet & Registry Inventory Engine
# ------------------------------------------------------------------------------
function Assert-WingetAvailability {
    $wingetCmd = Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        try {
            $rawVer = (& winget.exe --version 2>$null | Out-String).Trim()
            Write-Log "[i] WinGet detected: $rawVer" Gray
            return $true
        } catch {}
    }
    Write-Log "[!] WinGet is not available on this system. Registry/MSI uninstallers will be used." Yellow
    return $false
}

$hasWinget = Assert-WingetAvailability

function Get-RegistryInstalledApplications {
    [CmdletBinding()]
    param ()

    $installedList = [System.Collections.Generic.List[PSCustomObject]]::new()

    $hives = @(
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry32; Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser;  View = [Microsoft.Win32.RegistryView]::Default;    Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" }
    )

    foreach ($target in $hives) {
        $baseKey = $null
        $subKey  = $null
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($target.Hive, $target.View)
            $subKey  = $baseKey.OpenSubKey($target.Path)

            if ($subKey) {
                foreach ($keyName in $subKey.GetSubKeyNames()) {
                    $appKey = $null
                    try {
                        $appKey = $subKey.OpenSubKey($keyName)
                        if ($appKey) {
                            $rawDisplayName = $appKey.GetValue("DisplayName")
                            $displayName = if ($null -ne $rawDisplayName) { [string]$rawDisplayName } else { "" }

                            # Filter out system updates / empty names
                            $systemComponent = $appKey.GetValue("SystemComponent")
                            $parentKeyName   = $appKey.GetValue("ParentKeyName")
                            if ($systemComponent -eq 1 -or -not [string]::IsNullOrWhiteSpace($parentKeyName)) {
                                continue
                            }

                            if (-not [string]::IsNullOrWhiteSpace($displayName)) {
                                $rawVer          = $appKey.GetValue("DisplayVersion")
                                $rawPublisher    = $appKey.GetValue("Publisher")
                                $rawDate         = $appKey.GetValue("InstallDate")
                                $rawLocation     = $appKey.GetValue("InstallLocation")
                                $rawIcon         = $appKey.GetValue("DisplayIcon")
                                $uninstallString = $appKey.GetValue("UninstallString")
                                $quietUninstall  = $appKey.GetValue("QuietUninstallString")
                                $windowsInstaller= $appKey.GetValue("WindowsInstaller")

                                # Format date YYYYMMDD -> YYYY-MM-DD
                                $formattedDate = "Unavailable"
                                if ($null -ne $rawDate) {
                                    $dStr = [string]$rawDate
                                    if ($dStr -match '^\d{8}$') {
                                        $formattedDate = "$($dStr.Substring(0,4))-$($dStr.Substring(4,2))-$($dStr.Substring(6,2))"
                                    } elseif (-not [string]::IsNullOrWhiteSpace($dStr)) {
                                        $formattedDate = $dStr
                                    }
                                }

                                # Location determination with multiple fallback heuristics
                                $location = ""
                                if ($null -ne $rawLocation -and -not [string]::IsNullOrWhiteSpace([string]$rawLocation)) {
                                    $location = [string]$rawLocation
                                } elseif ($null -ne $rawIcon -and -not [string]::IsNullOrWhiteSpace([string]$rawIcon)) {
                                    $iconClean = ([string]$rawIcon -split ',')[0].Trim(' "')
                                    try {
                                        if ([System.IO.File]::Exists($iconClean)) {
                                            $location = [System.IO.Path]::GetDirectoryName($iconClean)
                                        }
                                    } catch {}
                                } elseif ($null -ne $uninstallString -and -not [string]::IsNullOrWhiteSpace([string]$uninstallString)) {
                                    if ($uninstallString -match '["'']([^"'']+\.exe)["'']|([^\s]+\.exe)') {
                                        $candidateExe = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
                                        try {
                                            if ([System.IO.File]::Exists($candidateExe)) {
                                                $location = [System.IO.Path]::GetDirectoryName($candidateExe)
                                            }
                                        } catch {}
                                    }
                                }
                                if ([string]::IsNullOrWhiteSpace($location)) {
                                    $location = "Unavailable / Not specified"
                                }

                                $installedList.Add([PSCustomObject]@{
                                    KeyName              = $keyName
                                    DisplayName          = $displayName.Trim()
                                    DisplayVersion       = if ($null -ne $rawVer) { [string]$rawVer } else { "Unknown" }
                                    Publisher            = if ($null -ne $rawPublisher -and -not [string]::IsNullOrWhiteSpace([string]$rawPublisher)) { [string]$rawPublisher } else { "Unknown" }
                                    InstallDate          = $formattedDate
                                    InstallLocation      = $location
                                    UninstallString      = if ($null -ne $uninstallString) { [string]$uninstallString } else { "" }
                                    QuietUninstallString = if ($null -ne $quietUninstall) { [string]$quietUninstall } else { "" }
                                    WindowsInstaller     = ($windowsInstaller -eq 1 -or $keyName -match '^\{[0-9A-Fa-f-]+\}$')
                                    Architecture         = if ($target.View -eq [Microsoft.Win32.RegistryView]::Registry32) { "32-bit" } else { "64-bit" }
                                    Scope                = if ($target.Hive -eq [Microsoft.Win32.RegistryHive]::CurrentUser) { "User" } else { "Machine" }
                                })
                            }
                        }
                    }
                    catch {}
                    finally {
                        if ($appKey) { $appKey.Close() }
                    }
                }
            }
        }
        catch {}
        finally {
            if ($subKey)  { $subKey.Close() }
            if ($baseKey) { $baseKey.Close() }
        }
    }

    return $installedList
}

function Get-WingetInstalledList {
    param ([string]$QueryPattern = "")

    $wingetItems = [System.Collections.Generic.List[PSCustomObject]]::new()
    if (-not (Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue)) {
        return $wingetItems
    }

    try {
        $cmdArgs = @("list", "--accept-source-agreements")
        if (-not [string]::IsNullOrWhiteSpace($QueryPattern)) {
            $cmdArgs += @("--query", $QueryPattern)
        }

        $rawOutput = (& winget.exe @cmdArgs 2>$null | Out-String)
        $lines = $rawOutput -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $headerIdx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '\b(Name|Nazwa)\b' -and $lines[$i] -match '\b(Id|Identyfikator)\b') {
                $headerIdx = $i
                break
            }
        }

        if ($headerIdx -ge 0 -and ($headerIdx + 1) -lt $lines.Count) {
            $header = $lines[$headerIdx]
            $matchId  = [regex]::Match($header, '\b(Id|Identyfikator)\b')
            $matchVer = [regex]::Match($header, '\b(Version|Wersja)\b')
            $matchSrc = [regex]::Match($header, '(?i)\bSource\b|\b.*r.*d.*o\b|\S+$')

            $idPos  = if ($matchId.Success) { $matchId.Index } else { 30 }
            $verPos = if ($matchVer.Success) { $matchVer.Index } else { 60 }
            $srcPos = if ($matchSrc.Success) { $matchSrc.Index } else { -1 }

            for ($j = $headerIdx + 2; $j -lt $lines.Count; $j++) {
                $line = $lines[$j]
                if ($line.Length -gt $idPos) {
                    $name = $line.Substring(0, [math]::Min($idPos, $line.Length)).Trim()
                    $id   = if ($line.Length -gt $verPos) { $line.Substring($idPos, $verPos - $idPos).Trim() } else { $line.Substring($idPos).Trim() }
                    $ver  = if ($srcPos -gt 0 -and $line.Length -gt $srcPos) { 
                        $line.Substring($verPos, $srcPos - $verPos).Trim() 
                    } elseif ($line.Length -gt $verPos) { 
                        $line.Substring($verPos).Trim() 
                    } else { "" }
                    $src  = if ($srcPos -gt 0 -and $line.Length -gt $srcPos) { $line.Substring($srcPos).Trim() } else { "" }

                    if (-not [string]::IsNullOrWhiteSpace($id)) {
                        $wingetItems.Add([PSCustomObject]@{
                            Name    = $name
                            Id      = $id
                            Version = $ver
                            Source  = $src
                        })
                    }
                }
            }
        }
    }
    catch {}

    return $wingetItems
}

function Find-InstalledApplicationsCatalog {
    param (
        [string]$SearchPattern,
        $RegistryInventory,
        $WingetInventory
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # 1. Match from WinGet inventory
    foreach ($w in $WingetInventory) {
        $matchesFilter = $true
        if (-not [string]::IsNullOrWhiteSpace($SearchPattern)) {
            $matchesFilter = ($w.Name -like "*$SearchPattern*") -or ($w.Id -like "*$SearchPattern*")
        }

        if ($matchesFilter) {
            # Find matching registry entry if exists
            $regMatch = $RegistryInventory | Where-Object {
                $_.DisplayName -eq $w.Name -or
                $_.KeyName -eq $w.Id -or
                ($w.Name.Length -ge 4 -and $_.DisplayName -like "*$($w.Name)*")
            } | Select-Object -First 1

            $uninstallId = $w.Id
            $method = if ($w.Id -match '^MSIX\\') { "MSIX" } else { "WinGet" }

            $instDate = if ($regMatch -and -not [string]::IsNullOrWhiteSpace($regMatch.InstallDate) -and $regMatch.InstallDate -ne "Unavailable") { $regMatch.InstallDate } else { "Unavailable" }
            $instLoc  = if ($regMatch -and -not [string]::IsNullOrWhiteSpace($regMatch.InstallLocation) -and $regMatch.InstallLocation -ne "Unavailable / Not specified") { $regMatch.InstallLocation } else { "Standard application folder" }

            $results.Add([PSCustomObject]@{
                UninstallId     = $uninstallId
                DisplayName     = $w.Name
                Publisher       = if ($regMatch) { $regMatch.Publisher } else { "Unknown" }
                Version         = if ($w.Version) { $w.Version } elseif ($regMatch) { $regMatch.DisplayVersion } else { "Unknown" }
                InstallDate     = $instDate
                InstallLocation = $instLoc
                Method          = $method
                RegistryKey     = if ($regMatch) { $regMatch.KeyName } else { "" }
                UninstallString = if ($regMatch) { $regMatch.UninstallString } else { "" }
                QuietString     = if ($regMatch) { $regMatch.QuietUninstallString } else { "" }
                WindowsInstaller= if ($regMatch) { $regMatch.WindowsInstaller } else { $false }
                Scope           = if ($regMatch) { $regMatch.Scope } else { "Machine" }
            })
            $seenIds.Add($uninstallId) | Out-Null
            if ($regMatch) { $seenIds.Add($regMatch.KeyName) | Out-Null }
        }
    }

    # 2. Match from Registry inventory (items not covered by WinGet)
    foreach ($r in $RegistryInventory) {
        if ($seenIds.Contains($r.KeyName) -or $seenIds.Contains($r.DisplayName)) {
            continue
        }

        $matchesFilter = $true
        if (-not [string]::IsNullOrWhiteSpace($SearchPattern)) {
            $matchesFilter = ($r.DisplayName -like "*$SearchPattern*") -or 
                             ($r.Publisher -like "*$SearchPattern*") -or 
                             ($r.KeyName -like "*$SearchPattern*")
        }

        if ($matchesFilter) {
            $method = "Registry"
            $uninstallId = $r.DisplayName

            if ($r.WindowsInstaller -or $r.KeyName -match '^\{[0-9A-Fa-f-]+\}$') {
                $method = "MSI"
                $uninstallId = $r.KeyName
            } elseif (-not [string]::IsNullOrWhiteSpace($r.QuietUninstallString) -or -not [string]::IsNullOrWhiteSpace($r.UninstallString)) {
                $method = "Registry"
                $uninstallId = $r.DisplayName
            }

            $results.Add([PSCustomObject]@{
                UninstallId     = $uninstallId
                DisplayName     = $r.DisplayName
                Publisher       = $r.Publisher
                Version         = $r.DisplayVersion
                InstallDate     = $r.InstallDate
                InstallLocation = $r.InstallLocation
                Method          = $method
                RegistryKey     = $r.KeyName
                UninstallString = $r.UninstallString
                QuietString     = $r.QuietUninstallString
                WindowsInstaller= $r.WindowsInstaller
                Scope           = $r.Scope
            })
            $seenIds.Add($r.KeyName) | Out-Null
            $seenIds.Add($r.DisplayName) | Out-Null
        }
    }

    return $results
}

# ------------------------------------------------------------------------------
# List Mode Execution
# ------------------------------------------------------------------------------
if ($List -or ($PSCmdlet.ParameterSetName -eq "Default" -and -not [string]::IsNullOrWhiteSpace($Filter))) {
    Write-Log "`n[*] Scanning installed applications catalog (Pattern: '$Filter')..." Cyan

    $regInventory = Get-RegistryInstalledApplications
    $wingetInventory = Get-WingetInstalledList -QueryPattern $Filter
    $matchedApps = Find-InstalledApplicationsCatalog -SearchPattern $Filter -RegistryInventory $regInventory -WingetInventory $wingetInventory

    if ($matchedApps.Count -eq 0) {
        Write-Log "[!] No installed applications found matching filter: '$Filter'." Yellow
        return
    }

    Write-Log "`n[+] Found $($matchedApps.Count) application(s) matching '$Filter':`n" Green
    Write-Log "----------------------------------" DarkGray

    $index = 1
    foreach ($app in ($matchedApps | Sort-Object DisplayName)) {
        $verText = if ($app.InstallDate -and $app.InstallDate -ne "Unavailable") {
            "$($app.Version) (Install Date: $($app.InstallDate))"
        } else {
            "$($app.Version)"
        }

        Write-Log "1. nr kolejny: $index" Cyan
        Write-Log "2. Uninstall Identifier: $($app.UninstallId)" Yellow
        Write-Log "3. Application Name: $($app.DisplayName)" White
        Write-Log "4. Version: $verText" Gray
        Write-Log "5. Location: $($app.InstallLocation)" Gray
        Write-Log "----------------------------------" DarkGray
        $index++
    }

    Write-Log "Installed / Filtered Applications number: $($matchedApps.Count)`n" Green

    Write-Log "--------------------------------------------------------------------------------" DarkGray
    Write-Log "USAGE TIP: To uninstall any program listed above, run:" Cyan
    Write-Log "  .\Uninstall-Applications.ps1 -Uninstall `"$($matchedApps[0].UninstallId)`"" Yellow
    if ($matchedApps.Count -gt 1) {
        Write-Log "  .\Uninstall-Applications.ps1 -Uninstall `"$($matchedApps[0].UninstallId)`", `"$($matchedApps[1].UninstallId)`" -Force" Yellow
    }
    Write-Log "--------------------------------------------------------------------------------`n" DarkGray
    return
}

# ------------------------------------------------------------------------------
# Uninstallation Execution Engine
# ------------------------------------------------------------------------------
function Resolve-ApplicationForUninstall {
    param (
        [string]$Target,
        $RegistryInventory,
        $WingetInventory
    )

    # 1. Exact WinGet ID match from pre-fetched inventory
    $wMatch = $WingetInventory | Where-Object { $_.Id -eq $Target } | Select-Object -First 1
    if ($wMatch) {
        $regMatch = $RegistryInventory | Where-Object { $_.DisplayName -eq $wMatch.Name -or $_.KeyName -eq $wMatch.Id } | Select-Object -First 1
        return [PSCustomObject]@{
            Target          = $Target
            DisplayName     = $wMatch.Name
            PackageId       = $wMatch.Id
            Publisher       = if ($regMatch) { $regMatch.Publisher } else { "Unknown" }
            Version         = if ($wMatch.Version) { $wMatch.Version } elseif ($regMatch) { $regMatch.DisplayVersion } else { "Unknown" }
            InstallDate     = if ($regMatch) { $regMatch.InstallDate } else { "Unavailable" }
            InstallLocation = if ($regMatch) { $regMatch.InstallLocation } else { "Standard application folder" }
            Method          = if ($wMatch.Id -match '^MSIX\\') { "MSIX" } else { "WinGet" }
            RegistryKey     = if ($regMatch) { $regMatch.KeyName } else { "" }
            UninstallString = if ($regMatch) { $regMatch.UninstallString } else { "" }
            QuietString     = if ($regMatch) { $regMatch.QuietUninstallString } else { "" }
            WindowsInstaller= if ($regMatch) { $regMatch.WindowsInstaller } else { $false }
            Scope           = if ($regMatch) { $regMatch.Scope } else { "Machine" }
        }
    }

    # 2. Direct WinGet lookup for exact ID or Query if winget is available
    if (Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue) {
        try {
            $wExactList = Get-WingetInstalledList -QueryPattern $Target
            $wExact = $wExactList | Where-Object { $_.Id -eq $Target -or $_.Name -eq $Target } | Select-Object -First 1
            if ($wExact) {
                $regMatch = $RegistryInventory | Where-Object { $_.DisplayName -eq $wExact.Name -or $_.KeyName -eq $wExact.Id } | Select-Object -First 1
                return [PSCustomObject]@{
                    Target          = $Target
                    DisplayName     = $wExact.Name
                    PackageId       = $wExact.Id
                    Publisher       = if ($regMatch) { $regMatch.Publisher } else { "Unknown" }
                    Version         = if ($wExact.Version) { $wExact.Version } elseif ($regMatch) { $regMatch.DisplayVersion } else { "Unknown" }
                    InstallDate     = if ($regMatch) { $regMatch.InstallDate } else { "Unavailable" }
                    InstallLocation = if ($regMatch) { $regMatch.InstallLocation } else { "Standard application folder" }
                    Method          = if ($wExact.Id -match '^MSIX\\') { "MSIX" } else { "WinGet" }
                    RegistryKey     = if ($regMatch) { $regMatch.KeyName } else { "" }
                    UninstallString = if ($regMatch) { $regMatch.UninstallString } else { "" }
                    QuietString     = if ($regMatch) { $regMatch.QuietUninstallString } else { "" }
                    WindowsInstaller= if ($regMatch) { $regMatch.WindowsInstaller } else { $false }
                    Scope           = if ($regMatch) { $regMatch.Scope } else { "Machine" }
                }
            }
        }
        catch {}
    }

    # 3. Exact Registry KeyName match (e.g. MSI GUID)
    $rKeyMatch = $RegistryInventory | Where-Object { $_.KeyName -eq $Target } | Select-Object -First 1
    if ($rKeyMatch) {
        $method = if ($rKeyMatch.WindowsInstaller -or $rKeyMatch.KeyName -match '^\{[0-9A-Fa-f-]+\}$') { "MSI" } else { "Registry" }
        return [PSCustomObject]@{
            Target          = $Target
            DisplayName     = $rKeyMatch.DisplayName
            PackageId       = $rKeyMatch.KeyName
            Publisher       = $rKeyMatch.Publisher
            Version         = $rKeyMatch.DisplayVersion
            InstallDate     = $rKeyMatch.InstallDate
            InstallLocation = $rKeyMatch.InstallLocation
            Method          = $method
            RegistryKey     = $rKeyMatch.KeyName
            UninstallString = $rKeyMatch.UninstallString
            QuietString     = $rKeyMatch.QuietUninstallString
            WindowsInstaller= $rKeyMatch.WindowsInstaller
            Scope           = $rKeyMatch.Scope
        }
    }

    # 4. Exact Registry DisplayName match
    $rNameMatch = $RegistryInventory | Where-Object { $_.DisplayName -eq $Target } | Select-Object -First 1
    if ($rNameMatch) {
        $method = if ($rNameMatch.WindowsInstaller -or $rNameMatch.KeyName -match '^\{[0-9A-Fa-f-]+\}$') { "MSI" } else { "Registry" }
        return [PSCustomObject]@{
            Target          = $Target
            DisplayName     = $rNameMatch.DisplayName
            PackageId       = $rNameMatch.KeyName
            Publisher       = $rNameMatch.Publisher
            Version         = $rNameMatch.DisplayVersion
            InstallDate     = $rNameMatch.InstallDate
            InstallLocation = $rNameMatch.InstallLocation
            Method          = $method
            RegistryKey     = $rNameMatch.KeyName
            UninstallString = $rNameMatch.UninstallString
            QuietString     = $rNameMatch.QuietUninstallString
            WindowsInstaller= $rNameMatch.WindowsInstaller
            Scope           = $rNameMatch.Scope
        }
    }

    # 5. Partial match in WinGet inventory
    $wPartial = $WingetInventory | Where-Object { $_.Name -like "*$Target*" -or $_.Id -like "*$Target*" } | Select-Object -First 1
    if ($wPartial) {
        $regPartialMatch = $RegistryInventory | Where-Object { $_.DisplayName -like "*$Target*" -or $_.KeyName -like "*$Target*" } | Select-Object -First 1
        return [PSCustomObject]@{
            Target          = $Target
            DisplayName     = $wPartial.Name
            PackageId       = $wPartial.Id
            Publisher       = if ($regPartialMatch) { $regPartialMatch.Publisher } else { "Unknown" }
            Version         = $wPartial.Version
            InstallDate     = if ($regPartialMatch) { $regPartialMatch.InstallDate } else { "Unavailable" }
            InstallLocation = if ($regPartialMatch) { $regPartialMatch.InstallLocation } else { "Standard application folder" }
            Method          = if ($wPartial.Id -match '^MSIX\\') { "MSIX" } else { "WinGet" }
            RegistryKey     = if ($regPartialMatch) { $regPartialMatch.KeyName } else { "" }
            UninstallString = if ($regPartialMatch) { $regPartialMatch.UninstallString } else { "" }
            QuietString     = if ($regPartialMatch) { $regPartialMatch.QuietUninstallString } else { "" }
            WindowsInstaller= if ($regPartialMatch) { $regPartialMatch.WindowsInstaller } else { $false }
            Scope           = "Machine"
        }
    }

    # 6. Partial match in Registry inventory
    $rPartial = $RegistryInventory | Where-Object { $_.DisplayName -like "*$Target*" } | Select-Object -First 1
    if ($rPartial) {
        $method = if ($rPartial.WindowsInstaller -or $rPartial.KeyName -match '^\{[0-9A-Fa-f-]+\}$') { "MSI" } else { "Registry" }
        return [PSCustomObject]@{
            Target          = $Target
            DisplayName     = $rPartial.DisplayName
            PackageId       = $rPartial.KeyName
            Publisher       = $rPartial.Publisher
            Version         = $rPartial.DisplayVersion
            InstallDate     = $rPartial.InstallDate
            InstallLocation = $rPartial.InstallLocation
            Method          = $method
            RegistryKey     = $rPartial.KeyName
            UninstallString = $rPartial.UninstallString
            QuietString     = $rPartial.QuietUninstallString
            WindowsInstaller= $rPartial.WindowsInstaller
            Scope           = $rPartial.Scope
        }
    }

    return $null
}

function Execute-PackageUninstall {
    param (
        [PSCustomObject]$AppInfo,
        [int]$Index,
        [int]$TotalCount,
        [switch]$BypassPrompt,
        [switch]$DryRun
    )

    $percent = [math]::Round((($Index / $TotalCount) * 100), 0)
    Write-Progress -Activity "Uninstalling Applications" -Status "[$Index/$TotalCount] Processing: $($AppInfo.DisplayName) ($percent%)" -PercentComplete $percent

    Write-Log "`n--------------------------------------------------------------------------------" DarkCyan
    Write-Log "[$Index/$TotalCount] Target: $($AppInfo.DisplayName)" Cyan
    Write-Log "  * Package ID   : $($AppInfo.PackageId)" Gray
    Write-Log "  * Version      : $($AppInfo.Version)" Gray
    Write-Log "  * Publisher    : $($AppInfo.Publisher)" Gray
    Write-Log "  * Install Date : $($AppInfo.InstallDate)" Gray
    Write-Log "  * Location     : $($AppInfo.InstallLocation)" Gray
    Write-Log "  * Architecture : $($AppInfo.Scope)" Gray
    Write-Log "  * Method       : $($AppInfo.Method)" Gray
    Write-Log "--------------------------------------------------------------------------------" DarkCyan

    if ($DryRun) {
        Write-Log "  [WhatIf] Dry Run Simulation: Would uninstall '$($AppInfo.DisplayName)' via $($AppInfo.Method)." Yellow
        return [PSCustomObject]@{
            Target     = $AppInfo.DisplayName
            PackageId  = $AppInfo.PackageId
            Status     = "SIMULATED"
            ExitCode   = 0
            Method     = $AppInfo.Method
            DurationSec= 0
        }
    }

    if (-not $BypassPrompt) {
        Write-Host "Are you sure you want to uninstall '$($AppInfo.DisplayName)' (ID: $($AppInfo.PackageId))? [Y/N]: " -NoNewline -ForegroundColor Yellow
        $response = [Console]::ReadLine()
        if ($response -notmatch '^(y|yes|t|tak)$') {
            Write-Log "  [-] Uninstallation cancelled by user for: $($AppInfo.DisplayName)" Yellow
            return [PSCustomObject]@{
                Target     = $AppInfo.DisplayName
                PackageId  = $AppInfo.PackageId
                Status     = "CANCELLED"
                ExitCode   = -1
                Method     = $AppInfo.Method
                DurationSec= 0
            }
        }
    }

    $startTime = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = -1
    $status = "FAILED"

    try {
        switch ($AppInfo.Method) {
            "WinGet" {
                Write-Log "  [*] Invoking WinGet uninstaller for ID: '$($AppInfo.PackageId)'..." Cyan
                $procArgs = @("uninstall", "--exact", "--id", $AppInfo.PackageId, "--silent", "--accept-source-agreements")
                $proc = Start-Process -FilePath "winget.exe" -ArgumentList $procArgs -Wait -PassThru -NoNewWindow
                $exitCode = $proc.ExitCode
            }

            "MSIX" {
                Write-Log "  [*] Invoking WinGet / Appx uninstaller for package: '$($AppInfo.PackageId)'..." Cyan
                $cleanId = $AppInfo.PackageId -replace '^MSIX\\', ''
                $procArgs = @("uninstall", "--id", $cleanId, "--silent", "--accept-source-agreements")
                $proc = Start-Process -FilePath "winget.exe" -ArgumentList $procArgs -Wait -PassThru -NoNewWindow
                $exitCode = $proc.ExitCode
            }

            "MSI" {
                $guid = if ($AppInfo.PackageId -match '^\{[0-9A-Fa-f-]+\}$') { $AppInfo.PackageId } else {
                    if ($AppInfo.UninstallString -match '\{[0-9A-Fa-f-]+\}') { $Matches[0] } else { $AppInfo.PackageId }
                }
                Write-Log "  [*] Invoking Windows Installer (MsiExec) for GUID: $guid..." Cyan
                $procArgs = "/x `"$guid`" /qn /norestart"
                $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $procArgs -Wait -PassThru -NoNewWindow
                $exitCode = $proc.ExitCode
            }

            "Registry" {
                $commandToRun = if (-not [string]::IsNullOrWhiteSpace($AppInfo.QuietString)) {
                    $AppInfo.QuietString
                } else {
                    $AppInfo.UninstallString
                }

                Write-Log "  [*] Invoking native uninstaller command: $commandToRun..." Cyan

                # Parse executable and arguments
                $exePath = ""
                $exeArgs = ""

                if ($commandToRun -match '^"([^"]+)"\s*(.*)$') {
                    $exePath = $Matches[1]
                    $exeArgs = $Matches[2]
                } elseif ($commandToRun -match '^([^\s]+)\s*(.*)$') {
                    $exePath = $Matches[1]
                    $exeArgs = $Matches[2]
                } else {
                    $exePath = $commandToRun
                    $exeArgs = ""
                }

                # Append silent flag if not already present
                if ($exeArgs -notmatch '(?i)/s|/silent|/quiet|/qn|/verysilent') {
                    $exeArgs = "$exeArgs /SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART".Trim()
                }

                $proc = Start-Process -FilePath $exePath -ArgumentList $exeArgs -Wait -PassThru -NoNewWindow
                $exitCode = $proc.ExitCode
            }
        }

        $startTime.Stop()
        $duration = [math]::Round($startTime.Elapsed.TotalSeconds, 1)

        # Evaluate exit codes
        # 0 = Success, 3010 / -1978335189 = Success (Reboot required), 1605 = Already uninstalled
        if ($exitCode -eq 0) {
            $status = "SUCCESS"
            Write-Log "  [+] Success: Uninstallation completed in $duration seconds (ExitCode: 0)." Green
        } elseif ($exitCode -eq 3010 -or $exitCode -eq -1978335189) {
            $status = "REBOOT_REQUIRED"
            Write-Log "  [!] Success: Uninstallation completed in $duration seconds. System reboot required (ExitCode: $exitCode)." Yellow
        } elseif ($exitCode -eq 1605) {
            $status = "SUCCESS"
            Write-Log "  [+] Application was already removed from system (ExitCode: 1605)." Green
        } else {
            $status = "FAILED"
            Write-Log "  [-] Uninstaller process exited with return code: $exitCode (Duration: $duration s)." Red
        }

        # Post-uninstallation verification
        Start-Sleep -Seconds 2
        Write-Log "  [*] Performing post-removal state verification..." DarkGray
        $recheckRegistry = Get-RegistryInstalledApplications
        $isStillPresent = $recheckRegistry | Where-Object { $_.DisplayName -eq $AppInfo.DisplayName -or $_.KeyName -eq $AppInfo.PackageId }

        if (-not $isStillPresent) {
            Write-Log "  [V] Verification Confirmed: Application no longer present in Windows registry." Green
            if ($status -eq "FAILED" -and $exitCode -eq 0) { $status = "SUCCESS" }
        } else {
            if ($status -eq "REBOOT_REQUIRED") {
                Write-Log "  [!] Verification Notice: Registry key will be cleared upon system restart." Yellow
            } else {
                Write-Log "  [!] Verification Warning: Application entry still detected in system registry." Yellow
            }
        }
    }
    catch {
        $startTime.Stop()
        $duration = [math]::Round($startTime.Elapsed.TotalSeconds, 1)
        Write-Log "  [-] Error executing uninstaller for '$($AppInfo.DisplayName)': $_" Red
        $status = "ERROR"
    }

    return [PSCustomObject]@{
        Target     = $AppInfo.DisplayName
        PackageId  = $AppInfo.PackageId
        Status     = $status
        ExitCode   = $exitCode
        Method     = $AppInfo.Method
        DurationSec= $duration
    }
}

# Run Uninstallation Batch
Write-Log "`n[*] Initializing batch uninstallation for $($Uninstall.Count) specified item(s)..." Cyan

$regInventory = Get-RegistryInstalledApplications
$wingetInventory = Get-WingetInstalledList
$summaryResults = [System.Collections.Generic.List[PSCustomObject]]::new()

$totalItems = $Uninstall.Count
$currentIndex = 1

foreach ($targetItem in $Uninstall) {
    Write-Log "`n>>> Resolving target: '$targetItem'..." Cyan
    $resolvedApp = Resolve-ApplicationForUninstall -Target $targetItem -RegistryInventory $regInventory -WingetInventory $wingetInventory

    if ($null -eq $resolvedApp) {
        Write-Log "[-] Target '$targetItem' was not found among installed applications or WinGet packages." Yellow
        $summaryResults.Add([PSCustomObject]@{
            Target     = $targetItem
            PackageId  = "-"
            Status     = "NOT_FOUND"
            ExitCode   = -1
            Method     = "-"
            DurationSec= 0
        })
        $currentIndex++
        continue
    }

    $result = Execute-PackageUninstall -AppInfo $resolvedApp -Index $currentIndex -TotalCount $totalItems -BypassPrompt:$Force -DryRun:$WhatIf
    $summaryResults.Add($result)
    $currentIndex++
}

Write-Progress -Activity "Uninstalling Applications" -Completed

# ------------------------------------------------------------------------------
# Executive Uninstallation Summary & Reporting
# ------------------------------------------------------------------------------
Write-Log "`n================================================================================" Cyan
Write-Log "  UNINSTALLATION BATCH EXECUTION SUMMARY" Cyan
Write-Log "================================================================================" Cyan

$successCount   = @($summaryResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
$rebootCount    = @($summaryResults | Where-Object { $_.Status -eq "REBOOT_REQUIRED" }).Count
$simCount       = @($summaryResults | Where-Object { $_.Status -eq "SIMULATED" }).Count
$failedCount    = @($summaryResults | Where-Object { $_.Status -in @("FAILED", "ERROR", "NOT_FOUND") }).Count
$cancelledCount = @($summaryResults | Where-Object { $_.Status -eq "CANCELLED" }).Count

Write-Log "  Total Targets Processed : $($summaryResults.Count)" White
Write-Log "  Successfully Removed    : $successCount" Green
if ($rebootCount -gt 0) {
    Write-Log "  Reboot Required         : $rebootCount" Yellow
}
if ($simCount -gt 0) {
    Write-Log "  Simulated (Dry Run)     : $simCount" Cyan
}
if ($failedCount -gt 0) {
    Write-Log "  Failed / Not Found      : $failedCount" Red
}
if ($cancelledCount -gt 0) {
    Write-Log "  Cancelled by User       : $cancelledCount" Yellow
}
Write-Log "--------------------------------------------------------------------------------" DarkGray

$summaryTable = $summaryResults | Format-Table `
    @{Label = "Target"; Expression = { $_.Target }; Width = 32}, `
    @{Label = "Status"; Expression = { "[$($_.Status)]" }; Width = 18}, `
    @{Label = "Method"; Expression = { $_.Method }; Width = 10}, `
    @{Label = "Exit Code"; Expression = { $_.ExitCode }; Width = 10}, `
    @{Label = "Time (s)"; Expression = { "$($_.DurationSec)s" }; Width = 10} `
    -AutoSize | Out-String -Width 100

Write-Log $summaryTable.TrimEnd() White
Write-Log "--------------------------------------------------------------------------------" DarkGray
Write-Log "  Execution Log Saved to: $script:ActiveLogFile" Cyan
Write-Log "================================================================================`n" Cyan
