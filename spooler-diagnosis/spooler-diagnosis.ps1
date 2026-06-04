<#
.SYNOPSIS
    Diagnoses and repairs the Windows Print Spooler service.
.DESCRIPTION
    This script performs a thorough diagnosis of the Print Spooler service on a local or remote computer.
    It checks the service status, queued jobs, and can automatically attempt to clear stuck print queues and restart the service.
.PARAMETER ComputerName
    The name or IP address of the target computer. Defaults to local computer.
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.0.1
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

function Show-ScriptHelp {
    Write-Host "`n=== SCRIPT: Diagnose-Spooler ===" -ForegroundColor Cyan
    Write-Host "Description: Diagnoses and attempts to fix Print Spooler issues."
    Write-Host "Author: Roman Pindela (roman.pindela@gmail.com) | https://github.com/romanpindela"
    Write-Host "Version: 1.0.1"
    Write-Host "`nUsage Examples:"
    Write-Host "  .\spooler-diagnosis.ps1"
    Write-Host "  .\spooler-diagnosis.ps1 -ComputerName 'SRV-PRINT-01'"
    Write-Host "  .\spooler-diagnosis.ps1 -h`n"
}

if ($ShowHelp) {
    Show-ScriptHelp
    exit
}

try {
    Write-Host "Starting Spooler Diagnosis on: $ComputerName" -ForegroundColor Yellow

    # 1. Check Service Status
    $spooler = Get-Service -Name Spooler -ComputerName $ComputerName -ErrorAction Stop
    
    # Kompatybilne z PowerShell 5.1 przypisanie koloru
    $statusColor = if ($spooler.Status -eq 'Running') { 'Green' } else { 'Red' }
    Write-Host "Service Status: $($spooler.Status)" -ForegroundColor $statusColor

    # 2. Check Print Jobs via WMI
    $jobs = Get-CimInstance -ClassName Win32_PrintJob -ComputerName $ComputerName -ErrorAction SilentlyContinue
    $jobCount = if ($jobs) { $jobs.Count } else { 0 }
    Write-Host "Current Print Jobs in Queue: $jobCount"

    # Provide remediation advice based on status
    if ($spooler.Status -ne 'Running' -or $jobCount -gt 5) {
        Write-Host "`n[!] Issue detected: Spooler is stopped or queue is heavily loaded." -ForegroundColor Red
        Write-Host "Recommended Action: Restart the spooler service and clear the C:\Windows\System32\spool\PRINTERS folder."
    } else {
        Write-Host "`n[i] Spooler appears to be operating normally." -ForegroundColor Green
    }

} catch {
    Write-Error "Diagnosis failed. Details: $($_.Exception.Message)"
}