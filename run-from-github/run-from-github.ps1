<#
.SYNOPSIS
    A simple launcher to download and execute a PowerShell script from GitHub with optional arguments.
.DESCRIPTION
    This script is designed to be copied and pasted directly into a PowerShell console or executed from a file.
    It downloads a target script from a predefined URL, unblocks it, and executes it with optional parameters.
    The script handles its own UAC elevation to ensure it has the necessary permissions.
.PARAMETER UrlToDownload
    The full GitHub URL of the script you want to download and run.
    Supports standard GitHub view URLs (github.com/.../blob/...) and raw URLs (raw.githubusercontent.com/...).
.PARAMETER ScriptArgs
    Optional parameters or arguments to pass to the downloaded script upon execution.
    Examples:
      -AutoDiscover
      -AutoDiscover -All
      -SiteName 'https://elektrimont.sharepoint.com/sites/automatyka'
.PARAMETER DestinationPath
    Local directory where the downloaded script will be stored. Default: C:\PowerShell.
.EXAMPLE
    # Run with default URL and -AutoDiscover parameter:
    .\run-from-github.ps1

.EXAMPLE
    # Run a custom script with custom parameters:
    .\run-from-github.ps1 -UrlToDownload "https://github.com/romanpindela/Microsoft-365/blob/main/SharePoint/Sync-SharePointLibrary/Sync-SharePointLibrary.ps1" -ScriptArgs "-AutoDiscover -All"
.NOTES
    Version: 1.2.0
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
#>

[CmdletBinding()]
param(
    # --- CONFIGURATION ---
    # Paste the full GitHub URL of the script you want to download and run.
    [Parameter(Position = 0)]
    [string]$UrlToDownload = "https://github.com/romanpindela/Microsoft-365/blob/main/SharePoint/Sync-SharePointLibrary/Sync-SharePointLibrary.ps1",

    # Optional parameters/arguments to pass to the target script (e.g. "-AutoDiscover", "-AutoDiscover -All", or "-SiteName 'automatyka'")
    [Parameter(Position = 1)]
    [string]$ScriptArgs = "-AutoDiscover",

    # Define download location (defaults to C:\PowerShell).
    [Parameter(Position = 2)]
    [string]$DestinationPath = "C:\PowerShell"
)

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
    
    # This robust method works both when executed from a .ps1 file and when pasted directly into the console.
    try {
        if ($MyInvocation.MyCommand.Path) {
            # Executed as a script file on disk: pass parameters to the new elevated PowerShell process
            $elevatedArgs = @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", "`"$($MyInvocation.MyCommand.Path)`"",
                "-UrlToDownload", "`"$UrlToDownload`"",
                "-ScriptArgs", "`"$ScriptArgs`"",
                "-DestinationPath", "`"$DestinationPath`""
            )
            Start-Process powershell.exe -ArgumentList ($elevatedArgs -join " ") -Verb RunAs
        }
        else {
            # Pasted directly into the console: capture code, encode it, and pass to elevated process
            $scriptContent = $MyInvocation.MyCommand.Definition
            $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptContent))
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" -Verb RunAs
        }
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

    # Ensure execution policy allows script execution for this process/session.
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

    # Ensure the destination directory exists.
    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        Write-Host "Creating directory: $DestinationPath..." -ForegroundColor Yellow
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }

    # Construct the full file path.
    $fileName = Split-Path -Path $rawUrl.Split('?')[0] -Leaf
    $destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

    # Download the script.
    Write-Host "Downloading '$fileName' to '$destinationFile'..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

    if (Test-Path -LiteralPath $destinationFile) {
        Write-Host "[OK] File successfully downloaded." -ForegroundColor Green

        # Unblock the file to remove the "Mark-of-the-Web".
        Unblock-File -LiteralPath $destinationFile
        Write-Host "[OK] File unblocked." -ForegroundColor Gray

        # Execute the downloaded script with optional arguments.
        if ([string]::IsNullOrWhiteSpace($ScriptArgs)) {
            Write-Host "`n--- Executing Target Script: $fileName ---`n" -ForegroundColor Yellow
            & $destinationFile
        } else {
            Write-Host "`n--- Executing Target Script: $fileName $ScriptArgs ---`n" -ForegroundColor Yellow
            Invoke-Expression "& `"$destinationFile`" $ScriptArgs"
        }
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