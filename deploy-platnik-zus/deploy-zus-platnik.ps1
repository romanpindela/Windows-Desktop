<#
.SYNOPSIS
    Prepares the system environment and downloads the necessary installers for ZUS Płatnik.
.DESCRIPTION
    This script streamlines the preparation for a manual ZUS Płatnik installation.
    It automatically checks for the required .NET Framework 4.8+ dependency and installs it using winget if it is missing.
    After ensuring the environment is ready, it downloads the latest Płatnik installer and its patch
    directly to the user's "Downloads" folder.

    The script requires Administrator privileges and will automatically prompt for UAC elevation if needed.
.PARAMETER InstallerUrl
    The direct URL to the main ZUS Płatnik installer executable.
.PARAMETER PatchUrl
    The direct URL to the ZUS Płatnik patch executable.
.PARAMETER Help
    Displays this help message and exits.
.EXAMPLE
    .\deploy-zus-platnik.ps1
    
    Checks prerequisites, installs them if needed, and downloads the Płatnik
    installer and patch to the user's Downloads folder.
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
    [Alias("h")]
    [switch]$Help
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
    Write-Host "    Prepares the system for a ZUS Płatnik installation."
    Write-Host "    It checks and installs the .NET prerequisite and then downloads the installer and patch to your Downloads folder."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    .\deploy-zus-platnik.ps1 [PARAMETERS]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "    -InstallerUrl <string>"
    Write-Host "        URL for the main Płatnik installer. Defaults to the official source."
    Write-Host ""
    Write-Host "    -PatchUrl <string>"
    Write-Host "        URL for the Płatnik patch. Defaults to the official source."
    Write-Host ""
    Write-Host "    -Help, -h"
    Write-Host "        Displays this help screen."
    Write-Host ""
    Write-Host "EXAMPLE:" -ForegroundColor Yellow
    Write-Host "    # Prepare the environment and download files"
    Write-Host "    .\deploy-zus-platnik.ps1"
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

# --- INITIALIZATION & VALIDATION ---

# Show help if requested.
if ($Help) {
    Show-Help
    exit 0
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
    $totalSteps = 5
    $currentStep = 0
    function Update-Step {
        param(
            [string]$StatusMessage
        )
        $script:currentStep++
        $percent = [math]::Round(($script:currentStep / $script:totalSteps) * 100)
        Write-Progress -Activity "Preparing for ZUS Płatnik Installation" -Status "$StatusMessage ($script:currentStep of $script:totalSteps)" -PercentComplete $percent
    }

    Write-Host "Starting environment preparation for ZUS Płatnik..." -ForegroundColor Cyan

    # Step 1: Check for winget
    Update-Step "Checking for winget package manager..."
    if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        throw "winget is not installed or not found in PATH. This script requires winget to install prerequisites. Please install 'App Installer' from the Microsoft Store."
    }
    Write-Host "[OK] winget package manager found." -ForegroundColor Green

    # Step 2: Initialize winget sources
    Update-Step "Initializing winget sources..."
    Write-Host "Attempting to initialize winget sources to accept agreements..."
    winget search "Microsoft.PowerShell" --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -eq 0x8a15000f) {
        throw "winget failed to initialize its 'msstore' source. Please open a terminal and run 'winget source list' once manually to accept the required agreements, then re-run this script."
    }
    Write-Host "[OK] winget initialization appears successful." -ForegroundColor Green

    # Step 3: Check .NET Framework
    Update-Step "Checking for .NET Framework 4.8+..."
    if (Test-NetFramework48OrHigher) {
        Write-Host "[OK] .NET Framework 4.8+ is already installed." -ForegroundColor Green
    } else {
        Write-Host "[WARN] .NET Framework 4.8+ not found. Attempting installation via winget..." -ForegroundColor Yellow
        winget install --id Microsoft.DotNet.Framework.DeveloperPack --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "Failed to install .NET Framework via winget." }
        Write-Host "[OK] .NET Framework installed successfully." -ForegroundColor Green
    }

    # Step 4 & 5: Download files to user's Downloads folder
    $userDownloadsPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Downloads)
    if (-not (Test-Path -Path $userDownloadsPath)) {
        $userDownloadsPath = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
        New-Item -Path $userDownloadsPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $installerFile = Join-Path -Path $userDownloadsPath -ChildPath "platnik_install.exe"
    $patchFile = Join-Path -Path $userDownloadsPath -ChildPath "platnik_patch.exe"

    Update-Step "Downloading ZUS Płatnik installer..."
    Write-Host "Downloading Płatnik installer to '$installerFile'..."
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerFile

    Update-Step "Downloading ZUS Płatnik patch..."
    Write-Host "Downloading Płatnik patch to '$patchFile'..."
    Invoke-WebRequest -Uri $PatchUrl -OutFile $patchFile

    Write-Progress -Activity "Installing ZUS Płatnik" -Completed

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host "  Environment is ready for ZUS Płatnik installation!" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installer files have been downloaded to your Downloads folder:" -ForegroundColor Cyan
    Write-Host "  - $installerFile"
    Write-Host "  - $patchFile"
    Write-Host ""
    Write-Host "You can now run 'platnik_install.exe' manually to begin the installation." -ForegroundColor Yellow
    Write-Host ""

}
catch {
    Write-Progress -Activity "Installing ZUS Płatnik" -Completed
    Write-Host ""
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "  An error occurred during the preparation process." -ForegroundColor Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Error "DETAILS: $($_.Exception.Message)"
    Write-Host "Script execution aborted." -ForegroundColor Red
    exit 1
}