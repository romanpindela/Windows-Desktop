<#
.SYNOPSIS
    Downloads a PowerShell script from a GitHub URL and optionally executes it.
.DESCRIPTION
    A utility script that takes a standard GitHub URL for a .ps1 file, converts it to the raw content URL,
    downloads it to a specified local directory, unblocks it, and optionally executes it.
    The script requires Administrator privileges to write to default system locations and will auto-elevate.
.PARAMETER Url
    The full GitHub URL to the .ps1 script file. (e.g., https://github.com/user/repo/blob/main/script.ps1)
.PARAMETER DestinationPath
    The local folder where the script will be downloaded. Defaults to C:\Temp.
.PARAMETER Execute
    A switch to execute the script immediately after download. If omitted, the script is only downloaded.
.PARAMETER Help
    Displays this help message.
.EXAMPLE
    .\download-run-script.ps1 -Url "https://github.com/user/repo/blob/main/script.ps1"
    
    Downloads 'script.ps1' to C:\Temp but does not run it.
.EXAMPLE
    .\download-run-script.ps1 -Url "https://github.com/user/repo/blob/main/script.ps1" -Execute
    
    Downloads 'script.ps1' to C:\Temp and runs it immediately.
.EXAMPLE
    .\download-run-script.ps1 -Url "https://github.com/user/repo/blob/main/script.ps1" -DestinationPath "C:\MyScripts"
    
    Downloads 'script.ps1' to the C:\MyScripts folder.
.EXAMPLE
    .\download-run-script.ps1 -Help
    
    Displays the help menu.
.NOTES
    Version: 1.2.0
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela

    It is crucial to unblock this script after downloading it from the internet.
    Run: Unblock-File -Path .\download-run-script.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="The full GitHub URL to the .ps1 script file.")]
    [string]$Url,

    [Parameter(Mandatory=$false, HelpMessage="The local folder where the script will be downloaded. Defaults to C:\Temp.")]
    [string]$DestinationPath = "C:\Temp",

    [Parameter(Mandatory=$false, HelpMessage="Execute the script immediately after download.")]
    [switch]$Execute,

    [Parameter(Mandatory=$false, Alias='h')]
    [switch]$Help
)

# --- CONFIGURATION FOR DIRECT EXECUTION (PASTE IN CONSOLE) ---
# To use this script by pasting its content directly into a PowerShell console,
# define the target URL here. If run from a file, use the -Url parameter instead.
$HardcodedUrl = "https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1" # e.g., "https://github.com/romanpindela/Windows-Desktop/blob/main/deploy-platnik-zus/deploy-zus-platnik.ps1"

# --- SCRIPT METADATA ---
$ScriptVersion = "1.2.0"
$AuthorName = "Roman Pindela"
$AuthorEmail = "roman.pindela@gmail.com"
$AuthorGitHub = "https://github.com/romanpindela"

# --- FUNCTIONS ---
function Show-Help {
    Write-Host ""
    Write-Host "DOWNLOAD-RUN-SCRIPT v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "by $AuthorName"
    Write-Host "-----------------------------------------------------------------"
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "    Downloads a PowerShell script from a GitHub URL, unblocks it,"
    Write-Host "    and optionally executes it. Requires admin rights."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    .\download-run-script.ps1 [-Url <string>] [PARAMETERS]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "    -Url <string>"
    Write-Host "        (Mandatory) The full GitHub URL of the .ps1 file to download."
    Write-Host ""
    Write-Host "    -DestinationPath <string>"
    Write-Host "        The local folder for the download. Defaults to 'C:\Temp'."
    Write-Host ""
    Write-Host "    -Execute"
    Write-Host "        A switch to run the script after it's downloaded."
    Write-Host ""
    Write-Host "    -Help, -h"
    Write-Host "        Displays this help screen."
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "    # Download a script to C:\Temp without running it"
    Write-Host "    .\download-run-script.ps1 -Url 'https://github.com/user/repo/blob/main/script.ps1'"
    Write-Host ""
    Write-Host "    # Download and run a script"
    Write-Host "    .\download-run-script.ps1 -Url 'https://github.com/user/repo/blob/main/script.ps1' -Execute"
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "    After downloading this utility, you must unblock it:"
    Write-Host "    Unblock-File -Path '.\download-run-script.ps1'"
    Write-Host ""
    Write-Host "CONTACT:" -ForegroundColor Yellow
    Write-Host "    Author : $AuthorName"
    Write-Host "    Email  : $AuthorEmail"
    Write-Host "    GitHub : $AuthorGitHub"
    Write-Host ""
}

# --- INITIALIZATION & VALIDATION ---

# If -Url parameter is not used, fall back to the hardcoded URL.
if (-not $PSBoundParameters.ContainsKey('Url') -and -not [string]::IsNullOrWhiteSpace($HardcodedUrl)) {
    $Url = $HardcodedUrl
    # In paste-to-run mode, we almost always want to execute.
    if (-not $PSBoundParameters.ContainsKey('Execute')) {
        $Execute = $true
    }
}

if ($Help -or -not $Url) {
    Show-Help
    exit 0
}

# Check if the script is already running with Administrator privileges using SID (language-independent)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)

$isAdmin = $principal.IsInRole($adminSid)

if (-not $isAdmin) {
    # If not running as Admin, prompt for UAC consent and relaunch the script with elevated privileges
    Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow    
    # If running from a file, relaunch the file.
    if ($PSCommandPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSBoundParameters" -Verb RunAs
    } else {
        # If pasted in console, relaunch with the entire script content as an encoded command.
        $scriptContent = $MyInvocation.MyCommand.Definition
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptContent))
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" -Verb RunAs
    }
    Exit
}

# Force TLS 1.2 security protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    # Automatically convert standard GitHub URL to RAW format
    if ($Url -like "*github.com/*/blob/*") {
        $rawUrl = $Url -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
    } else {
        $rawUrl = $Url
    }

    # Extract file name from the URL
    $fileName = Split-Path -Path $rawUrl -Leaf
    $destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

    # Check and create target folder if it does not exist
    if (-not (Test-Path -Path $DestinationPath)) {
        Write-Host "Creating directory: $DestinationPath..." -ForegroundColor Yellow
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }

    Write-Host "Downloading '$fileName' to '$destinationFile'..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

    if (Test-Path -Path $destinationFile) {
        Write-Host "[OK] File successfully downloaded." -ForegroundColor Green

        Unblock-File -Path $destinationFile
        Write-Host "[OK] File unblocked." -ForegroundColor Gray

        if ($Execute) {
            Write-Host "`n--- Executing script: $fileName ---`n" -ForegroundColor Yellow
            & $destinationFile
        }
    }
} catch {
    Write-Host ""
    Write-Error "An error occurred during the process: $($_.Exception.Message)"
    exit 1
}