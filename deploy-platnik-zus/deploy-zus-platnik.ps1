<#
.SYNOPSIS
    Prepares the system environment and downloads the necessary installers for ZUS Płatnik.
.DESCRIPTION
    This script streamlines the preparation for a manual ZUS Płatnik installation.
    It automatically checks for the required .NET Framework 4.8+ dependency and installs it using winget if it is missing.
    After ensuring the environment is ready, it downloads the latest Płatnik installer and its patch to the C:\Temp folder.
    
    The script requires Administrator privileges and will automatically prompt for UAC elevation if needed.
.PARAMETER InstallerUrl
    The direct URL to the main ZUS Płatnik installer executable.
.PARAMETER PatchUrl
    The direct URL to the ZUS Płatnik patch executable.
.PARAMETER PrepareEnvironment
    A switch to only prepare the environment by checking and installing prerequisites.
.PARAMETER PrepareAndDownload
    A switch to prepare the environment and then download the Płatnik installers.
.PARAMETER Help
    Displays this help message and exits.
.EXAMPLE
    .\deploy-zus-platnik.ps1
    
    Checks prerequisites, installs them if needed, and downloads the Płatnik
    installer and patch to the C:\Temp folder.
.EXAMPLE
    .\deploy-zus-platnik.ps1 -PrepareEnvironment
    
    Checks and installs all necessary prerequisites without downloading any Płatnik files.
.EXAMPLE
    .\deploy-zus-platnik.ps1 -PrepareAndDownload -Download PatchOnly
    
    Prepares the environment and then downloads only the Płatnik patch file.
    This is similar to the previous default behavior but explicitly triggered.
.EXAMPLE
    .\deploy-zus-platnik.ps1 -Help
    
    Displays the help screen with information about the script, parameters, and examples. 
.NOTES
    Version: 1.1.0
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela

    This script is designed to be language-agnostic and will work on both Polish and English
    versions of Windows. It is crucial to unblock the script after downloading it from the internet.
    Run: Unblock-File -Path .\deploy-zus-platnik.ps1
#>

[CmdletBinding(DefaultParameterSetName='HelpOnly')]
param(
    [Parameter(Mandatory = $false, ParameterSetName='PrepareAndDownload')]
    [string]$InstallerUrl = "https://redir.cache.orange.pl/zus/pobierz/dystrybucja/a1_10_02_002/pelna/install.exe",

    [Parameter(Mandatory = $false, ParameterSetName='PrepareAndDownload')]
    [string]$PatchUrl = "https://redir.cache.orange.pl/zus/pobierz/dystrybucja/a1_10_02_002/dodatki/P2StartFix2.exe",

    [Parameter(Mandatory = $false, ParameterSetName='PrepareAndDownload')]
    [ValidateSet('All', 'InstallerOnly', 'PatchOnly')]
    [string]$Download = 'All',

    [Parameter(Mandatory = $true, ParameterSetName='PrepareEnvironment')]
    [switch]$PrepareEnvironment,

    [Parameter(Mandatory = $true, ParameterSetName='PrepareAndDownload')]
    [switch]$PrepareAndDownload,

    [Parameter(Mandatory = $false, ParameterSetName='HelpOnly')]
    [Parameter(Mandatory = $false, ParameterSetName='PrepareEnvironment')]
    [Parameter(Mandatory = $false, ParameterSetName='PrepareAndDownload')]
    [Alias("h")]
    [switch]$Help
)

# --- SCRIPT METADATA ---
$ScriptVersion = "1.1.0"
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
    Write-Host "    It checks and installs the .NET prerequisite and then downloads the installer and patch to the C:\Temp folder."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    .\deploy-zus-platnik.ps1 [-PrepareEnvironment | -PrepareAndDownload] [PARAMETERS]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "    -InstallerUrl <string>"
    Write-Host "        URL for the main Płatnik installer. Defaults to the official source."
    Write-Host ""
    Write-Host "    -PatchUrl <string>"
    Write-Host "        URL for the Płatnik patch. Defaults to the official source."
    Write-Host ""
    Write-Host "    -PrepareEnvironment"
    Write-Host "        Only checks and installs prerequisites (e.g., .NET, VSTO, WSE)."
    Write-Host "        No Płatnik installers are downloaded."
    Write-Host ""
    Write-Host "    -PrepareAndDownload"
    Write-Host "        Checks and installs prerequisites, then downloads Płatnik installers."
    Write-Host "        This parameter enables -Download, -InstallerUrl, and -PatchUrl."
    Write-Host ""
    Write-Host "    -Download <string>"
    Write-Host "        Specifies which files to download. Options: 'All', 'InstallerOnly', 'PatchOnly'."
    Write-Host "        (Default is 'All')"
    Write-Host ""
    Write-Host "    -Help, -h"
    Write-Host "        Displays this help screen."
    Write-Host ""
    Write-Host "EXAMPLE:" -ForegroundColor Yellow
    Write-Host "    # Prepare environment and download all files (default)"
    Write-Host "    .\deploy-zus-platnik.ps1"
    Write-Host ""
    Write-Host "    # Only prepare the environment (install prerequisites)"
    Write-Host "    .\deploy-zus-platnik.ps1 -PrepareEnvironment"
    Write-Host ""
    Write-Host "    # Prepare environment and download all files (explicitly)"
    Write-Host "    .\deploy-zus-platnik.ps1 -PrepareAndDownload"
    Write-Host ""
    Write-Host "    # Prepare environment and download only the patch"
    Write-Host "    .\deploy-zus-platnik.ps1 -Download PatchOnly"
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

function Test-VstoRuntimeInstalled {
    # VSTO 2010 Runtime for .NET 4.0 installs this key.
    $vstoPath = "HKLM:\SOFTWARE\Microsoft\VSTO Runtime Setup\v4R"
    if (Test-Path $vstoPath) {
        $installValue = (Get-ItemProperty -Path $vstoPath -Name "Install" -ErrorAction SilentlyContinue).Install
        if ($installValue -eq 1) {
            return $true
        }
    }
    return $false
}

function Test-Wse3Installed {
    # Product code for Microsoft WSE 3.0
    $productCode = "{2495B3AF-4253-4323-A551-27B567542613}"
    $uninstallPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$productCode"
    $uninstallPathWow = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$productCode"
    if ((Test-Path $uninstallPath) -or (Test-Path $uninstallPathWow)) {
        return $true
    }
    return $false
}

# --- INITIALIZATION & VALIDATION ---

# Show help if requested.
if ($Help -or ($PSBoundParameters.Count -eq 0 -and $PSCmdlet.ParameterSetName -eq 'HelpOnly')) {
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
    # Dynamically set total steps for progress bar based on execution mode
    $totalSteps = 8 # Base steps for prerequisites (winget, winget-init, dotnet, vsto-check, vsto-install, wse-check, wse-install, mdac-check)
    if ($PSCmdlet.ParameterSetName -eq 'PrepareAndDownload') {
        $totalSteps += 1 # For directory check
        if ($Download -in ('All', 'InstallerOnly')) { $totalSteps += 1 } # For installer download
        if ($Download -in ('All', 'PatchOnly')) { $totalSteps += 1 } # For patch download
    }

    $currentStep = 0
    function Update-Step {
        param(
            [string]$StatusMessage
        )
        $script:currentStep++
        $percent = [math]::Round(($script:currentStep / $script:totalSteps) * 100)
        Write-Progress -Activity "Preparing for ZUS Płatnik Installation" -Status "$StatusMessage ($script:currentStep of $script:totalSteps)" -PercentComplete $percent
    }

    Write-Host "Starting environment preparation for ZUS Płatnik ($($PSCmdlet.ParameterSetName) mode)..." -ForegroundColor Cyan

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

    # Step 4 & 5: Check for VSTO 2010 Runtime
    Update-Step "Checking for VSTO 2010 Runtime..."
    Write-Host "`n-> Checking for 'Visual Studio 2010 Tools for Office Runtime'..." -ForegroundColor Cyan
    Write-Host "   (A component for applications integrating with Microsoft Office)"
    if (Test-VstoRuntimeInstalled) {
        Write-Host "[OK] VSTO 2010 Runtime is already installed." -ForegroundColor Green
    } else {
        Write-Host "[WARN] VSTO 2010 Runtime not found. Attempting automatic installation..." -ForegroundColor Yellow
        Update-Step "Installing VSTO 2010 Runtime..."
        $vstoUrl = "https://download.microsoft.com/download/C/3/A/C3A5200B-D33C-47E9-9D70-2F73D5529254/vstor_redist.exe"
        $vstoInstaller = Join-Path -Path $env:TEMP -ChildPath "vstor_redist.exe"
        Invoke-WebRequest -Uri $vstoUrl -OutFile $vstoInstaller
        Start-Process -FilePath $vstoInstaller -ArgumentList "/q /norestart" -Wait
        Remove-Item -Path $vstoInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] VSTO 2010 Runtime installed successfully." -ForegroundColor Green
    }

    # Step 6 & 7: Check for WSE 3.0
    Update-Step "Checking for WSE 3.0..."
    Write-Host "`n-> Checking for 'Web Services Enhancements (WSE) 3.0'..." -ForegroundColor Cyan
    Write-Host "   (A .NET Framework extension for advanced web service standards)"
    if (Test-Wse3Installed) {
        Write-Host "[OK] WSE 3.0 is already installed." -ForegroundColor Green
    } else {
        Write-Host "[WARN] WSE 3.0 not found. Attempting automatic installation..." -ForegroundColor Yellow
        Update-Step "Installing WSE 3.0..."
        $wseUrl = "https://download.microsoft.com/download/5/f/a/5fa3c898-a035-4fb9-a51a-17014a610368/WSE30.msi"
        $wseInstaller = Join-Path -Path $env:TEMP -ChildPath "WSE30.msi"
        Invoke-WebRequest -Uri $wseUrl -OutFile $wseInstaller
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$wseInstaller`" /qn /norestart" -Wait
        Remove-Item -Path $wseInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] WSE 3.0 installed successfully." -ForegroundColor Green
    }

    # Step 8: Check for MDAC
    Update-Step "Checking for MDAC 2.8..."
    Write-Host "`n-> Checking for 'Microsoft Data Access Components (MDAC) 2.8'..." -ForegroundColor Cyan
    Write-Host "   (A legacy data access component. Modern Windows includes a newer, integrated version - Windows DAC.)"
    Write-Host "[INFO] Installation is not required as a modern equivalent is part of the operating system." -ForegroundColor Green

    # --- Download Section (only if PrepareAndDownload is specified) ---
    if ($PSCmdlet.ParameterSetName -eq 'PrepareAndDownload') {
        # Step 9: Ensure download directory exists
        $downloadPath = "C:\Temp"
        Update-Step "Ensuring download directory '$downloadPath' exists..."
        if (-not (Test-Path -Path $downloadPath)) {
            New-Item -Path $downloadPath -ItemType Directory -Force | Out-Null
            Write-Host "Created directory: $downloadPath" -ForegroundColor Green
        }
        
        $downloadedFiles = [System.Collections.Generic.List[string]]::new()

        # Step 10: Download Installer (if requested)
        if ($Download -in ('All', 'InstallerOnly')) {
            $installerFileName = [System.IO.Path]::GetFileName($InstallerUrl)
            $installerFile = Join-Path -Path $downloadPath -ChildPath $installerFileName
            Update-Step "Downloading ZUS Płatnik installer..."
            Write-Host "Downloading Płatnik installer to '$installerFile'..."
            Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerFile
            $downloadedFiles.Add($installerFile)
        }

        # Step 11: Download Patch (if requested)
        if ($Download -in ('All', 'PatchOnly')) {
            $patchFileName = [System.IO.Path]::GetFileName($PatchUrl)
            $patchFile = Join-Path -Path $downloadPath -ChildPath $patchFileName
            Update-Step "Downloading ZUS Płatnik patch..."
            Write-Host "Downloading Płatnik patch to '$patchFile'..."
            Invoke-WebRequest -Uri $PatchUrl -OutFile $patchFile
            $downloadedFiles.Add($patchFile)
        }

        Write-Progress -Activity "Preparing for ZUS Płatnik Installation" -Completed

        Write-Host ""
        Write-Host "======================================================" -ForegroundColor Green
        Write-Host "  Environment is ready for ZUS Płatnik installation!" -ForegroundColor Green
        Write-Host "======================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "The following files have been downloaded to C:\Temp:" -ForegroundColor Cyan
        foreach($file in $downloadedFiles) {
            Write-Host "  - $file"
        }
        Write-Host ""
        Write-Host "You can now run the installer manually from C:\Temp." -ForegroundColor Yellow
        Write-Host ""
    } else { # PrepareEnvironment mode
        Write-Progress -Activity "Preparing for ZUS Płatnik Installation" -Completed
        Write-Host ""
        Write-Host "======================================================" -ForegroundColor Green
        Write-Host "  Environment prepared for ZUS Płatnik installation!" -ForegroundColor Green
        Write-Host "======================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Prerequisites have been checked/installed. No Płatnik installers were downloaded." -ForegroundColor Yellow
    }

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