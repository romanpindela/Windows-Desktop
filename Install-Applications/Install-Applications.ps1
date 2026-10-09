<#
================================================================================
  Script Name : Install-Applications.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  Version     : 1.9.9
  Release Date: 2026-10-04
  License     : MIT
  Repository  : https://github.com/roman/install-applications

  DESCRIPTION:
    Automates workstation software installation and configuration in Windows
    (x64 architecture) based on winget and a JSON configuration file.
    Utilizes native .NET Registry API for fast in-memory auditing and retrieval
    of installed application metadata (DisplayName, DisplayVersion,
    InstallDate, InstallLocation). Skips programs already present on the system
    and supports user-profile fallback (non-admin execution for apps like Spotify).
    The emergency Office Deployment Tool (ODT) procedure for Microsoft 365
    is executed ONLY when the user explicitly provides the -Fallback switch.
    Includes comprehensive execution logging to a file.

================================================================================
.SYNOPSIS
    Automatically retrieves, audits, and installs applications from a JSON file using winget.
.PARAMETER ConfigPath
    Path to the JSON file containing the list of software packages to install.
.PARAMETER LogPath
    Path to the installation log or installed applications report.
    In report mode, an empty value (-l "") saves the report under a default name
    with the suffix -installedApplications.txt.
.PARAMETER Fallback
    Allows fallback to the Office Deployment Tool (ODT) procedure for Microsoft 365
    in case of winget checksum mismatch errors. Disabled by default.
.PARAMETER VerifyInstalledApps
    Displays installed programs grouped by publisher and sorted by install date.
.PARAMETER Help
    Displays detailed help menu, version, and author information.
.EXAMPLE
    .\Install-Applications.ps1 -ConfigPath .\ApplicationList-Roman.json
.EXAMPLE
    .\Install-Applications.ps1 -ConfigPath .\ApplicationList.json -Fallback
.EXAMPLE
    .\Install-Applications.ps1 -VerifyInstalledApps
.EXAMPLE
    .\Install-Applications.ps1 -v -l ""
.EXAMPLE
    .\Install-Applications.ps1 -h
#>
[CmdletBinding(DefaultParameterSetName = "Install")]
param (
    [Parameter(ParameterSetName = "Install", Position = 0)]
    [Alias("c", "Path")]
    [ValidateScript({
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_);
        if ([System.IO.File]::Exists($resolved)) { $true }
        else { throw "Configuration file does not exist at specified path: $_" }
    })]
    [string]$ConfigPath,

    [Parameter(ParameterSetName = "Install", Position = 1)]
    [Parameter(ParameterSetName = "Verify")]
    [Alias("l", "Log")]
    [string]$LogPath,

    [Parameter(ParameterSetName = "Install")]
    [Alias("fo", "FallbackOffice")]
    [switch]$Fallback,

    [Parameter(ParameterSetName = "Verify")]
    [Alias("v")]
    [switch]$VerifyInstalledApps,

    [Parameter(ParameterSetName = "Help")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";

$SCRIPT_INFO = @{
    Name        = "Install-Applications";
    Version     = "1.9.9";
    Author      = "Roman Pindela";
    Contact     = "roman.pindela@gmail.com";
    ReleaseDate = "2026-10-04";
};

# Global variable holding active log file path
$script:ActiveLogFile = $null;

function Write-Log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    [Console]::CursorLeft = 0;
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
    [Console]::CursorLeft = 0;
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)
================================================================================
DESCRIPTION:
  Automated Windows x64 workstation deployment tool featuring complete
  in-memory registry auditing and structured activity logging.

USAGE:
  .\Install-Applications.ps1 -ConfigPath <path_to_file.json> [-LogPath <path_to_log.txt>] [-Fallback]
  .\Install-Applications.ps1 -VerifyInstalledApps [-LogPath <path_to_report.txt>]
  .\Install-Applications.ps1 -v [-l ""]
  .\Install-Applications.ps1 -h | -Help

PARAMETERS:
  -ConfigPath, -c, -Path : [Required] Path to JSON file with package configurations.
  -LogPath, -l, -Log     : [Optional] Path to installation log file. With -v, saves
                           the report; -v -l "" selects default name ending with
                           -installedApplications.txt.
  -Fallback, -fo         : [Optional] Enables emergency ODT procedure for Office 365
                           in case of winget checksum mismatch. Without this flag,
                           the emergency procedure is skipped.
  -VerifyInstalledApps, -v : Displays installed programs grouped by publisher,
                             sorted by installation date.
  -Help, -h              : Displays this help menu and author info.

EXAMPLES:
  .\Install-Applications.ps1 -h
  .\Install-Applications.ps1 -ConfigPath .\ApplicationList-Roman.json
  .\Install-Applications.ps1 -c .\ApplicationList.json -Fallback
  .\Install-Applications.ps1 -v
  .\Install-Applications.ps1 -v -l ""
  .\Install-Applications.ps1 -v -l "C:\Reports\InstalledApps.txt"
  .\Install-Applications.ps1 .\ApplicationList.json -LogPath "C:\Deploy\log.txt"
================================================================================
"@ -ForegroundColor Yellow;
}

if ($Help -or ([string]::IsNullOrWhiteSpace($ConfigPath) -and -not $VerifyInstalledApps)) {
    Show-HelpGuide;
    return;
}

# Initialize default log path if not provided
if (-not $VerifyInstalledApps) {
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

# --- Main Program Flow ---

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

Clear-Host;
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