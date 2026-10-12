<#
================================================================================
  Script Name : Install-Applications.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  Version     : 2.0.0
  Release Date: 2026-10-12
  License     : MIT
  Repository  : https://github.com/roman/install-applications

  DESCRIPTION:
    Automates workstation software installation, upgrades, and catalog search
    in Windows (x64 architecture) based on winget and optional JSON configurations.
    Utilizes native .NET Registry API for fast in-memory auditing and retrieval
    of installed application metadata (DisplayName, DisplayVersion,
    InstallDate, InstallLocation). Skips programs already present on the system
    and supports user-profile fallback (non-admin execution for apps like Spotify).
    Supports:
    - Workstation software deployment from a JSON configuration file.
    - Upgrading all installed applications (or a specific package) via winget.
    - Installing individual applications by package name/ID with disambiguation.
    - Searching the online winget repository by keyword/pattern (e.g. "Google").
    - Generating an audit report of currently installed workstation software.
    The emergency Office Deployment Tool (ODT) procedure for Microsoft 365
    is executed ONLY when the user explicitly provides the -Fallback switch.
    Includes comprehensive execution logging to a file.

================================================================================
.SYNOPSIS
    Installs, upgrades, searches, and audits software packages using winget and native registry inspection.
.PARAMETER ConfigPath
    Path to the JSON file containing the list of software packages to install.
.PARAMETER Install
    Package ID or name of an application to install via winget. If ambiguous, displays matching candidates with a clarification request.
    Aliases: -Package, -PackageName, -Id, -Name, -App, -i.
.PARAMETER Upgrade
    Upgrades installed workstation applications via winget. If -Package is omitted, upgrades all packages with available updates.
    Aliases: -u, -Update, -UpgradeAll.
.PARAMETER UpgradeTarget
    Optional target package ID or name when used with -Upgrade.
    Aliases: -Target, -TargetPackage, -TargetApp.
.PARAMETER Search
    Searches the online winget repository by pattern or keyword (e.g. "Google"), returning matching publisher, name, moniker, and tag results.
    Aliases: -s, -Find, -Query.
.PARAMETER VerifyInstalledApps
    Displays installed programs grouped by publisher and sorted by install date.
    Aliases: -v.
.PARAMETER LogPath
    Path to the installation/upgrade log or report.
    Aliases: -l, -Log.
.PARAMETER Fallback
    Allows fallback to the Office Deployment Tool (ODT) procedure for Microsoft 365 in case of winget checksum mismatch errors. Disabled by default.
    Aliases: -fo, -FallbackOffice.
.PARAMETER Help
    Displays detailed help menu, version, and author information.
    Aliases: -h.
.EXAMPLE
    .\Install-Applications.ps1 -ConfigPath .\ApplicationList-Roman.json
.EXAMPLE
    .\Install-Applications.ps1 -Upgrade
.EXAMPLE
    .\Install-Applications.ps1 -Upgrade -Package "7zip.7zip"
.EXAMPLE
    .\Install-Applications.ps1 -Install "Google Chrome"
.EXAMPLE
    .\Install-Applications.ps1 -Install "Chrome"
.EXAMPLE
    .\Install-Applications.ps1 -Search "Google"
.EXAMPLE
    .\Install-Applications.ps1 -VerifyInstalledApps
.EXAMPLE
    .\Install-Applications.ps1 -v -l ""
.EXAMPLE
    .\Install-Applications.ps1 -h
#>
[CmdletBinding(DefaultParameterSetName = "Config")]
param (
    # --- Mode: Deploy from JSON configuration ---
    [Parameter(ParameterSetName = "Config", Position = 0)]
    [Alias("c", "Path")]
    [ValidateScript({
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_);
        if ([System.IO.File]::Exists($resolved)) { $true }
        else { throw "Configuration file does not exist at specified path: $_" }
    })]
    [string]$ConfigPath,

    # --- Mode: Single Package Installation ---
    [Parameter(ParameterSetName = "InstallPackage", Mandatory = $true, Position = 0)]
    [Alias("Package", "PackageName", "Id", "Name", "App", "i")]
    [string]$Install,

    # --- Mode: Upgrade Installed Applications ---
    [Parameter(ParameterSetName = "Upgrade", Mandatory = $true)]
    [Alias("u", "Update", "UpgradeAll")]
    [switch]$Upgrade,

    [Parameter(ParameterSetName = "Upgrade", Mandatory = $false, Position = 0)]
    [Alias("Target", "TargetPackage", "TargetApp")]
    [string]$UpgradeTarget,

    # --- Mode: Online Search ---
    [Parameter(ParameterSetName = "Search", Mandatory = $true, Position = 0)]
    [Alias("s", "Find", "Query")]
    [string]$Search,

    # --- Mode: Verify Installed Applications Report ---
    [Parameter(ParameterSetName = "Verify", Mandatory = $true)]
    [Alias("v")]
    [switch]$VerifyInstalledApps,

    # --- Global Switches and Options ---
    [Parameter(ParameterSetName = "Config")]
    [Parameter(ParameterSetName = "InstallPackage")]
    [Alias("fo", "FallbackOffice")]
    [switch]$Fallback,

    [Parameter(ParameterSetName = "Config", Position = 1)]
    [Parameter(ParameterSetName = "InstallPackage")]
    [Parameter(ParameterSetName = "Upgrade")]
    [Parameter(ParameterSetName = "Search")]
    [Parameter(ParameterSetName = "Verify")]
    [Alias("l", "Log")]
    [string]$LogPath,

    # --- Help Mode ---
    [Parameter(ParameterSetName = "Help")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";

$SCRIPT_INFO = @{
    Name        = "Install-Applications";
    Version     = "2.0.0";
    Author      = "Roman Pindela";
    Contact     = "roman.pindela@gmail.com";
    ReleaseDate = "2026-10-12";
};

# Global variable holding active log file path
$script:ActiveLogFile = $null;

function Write-Log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    try { [Console]::CursorLeft = 0; } catch {}
    Write-Host "$Message" -ForegroundColor $Color;

    if (-not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
        try {
            $timePrefix = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss");
            $cleanLine = "[$timePrefix] $Message`r`n";
            [System.IO.File]::AppendAllText($script:ActiveLogFile, $cleanLine, [System.Text.Encoding]::UTF8);
        }
        catch {}
    }
}

function Show-HelpGuide {
    try { [Console]::CursorLeft = 0; } catch {}
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)
================================================================================
DESCRIPTION:
  Automated Windows x64 workstation deployment, upgrade, search, and auditing tool
  powered by winget and native .NET Registry inspection.

USAGE:
  # 1. Batch installation from JSON configuration file:
  .\Install-Applications.ps1 -ConfigPath <path.json> [-LogPath <log.txt>] [-Fallback]
  .\Install-Applications.ps1 .\ApplicationList.json

  # 2. Upgrade installed applications via winget:
  .\Install-Applications.ps1 -Upgrade [-LogPath <log.txt>]
  .\Install-Applications.ps1 -Upgrade -Package <PackageId>
  .\Install-Applications.ps1 -u

  # 3. Single application installation with disambiguation:
  .\Install-Applications.ps1 -Install <PackageNameOrId> [-Fallback] [-LogPath <log.txt>]
  .\Install-Applications.ps1 -Package "Google.Chrome"
  .\Install-Applications.ps1 -i "Chrome"

  # 4. Search online winget catalog by pattern/keyword:
  .\Install-Applications.ps1 -Search <pattern> [-LogPath <report.txt>]
  .\Install-Applications.ps1 -s "Google"

  # 5. Generate installed applications audit report:
  .\Install-Applications.ps1 -VerifyInstalledApps [-LogPath <report.txt>]
  .\Install-Applications.ps1 -v [-l ""]

  # 6. Display help menu:
  .\Install-Applications.ps1 -h | -Help

PARAMETERS:
  -ConfigPath, -c, -Path : Path to JSON file containing application package list.
  -Upgrade, -u, -Update  : Upgrades installed applications via winget. If -Package is omitted,
                           upgrades all applications with available updates.
  -Install, -Package, -i : Installs an application by package name or ID. If ambiguous,
                           lists matching candidates and asks to clarify.
  -Search, -s, -Find     : Searches online winget repository by pattern (e.g. "Google").
  -VerifyInstalledApps, -v : Displays installed programs grouped by publisher and install date.
  -LogPath, -l, -Log     : Path to log file or report. If omitted in install/upgrade mode,
                           defaults to C:\Logs\<DateTime>-<Computer>-<User>-Install-Applications.txt.
  -Fallback, -fo         : Enables emergency ODT procedure for Office 365 on checksum mismatch.
  -Help, -h              : Displays this help menu and author info.

EXAMPLES:
  .\Install-Applications.ps1 -h
  .\Install-Applications.ps1 -ConfigPath .\ApplicationList-Roman.json
  .\Install-Applications.ps1 -Upgrade
  .\Install-Applications.ps1 -Upgrade -Package "7zip.7zip"
  .\Install-Applications.ps1 -Install "Google Chrome"
  .\Install-Applications.ps1 -Install "Chrome"
  .\Install-Applications.ps1 -Search "Google"
  .\Install-Applications.ps1 -v
  .\Install-Applications.ps1 -v -l ""
================================================================================
"@ -ForegroundColor Yellow;
}

if ($Help -or (-not $Upgrade -and -not $VerifyInstalledApps -and [string]::IsNullOrWhiteSpace($ConfigPath) -and [string]::IsNullOrWhiteSpace($Install) -and [string]::IsNullOrWhiteSpace($Search))) {
    Show-HelpGuide;
    return;
}

# Initialize default log path if not provided (for modifying operations)
$needsLogging = (-not $VerifyInstalledApps -and [string]::IsNullOrWhiteSpace($Search));
if ($needsLogging) {
    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $defaultLogDir = "C:\Logs";
        $timeMarker = (Get-Date).ToString("yyyyMMdd_HHmmss");
        $compName   = $env:COMPUTERNAME;
        $userName   = $env:USERNAME;
        $scriptName = $SCRIPT_INFO.Name;
        $logFileName = "${timeMarker}-${compName}-${userName}-${scriptName}.txt";
        $LogPath = Join-Path ($defaultLogDir) ($logFileName);
    }

    $resolvedLogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath);
    $logDirectory = [System.IO.Path]::GetDirectoryName($resolvedLogPath);
    if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not [System.IO.Directory]::Exists($logDirectory)) {
        [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null;
    }
    $script:ActiveLogFile = $resolvedLogPath;
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent();
    $principal = New-Object Security.Principal.WindowsPrincipal($identity);
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
}

function Assert-WingetPrerequisites {
    param ([string]$MinimumVersion = "1.7.0")

    $wingetCmd = Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue;
    $needsUpdate = $false;

    if (-not $wingetCmd) {
        Write-Log "[!] winget tool is not installed." Yellow;
        $needsUpdate = $true;
    }
    else {
        try {
            $rawVer = (& winget.exe --version 2>$null | Out-String).Trim().TrimStart('v');
            $parsedParts = $rawVer.Split('-')[0].Split('.');
            while ($parsedParts.Count -lt 2) { $parsedParts += "0"; }
            $installedVer = [version]($parsedParts -join '.');

            Write-Log "[i] Detected winget version: $rawVer" Gray;

            if ($installedVer -lt [version]$MinimumVersion) {
                Write-Log "[!] winget version ($rawVer) requires update (min. $MinimumVersion)..." Yellow;
                $needsUpdate = $true;
            }
        }
        catch {
            $needsUpdate = $true;
        }
    }

    if (-not $needsUpdate) {
        Write-Log "[+] winget environment is ready." Green;
        return;
    }

    Write-Log "[*] Installing winget updates and dependencies..." Cyan;
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

    try {
        if (-not (Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.201 -Force | Out-Null;
        }
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted;
        if (-not (Get-Module -ListAvailable -Name "Microsoft.WinGet.Client")) {
            Install-Module -Name "Microsoft.WinGet.Client" -Force -AllowClobber | Out-Null;
        }
        Import-Module -Name "Microsoft.WinGet.Client" -Force;
        Repair-WinGetPackageManager -Latest -Force;

        $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine);
        $userPath    = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User);
        $env:Path    = "$machinePath;$userPath";

        Write-Log "[+] winget was successfully updated." Green;
    }
    catch {
        throw "Failed to update winget: $_";
    }
}

function Install-OfficeFallback {
    Write-Log "    [!] Starting emergency procedure (Office Deployment Tool - x64)..." Yellow;

    $tempDir = Join-Path ($env:TEMP) "OfficeInstall";
    if (-not [System.IO.Directory]::Exists($tempDir)) {
        [System.IO.Directory]::CreateDirectory($tempDir) | Out-Null;
    }

    $setupExe = Join-Path ($tempDir) "setup.exe";
    $configXml = Join-Path ($tempDir) "configuration.xml";
    $directSetupUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe";

    $xmlContent = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="MatchOS" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
</Configuration>
"@;

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
        [System.IO.File]::WriteAllText($configXml, $xmlContent, [System.Text.Encoding]::UTF8);

        $webParams = @{
            Uri             = $directSetupUrl
            OutFile         = $setupExe
            UseBasicParsing = $true
        };
        Invoke-WebRequest @webParams;

        $officeProcParams = @{
            FilePath         = "setup.exe"
            WorkingDirectory = $tempDir
            ArgumentList     = "/configure `"$configXml`""
            Wait             = $true
            PassThru         = $true
        };
        $process = Start-Process @officeProcParams;

        if ($process.ExitCode -eq 0) {
            Write-Log "    [+] Success: Microsoft 365 Apps installed successfully." Green;
        }
        else {
            Write-Log "    [-] Office installer exited with code: $($process.ExitCode)" Yellow;
        }
    }
    catch {
        Write-Log "    [-] Error during Office fallback installation: $_" Red;
    }
    finally {
        if ([System.IO.Directory]::Exists($tempDir)) {
            try { [System.IO.Directory]::Delete($tempDir, $true); } catch {}
        }
    }
}

# --- Inventory & Matching Engine (.NET Registry API) ---

function Get-WindowsInstalledApplications {
    [CmdletBinding()]
    param ()

    $installedList = [System.Collections.Generic.List[PSCustomObject]]::new();

    $hives = @(
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry32; Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser;  View = [Microsoft.Win32.RegistryView]::Default;    Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" }
    );

    foreach ($target in $hives) {
        $baseKey = $null;
        $subKey  = $null;
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($target.Hive, $target.View);
            $subKey  = $baseKey.OpenSubKey($target.Path);

            if ($subKey) {
                foreach ($keyName in $subKey.GetSubKeyNames()) {
                    $appKey = $null;
                    try {
                        $appKey = $subKey.OpenSubKey($keyName);
                        if ($appKey) {
                            $rawDisplayName = $appKey.GetValue("DisplayName");
                            $displayName = if ($null -ne $rawDisplayName) { [string]$rawDisplayName } else { "" };

                            if (-not [string]::IsNullOrWhiteSpace($displayName)) {
                                $rawVer  = $appKey.GetValue("DisplayVersion");
                                $rawDate = $appKey.GetValue("InstallDate");
                                $rawLoc  = $appKey.GetValue("InstallLocation");
                                $rawIcon = $appKey.GetValue("DisplayIcon");
                                $rawPublisher = $appKey.GetValue("Publisher");
                                $rawSize = $appKey.GetValue("EstimatedSize");
                                
                                # Date formatting YYYYMMDD -> YYYY-MM-DD
                                $formattedDate = "No date entry in registry";
                                $installDateSort = $null;
                                if ($null -ne $rawDate) {
                                    $dStr = [string]$rawDate;
                                    if ($dStr -match '^\d{8}$') {
                                        $formattedDate = "$($dStr.Substring(0,4))-$($dStr.Substring(4,2))-$($dStr.Substring(6,2))";
                                        try { $installDateSort = [datetime]::ParseExact($dStr, "yyyyMMdd", [Globalization.CultureInfo]::InvariantCulture); } catch {}
                                    } elseif (-not [string]::IsNullOrWhiteSpace($dStr)) {
                                        $formattedDate = $dStr;
                                        $parsedDate = [datetime]::MinValue;
                                        if ([datetime]::TryParse($dStr, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                                            $installDateSort = $parsedDate;
                                        }
                                    }
                                }

                                $sizeMB = $null;
                                if ($null -ne $rawSize) {
                                    $sizeKB = 0.0;
                                    if ([double]::TryParse([string]$rawSize, [ref]$sizeKB) -and $sizeKB -gt 0) {
                                        $sizeMB = [math]::Round(($sizeKB / 1024), 2);
                                    }
                                }

                                # Installation path determination
                                $location = "";
                                if ($null -ne $rawLoc -and -not [string]::IsNullOrWhiteSpace([string]$rawLoc)) {
                                    $location = [string]$rawLoc;
                                } elseif ($null -ne $rawIcon -and -not [string]::IsNullOrWhiteSpace([string]$rawIcon)) {
                                    $iconClean = ([string]$rawIcon -split ',')[0].Trim(' "');
                                    if ([System.IO.File]::Exists($iconClean)) {
                                        $location = [System.IO.Path]::GetDirectoryName($iconClean);
                                    }
                                }

                                if (-not $location) {
                                    $location = "Default system / profile directory";
                                }

                                $installedList.Add([PSCustomObject]@{
                                    KeyName         = $keyName;
                                    DisplayName     = $displayName;
                                    DisplayVersion  = if ($null -ne $rawVer) { [string]$rawVer } else { "Version data unavailable" };
                                    Publisher       = if ($null -ne $rawPublisher -and -not [string]::IsNullOrWhiteSpace([string]$rawPublisher)) { [string]$rawPublisher } else { "Unknown publisher" };
                                    InstallDate     = $formattedDate;
                                    InstallDateSort = $installDateSort;
                                    SizeMB          = $sizeMB;
                                    Architecture    = if ($target.View -eq [Microsoft.Win32.RegistryView]::Registry32) { "32-bit" } else { "64-bit" };
                                    Scope           = if ($target.Hive -eq [Microsoft.Win32.RegistryHive]::CurrentUser) { "User" } else { "Machine" };
                                    InstallLocation = $location;
                                });
                            }
                        }
                    }
                    catch {}
                    finally {
                        if ($appKey) { $appKey.Close(); }
                    }
                }
            }
        }
        catch {}
        finally {
            if ($subKey)  { $subKey.Close(); }
            if ($baseKey) { $baseKey.Close(); }
        }
    }

    return $installedList;
}

function Find-InstalledApp {
    param (
        [string]$TargetName,
        [string]$TargetId,
        $SystemInventory
    )

    $cleanTargetName = ($TargetName -replace '\s*\([^)]*\)', '').Trim();

    # 1. Search in-memory registry inventory
    foreach ($item in $SystemInventory) {
        if (-not [string]::IsNullOrWhiteSpace($TargetId) -and $item.KeyName -eq $TargetId) {
            return $item;
        }

        if ($item.DisplayName -eq $TargetName) {
            return $item;
        }

        if ($item.DisplayName -like "$cleanTargetName*" -or ($cleanTargetName.Length -ge 4 -and $item.DisplayName -like "*$cleanTargetName*")) {
            return $item;
        }
    }

    # 2. Fallback query winget list for apps without standard ARP entries
    if (-not [string]::IsNullOrWhiteSpace($TargetId)) {
        try {
            $wOut = (& winget.exe list --exact --id $TargetId --accept-source-agreements 2>$null | Out-String).Trim();
            if ($wOut -and $wOut -notmatch "No installed" -and $wOut -notmatch "Nie znaleziono") {
                $lines = $wOut -split "[\r\n]+" | Where-Object {
                    $_ -match [regex]::Escape($TargetId) -and
                    $_ -notmatch '^-{3,}' -and
                    $_ -notmatch '^Name\s+Id\s+Version' -and
                    $_ -notmatch '^Nazwa\s+Identyfikator'
                };
                if ($lines.Count -gt 0) {
                    $row = ($lines[0] -replace '\s{2,}', '|').Trim();
                    $cols = $row -split '\|';
                    $wName = if ($cols.Count -ge 1) { $cols[0].Trim() } else { $TargetName };
                    $wVer  = if ($cols.Count -ge 3) { $cols[2].Trim() } elseif ($cols.Count -ge 2) { $cols[1].Trim() } else { "Current (winget)" };

                    return [PSCustomObject]@{
                        KeyName         = $TargetId;
                        DisplayName     = $wName;
                        DisplayVersion  = $wVer;
                        InstallDate     = "Installed via winget";
                        InstallLocation = "Standard application folder";
                    };
                }
            }
        }
        catch {}
    }

    return $null;
}

function Show-AppMetadata {
    param (
        [PSCustomObject]$Info,
        [string]$Header = "Installed package information:"
    )
    Write-Log "    ----------------------------------------------------------------" DarkGray;
    Write-Log "    $Header" DarkCyan;
    Write-Log "      * Application Name : $($Info.DisplayName)" Gray;
    Write-Log "      * Program Version  : $($Info.DisplayVersion)" Gray;
    Write-Log "      * Install Date     : $($Info.InstallDate)" Gray;
    Write-Log "      * Location         : $($Info.InstallLocation)" Gray;
    Write-Log "    ----------------------------------------------------------------" DarkGray;
}

function Invoke-UserContextInstall {
    param (
        [string]$AppId,
        [string]$AppName
    )
    Write-Log "    [!] Package $AppName requires installation in user profile." Yellow;
    Write-Log "        -> Starting task in logged-on user context..." Cyan;

    $loggedUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName;
    if (-not $loggedUser) { $loggedUser = [Environment]::UserName; }

    $taskName = "WinGet_UserInstall_" + ($AppId -replace '[^a-zA-Z0-9]', '_');
    $userArgs = "install --exact --id $AppId --scope user --silent --accept-package-agreements --accept-source-agreements";

    $actionParams = @{
        Execute  = "winget.exe"
        Argument = $userArgs
    };
    $action = New-ScheduledTaskAction @actionParams;

    $principalParams = @{
        UserId    = $loggedUser
        LogonType = "Interactive"
        RunLevel  = "Limited"
    };
    $principal = New-Object Microsoft.PowerShell.Commands.ScheduledTaskPrincipal @principalParams;

    $regParams = @{
        TaskName  = $taskName
        Action    = $action
        Principal = $principal
        Force     = $true
    };
    Register-ScheduledTask @regParams | Out-Null;

    $taskParams = @{ TaskName = $taskName };
    Start-ScheduledTask @taskParams;

    do {
        Start-Sleep -Seconds 2;
        $taskState = (Get-ScheduledTask @taskParams).State;
    } while ($taskState -eq 'Running')

    $taskInfo = Get-ScheduledTaskInfo @taskParams;
    Unregister-ScheduledTask @taskParams -Confirm:$false;

    return $taskInfo.LastTaskResult;
}

function Install-AppPackage {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$App,

        [Parameter(Mandatory = $true)]
        [int]$CurrentIndex,

        [Parameter(Mandatory = $true)]
        [int]$TotalCount,

        [Parameter(Mandatory = $true)]
        $SystemInventory,

        [Parameter(Mandatory = $false)]
        [switch]$EnableOfficeFallback
    )

    $prefix = "[$CurrentIndex/$TotalCount]";
    Write-Log "`n$prefix Verifying and preparing: $($App.Name) (ID: $($App.Id))..." Cyan;

    # 1. Check presence in indexed registry inventory
    $match = Find-InstalledApp ($App.Name) ($App.Id) ($SystemInventory);
    if ($null -ne $match) {
        Write-Log "    [V] Skipped: Application is already installed on system." Green;
        Show-AppMetadata ($match) ("Detected parameters of installed application:");
        return;
    }

    Write-Log "    [-] Application not found on system. Starting download and installation..." Yellow;

    # 2. Standard winget installation
    $installArgs = @(
        "install",
        "--exact",
        "--id", $App.Id,
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements"
    );

    try {
        $procParams = @{
            FilePath     = "winget.exe"
            ArgumentList = $installArgs
            NoNewWindow  = $true
            Wait         = $true
            PassThru     = $true
        };
        $process = Start-Process @procParams;

        if ($process.ExitCode -eq -1978335146) {
            $userResult = Invoke-UserContextInstall ($App.Id) ($App.Name);
            if ($userResult -eq 0 -or $userResult -eq -1978335189) {
                Write-Log "    [+] Successfully completed installation in user profile." Green;
            } else {
                Write-Log "    [-] User installer returned code: $userResult" Yellow;
            }
        }
        elseif ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) {
            Write-Log "    [+] Success: Installation of $($App.Name) completed successfully." Green;
        }
        elseif ($process.ExitCode -eq -1978335215) {
            Write-Log "    [-] Detected checksum mismatch in winget for $($App.Name)." Yellow;
            if ($App.Id -eq "Microsoft.Office" -or $App.Id -like "*Office*") {
                if ($EnableOfficeFallback) {
                    Write-Log "    [!] -Fallback flag active. Running emergency ODT procedure..." Cyan;
                    Install-OfficeFallback;
                } else {
                    Write-Log "    [!] Emergency ODT procedure disabled (no -Fallback parameter). Office installation aborted." Yellow;
                }
            }
        }
        else {
            Write-Log "    [-] Installer exit code for $($App.Name): $($process.ExitCode)" Yellow;
        }

        # 3. Refresh and show metadata directly after successful install
        $refreshedInventory = Get-WindowsInstalledApplications;
        $postMatch = Find-InstalledApp ($App.Name) ($App.Id) ($refreshedInventory);
        if ($null -ne $postMatch) {
            Show-AppMetadata ($postMatch) ("Details of newly installed application:");
        } else {
            Write-Log "    [i] Package registration state verified." Gray;
        }
    }
    catch {
        Write-Log "    Critical error during installation of $($App.Name): $_" Red;
    }
}

# --- WinGet Parsing & Output Engine ---

function Parse-WingetOutput {
    param ([string]$Raw)

    $items = [System.Collections.Generic.List[PSCustomObject]]::new();
    if ([string]::IsNullOrWhiteSpace($Raw)) { return @($items); }

    $lines = $Raw -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) };
    $headerIdx = -1;
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '\b(Name|Nazwa)\b' -and $lines[$i] -match '\b(Id|Identyfikator)\b') {
            $headerIdx = $i;
            break;
        }
    }

    if ($headerIdx -lt 0 -or ($headerIdx + 1) -ge $lines.Count) { return @($items); }

    $header = $lines[$headerIdx];
    $mId    = [regex]::Match($header, '\b(Id|Identyfikator)\b');
    $mVer   = [regex]::Match($header, '\b(Version|Wersja)\b');
    $mAvail = [regex]::Match($header, '\b(Available|Dostępne)\b');
    $mMatch = [regex]::Match($header, '\b(Match|Dopasowanie)\b');
    $mSrc   = [regex]::Match($header, '(?i)\bSource\b|\b.*r.*d.*o\b|\S+$');

    $idPos    = if ($mId.Success) { $mId.Index } else { 30 };
    $verPos   = if ($mVer.Success) { $mVer.Index } else { 60 };
    $availPos = if ($mAvail.Success) { $mAvail.Index } else { -1 };
    $matchPos = if ($mMatch.Success) { $mMatch.Index } else { -1 };
    $srcPos   = if ($mSrc.Success) { $mSrc.Index } else { -1 };

    for ($j = $headerIdx + 2; $j -lt $lines.Count; $j++) {
        $line = $lines[$j];
        if ($line -match '^-{3,}') { continue; }
        if ($line.Length -gt $idPos) {
            $name = $line.Substring(0, [math]::Min($idPos, $line.Length)).Trim();

            $id = if ($line.Length -gt $verPos) { $line.Substring($idPos, $verPos - $idPos).Trim() } else { $line.Substring($idPos).Trim() };

            $colAfterVer = -1;
            if ($availPos -gt $verPos) { $colAfterVer = $availPos; }
            elseif ($matchPos -gt $verPos) { $colAfterVer = $matchPos; }
            elseif ($srcPos -gt $verPos) { $colAfterVer = $srcPos; }

            $ver = if ($colAfterVer -gt 0 -and $line.Length -gt $colAfterVer) {
                $line.Substring($verPos, $colAfterVer - $verPos).Trim();
            } elseif ($line.Length -gt $verPos) {
                $line.Substring($verPos).Trim();
            } else { ""; };

            $avail = "";
            if ($availPos -gt 0 -and $line.Length -gt $availPos) {
                $availEnd = if ($srcPos -gt $availPos) { $srcPos } else { $line.Length };
                $avail = if ($line.Length -gt $availEnd) { $line.Substring($availPos, $availEnd - $availPos).Trim() } else { $line.Substring($availPos).Trim() };
            }

            $matchVal = "";
            if ($matchPos -gt 0 -and $line.Length -gt $matchPos) {
                $matchEnd = if ($srcPos -gt $matchPos) { $srcPos } else { $line.Length };
                $matchVal = if ($line.Length -gt $matchEnd) { $line.Substring($matchPos, $matchEnd - $matchPos).Trim() } else { $line.Substring($matchPos).Trim() };
            }

            $src = if ($srcPos -gt 0 -and $line.Length -gt $srcPos) { $line.Substring($srcPos).Trim() } else { ""; };

            if (-not [string]::IsNullOrWhiteSpace($id)) {
                $items.Add([PSCustomObject]@{
                    Name      = $name;
                    Id        = $id;
                    Version   = $ver;
                    Available = $avail;
                    Match     = $matchVal;
                    Source    = $src;
                });
            }
        }
    }
    return @($items);
}

function Search-WingetCatalog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Query,
        [switch]$ExactId,
        [switch]$ExactName
    )

    $cmdArgs = @("search", "--accept-source-agreements");
    if ($ExactId) {
        $cmdArgs += @("--exact", "--id", $Query);
    } elseif ($ExactName) {
        $cmdArgs += @("--exact", "--name", $Query);
    } else {
        $cmdArgs += $Query;
    }

    try {
        $raw = (& winget.exe @cmdArgs 2>&1 | Out-String);
        return @(Parse-WingetOutput -Raw $raw);
    }
    catch {
        return @();
    }
}

function Get-WingetAvailableUpgrades {
    try {
        $raw = (& winget.exe upgrade --accept-source-agreements 2>&1 | Out-String);
        return @(Parse-WingetOutput -Raw $raw);
    }
    catch {
        return @();
    }
}

function Invoke-ApplicationsUpgrade {
    param (
        [string]$TargetPackage
    )

    try { Clear-Host; } catch {}
    Write-Log "================================================================================" Cyan;
    Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - Workstation Software Upgrade" Cyan;
    Write-Log "  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)" Gray;
    Write-Log "  Log File: $resolvedLogPath" DarkCyan;
    Write-Log "================================================================================" Cyan;

    Write-Log "[*] Checking for available software upgrades via winget..." Gray;
    $upgrades = @(Get-WingetAvailableUpgrades);

    if ($upgrades.Count -eq 0) {
        Write-Log "[+] All installed applications are up to date. No upgrades available." Green;
        return;
    }

    Write-Log "[*] Found $($upgrades.Count) application(s) with available upgrades:" Cyan;
    $summaryTable = $upgrades |
        Format-Table `
            @{Label = "Application"; Expression = { $_.Name }; Width = 40}, `
            @{Label = "Package ID"; Expression = { $_.Id }; Width = 36}, `
            @{Label = "Current Version"; Expression = { $_.Version }; Width = 18}, `
            @{Label = "Available Version"; Expression = { $_.Available }; Width = 18} `
        -Wrap -AutoSize | Out-String -Width 120;
    Write-Log $summaryTable.TrimEnd() Gray;

    # If user specified a specific package to upgrade
    if (-not [string]::IsNullOrWhiteSpace($TargetPackage)) {
        $filtered = @($upgrades | Where-Object {
            $_.Id -ieq $TargetPackage -or
            $_.Name -ieq $TargetPackage -or
            $_.Id -like "*$TargetPackage*" -or
            $_.Name -like "*$TargetPackage*"
        });

        if ($filtered.Count -eq 0) {
            Write-Log "[i] No available upgrades found matching target '$TargetPackage'." Yellow;
            Write-Log "    The package might already be up to date or is not installed via winget." Gray;
            return;
        }

        if ($filtered.Count -gt 1 -and -not ($filtered | Where-Object { $_.Id -ieq $TargetPackage -or $_.Name -ieq $TargetPackage })) {
            Write-Log "[!] Multiple upgrade candidates match '$TargetPackage'. Please specify exact Id:" Yellow;
            foreach ($cand in $filtered) {
                Write-Log "    * $($cand.Name) (Id: $($cand.Id))" Gray;
            }
            return;
        }

        $targetObj = if ($filtered.Count -eq 1) { $filtered[0] } else { ($filtered | Where-Object { $_.Id -ieq $TargetPackage -or $_.Name -ieq $TargetPackage })[0] };
        $toUpgradeList = @($targetObj);
    } else {
        $toUpgradeList = $upgrades;
    }

    if (-not (Test-IsAdmin)) {
        throw "Script requires administrator privileges to upgrade software. Run PowerShell as Administrator.";
    }

    Assert-WingetPrerequisites "1.7.0";

    $total = $toUpgradeList.Count;
    Write-Log "`nStarting upgrade process for $total package(s)...`n" DarkCyan;

    $idx = 0;
    foreach ($pkg in $toUpgradeList) {
        $idx++;
        $prefix = "[$idx/$total]";
        Write-Log "$prefix Upgrading: $($pkg.Name) (ID: $($pkg.Id))..." Cyan;
        Write-Log "    Current: $($pkg.Version) -> Latest: $($pkg.Available)" Gray;

        $percentComplete = [math]::Round(((($idx - 1) / $total) * 100));
        Write-Progress -Activity "Windows Workstation Software Upgrade" `
                       -Status "Upgrading ($idx of $total): $($pkg.Name)" `
                       -PercentComplete $percentComplete;

        $upgradeArgs = @(
            "upgrade",
            "--exact",
            "--id", $pkg.Id,
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements"
        );

        try {
            $procParams = @{
                FilePath     = "winget.exe"
                ArgumentList = $upgradeArgs
                NoNewWindow  = $true
                Wait         = $true
                PassThru     = $true
            };
            $process = Start-Process @procParams;

            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) {
                Write-Log "    [+] Success: Upgrade of $($pkg.Name) completed successfully." Green;
            }
            elseif ($process.ExitCode -eq -1978335146) {
                # User-context fallback if elevated admin rejected
                $userResult = Invoke-UserContextInstall ($pkg.Id) ($pkg.Name);
                if ($userResult -eq 0 -or $userResult -eq -1978335189) {
                    Write-Log "    [+] Successfully completed upgrade in user profile." Green;
                } else {
                    Write-Log "    [-] User installer returned code: $userResult" Yellow;
                }
            }
            else {
                Write-Log "    [-] Upgrade exit code for $($pkg.Name): $($process.ExitCode)" Yellow;
            }
        }
        catch {
            Write-Log "    [-] Critical error during upgrade of $($pkg.Name): $_" Red;
        }
    }

    Write-Progress -Activity "Windows Workstation Software Upgrade" -Completed;

    Write-Log "`n================================================================================" Green;
    Write-Log "  [+] Upgrade procedure completed for $total package(s)." Green;
    Write-Log "  [+] Execution report saved to: $resolvedLogPath" Green;
    Write-Log "================================================================================" Green;
}

function Invoke-SinglePackageInstall {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageQuery
    )

    try { Clear-Host; } catch {}
    Write-Log "================================================================================" Cyan;
    Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - Single Package Installation" Cyan;
    Write-Log "  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)" Gray;
    Write-Log "  Log File: $resolvedLogPath" DarkCyan;
    Write-Log "  ODT Fallback  : $(if ($Fallback) { 'ENABLED' } else { 'DISABLED (default)' })" $(if ($Fallback) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray });
    Write-Log "================================================================================" Cyan;

    if (-not (Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue)) {
        throw "winget.exe is not available on this system.";
    }

    Write-Log "[*] Resolving package in winget repositories: '$PackageQuery'..." Gray;

    # 1. Try exact ID match
    $exactIdMatches = @(Search-WingetCatalog -Query $PackageQuery -ExactId);
    $targetPackage = $null;

    if ($exactIdMatches.Count -eq 1) {
        $targetPackage = $exactIdMatches[0];
        Write-Log "[+] Found exact package ID match: $($targetPackage.Name) ($($targetPackage.Id))" Green;
    }

    # 2. Try exact Name match if not resolved by ID
    if ($null -eq $targetPackage) {
        $exactNameMatches = @(Search-WingetCatalog -Query $PackageQuery -ExactName);
        if ($exactNameMatches.Count -eq 1) {
            $targetPackage = $exactNameMatches[0];
            Write-Log "[+] Found exact package Name match: $($targetPackage.Name) ($($targetPackage.Id))" Green;
        }
    }

    # 3. If still not resolved, perform broad search
    if ($null -eq $targetPackage) {
        $broadMatches = @(Search-WingetCatalog -Query $PackageQuery);

        # Check if any broad match has exact case-insensitive match on Id or Name
        $caseInsensitiveMatch = @($broadMatches | Where-Object { $_.Id -ieq $PackageQuery -or $_.Name -ieq $PackageQuery });
        if ($caseInsensitiveMatch.Count -eq 1) {
            $targetPackage = $caseInsensitiveMatch[0];
            Write-Log "[+] Resolved matching package: $($targetPackage.Name) ($($targetPackage.Id))" Green;
        }
        elseif ($broadMatches.Count -eq 1) {
            $targetPackage = $broadMatches[0];
            Write-Log "[+] Resolved single matching package: $($targetPackage.Name) ($($targetPackage.Id))" Green;
        }
        elseif ($broadMatches.Count -eq 0) {
            Write-Log "[-] Nie znaleziono żadnego pakietu odpowiadającego: '$PackageQuery'." Yellow;
            Write-Log "    Upewnij się, że nazwa jest poprawna lub użyj -Search `"$PackageQuery`" aby przeszukać katalog online." Gray;
            return;
        }
        else {
            # Multiple candidates found - prompt user to clarify
            Write-Log "`n[!] Nie znaleziono jednoznacznego pakietu dla: '$PackageQuery'" Yellow;
            Write-Log "[!] Znaleziono $($broadMatches.Count) pasujących pakietów. Proszę doprecyzować wybór:`n" Yellow;

            $candidateTable = $broadMatches |
                Format-Table `
                    @{Label = "Application"; Expression = { $_.Name }; Width = 38}, `
                    @{Label = "Package ID"; Expression = { $_.Id }; Width = 38}, `
                    @{Label = "Version"; Expression = { $_.Version }; Width = 16}, `
                    @{Label = "Match"; Expression = { $_.Match }; Width = 20}, `
                    @{Label = "Source"; Expression = { $_.Source }; Width = 8} `
                -Wrap -AutoSize | Out-String -Width 130;
            Write-Host $candidateTable.TrimEnd() -ForegroundColor Gray;

            Write-Log "`n[*] Aby zainstalować wybrany pakiet, uruchom ponownie skrypt podając dokładny identyfikator (Id):" Cyan;
            Write-Log "    .\Install-Applications.ps1 -Install <PackageId>" White;
            Write-Log "    Przykład: .\Install-Applications.ps1 -Install `"$($broadMatches[0].Id)`"`n" DarkCyan;
            return;
        }
    }

    # Scan local registry inventory to check if package is already present
    Write-Log "[*] Scanning installed software (.NET Registry API)..." Gray;
    $systemInventory = Get-WindowsInstalledApplications;

    $match = Find-InstalledApp ($targetPackage.Name) ($targetPackage.Id) ($systemInventory);
    if ($null -ne $match) {
        Write-Log "    [V] Skipped: Application '$($targetPackage.Name)' is already installed on system." Green;
        Show-AppMetadata ($match) ("Detected parameters of installed application:");
        return;
    }

    # Verify admin privileges and prerequisites before making system changes
    if (-not (Test-IsAdmin)) {
        throw "Script requires administrator privileges to install software. Run PowerShell as Administrator.";
    }

    Assert-WingetPrerequisites "1.7.0";

    $appObj = [PSCustomObject]@{
        Name = $targetPackage.Name
        Id   = $targetPackage.Id
    };

    $callArgs = @{
        App                  = $appObj
        CurrentIndex         = 1
        TotalCount           = 1
        SystemInventory      = $systemInventory
        EnableOfficeFallback = $Fallback
    };
    Install-AppPackage @callArgs;

    Write-Log "`n================================================================================" Green;
    Write-Log "  [+] Process completed for $($targetPackage.Name)." Green;
    Write-Log "  [+] Execution report saved to: $resolvedLogPath" Green;
    Write-Log "================================================================================" Green;
}

function Invoke-OnlineCatalogSearch {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    if (-not (Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue)) {
        throw "winget.exe is not available on this system.";
    }

    Write-Host "`n[*] Przeszukiwanie internetowego repozytorium winget dla wzorca: '$Pattern'..." -ForegroundColor Cyan;
    $searchResults = @(Search-WingetCatalog -Query $Pattern);

    if ($searchResults.Count -eq 0) {
        Write-Host "[-] Nie znaleziono żadnych pakietów pasujących do wzorca '$Pattern'." -ForegroundColor Yellow;
        return;
    }

    Write-Host "[+] Znaleziono $($searchResults.Count) pakietów:" -ForegroundColor Green;

    $tableText = $searchResults |
        Format-Table `
            @{Label = "Application"; Expression = { $_.Name }; Width = 38}, `
            @{Label = "Package ID"; Expression = { $_.Id }; Width = 38}, `
            @{Label = "Version"; Expression = { $_.Version }; Width = 16}, `
            @{Label = "Match"; Expression = { $_.Match }; Width = 22}, `
            @{Label = "Source"; Expression = { $_.Source }; Width = 8} `
        -Wrap -AutoSize | Out-String -Width 130;

    Write-Host $tableText.TrimEnd();

    Write-Host "`n[*] Aby zainstalować wybrany pakiet, użyj polecenia:" -ForegroundColor Cyan;
    Write-Host "    .\Install-Applications.ps1 -Install <PackageId>" -ForegroundColor White;
    Write-Host "    Przykład: .\Install-Applications.ps1 -Install `"$($searchResults[0].Id)`"`n" -ForegroundColor DarkCyan;

    # If log path was specified, save the search report
    if ($PSBoundParameters.ContainsKey("LogPath")) {
        if ([string]::IsNullOrWhiteSpace($LogPath)) {
            $defaultLogDir = "C:\Logs";
            $timeMarker = (Get-Date).ToString("yyyyMMdd_HHmmss");
            $compName = $env:COMPUTERNAME;
            $userName = $env:USERNAME;
            $reportFileName = "${timeMarker}-${compName}-${userName}-$($SCRIPT_INFO.Name)-search-${Pattern}.txt";
            $resolvedReportPath = Join-Path $defaultLogDir $reportFileName;
        } else {
            $resolvedReportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath);
        }

        $reportDirectory = [System.IO.Path]::GetDirectoryName($resolvedReportPath);
        if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not [System.IO.Directory]::Exists($reportDirectory)) {
            [System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null;
        }
        $fullReport = "Online search results for pattern: '$Pattern'`r`nTotal packages: $($searchResults.Count)`r`n`r`n" + $tableText;
        [System.IO.File]::WriteAllText($resolvedReportPath, $fullReport, [System.Text.Encoding]::UTF8);
        Write-Host "Search report saved to: $resolvedReportPath" -ForegroundColor Cyan;
    }
}

# --- Main Program Flow ---

# 1. Verification/Audit mode (-VerifyInstalledApps, -v)
if ($VerifyInstalledApps) {
    $systemInventory = Get-WindowsInstalledApplications;
    if ($systemInventory.Count -eq 0) {
        Write-Host "No installed applications found in inspected registry hives." -ForegroundColor Yellow;
        return;
    }

    $reportLines = [System.Collections.Generic.List[string]]::new();
    $reportLines.Add("Installed applications: $($systemInventory.Count)");
    foreach ($publisherGroup in ($systemInventory | Group-Object -Property Publisher | Sort-Object -Property Name)) {
        $reportLines.Add("");
        $reportLines.Add("=== $($publisherGroup.Name) ===");
        $summaryTable = $publisherGroup.Group |
            Sort-Object -Property InstallDateSort -Descending |
            Format-Table `
                @{Label = "Application"; Expression = { $_.DisplayName }; Width = 46}, `
                @{Label = "Version"; Expression = { $_.DisplayVersion }; Width = 28}, `
                @{Label = "Installed"; Expression = { if ($_.InstallDateSort) { $_.InstallDateSort.ToString("yyyy-MM-dd") } elseif ($_.InstallDate -eq "No date entry in registry") { "Unavailable" } else { $_.InstallDate } }; Width = 12} `
            -Wrap -AutoSize | Out-String -Width 120;
        $reportLines.Add($summaryTable.TrimEnd());

        $locationTable = $publisherGroup.Group |
            Sort-Object -Property InstallDateSort -Descending |
            Format-Table `
                @{Label = "Application"; Expression = { $_.DisplayName }; Width = 36}, `
                @{Label = "Arch / Scope / MB"; Expression = { "$($_.Architecture) / $($_.Scope) / $(if ($null -ne $_.SizeMB) { "$($_.SizeMB) MB" } else { 'n/a' })" }; Width = 26}, `
                @{Label = "Install Location"; Expression = { $_.InstallLocation }; Width = 56} `
            -Wrap -AutoSize | Out-String -Width 120;
        $reportLines.Add($locationTable.TrimEnd());
    }

    $reportText = $reportLines -join [Environment]::NewLine;
    Write-Host $reportText;

    if ($PSBoundParameters.ContainsKey("LogPath")) {
        if ([string]::IsNullOrWhiteSpace($LogPath)) {
            $defaultLogDir = "C:\Logs";
            $timeMarker = (Get-Date).ToString("yyyyMMdd_HHmmss");
            $compName = $env:COMPUTERNAME;
            $userName = $env:USERNAME;
            $reportFileName = "${timeMarker}-${compName}-${userName}-$($SCRIPT_INFO.Name)-installedApplications.txt";
            $resolvedReportPath = Join-Path $defaultLogDir $reportFileName;
        } else {
            $resolvedReportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath);
        }

        $reportDirectory = [System.IO.Path]::GetDirectoryName($resolvedReportPath);
        if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not [System.IO.Directory]::Exists($reportDirectory)) {
            [System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null;
        }
        [System.IO.File]::WriteAllText($resolvedReportPath, $reportText + [Environment]::NewLine, [System.Text.Encoding]::UTF8);
        Write-Host "`nReport saved to: $resolvedReportPath" -ForegroundColor Cyan;
    }
    return;
}

# 2. Online search mode (-Search, -s)
if (-not [string]::IsNullOrWhiteSpace($Search)) {
    Invoke-OnlineCatalogSearch -Pattern $Search;
    return;
}

# 3. Upgrade mode (-Upgrade, -u)
if ($Upgrade) {
    Invoke-ApplicationsUpgrade -TargetPackage $UpgradeTarget;
    return;
}

# 4. Single package install mode (-Install, -Package, -i)
if (-not [string]::IsNullOrWhiteSpace($Install)) {
    Invoke-SinglePackageInstall -PackageQuery $Install;
    return;
}

# 5. Batch installation mode from JSON configuration file (-ConfigPath)
try { Clear-Host; } catch {}
Write-Log "================================================================================" Cyan;
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - Environment Initialization" Cyan;
Write-Log "  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)" Gray;
Write-Log "  Log File: $resolvedLogPath" DarkCyan;
Write-Log "  ODT Fallback  : $(if ($Fallback) { 'ENABLED' } else { 'DISABLED (default)' })" $(if ($Fallback) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray });
Write-Log "================================================================================" Cyan;

if (-not (Test-IsAdmin)) {
    throw "Script requires administrator privileges. Run PowerShell as Administrator.";
}

# 1. Verify winget environment
Assert-WingetPrerequisites "1.7.0";

# 2. Load configuration from JSON file
try {
    Write-Log "[i] Loading configuration from: $ConfigPath" Gray;
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ConfigPath);
    $jsonRaw = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8);
    $applications = $jsonRaw | ConvertFrom-Json;
}
catch {
    throw "Error reading or parsing JSON file: $_";
}

if ($null -eq $applications -or $applications.Count -eq 0) {
    Write-Log "Specified JSON file is empty. Exiting script." Yellow;
    return;
}

# 3. Scan Windows registry in RAM (.NET API)
Write-Log "[*] Scanning installed software (.NET Registry API)..." Gray;
$systemInventory = Get-WindowsInstalledApplications;
Write-Log "[+] Indexed $($systemInventory.Count) installed entries in registry." Green;

$totalApps = [int]$applications.Count;
Write-Log "`nFound $totalApps items to verify and install." DarkCyan;
Write-Log "Starting installation process...`n" DarkCyan;

# 4. Process packages in loop
$currentIndex = 0;

foreach ($app in $applications) {
    $currentIndex++;

    if (-not ($app.PSObject.Properties['Id'] -and $app.PSObject.Properties['Name'])) {
        Write-Log "Skipped invalid JSON entry (required fields: 'Id', 'Name')." Yellow;
        continue;
    }

    $percentComplete = [math]::Round(((($currentIndex - 1) / $totalApps) * 100));
    $progParams = @{
        Activity        = "Windows Workstation Software Deployment"
        Status          = "Processing ($currentIndex of $totalApps): $($app.Name)"
        PercentComplete = $percentComplete
    };
    Write-Progress @progParams;

    $callArgs = @{
        App                  = $app
        CurrentIndex         = [int]$currentIndex
        TotalCount           = [int]$totalApps
        SystemInventory      = $systemInventory
        EnableOfficeFallback = $Fallback
    };
    Install-AppPackage @callArgs;
}

Write-Progress -Activity "Windows Workstation Software Deployment" -Completed;

Write-Log "`n================================================================================" Green;
Write-Log "  [+] Completed checking all packages ($totalApps/$totalApps)." Green;
Write-Log "  [+] Execution report saved to: $resolvedLogPath" Green;
Write-Log "================================================================================" Green;
Write-Log "Author contact: $($SCRIPT_INFO.Contact)`n" Gray;