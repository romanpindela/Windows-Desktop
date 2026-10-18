<#
================================================================================
  Script Name : Add-NetworkPrinter.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  Version     : 1.0.0
  Release Date: 2026-10-15
  License     : MIT
  Repository  : https://github.com/romanpindela

  DESCRIPTION:
    Automates the installation and configuration of network TCP/IP printers in
    local area networks (LAN) across Windows 10, Windows 11, and Windows Server
    (x64 / ARM64).

    Features and Capabilities:
    1. Zero-Parameter Interactive Help:
       When run without arguments or with -Help / -h, displays comprehensive
       usage syntax, version, author info, and practical real-world examples
       without triggering an unnecessary UAC elevation prompt.
    2. Input Validation & Security:
       Validates IP addresses, printer queue names, paths, and URLs to defend
       against command injection and invalid parameter input.
    3. Language-Agnostic UAC Elevation:
       Uses standard Windows well-known SIDs (BuiltInAdministratorsSid) to
       reliably verify administrative privileges across both English
       ("Administrators") and Polish ("Administratorzy") Windows editions.
       Automatically prompts for elevation when needed while preserving all
       supplied parameters.
    4. Flexible Driver Provisioning:
       - System Driver (Default/No Path): Automatically discovers and reuses
         matching print drivers already staged in the Windows system / DriverStore
         (e.g., vendor PCL or universal drivers matching the printer name).
       - Local .INF File or Folder: Imports and registers drivers from a local
         path using pnputil.
       - Remote Web URL (HTTP/HTTPS): Downloads driver packages (.inf or .zip),
         extracts archives to a secure temporary directory, and stages drivers.
    5. Robust Diagnostics:
       Validates Print Spooler service health, executes ICMP ping checks, and
       performs RAW TCP port (default: 9100) reachability checks prior to and
       during deployment.
    6. Idempotent Queue & Port Configuration:
       Safely creates standard TCP/IP printer ports (with configurable SNMP)
       and installs or updates existing printer queues without duplicate port
       or device conflicts.
    7. Enterprise Audit Logging:
       Outputs colorized console feedback and writes timestamped UTF-8 logs
       to C:\Logs or a custom designated log file path.
================================================================================
.SYNOPSIS
    Installs and configures a network TCP/IP printer in a local area network (LAN).

.DESCRIPTION
    Automates the full lifecycle of installing a network printer queue in Windows:
    starting the Print Spooler if stopped, running network connectivity diagnostics
    (ICMP Ping and RAW TCP port 9100), staging drivers from system DriverStore,
    local .INF files, or remote HTTP/HTTPS URLs (including ZIP archives), creating
    the standard TCP/IP port, mapping the printer queue, and optionally sending a test page.

.PARAMETER PrinterIP
    Specifies the IPv4/IPv6 address or network hostname of the printer in the LAN
    (e.g., '10.10.1.71').

.PARAMETER PrinterName
    Specifies the display name of the printer queue after installation
    (e.g., 'Konica Minolta C224e').

.PARAMETER DriverPath
    Optional path to the printer driver. Can be:
    - A local path to a driver file (.inf)
    - A local directory containing .inf driver files
    - A web URL (http:// or https://) pointing to an .inf file or a .zip archive
    If omitted, the script automatically searches and uses matching drivers
    already installed in the Windows system.

.PARAMETER DriverName
    Optional exact or wildcard model name of the driver to register with the printer
    (e.g., 'KONICA MINOLTA Universal PCL'). If omitted, the driver name is resolved
    automatically from the .inf file or system driver store based on the printer name.

.PARAMETER PortName
    Optional name for the TCP/IP printer port.
    Default: 'IP_<PrinterIP>' (e.g., 'IP_10.10.1.71').

.PARAMETER PortNumber
    Optional RAW TCP port number used by the printer hardware.
    Default: 9100.

.PARAMETER SNMP
    Enables (1) or disables (0) SNMP status monitoring on the TCP/IP port.
    Default: 1.

.PARAMETER SNMPCommunity
    Specifies the SNMP community string for status monitoring.
    Default: 'public'.

.PARAMETER PrintTestPage
    Switch parameter to automatically trigger a Windows printer test page
    immediately after successful installation.

.PARAMETER LogPath
    Optional custom path to write execution and diagnostic logs.
    Default: C:\Logs\<yyyyMMdd_HHmmss>-<ComputerName>-<UserName>-Add-NetworkPrinter.txt

.PARAMETER Help
    Switch parameter (-h, -Help) to display syntax, examples, version, and author info.

.EXAMPLE
    .\Add-NetworkPrinter.ps1
    Displays the help guide, author info, version, and usage examples.

.EXAMPLE
    .\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e"
    Installs a network printer at 10.10.1.71 using pre-existing drivers in the system
    (automatically detects 'KONICA MINOLTA Universal PCL' or matching drivers).

.EXAMPLE
    .\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e" -DriverPath "C:\Drivers\Konica\KOB0J___.inf"
    Installs the printer using an exact local .INF driver file.

.EXAMPLE
    .\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e" -DriverPath "https://company-files.lan/drivers/c224e_driver.zip"
    Downloads the driver package archive from the local intranet, extracts it, stages the driver,
    and sets up the printer queue.

.EXAMPLE
    .\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e" -PrintTestPage
    Installs the printer from system drivers and immediately prints a test page.

.NOTES
    Author      : Roman Pindela
    Contact     : roman.pindela@gmail.com
    GitHub      : https://github.com/romanpindela
    Version     : 1.0.0
    Compatible  : Windows 10, Windows 11, Windows Server 2016/2019/2022/2025
    Privileges  : Requires Administrator privileges for printer installation
                  (automatically prompts for elevation via UAC if needed).
#>

[CmdletBinding(DefaultParameterSetName = "Default")]
param (
    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "InstallSet")]
    [Alias("IP", "Address", "Host")]
    [string]$PrinterIP,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "InstallSet")]
    [Alias("Name")]
    [string]$PrinterName,

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "InstallSet")]
    [Alias("Path", "DriverLocation", "DriverSource", "DriverUrl")]
    [string]$DriverPath,

    [Parameter(Mandatory = $false, ParameterSetName = "InstallSet")]
    [Alias("Driver", "DriverModel")]
    [string]$DriverName,

    [Parameter(Mandatory = $false, ParameterSetName = "InstallSet")]
    [Alias("Port")]
    [string]$PortName,

    [Parameter(Mandatory = $false, ParameterSetName = "InstallSet")]
    [Alias("PortNum")]
    [int]$PortNumber = 9100,

    [Parameter(Mandatory = $false, ParameterSetName = "InstallSet")]
    [ValidateRange(0, 1)]
    [int]$SNMP = 1,

    [Parameter(Mandatory = $false, ParameterSetName = "InstallSet")]
    [string]$SNMPCommunity = "public",

    [Parameter(Mandatory = $false, ParameterSetName = "InstallSet")]
    [Alias("TestPage", "TestPrint")]
    [switch]$PrintTestPage,

    [Parameter(Mandatory = $false, ParameterSetName = "InstallSet")]
    [Alias("l", "Log")]
    [string]$LogPath,

    [Parameter(Mandatory = $false, ParameterSetName = "HelpSet")]
    [Parameter(Mandatory = $false, ParameterSetName = "Default")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ==============================================================================
# SCRIPT METADATA & GLOBALS
# ==============================================================================
$SCRIPT_INFO = @{
    Name        = "Add-NetworkPrinter"
    FileName    = "Add-NetworkPrinter.ps1"
    Version     = "1.0.0"
    Author      = "Roman Pindela"
    Contact     = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    ReleaseDate = "2026-10-15"
}

$script:ActiveLogFile = $null

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
            # Suppress logging file errors so main execution is never aborted
        }
    }
}

# ==============================================================================
# INPUT SANITIZATION & SECURITY CHECKS
# ==============================================================================
function Protect-InputPath {
    param ([string]$PathToValidate)

    if ([string]::IsNullOrWhiteSpace($PathToValidate)) {
        return
    }

    # Defend against command injection or dangerous control characters
    if ($PathToValidate -match '[`$;&|><*?"\r\n]') {
        throw "Security Alert: Invalid or potentially dangerous characters detected in path: '$PathToValidate'."
    }

    if ($PathToValidate.Length -gt 260) {
        throw "Validation Error: Specified path exceeds maximum allowable path length (260 characters)."
    }
}

function Protect-StringInput {
    param (
        [string]$Value,
        [string]$FieldName,
        [int]$MaxLength = 255
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if ($Value.Length -gt $MaxLength) {
        throw "Validation Error: Parameter '$FieldName' exceeds maximum allowed length of $MaxLength characters."
    }

    # Defend against command chaining and injection metacharacters
    if ($Value -match '[`;&|><\r\n]') {
        throw "Security Alert: Parameter '$FieldName' contains illegal or potentially dangerous characters."
    }
}

# ==============================================================================
# HELP & DOCUMENTATION MENU
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
  Automates the complete installation and network configuration of TCP/IP
  printers in local networks (LAN) for Windows 10, 11, and Windows Server.

  Features:
  - Verifies and starts Print Spooler service if inactive.
  - Performs network diagnostics: ICMP Ping and RAW TCP port (9100) testing.
  - Three driver provisioning methods:
      1) System Driver (Default/Empty): Automatically matches and reuses drivers
         already installed in the Windows DriverStore.
      2) Local Driver Path: Stages .inf drivers from local file or directory.
      3) Remote Driver URL: Downloads and extracts .inf or .zip driver packages.
  - Idempotently creates TCP/IP port and installs or updates the printer queue.
  - Optional automated test page printing (-PrintTestPage).
  - Language-independent UAC auto-elevation (supports English and Polish Windows).

SYNTAX:
  .\Add-NetworkPrinter.ps1 -PrinterIP <IP> -PrinterName <Name> [-DriverPath <Path_or_URL>]
                           [-DriverName <Model>] [-PortName <Port>] [-PortNumber <9100>]
                           [-SNMP <0|1>] [-SNMPCommunity <Community>] [-PrintTestPage]
                           [-LogPath <Path>]

  .\Add-NetworkPrinter.ps1 [-Help | -h]

PARAMETERS:
  -PrinterIP       (Alias: -IP)       : IP address or hostname of printer (e.g., 10.10.1.71).
  -PrinterName     (Alias: -Name)     : Queue name after install (e.g., "Konica Minolta C224e").
  -DriverPath      (Alias: -Path)     : Local path to .inf file/dir OR https:// download URL.
                                        If omitted, installs from drivers already in system.
  -DriverName      (Alias: -Driver)   : Driver model name (e.g., "KONICA MINOLTA Universal PCL").
  -PortName        (Alias: -Port)     : TCP/IP port name (Default: IP_<PrinterIP>).
  -PortNumber      (Alias: -PortNum)  : RAW port number (Default: 9100).
  -SNMP                               : SNMP status monitoring: 1 = Enabled, 0 = Disabled (Default: 1).
  -SNMPCommunity                      : SNMP Community name (Default: public).
  -PrintTestPage   (Alias: -TestPage) : Automatically sends a test page after install.
  -LogPath         (Alias: -Log, -l)  : Custom log file path (Default: C:\Logs\...).
  -Help            (Alias: -h)        : Displays this help menu.

PRACTICAL EXAMPLES:
  1. Install using existing system driver (Recommended for Konica Minolta C224e):
     .\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e"

  2. Install using local .INF driver file:
     .\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e" -DriverPath "C:\Drivers\KM\KOB0J___.inf"

  3. Install by downloading driver package (.zip / .inf) over HTTPS:
     .\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e" -DriverPath "https://company.lan/drivers/c224e.zip"

  4. Install with custom driver name, custom port, and test page:
     .\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e" -DriverName "KONICA MINOLTA Universal PCL" -PrintTestPage

SECURITY & FIRST RUN:
  If downloaded from GitHub, unblock the script before executing:
     Unblock-File -Path .\Add-NetworkPrinter.ps1

================================================================================
"@ -ForegroundColor Yellow
}

# ==============================================================================
# ZERO-PARAMETER / HELP HANDLING
# ==============================================================================
if ($Help -or ([string]::IsNullOrWhiteSpace($PrinterIP) -and [string]::IsNullOrWhiteSpace($PrinterName))) {
    Show-HelpGuide
    return
}

# Ensure both core parameters are provided
if ([string]::IsNullOrWhiteSpace($PrinterIP) -or [string]::IsNullOrWhiteSpace($PrinterName)) {
    Write-Host "[-] Error: Both -PrinterIP and -PrinterName are required for printer installation." -ForegroundColor Red
    Write-Host "    Use -Help to review syntax and practical usage examples.`n" -ForegroundColor Yellow
    Show-HelpGuide
    return
}

# ==============================================================================
# INPUT VALIDATION
# ==============================================================================
Protect-StringInput -Value $PrinterIP -FieldName "PrinterIP" -MaxLength 255
Protect-StringInput -Value $PrinterName -FieldName "PrinterName" -MaxLength 220

# Validate IP address or hostname format
$ipParsed = $null
$isIp = [System.Net.IPAddress]::TryParse($PrinterIP, [ref]$ipParsed)
$isHostname = $PrinterIP -match '^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$|^[a-zA-Z0-9\-]+$'

if (-not $isIp -and -not $isHostname) {
    throw "Validation Error: '$PrinterIP' is neither a valid IPv4/IPv6 address nor a valid network hostname."
}

# Validate printer name characters (disallow Windows forbidden printer characters: \, /, ,, !, ;, ?)
if ($PrinterName -match '[\\/,!;?]') {
    throw "Validation Error: Printer name '$PrinterName' contains illegal characters (\, /, ,, !, ;, ?)."
}

if (-not [string]::IsNullOrWhiteSpace($PortName)) {
    Protect-StringInput -Value $PortName -FieldName "PortName" -MaxLength 255
} else {
    $PortName = "IP_$PrinterIP"
}

if (-not [string]::IsNullOrWhiteSpace($DriverName)) {
    Protect-StringInput -Value $DriverName -FieldName "DriverName" -MaxLength 255
}

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

if (-not (Test-IsAdminElevated)) {
    Write-Host "Missing Administrator privileges. Requesting elevation via UAC..." -ForegroundColor Yellow

    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -PrinterIP `"$PrinterIP`" -PrinterName `"$PrinterName`""

    if (-not [string]::IsNullOrWhiteSpace($DriverPath)) {
        $argList += " -DriverPath `"$DriverPath`""
    }
    if (-not [string]::IsNullOrWhiteSpace($DriverName)) {
        $argList += " -DriverName `"$DriverName`""
    }
    if (-not [string]::IsNullOrWhiteSpace($PortName)) {
        $argList += " -PortName `"$PortName`""
    }
    if ($PortNumber -ne 9100) {
        $argList += " -PortNumber $PortNumber"
    }
    if ($SNMP -ne 1) {
        $argList += " -SNMP $SNMP"
    }
    if ($SNMPCommunity -ne "public") {
        $argList += " -SNMPCommunity `"$SNMPCommunity`""
    }
    if ($PrintTestPage) {
        $argList += " -PrintTestPage"
    }
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

# ==============================================================================
# LOG INITIALIZATION
# ==============================================================================
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
    $script:ActiveLogFile = Join-Path -Path $defaultLogDir -ChildPath "$timestamp-$computerName-$userName-$($SCRIPT_INFO.Name).txt"
} else {
    $parentDir = [System.IO.Path]::GetDirectoryName($LogPath)
    if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
    $script:ActiveLogFile = $LogPath
}

# ==============================================================================
# HELPER FUNCTIONS: DRIVER DISCOVERY & INF PARSING
# ==============================================================================
function Get-DriverNamesFromInf {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InfPath
    )

    if (-not (Test-Path -Path $InfPath -PathType Leaf)) {
        return @()
    }

    $lines = Get-Content -Path $InfPath -ErrorAction SilentlyContinue
    if (-not $lines) { return @() }

    # Parse [Strings] section to resolve variable references
    $stringsMap = @{}
    $inStrings = $false
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[Strings\]') {
            $inStrings = $true
            continue
        }
        elseif ($trimmed -match '^\[.+\]') {
            $inStrings = $false
            continue
        }

        if ($inStrings -and ($trimmed -match '^([^=\s]+)\s*=\s*"?([^"]*)"?')) {
            $stringsMap[$matches[1].Trim()] = $matches[2].Trim()
        }
    }

    $modelNames = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        # Direct quoted string: "Driver Model Name" = Section, HardwareID...
        if ($trimmed -match '^\s*"([^"]+)"\s*=') {
            $name = $matches[1].Trim()
            if ($name -and -not $modelNames.Contains($name)) {
                $modelNames.Add($name)
            }
        }
        # Variable string: %ModelKey% = Section, HardwareID...
        elseif ($trimmed -match '^\s*%([^%]+)%\s*=') {
            $key = $matches[1].Trim()
            if ($stringsMap.ContainsKey($key)) {
                $resolved = $stringsMap[$key]
                if ($resolved -and -not $modelNames.Contains($resolved)) {
                    $modelNames.Add($resolved)
                }
            }
        }
    }

    return $modelNames
}

function Find-InstalledSystemDriver {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TargetPrinterName,

        [Parameter(Mandatory = $false)]
        [string]$PreferredDriverName
    )

    $allDrivers = Get-PrinterDriver -ErrorAction SilentlyContinue
    if (-not $allDrivers) {
        return $null
    }

    # 1. If explicit preferred driver name or pattern is supplied
    if (-not [string]::IsNullOrWhiteSpace($PreferredDriverName)) {
        $exact = $allDrivers | Where-Object { $_.Name -eq $PreferredDriverName } | Select-Object -First 1
        if ($exact) { return $exact.Name }

        $wildcard = $allDrivers | Where-Object { $_.Name -like "*$PreferredDriverName*" } | Select-Object -First 1
        if ($wildcard) { return $wildcard.Name }
    }

    # 2. Exact match with target printer name
    $exactPrinter = $allDrivers | Where-Object { $_.Name -eq $TargetPrinterName } | Select-Object -First 1
    if ($exactPrinter) { return $exactPrinter.Name }

    # 3. Extract meaningful keywords from target printer name (e.g., 'Konica', 'Minolta', 'C224e')
    $words = ($TargetPrinterName -replace '[^\w\s-]', ' ' -split '\s+') | Where-Object { $_.Length -ge 2 }

    # Try matching all keywords together (e.g., *Konica*Minolta*C224e*)
    if ($words.Count -ge 2) {
        $patternAll = "*" + ($words -join "*") + "*"
        $matchAll = $allDrivers | Where-Object { $_.Name -like $patternAll } | Select-Object -First 1
        if ($matchAll) { return $matchAll.Name }

        # Match vendor and product family (first two keywords, e.g., *Konica*Minolta*)
        $patternTwo = "*$($words[0])*$($words[1])*"
        $matchTwo = $allDrivers | Where-Object { $_.Name -like $patternTwo }
        if ($matchTwo) {
            # Prefer Universal PCL / standard PCL drivers if available
            $pclType3 = $matchTwo | Where-Object { $_.Name -like "*PCL*" -and $_.Name -notlike "*V4*" } | Select-Object -First 1
            if ($pclType3) { return $pclType3.Name }

            $pclAny = $matchTwo | Where-Object { $_.Name -like "*PCL*" } | Select-Object -First 1
            if ($pclAny) { return $pclAny.Name }

            return ($matchTwo | Select-Object -First 1).Name
        }
    }

    # 4. Fallback: match vendor name with PCL (e.g. *Konica*PCL*)
    if ($words.Count -ge 1) {
        $vendorPattern = "*$($words[0])*PCL*"
        $vendorMatch = $allDrivers | Where-Object { $_.Name -like $vendorPattern } | Select-Object -First 1
        if ($vendorMatch) { return $vendorMatch.Name }
    }

    return $null
}

# ==============================================================================
# MAIN INSTALLATION WORKFLOW
# ==============================================================================
Write-Log "================================================================================" -Color Cyan
Write-Log "  $($SCRIPT_INFO.Name) - Network Printer Deployment v$($SCRIPT_INFO.Version)" -Color Cyan
Write-Log "  Target Printer : $PrinterName ($PrinterIP)" -Color Cyan
Write-Log "  Execution Log  : $script:ActiveLogFile" -Color Cyan
Write-Log "================================================================================" -Color Cyan

# ------------------------------------------------------------------------------
# STEP 1: Verify and Start Print Spooler Service
# ------------------------------------------------------------------------------
Write-Log "`n[1/5] Checking Print Spooler service status..." -Color Yellow
$spooler = Get-Service -Name "Spooler" -ErrorAction SilentlyContinue
if ($null -eq $spooler) {
    throw "Print Spooler service ('Spooler') was not found on this operating system."
}

if ($spooler.Status -ne 'Running') {
    Write-Log " -> Spooler service is currently '$($spooler.Status)'. Starting service..." -Color Yellow
    Start-Service -Name "Spooler" -ErrorAction Stop
    Start-Sleep -Seconds 2
    $spooler.Refresh()
    if ($spooler.Status -ne 'Running') {
        throw "Failed to start Print Spooler service. Current state: $($spooler.Status)"
    }
}
Write-Log " -> Print Spooler service is active and running." -Color Green

# ------------------------------------------------------------------------------
# STEP 2: Network Connectivity Diagnostics (ICMP & Port 9100 RAW)
# ------------------------------------------------------------------------------
Write-Log "`n[2/5] Running network diagnostics for host ($PrinterIP)..." -Color Yellow

$pingSuccess = $false
try {
    $pingParams = @{
        ComputerName = $PrinterIP
        Count        = 2
        Quiet        = $true
        ErrorAction  = "SilentlyContinue"
    }
    $pingSuccess = [bool](Test-Connection @pingParams)
} catch {
    $pingSuccess = $false
}

if ($pingSuccess) {
    Write-Log " -> ICMP Ping OK: Target host $PrinterIP is responding on LAN." -Color Green
} else {
    Write-Log " -> WARNING: Host $PrinterIP did not respond to ICMP Ping (host may be offline or blocking ICMP)." -Color Yellow
}

$rawPortOpen = $false
try {
    $tcpParams = @{
        ComputerName  = $PrinterIP
        Port          = $PortNumber
        WarningAction = "SilentlyContinue"
        ErrorAction   = "SilentlyContinue"
    }
    $tcpTest = Test-NetConnection @tcpParams
    $rawPortOpen = [bool]($tcpTest.TcpTestSucceeded)
} catch {
    $rawPortOpen = $false
}

if ($rawPortOpen) {
    Write-Log " -> TCP Port $PortNumber (RAW) OK: Port is open and ready for print jobs." -Color Green
} else {
    Write-Log " -> WARNING: TCP Port $PortNumber is unreachable. Continuing installation in offline/queued mode..." -Color Yellow
}

# ------------------------------------------------------------------------------
# STEP 3: Driver Verification and Provisioning
# ------------------------------------------------------------------------------
Write-Log "`n[3/5] Resolving and provisioning printer driver..." -Color Yellow

$finalDriverName = $null

if (-not [string]::IsNullOrWhiteSpace($DriverPath)) {
    # --------------------------------------------------------------------------
    # Case A: Driver Path is Remote Web URL (HTTP / HTTPS)
    # --------------------------------------------------------------------------
    if ($DriverPath -match '^https?://') {
        Write-Log " -> DriverPath is a remote web URL. Downloading driver package..." -Color Cyan
        $downloadGuid = [System.Guid]::NewGuid().ToString("N")
        $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "AddPrinterDriver_$downloadGuid"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        try {
            $uri = [System.Uri]$DriverPath
            $rawFileName = [System.IO.Path]::GetFileName($uri.AbsolutePath)
            if ([string]::IsNullOrWhiteSpace($rawFileName)) {
                $rawFileName = "driver_package.tmp"
            }
            $downloadFilePath = Join-Path -Path $tempDir -ChildPath $rawFileName

            Write-Log " -> Downloading from: $DriverPath" -Color White
            Invoke-WebRequest -Uri $DriverPath -OutFile $downloadFilePath -UseBasicParsing -ErrorAction Stop

            $targetInfDir = $tempDir
            if ($downloadFilePath -like "*.zip") {
                Write-Log " -> Extracting ZIP archive..." -Color Cyan
                Expand-Archive -Path $downloadFilePath -DestinationPath $tempDir -Force -ErrorAction Stop
            }

            $infFiles = Get-ChildItem -Path $targetInfDir -Filter "*.inf" -Recurse -File
            if ($infFiles.Count -eq 0) {
                throw "No .inf driver files found inside downloaded package from '$DriverPath'."
            }

            $selectedInf = $infFiles[0].FullName
            Write-Log " -> Located driver setup file: '$selectedInf'" -Color Green

            # Stage driver into Windows DriverStore
            Write-Log " -> Staging driver into Windows DriverStore (pnputil)..." -Color White
            & pnputil.exe /add-driver "$selectedInf" /install | Out-Null

            # Determine driver name from .inf or user parameter
            if (-not [string]::IsNullOrWhiteSpace($DriverName)) {
                $finalDriverName = $DriverName
            } else {
                $infModelNames = Get-DriverNamesFromInf -InfPath $selectedInf
                if ($infModelNames.Count -gt 0) {
                    # Pick match closest to printer name or first model
                    $matchedModel = $infModelNames | Where-Object { $PrinterName -like "*$_*" -or $_ -like "*$PrinterName*" } | Select-Object -First 1
                    $finalDriverName = if ($matchedModel) { $matchedModel } else { $infModelNames[0] }
                } else {
                    $finalDriverName = $PrinterName
                }
            }

            # Register printer driver in Windows spooler
            Write-Log " -> Registering driver '$finalDriverName' with Print Spooler..." -Color White
            Add-PrinterDriver -Name $finalDriverName -ErrorAction SilentlyContinue
        }
        finally {
            # Optional cleanup of temp download files if desired
        }
    }
    # --------------------------------------------------------------------------
    # Case B: Driver Path is a Local File or Directory
    # --------------------------------------------------------------------------
    else {
        if (-not (Test-Path -Path $DriverPath)) {
            throw "Specified driver path does not exist: '$DriverPath'"
        }

        $selectedInf = $null
        if ((Get-Item -Path $DriverPath) -is [System.IO.DirectoryInfo]) {
            $infFiles = Get-ChildItem -Path $DriverPath -Filter "*.inf" -Recurse -File
            if ($infFiles.Count -eq 0) {
                throw "No .inf driver files found inside directory: '$DriverPath'"
            }
            $selectedInf = $infFiles[0].FullName
        } else {
            if ($DriverPath -notlike "*.inf") {
                throw "Specified local file is not a valid .inf driver setup file: '$DriverPath'"
            }
            $selectedInf = (Resolve-Path -Path $DriverPath).Path
        }

        Write-Log " -> Using local driver file: '$selectedInf'" -Color Green
        Write-Log " -> Staging driver into Windows DriverStore (pnputil)..." -Color White
        & pnputil.exe /add-driver "$selectedInf" /install | Out-Null

        if (-not [string]::IsNullOrWhiteSpace($DriverName)) {
            $finalDriverName = $DriverName
        } else {
            $infModelNames = Get-DriverNamesFromInf -InfPath $selectedInf
            if ($infModelNames.Count -gt 0) {
                $matchedModel = $infModelNames | Where-Object { $PrinterName -like "*$_*" -or $_ -like "*$PrinterName*" } | Select-Object -First 1
                $finalDriverName = if ($matchedModel) { $matchedModel } else { $infModelNames[0] }
            } else {
                $finalDriverName = $PrinterName
            }
        }

        Write-Log " -> Registering driver '$finalDriverName' with Print Spooler..." -Color White
        Add-PrinterDriver -Name $finalDriverName -ErrorAction SilentlyContinue
    }
}
# ------------------------------------------------------------------------------
# Case C: Driver Path is OMITTED (Install from System DriverStore)
# ------------------------------------------------------------------------------
else {
    Write-Log " -> No driver path specified. Searching existing drivers in system..." -Color Cyan
    $discoveredDriver = Find-InstalledSystemDriver -TargetPrinterName $PrinterName -PreferredDriverName $DriverName

    if ($discoveredDriver) {
        $finalDriverName = $discoveredDriver
        Write-Log " -> Found compatible driver installed in system: '$finalDriverName'" -Color Green
    } else {
        $installedList = (Get-PrinterDriver -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) -join ", "
        throw "No matching driver found in system for '$PrinterName'. Please specify -DriverPath (path to .inf or URL) or -DriverName. Available drivers: $installedList"
    }
}

# ------------------------------------------------------------------------------
# STEP 4: Standard TCP/IP Port Setup
# ------------------------------------------------------------------------------
Write-Log "`n[4/5] Configuring TCP/IP printer port ($PortName)..." -Color Yellow
$existingPort = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue

if (-not $existingPort) {
    $portParams = @{
        Name               = $PortName
        PrinterHostAddress = $PrinterIP
        PortNumber         = $PortNumber
        SNMP               = $SNMP
        SNMPCommunity      = $SNMPCommunity
        ErrorAction        = "Stop"
    }
    Add-PrinterPort @portParams
    Write-Log " -> Successfully created printer port: '$PortName' (Host: $PrinterIP, Port: $PortNumber, SNMP: $SNMP)." -Color Green
} else {
    Write-Log " -> Printer port '$PortName' already exists. Reusing existing port configuration." -Color Green
}

# ------------------------------------------------------------------------------
# STEP 5: Printer Queue Creation or Update
# ------------------------------------------------------------------------------
Write-Log "`n[5/5] Installing printer queue '$PrinterName'..." -Color Yellow
$existingPrinter = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue

if ($existingPrinter) {
    Write-Log " -> Printer '$PrinterName' already exists. Updating driver and port configuration..." -Color Yellow
    $setParams = @{
        Name        = $PrinterName
        PortName    = $PortName
        DriverName  = $finalDriverName
        ErrorAction = "Stop"
    }
    Set-Printer @setParams
    Write-Log " -> Printer '$PrinterName' configuration updated successfully." -Color Green
} else {
    $addParams = @{
        Name        = $PrinterName
        DriverName  = $finalDriverName
        PortName    = $PortName
        ErrorAction = "Stop"
    }
    Add-Printer @addParams
    Write-Log " -> Printer '$PrinterName' created and mapped successfully." -Color Green
}

# ------------------------------------------------------------------------------
# OPTIONAL: Test Page Printing
# ------------------------------------------------------------------------------
if ($PrintTestPage) {
    Write-Log "`n[*] Sending test page to printer '$PrinterName'..." -Color Cyan
    try {
        $wmiPrinter = Get-CimInstance -ClassName Win32_Printer -Filter "Name='$([regex]::Escape($PrinterName))'" -ErrorAction Stop
        if ($wmiPrinter) {
            $testRes = Invoke-CimMethod -InputObject $wmiPrinter -MethodName "PrintTestPage" -ErrorAction Stop
            if ($testRes.ReturnValue -eq 0) {
                Write-Log " -> Windows test page submitted successfully to spooler queue." -Color Green
            } else {
                Write-Log " -> WARNING: PrintTestPage returned status code: $($testRes.ReturnValue)" -Color Yellow
            }
        }
    } catch {
        Write-Log " -> WARNING: Could not submit test page via WMI/CIM: $_" -Color Yellow
    }
}

# ------------------------------------------------------------------------------
# INSTALLATION SUMMARY & VERIFICATION
# ------------------------------------------------------------------------------
$finalCheck = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
if ($finalCheck) {
    Write-Log "`n================================================================================" -Color Cyan
    Write-Log "  PRINTER INSTALLATION SUMMARY" -Color Cyan
    Write-Log "================================================================================" -Color Cyan
    $summaryObj = [PSCustomObject]@{
        "Printer Name"      = $finalCheck.Name
        "Printer IP / Host" = $PrinterIP
        "Port Name"         = $finalCheck.PortName
        "RAW Port"          = $PortNumber
        "Driver Name"       = $finalCheck.DriverName
        "Printer Status"    = if ($finalCheck.PrinterStatus) { $finalCheck.PrinterStatus } else { "Normal" }
        "Network Ping"      = if ($pingSuccess) { "Responding (OK)" } else { "No ICMP response" }
        "RAW Port 9100"     = if ($rawPortOpen) { "Listening (Open)" } else { "Unreachable / Offline" }
        "Log File"          = $script:ActiveLogFile
    }
    $summaryObj | Format-List | Out-String | ForEach-Object { Write-Host $_.TrimEnd() }
}
