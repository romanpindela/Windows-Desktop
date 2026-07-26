<#
.SYNOPSIS
    A simple launcher to download and execute a PowerShell script from GitHub.
.DESCRIPTION
    This script is designed to be copied and pasted directly into a PowerShell console.
    It downloads a target script from a predefined URL, unblocks it, and executes it.
    The script handles its own UAC elevation to ensure it has the necessary permissions.
.NOTES
    Version: 1.0.0
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
#>

# --- CONFIGURATION ---
# Paste the full GitHub URL of the script you want to download and run.
$UrlToDownload = "https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"

# --- SCRIPT BODY ---

# 1. UAC ELEVATION
# Check if the script is already running with Administrator privileges using a language-independent SID.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
$isAdmin = $principal.IsInRole($adminSid)

if (-not $isAdmin) {
    # If not running as Admin, relaunch the script with elevated privileges.
    Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow
    
    # This robust method works even when the script is pasted directly into the console.
    # It captures its own code, encodes it, and passes it to a new elevated PowerShell process.
    try {
        $scriptContent = $MyInvocation.MyCommand.Definition
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptContent))
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" -Verb RunAs
    }
    catch {
        Write-Error "Failed to self-elevate. Please run this script in an administrative PowerShell console."
    }
    
    # Exit the current non-elevated session.
    Exit
}

# 2. MAIN LOGIC
try {
    # Ensure modern security protocols are used for the download.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Validate that a URL has been provided.
    if ([string]::IsNullOrWhiteSpace($UrlToDownload)) {
        throw "The `$UrlToDownload variable is empty. Please define the target GitHub URL."
    }

    Write-Host "--- Starting Script Launcher ---" -ForegroundColor Cyan

    # Convert standard GitHub URL to the raw content URL.
    if ($UrlToDownload -like "*github.com/*/blob/*") {
        $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
    } else {
        $rawUrl = $UrlToDownload
    }

    # Define a temporary download location.
    $destinationPath = "C:\Temp"
    if (-not (Test-Path -Path $destinationPath)) {
        Write-Host "Creating directory: $destinationPath..." -ForegroundColor Yellow
        New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
    }

    # Construct the full file path.
    $fileName = Split-Path -Path $rawUrl -Leaf
    $destinationFile = Join-Path -Path $destinationPath -ChildPath $fileName

    # Download the script.
    Write-Host "Downloading '$fileName' to '$destinationFile'..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

    if (Test-Path -Path $destinationFile) {
        Write-Host "[OK] File successfully downloaded." -ForegroundColor Green

        # Unblock the file to remove the "Mark-of-the-Web".
        Unblock-File -Path $destinationFile
        Write-Host "[OK] File unblocked." -ForegroundColor Gray

        # Execute the downloaded script.
        Write-Host "`n--- Executing Target Script: $fileName ---`n" -ForegroundColor Yellow
        & $destinationFile
    }
    else {
        throw "File download failed. The file was not found at the destination."
    }

    Write-Host "`n--- Target Script Finished ---" -ForegroundColor Yellow

} catch {
    Write-Host ""
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}