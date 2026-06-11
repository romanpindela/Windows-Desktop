<#
.SYNOPSIS
    Diagnoses and repairs the Windows Print Spooler service.
.DESCRIPTION
    This script performs a thorough diagnosis of the Print Spooler service on a local computer.
    It checks the service status, queued jobs, and can automatically attempt to clear stuck print queues and restart the service.
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.1.1
#>

param (
    [Alias("h", "Help")]
    [switch]$ShowHelp
)

function Show-ScriptHelp {
    Write-Host "`n=== SCRIPT: Diagnose-Spooler ===" -ForegroundColor Cyan
    Write-Host "Description: Diagnoses and attempts to fix Print Spooler issues."
    Write-Host "Author: Roman Pindela (roman.pindela@gmail.com) | https://github.com/romanpindela"
    Write-Host "Version: 1.1.1"
    Write-Host "`nUsage Examples:"
    Write-Host "  .\spooler-diagnosis.ps1"
    Write-Host "  .\spooler-diagnosis.ps1 -h`n"
}

if ($ShowHelp) {
    Show-ScriptHelp
    exit
}

try {
    Write-Host "Starting Spooler Diagnosis on: $($env:COMPUTERNAME)" -ForegroundColor Yellow

    # 1. Check Service Status
    $spooler = Get-CimInstance -ClassName Win32_Service -Filter "Name='Spooler'" -ErrorAction Stop
    
    # Kompatybilne z PowerShell 5.1 przypisanie koloru
    $statusColor = if ($spooler.State -eq 'Running') { 'Green' } else { 'Red' }
    Write-Host "Service Status: $($spooler.State)" -ForegroundColor $statusColor

    # 2. Check Print Jobs via WMI
    $jobs = Get-CimInstance -ClassName Win32_PrintJob -ErrorAction SilentlyContinue
    $jobCount = if ($jobs) { $jobs.Count } else { 0 }
    Write-Host "Current Print Jobs in Queue: $jobCount"

    # 3. Check Printer Statuses
    Write-Host "`nChecking printer statuses..." -ForegroundColor Yellow
    $printers = Get-Printer -ErrorAction SilentlyContinue
    $pausedCount = 0
    
    if ($printers) {
        Write-Host "--- Printer Status List ---" -ForegroundColor Cyan
        foreach ($printer in $printers) {
            if ($printer.PrinterStatus -match 'Paused') {
                Write-Host "  > $($printer.Name) - Status: $($printer.PrinterStatus)" -ForegroundColor Red
                $pausedCount++
            } else {
                Write-Host "  > $($printer.Name) - Status: $($printer.PrinterStatus)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  No printers found or unable to query printers." -ForegroundColor DarkGray
    }

    # Provide remediation advice based on status
    if ($spooler.State -ne 'Running' -or $jobCount -gt 5 -or $pausedCount -gt 0) {
        Write-Host "`n[!] Issue detected: Spooler is stopped, queue is loaded, or printers are paused." -ForegroundColor Red
        Write-Host "Recommended Action: Restart the spooler service and clear the C:\Windows\System32\spool\PRINTERS folder."
    } else {
        Write-Host "`n[i] Spooler appears to be operating normally." -ForegroundColor Green
    }

} catch {
    Write-Error "Diagnosis failed. Details: $($_.Exception.Message)"
}