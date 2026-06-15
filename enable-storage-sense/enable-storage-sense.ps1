# ==============================================================================
# EXTENDED STORAGE SENSE AND SYSTEM CLEANUP CONFIGURATION SCRIPT
# ==============================================================================

param(
    [switch]$Help,
    [switch]$h
)

$ScriptVersion = "1.0.0"

function Show-Help {
    Write-Host ""
    Write-Host "ENABLE-STORAGE-SENSE v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Windows Automatic Cleanup Configuration Script"
    Write-Host ""
    Write-Host "DESCRIPTION"
    Write-Host "    This script fully automates the disk cleanup process in Windows 10/11."
    Write-Host "    It configures native Storage Sense mechanisms to run in the background,"
    Write-Host "    cleans temporary files, OneDrive files, old Windows installations, unused"
    Write-Host "    apps, securely clears Windows Update cache, and removes bloatware."
    Write-Host ""
    Write-Host "USAGE"
    Write-Host "    .\enable-storage-sense.ps1"
    Write-Host ""
    Write-Host "EXAMPLES"
    Write-Host "    .\enable-storage-sense.ps1"
    Write-Host "    .\enable-storage-sense.ps1 -Help"
    Write-Host ""
    Write-Host "OPTIONS"
    Write-Host "    -Help, -h"
    Write-Host "        Display this help screen."
    Write-Host ""
    Write-Host "REQUIREMENTS"
    Write-Host "    - Administrator privileges (auto-prompts for UAC elevation)"
    Write-Host ""
    Write-Host "AUTHOR"
    Write-Host "    Roman Pindela"
    Write-Host "    Email  : roman.pindela@gmail.com"
    Write-Host "    GitHub : https://github.com/romanpindela"
    Write-Host ""
}

if ($Help -or $h) {
    Show-Help
    exit 0
}

# 0. Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Administrator privileges required. Prompting for administrator credentials..."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Write-Host "Starting automatic cleanup configuration..." -ForegroundColor Cyan

# Registry path for the main Storage Sense policy
$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}

# ==============================================================================
# BASE STORAGE SENSE CONFIGURATION
# ==============================================================================

# Enable Storage Sense permanently
Set-ItemProperty -Path $RegistryPath -Name "StorageSense" -Value 1 -Type DWord

# Frequency: 1 = Daily | 7 = Weekly | 30 = Monthly | 0 = During low free disk space
Set-ItemProperty -Path $RegistryPath -Name "RunStorageSense" -Value 30 -Type DWord

# Clean basic application temporary files
Set-ItemProperty -Path $RegistryPath -Name "CleanTemporaryFiles" -Value 1 -Type DWord

# Recycle Bin (files older than 14 days)
Set-ItemProperty -Path $RegistryPath -Name "CleanRecycleBinAge" -Value 60 -Type DWord


# ==============================================================================
# ADVANCED CLEANUP FEATURES (POINTS A, B, C, D)
# ==============================================================================

# ------------------------------------------------------------------------------
# [POINT A] OneDrive Optimization (Storage Sense for cloud files)
# ------------------------------------------------------------------------------
# The "Files On-Demand" feature allows you to recover space by changing local
# files to "online-only" if they haven't been opened for a defined period.
# Values: 1, 14, 30, 60 (days). 0 = Disabled. Setting to 30 days.
Write-Host "[A] Configuring OneDrive file dehydration (30 days)..." -ForegroundColor Gray
Set-ItemProperty -Path $RegistryPath -Name "LocalContentMinAge" -Value 30 -Type DWord

# ------------------------------------------------------------------------------
# [POINT B] Windows.old folder cleanup (Previous Windows installations)
# ------------------------------------------------------------------------------
# After major Windows feature updates, an archived Windows.old folder remains
# on the system drive. This key activates its automatic and safe removal
# after the default rollback period expires.
Write-Host "[B] Enabling automatic removal of the Windows.old folder..." -ForegroundColor Gray
Set-ItemProperty -Path $RegistryPath -Name "PreviousVersionCleanupStatus" -Value 1 -Type DWord

# ------------------------------------------------------------------------------
# [POINT C] Archiving rarely used applications (Microsoft Store)
# ------------------------------------------------------------------------------
# Freezes and automatically uninstalls binaries of rarely launched store apps,
# keeping their configuration files and user data intact to quickly restore
# them if needed.
Write-Host "[C] Enabling automatic archiving of unused apps..." -ForegroundColor Gray
$AppDefaultsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppDefaults"
if (-not (Test-Path $AppDefaultsPath)) {
    New-Item -Path $AppDefaultsPath -Force | Out-Null
}
Set-ItemProperty -Path $AppDefaultsPath -Name "ArchiveUnusedApps" -Value 1 -Type DWord



# ------------------------------------------------------------------------------
# [POINT D] Securely clear Windows Update download folder
# ------------------------------------------------------------------------------
# Clear Delivery Optimization Cache
Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
# Securely clear Windows Update download folder
Write-Host "[POINT D] Securely clear Windows Update download folder..." -ForegroundColor Gray

Stop-Service -Name wuauserv -Force -WarningAction SilentlyContinue
Stop-Service -Name bits -Force -WarningAction SilentlyContinue
Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -WarningAction SilentlyContinue
Start-Service -Name bits -WarningAction SilentlyContinue



# ------------------------------------------------------------------------------
# [POINT E] Debloat pre-installed Windows apps
# ------------------------------------------------------------------------------
Write-Host "[E] Removing bloatware apps..." -ForegroundColor Gray
$bloatware = @(
    "*Microsoft.ZuneVideo*",
    "*Microsoft.XboxApp*",
    "*Microsoft.GetHelp*",
    "*Microsoft.BingNews*"
)

foreach ($app in $bloatware) {
    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

# ==============================================================================
# EXECUTION AND VALIDATION
# ==============================================================================

Write-Host "`n[+] All features have been successfully configured in the registry." -ForegroundColor Green

# Force immediate execution of the first background cleanup
Write-Host "[*] Triggering the system cleanup task to apply changes..." -ForegroundColor Cyan
Get-ScheduledTask -TaskName "SilentCleanup" -TaskPath "\Microsoft\Windows\DiskCleanup\" | Start-ScheduledTask

Write-Host "`nDONE! The system will now automatically maintain cleanliness every month." -ForegroundColor Green