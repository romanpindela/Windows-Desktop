<#
.SYNOPSIS
    Automated Windows Health Checker and Repair Tool (DISM & SFC).
.DESCRIPTION
    This script verifies administrator privileges independently of the OS language using WellKnownSidType.
    It performs sequential system repair tasks: CheckHealth, ScanHealth, RestoreHealth, and SFC Scannow.
    Logs are written to C:\Windows\Logs\SystemRepair_Log.txt.
.PARAMETER Action
    Defines the specific action to perform. Options: "All", "Check", "Scan", "Restore", "Sfc". Default is "All".
.PARAMETER LogPath
    Defines the custom path for the log file. Default is "C:\Windows\Logs\SystemRepair_Log.txt".
.PARAMETER Help
    Displays the help menu and usage examples.
.EXAMPLE
    .\invoke-windows-repair.ps1 -Action All
.EXAMPLE
    .\invoke-windows-repair.ps1 -Action Scan -LogPath "C:\CustomLogs\Repair.txt"
.EXAMPLE
    .\invoke-windows-repair.ps1 -Help
#>

param (
    [ValidateSet('All', 'Check', 'Scan', 'Restore', 'Sfc')]
    [string]$Action = "All",

    [string]$LogPath = "C:\Windows\Logs\SystemRepair_Log.txt",

    [switch]$Help
)

# --- CONFIGURATION & METADATA ---
$Script:Version = "1.2.0"
$Script:Author = "Roman Pindela"
$Script:Email = "roman.pindela@gmail.com"
$Script:GitHub = "https://github.com/romanpindela"

# --- FUNCTIONS ---

function Show-HelpMenu {
    Clear-Host
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host " WINDOWS HEALTH CHECKER & REPAIR TOOL - HELP MENU" -ForegroundColor Cyan
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host "Version : $($Script:Version)"
    Write-Host "Author  : $($Script:Author) ($($Script:Email))"
    Write-Host "GitHub  : $($Script:GitHub)"
    Write-Host "-------------------------------------------------------------------------"
    Write-Host "DESCRIPTION:"
    Write-Host "  Automates Windows image servicing (DISM) and system file validation (SFC)."
    Write-Host "  Supports both English and Polish Windows environments (language-agnostic)."
    Write-Host ""
    Write-Host "PARAMETERS:"
    Write-Host "  -Action   <String>  Specifies execution mode: 'All', 'Check', 'Scan', 'Restore', 'Sfc'."
    Write-Host "                      (Default is 'All')"
    Write-Host "  -LogPath  <String>  Custom path to save the execution logs."
    Write-Host "                      (Default: C:\Windows\Logs\SystemRepair_Log.txt)"
    Write-Host "  -Help               Displays this professional help interface."
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "  .\invoke-windows-repair.ps1 -Help"
    Write-Host "  .\invoke-windows-repair.ps1 -Action All"
    Write-Host "  .\invoke-windows-repair.ps1 -Action Restore -LogPath 'D:\Logs\repair.txt'"
    Write-Host "=========================================================================" -ForegroundColor Cyan
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message, 
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Type = "INFO"
    )
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$TimeStamp] [$Type] $Message"
    
    $Color = switch ($Type) {
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        default   { "Cyan" }
    }
    
    Write-Host $LogLine -ForegroundColor $Color
    
    # Ensure directory exists before logging
    $LogDir = Split-Path -Path $LogPath
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    $LogLine | Out-File -FilePath $LogPath -Append -Encoding utf8
}

# --- UNEXPECTED/DANGEROUS INPUT PROTECTION & DEFAULT INTERACTION ---
if ($args.Count -gt 0) {
    Write-Host "Dangerous or invalid arguments detected!" -ForegroundColor Red
    Show-HelpMenu
    Exit
}

if ($Help) {
    Show-HelpMenu
    Exit
}

# --- SECURITY & PRIVILEGE VALIDATION (LANGUAGE-INDEPENDENT) ---
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)

$isAdmin = $principal.IsInRole($adminSid)

if (-not $isAdmin) {
    # If not running as Admin, prompt for UAC consent and relaunch the script with elevated privileges
    Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# --- MAIN EXECUTION LOGIC ---
Clear-Host
Write-Log "=== STARTING WINDOWS SYSTEM REPAIR PROCEDURE ===" "INFO"
Write-Log "Target Log Location: $LogPath" "INFO"
Write-Log "Selected Action Mode: $Action" "INFO"

# Task 1: DISM CheckHealth
if ($Action -eq "All" -or $Action -eq "Check") {
    Write-Log "Executing: DISM CheckHealth (Verifying corruption flags)..." "INFO"
    try {
        $Result = DISM.exe /Online /Cleanup-Image /CheckHealth 2>&1
        Write-Log "DISM CheckHealth result recorded successfully." "SUCCESS"
        $Result | Out-File -FilePath $LogPath -Append -Encoding utf8
    } catch {
        Write-Log "Critical error during DISM CheckHealth execution: $_" "ERROR"
    }
}

# Task 2: DISM ScanHealth
if ($Action -eq "All" -or $Action -eq "Scan") {
    Write-Log "Executing: DISM ScanHealth (Deep component store scanning)..." "INFO"
    try {
        $Result = DISM.exe /Online /Cleanup-Image /ScanHealth 2>&1
        Write-Log "DISM ScanHealth operation completed." "SUCCESS"
        $Result | Out-File -FilePath $LogPath -Append -Encoding utf8
    } catch {
        Write-Log "Critical error during DISM ScanHealth execution: $_" "ERROR"
    }
}

# Task 3: DISM RestoreHealth
if ($Action -eq "All" -or $Action -eq "Restore") {
    Write-Log "Executing: DISM RestoreHealth (Repairing components from Windows Update)..." "INFO"
    try {
        $Result = DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1
        Write-Log "DISM RestoreHealth processing finished." "SUCCESS"
        $Result | Out-File -FilePath $LogPath -Append -Encoding utf8
    } catch {
        Write-Log "Critical error during DISM RestoreHealth execution: $_" "ERROR"
    }
}

# Task 4: SFC Scannow
if ($Action -eq "All" -or $Action -eq "Sfc") {
    Write-Log "Executing: SFC /Scannow (Validating protected system files)..." "INFO"
    try {
        $SfcResult = sfc /scannow
        foreach ($Line in $SfcResult) {
            if ($Line -match '\S') { 
                Write-Log $Line.Trim() "INFO" 
            }
        }
    } catch {
        Write-Log "Critical error during SFC Scannow execution: $_" "ERROR"
    }
}

Write-Log "=== SYSTEM REPAIR PROCEDURE COMPLETED ===" "SUCCESS"