<#
.SYNOPSIS
    Automates the download and installation of ZUS Płatnik and its prerequisites.
.DESCRIPTION
    This script provides a complete, unattended installation experience for ZUS Płatnik.
    It automatically checks for and installs required dependencies (.NET Framework, SQL Server LocalDB)
    using winget, downloads the latest Płatnik installer and patch, performs a silent installation,
    and cleans up afterward. The entire process is tracked with a detailed progress bar.

    The script requires Administrator privileges and will automatically prompt for UAC elevation if needed.
.PARAMETER InstallerUrl
    The direct URL to the main ZUS Płatnik installer executable.
.PARAMETER PatchUrl
    The direct URL to the ZUS Płatnik patch executable.
.PARAMETER DownloadPath
    The local directory where installer files will be temporarily downloaded. Defaults to the user's temp folder.
.PARAMETER Help
    Displays this help message and exits.
.PARAMETER Install
    Triggers the installation process. This parameter is required to start the installation.
.EXAMPLE
    .\deploy-zus-platnik.ps1 -Install
    
    Triggers the installation with default settings. It will check for prerequisites,
    download the official installer and patch, install them silently, and clean up.
.EXAMPLE
    .\deploy-zus-platnik.ps1 -Help
    
    Displays the help screen with information about the script, parameters, and examples.
.NOTES
    Version: 1.0.0
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela

    This script is designed to be language-agnostic and will work on both Polish and English
    versions of Windows. It is crucial to unblock the script after downloading it from the internet.
    Run: Unblock-File -Path .\deploy-zus-platnik.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallerUrl = "https://redir.cache.orange.pl/zus/pobierz/dystrybucja/a1_10_02_002/pelna/install.exe",

    [Parameter(Mandatory = $false)]
    [string]$PatchUrl = "https://redir.cache.orange.pl/zus/pobierz/dystrybucja/a1_10_02_002/dodatki/P2StartFix2.exe",

    [Parameter(Mandatory = $false)]
    [string]$DownloadPath = $env:TEMP,

    [Parameter(Mandatory = $false)]
    [Alias("h")]
    [switch]$Help,

    [Parameter(Mandatory = $false, HelpMessage = "Triggers the installation process.")]
    [switch]$Install
)

# --- SCRIPT METADATA ---
$ScriptVersion = "1.0.0"
$AuthorName = "Roman Pindela"
$AuthorEmail = "roman.pindela@gmail.com"
$AuthorGitHub = "https://github.com/romanpindela"

# --- FUNCTIONS ---

function Show-Help {
    Write-Host ""
    Write-Host "ZUS PŁATNIK AUTOMATED INSTALLER v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "by $AuthorName"
    Write-Host "-----------------------------------------------------------------"
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "    Automates the full, unattended installation of ZUS Płatnik."
    Write-Host "    Handles prerequisite checks (.NET, SQL), downloads, silent"
    Write-Host "    installation, and cleanup, with full progress tracking."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    .\deploy-zus-platnik.ps1 -Install [PARAMETERS]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "    -InstallerUrl <string>"
    Write-Host "        URL for the main Płatnik installer. Defaults to the official source."
    Write-Host ""
    Write-Host "    -PatchUrl <string>"
    Write-Host "        URL for the Płatnik patch. Defaults to the official source."
    Write-Host ""
    Write-Host "    -DownloadPath <string>"
    Write-Host "        Temporary location for downloaded files. Defaults to '$env:TEMP'."
    Write-Host ""
    Write-Host "    -Help, -h"
    Write-Host "        Displays this help screen."
    Write-Host "    -Install"
    Write-Host "        Triggers the installation process. Required to run."
    Write-Host ""
    Write-Host "EXAMPLE:" -ForegroundColor Yellow
    Write-Host "    # Run the default installation"
    Write-Host "    .\deploy-zus-platnik.ps1 -Install"
    Write-Host ""
    Write-Host "    # Display this help menu"
    Write-Host "    .\deploy-zus-platnik.ps1 -Help"
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "    After downloading, you must unblock the script:"
    Write-Host "    Unblock-File -Path '.\deploy-zus-platnik.ps1'"
    Write-Host ""
    Write-Host "CONTACT:" -ForegroundColor Yellow
    Write-Host "    Author : $AuthorName"
    Write-Host "    Email  : $AuthorEmail"
    Write-Host "    GitHub : $AuthorGitHub"
    Write-Host ""
}

function Test-NetFramework48OrHigher {
    $ndpPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
    if (Test-Path $ndpPath) {
        $release = (Get-ItemProperty -Path $ndpPath -Name "Release" -ErrorAction SilentlyContinue).Release
        # 528040 corresponds to .NET Framework 4.8
        if ($release -ge 528040) {
            return $true
        }
    }
    return $false
}

function Test-IsSqlServerInstalled {
    # Check for LocalDB executable
    if (Get-Command "sqllocaldb.exe" -ErrorAction SilentlyContinue) {
        return $true
    }
    # Check for any running SQL Server database engine service (language-agnostic)
    $sqlServices = Get-Service -Name "MSSQL*" -ErrorAction SilentlyContinue
    if ($sqlServices | Where-Object { $_.Name -like "MSSQL`$*" -or $_.Name -eq "MSSQLSERVER" }) {
        return $true
    }
    return $false
}

function Test-IsPlatnikInstalled {
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($path in $uninstallPaths) {
        if (Test-Path $path) {
            $installed = Get-ItemProperty -Path "$path\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq "Płatnik" }
            if ($installed) {
                return $true
            }
        }
    }
    return $false
}

# --- INITIALIZATION & VALIDATION ---

# Show help if requested or if no parameters are provided at all.
if ($Help -or $PSBoundParameters.Count -eq 0) {
    Show-Help
    exit 0
}

# If parameters are provided, but -Install is not one of them, show an error and exit.
if (-not $Install) {
    Write-Host ""
    Write-Host "Error: The -Install parameter is required to start the installation." -ForegroundColor Red
    Write-Host "Use -Help to see available options." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Check for Administrator privileges using SID (language-independent)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
$isAdmin = $principal.IsInRole($adminSid)

if (-not $isAdmin) {
    Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# --- MAIN EXECUTION LOGIC ---

try {
    $totalSteps = 11 # Maximum possible steps
    $currentStep = 0
    function Update-Step {
        param(
            [string]$StatusMessage
        )
        $script:currentStep++
        $percent = [math]::Round(($script:currentStep / $script:totalSteps) * 100)
        Write-Progress -Activity "Installing ZUS Płatnik" -Status "$StatusMessage ($script:currentStep of $script:totalSteps)" -PercentComplete $percent
    }

    Write-Host "Starting ZUS Płatnik installation process..." -ForegroundColor Cyan

    # 1. Check for winget
    Update-Step "Checking for winget package manager..."
    if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        throw "winget is not installed or not found in PATH. This script requires winget to install prerequisites. Please install 'App Installer' from the Microsoft Store."
    }
    Write-Host "[OK] winget package manager found." -ForegroundColor Green

    # 2. Initialize winget sources
    Update-Step "Initializing winget sources..."
    Write-Host "Attempting to initialize winget sources to accept agreements..."
    # Running a harmless search forces winget to initialize its sources if needed.
    winget search "Microsoft.PowerShell" --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -eq 0x8a15000f) {
        throw "winget failed to initialize its 'msstore' source. Please open a terminal and run 'winget source list' once manually to accept the required agreements, then re-run this script."
    }
    Write-Host "[OK] winget initialization appears successful." -ForegroundColor Green

    # 3. Check .NET Framework
    Update-Step "Checking for .NET Framework 4.8+..."
    if (Test-NetFramework48OrHigher) {
        Write-Host "[OK] .NET Framework 4.8+ is already installed." -ForegroundColor Green
    } else {
        Write-Host "[WARN] .NET Framework 4.8+ not found. Attempting installation via winget..." -ForegroundColor Yellow
        Update-Step "Installing .NET Framework..."
        winget install --id Microsoft.DotNet.Framework.DeveloperPack --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "Failed to install .NET Framework via winget." }
        Write-Host "[OK] .NET Framework installed successfully." -ForegroundColor Green
    }

    # 4. Check for SQL Server (automatic installation is now skipped)
    Write-Host "Checking for SQL Server instance..." -ForegroundColor Cyan
    if (Test-IsSqlServerInstalled) {
        Write-Host "[OK] An existing SQL Server instance was found." -ForegroundColor Green
    } else {
        Write-Host "[WARN] No SQL Server instance found. The Płatnik installation may fail if it cannot connect to a database." -ForegroundColor Yellow
    }

    $installerFile = Join-Path -Path $DownloadPath -ChildPath "platnik_install.exe"
    $patchFile = Join-Path -Path $DownloadPath -ChildPath "platnik_patch.exe"

    # Check for existing Płatnik installation
    Update-Step "Checking for existing ZUS Płatnik installation..."
    if (Test-IsPlatnikInstalled) {
        Write-Host "[OK] ZUS Płatnik is already installed. Skipping main installation." -ForegroundColor Green
    }
    else {
        # Download and install the main application
        Update-Step "Downloading ZUS Płatnik installer..."
        Write-Host "Downloading Płatnik installer from $InstallerUrl..."
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerFile

        Update-Step "Installing ZUS Płatnik (this may take a few minutes)..."
        Write-Host "Running silent installation of Płatnik..."
        $installArgs = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
        $process = Start-Process -FilePath $installerFile -ArgumentList $installArgs -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Płatnik installer failed with exit code $($process.ExitCode)." }
        Write-Host "[OK] ZUS Płatnik installed successfully." -ForegroundColor Green
    }

    # Download and install the patch
    Update-Step "Downloading ZUS Płatnik patch..."
    Write-Host "Downloading Płatnik patch from $PatchUrl..."
    Invoke-WebRequest -Uri $PatchUrl -OutFile $patchFile
    Write-Host "[OK] Patch file downloaded." -ForegroundColor Green

    # Stop Płatnik processes before patching to avoid file locks
    Update-Step "Stopping Płatnik processes before patching..."
    Write-Host "Ensuring no Płatnik processes are running before patching..." -ForegroundColor Yellow
    Get-Process -Name "P2Start", "platnik" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2 # Give processes a moment to terminate

    Update-Step "Installing ZUS Płatnik patch..."
    Write-Host "Running silent installation of the patch..."
    $patchArgs = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
    $process = Start-Process -FilePath $patchFile -ArgumentList $patchArgs -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Płatnik patch installer failed with exit code $($process.ExitCode)." }
    Write-Host "[OK] Płatnik patch installed successfully." -ForegroundColor Green
    
    Update-Step "Cleaning up temporary files..."
    Write-Host "Removing temporary installer files..."
    Remove-Item -Path $installerFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $patchFile -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Cleanup complete." -ForegroundColor Green

    Write-Progress -Activity "Installing ZUS Płatnik" -Completed

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host "  ZUS Płatnik has been successfully installed!" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host ""

}
catch {
    Write-Progress -Activity "Installing ZUS Płatnik" -Completed
    Write-Host ""
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "  An error occurred during the installation process." -ForegroundColor Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Error "DETAILS: $($_.Exception.Message)"
    Write-Host "Script execution aborted." -ForegroundColor Red
    exit 1
}