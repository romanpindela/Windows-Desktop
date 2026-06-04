<#
.SYNOPSIS
    Restart the Windows Print Spooler service and clear stuck print jobs.

.DESCRIPTION
    Stops the Print Spooler service, removes all pending print jobs
    from the spool directory, and starts the service again.

.PARAMETER Help
    Displays help information.

.EXAMPLE
    .\spooler-restart.ps1

.EXAMPLE
    .\spooler-restart.ps1 -Help

.NOTES
    Version : 1.0.0
    Author  : Roman Pindela
    Email   : roman.pindela@gmail.com
    GitHub  : https://github.com/romanpindela
#>

param(
    [switch]$Help,
    [switch]$H
)

$ScriptVersion = "1.0.0"

function Show-Help {

    Write-Host ""
    Write-Host "SPOOLER-RESTART v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Windows Print Spooler Recovery Utility"
    Write-Host ""

    Write-Host "DESCRIPTION"
    Write-Host "    Stops the Windows Print Spooler service,"
    Write-Host "    removes pending print jobs, and starts"
    Write-Host "    the service again."
    Write-Host ""

    Write-Host "USAGE"
    Write-Host "    .\spooler-restart.ps1"
    Write-Host ""

    Write-Host "OPTIONS"
    Write-Host "    -Help"
    Write-Host "    -H"
    Write-Host "        Display this help screen."
    Write-Host ""

    Write-Host "REQUIREMENTS"
    Write-Host "    - Run PowerShell as Administrator"
    Write-Host ""

    Write-Host "AUTHOR"
    Write-Host "    Roman Pindela"
    Write-Host "    Email  : roman.pindela@gmail.com"
    Write-Host "    GitHub : https://github.com/romanpindela"
    Write-Host ""

    Write-Host "VERSION"
    Write-Host "    $ScriptVersion"
    Write-Host ""
}

if ($Help -or $H) {
    Show-Help
    exit
}

$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {
    Write-Host ""
    Write-Host "ERROR: Administrator privileges are required." -ForegroundColor Red
    Write-Host ""
    exit 1
}

try {

    Write-Host ""
    Write-Host "Spooler-Restart v$ScriptVersion" -ForegroundColor Green
    Write-Host ""

    Write-Host "Stopping Print Spooler service..." -ForegroundColor Yellow
    Stop-Service -Name Spooler -Force -ErrorAction Stop

    $SpoolPath = Join-Path $env:SystemRoot "System32\spool\PRINTERS"

    Write-Host "Removing pending print jobs..." -ForegroundColor Yellow

    if (Test-Path $SpoolPath) {
        Remove-Item "$SpoolPath\*" -Force -Recurse -ErrorAction SilentlyContinue
    }

    Write-Host "Starting Print Spooler service..." -ForegroundColor Yellow
    Start-Service -Name Spooler -ErrorAction Stop

    Write-Host ""
    Write-Host "Print Spooler successfully restarted." -ForegroundColor Green
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "Operation failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    exit 1
}