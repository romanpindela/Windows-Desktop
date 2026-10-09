<#
================================================================================
  Script Name : enable-hibernation.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  Version     : 1.1.1
  Release Date: 2026-10-08
  License     : MIT
  Repository  : https://github.com/roman/enable-hibernation

  DESCRIPTION:
    Enables full management of the Windows hibernation subsystem and controls
    the visibility of the Hibernate option in the Start Menu power options (Windows 10/11 x64).
    Supports enabling (allocates hiberfil.sys, configures FlyoutMenuSettings registry entry)
    and disabling (deletes hiberfil.sys, hides Hibernate in the Start Menu).
    Running without parameters displays the help menu with version and author info.

================================================================================
.SYNOPSIS
    Enables or disables system hibernation and Start menu power visibility.
.PARAMETER EnableHibernation
    Allocates hiberfil.sys and adds Hibernate to Start menu power options.
.PARAMETER DisableHibernation
    Removes hiberfil.sys, frees disk space, and hides Hibernate in Start menu.
.PARAMETER LogPath
    Path to a text file for detailed execution logging.
    Default: C:\Logs\<yyyyMMdd_HHmmss>-<ComputerName>-<UserName>-Enable-Hibernation.txt
.PARAMETER Help
    Displays detailed help menu and author info.
.EXAMPLE
    .\enable-hibernation.ps1
.EXAMPLE
    .\enable-hibernation.ps1 -EnableHibernation
.EXAMPLE
    .\enable-hibernation.ps1 -DisableHibernation
.EXAMPLE
    .\enable-hibernation.ps1 -EnableHibernation -LogPath "C:\Logs\hibernation.txt"
.EXAMPLE
    .\enable-hibernation.ps1 -h
#>
[CmdletBinding(DefaultParameterSetName = "Default")]
param (
    [Parameter(ParameterSetName = "Enable")]
    [Alias("e", "Enable")]
    [switch]$EnableHibernation,

    [Parameter(ParameterSetName = "Disable")]
    [Alias("d", "Disable")]
    [switch]$DisableHibernation,

    [Parameter(ParameterSetName = "Enable")]
    [Parameter(ParameterSetName = "Disable")]
    [Alias("l", "Log")]
    [string]$LogPath,

    [Parameter(ParameterSetName = "Help")]
    [Parameter(ParameterSetName = "Default")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";

$SCRIPT_INFO = @{
    Name        = "Enable-Hibernation";
    Version     = "1.1.1";
    Author      = "Roman Pindela";
    Contact     = "roman.pindela@gmail.com";
    ReleaseDate = "2026-10-08";
};

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
  Automated Windows power management configurator to enable or disable
  full hibernation and toggle its visibility in the Start Menu power options.

USAGE:
  .\enable-hibernation.ps1 -EnableHibernation [-LogPath <path_to_log.txt>]
  .\enable-hibernation.ps1 -DisableHibernation [-LogPath <path_to_log.txt>]
  .\enable-hibernation.ps1 -h | -Help

PARAMETERS:
  -EnableHibernation, -e  : Enables hibernation in system and Start menu.
  -DisableHibernation, -d : Disables hibernation, deletes hiberfil.sys, and hides in menu.
  -LogPath, -l, -Log      : [Optional] Path to text log file.
                            Default: C:\Logs\<DateTime>-<Host>-<User>-Enable-Hibernation.txt
  -Help, -h               : Displays this help menu and author info.

EXAMPLES:
  .\enable-hibernation.ps1
  .\enable-hibernation.ps1 -h
  .\enable-hibernation.ps1 -EnableHibernation
  .\enable-hibernation.ps1 -DisableHibernation
  .\enable-hibernation.ps1 -e -LogPath "C:\Deploy\hibernation_setup.txt"
================================================================================
"@ -ForegroundColor Yellow;
}

# If help invoked or executed without action parameters
if ($Help -or (-not $EnableHibernation -and -not $DisableHibernation)) {
    Show-HelpGuide;
    return;
}

# Initialize log path
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

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent();
    $principal = New-Object Security.Principal.WindowsPrincipal($identity);
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
}

function Set-PowercfgHibernationState {
    param ([bool]$Enable)

    $stateWord = if ($Enable) { "on" } else { "off" };
    $stateDesc = if ($Enable) { "Activating" } else { "Deactivating" };

    Write-Log "[1/3] $stateDesc hibernation subsystem (powercfg /hibernate $stateWord)..." Cyan;

    try {
        $pcfgParams = @{
            FilePath     = "$env:windir\System32\powercfg.exe"
            ArgumentList = "/hibernate $stateWord"
            NoNewWindow  = $true
            Wait         = $true
            PassThru     = $true
        };
        $proc = Start-Process @pcfgParams;

        if ($proc.ExitCode -eq 0) {
            if ($Enable) {
                Write-Log "    [+] hiberfil.sys and ACPI support successfully enabled." Green;
            } else {
                Write-Log "    [+] Hibernation subsystem disabled; hiberfil.sys removed from disk." Green;
            }
        }
        else {
            Write-Log "    [-] powercfg exited with error code: $($proc.ExitCode)" Yellow;
        }
    }
    catch {
        Write-Log "    [-] Critical error while invoking powercfg: $_" Red;
        throw $_;
    }
}

function Set-StartMenuHibernateVisibility {
    param ([int]$TargetValue)

    Write-Log "[2/3] Configuring Explorer FlyoutMenuSettings registry entry (Value: $TargetValue)..." Cyan;

    $registryHivePath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings";
    $baseKey = $null;
    $subKey  = $null;

    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64);
        $subKey  = $baseKey.OpenSubKey($registryHivePath, $true);

        if ($null -eq $subKey) {
            Write-Log "    [*] Creating missing FlyoutMenuSettings key in HKLM registry..." DarkGray;
            $subKey = $baseKey.CreateSubKey($registryHivePath);
        }

        $currentVal = $subKey.GetValue("ShowHibernateOption");
        if ($null -ne $currentVal -and [int]$currentVal -eq $TargetValue) {
            Write-Log "    [V] Skipped: ShowHibernateOption already contains desired value ($TargetValue)." Green;
        }
        else {
            $subKey.SetValue("ShowHibernateOption", $TargetValue, [Microsoft.Win32.RegistryValueKind]::DWord);
            Write-Log "    [+] Success: Set ShowHibernateOption = $TargetValue (DWORD)." Green;
        }
    }
    catch {
        Write-Log "    [-] Windows registry modification error: $_" Red;
        throw $_;
    }
    finally {
        if ($null -ne $subKey)  { $subKey.Close(); }
        if ($null -ne $baseKey) { $baseKey.Close(); }
    }
}

function Show-HibernationStatusSummary {
    param ([bool]$TargetEnabled)

    Write-Log "[3/3] Verifying final power subsystem state..." Cyan;

    $regVal  = $null;
    $baseKey = $null;
    $subKey  = $null;
    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64);
        $subKey  = $baseKey.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings");
        if ($null -ne $subKey) {
            $regVal = $subKey.GetValue("ShowHibernateOption");
        }
    }
    catch {}
    finally {
        if ($null -ne $subKey)  { $subKey.Close(); }
        if ($null -ne $baseKey) { $baseKey.Close(); }
    }

    $systemDrive = $env:SystemDrive;
    $hiberFilePath = Join-Path ($systemDrive) "hiberfil.sys";
    $hiberExists = [System.IO.File]::Exists($hiberFilePath);

    $stateText = if ($TargetEnabled) { "ACTIVE (VISIBLE)" } else { "INACTIVE (HIDDEN)" };
    $stateColor = if ($TargetEnabled) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow };

    Write-Log "    ----------------------------------------------------------------" DarkGray;
    Write-Log "    Power configuration summary:" DarkCyan;
    Write-Log "      * hiberfil.sys file           : $(if ($hiberExists) { "Present ($hiberFilePath)" } else { "Not on disk (space freed)" })" Gray;
    Write-Log "      * Start Menu registry entry   : ShowHibernateOption = $regVal" Gray;
    Write-Log "      * Start Menu visibility       : $stateText" $stateColor;
    Write-Log "    ----------------------------------------------------------------" DarkGray;
}

# --- Main Program Flow ---

Clear-Host;

$actionName = "";
if ($EnableHibernation) {
    $actionName = "Enabling hibernation";
} else {
    $actionName = "Disabling hibernation";
}

Write-Log "================================================================================" Cyan;
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - $actionName" Cyan;
Write-Log "  Author: $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)" Gray;
Write-Log "  Log File: $resolvedLogPath" DarkCyan;
Write-Log "================================================================================" Cyan;

if (-not (Test-IsAdmin)) {
    throw "Script requires administrator privileges. Run PowerShell as Administrator.";
}

if ($EnableHibernation) {
    Set-PowercfgHibernationState -Enable $true;
    Set-StartMenuHibernateVisibility -TargetValue 1;
    Show-HibernationStatusSummary -TargetEnabled $true;
}
else {
    Set-PowercfgHibernationState -Enable $false;
    Set-StartMenuHibernateVisibility -TargetValue 0;
    Show-HibernationStatusSummary -TargetEnabled $false;
}

Write-Log "`n================================================================================" Green;
Write-Log "  [+] Procedure ($actionName) completed successfully." Green;
Write-Log "  [+] Execution log saved to: $resolvedLogPath" Green;
Write-Log "================================================================================" Green;
Write-Log "Author contact: $($SCRIPT_INFO.Contact)`n" Gray;