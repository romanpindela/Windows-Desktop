<#
.SYNOPSIS
    Restart the Windows Print Spooler service and clear stuck print jobs.

.DESCRIPTION
    Stops the Print Spooler service, removes all pending print jobs
    from the spool directory, and starts the service again.
    It also checks for paused printers and resumes them by default.
    Automatically requests Administrator privileges if not already elevated.

.PARAMETER Help
    Displays help information.

.PARAMETER SkipPrinterResume
    Skips the automatic resuming of paused printers.

.EXAMPLE
    .\spooler-restart.ps1

.EXAMPLE
    .\spooler-restart.ps1 -Help

.EXAMPLE
    .\spooler-restart.ps1 -SkipPrinterResume

.NOTES
    Version : 1.2.0
    Author  : Roman Pindela
    Email   : roman.pindela@gmail.com
    GitHub  : https://github.com/romanpindela
#>

param(
    [switch]$SkipPrinterResume,
    [switch]$Help,
    [switch]$H
)

$ScriptVersion = "1.2.0"

function Show-Help {

    Write-Host ""
    Write-Host "SPOOLER-RESTART v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Windows Print Spooler Recovery Utility"
    Write-Host ""

    Write-Host "DESCRIPTION"
    Write-Host "    Stops the Windows Print Spooler service,"
    Write-Host "    removes pending print jobs, starts"
    Write-Host "    the service again, and optionally resumes"
    Write-Host "    any paused printers."
    Write-Host "    Auto-elevates to Administrator if required."
    Write-Host ""

    Write-Host "USAGE"
    Write-Host "    .\spooler-restart.ps1"
    Write-Host ""

    Write-Host "OPTIONS"
    Write-Host "    -SkipPrinterResume"
    Write-Host "        Do not attempt to automatically resume"
    Write-Host "        printers that are in a 'Paused' state."
    Write-Host "    -Help"
    Write-Host "    -H"
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

    Write-Host "VERSION"
    Write-Host "    $ScriptVersion"
    Write-Host ""
}

if ($Help -or $H) {
    Show-Help
    exit
}

# Check if the script is already running with Administrator privileges using SID (language-independent)
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
    Write-Host "Checking printer statuses..." -ForegroundColor Yellow
    
    # Give the spooler a brief moment to initialize before querying printers
    Start-Sleep -Seconds 2
    
    $Printers = Get-Printer -ErrorAction SilentlyContinue
    
    if ($Printers) {
        $PausedPrinters = @()
        Write-Host "--- Printer Status List ---" -ForegroundColor Cyan
        foreach ($Printer in $Printers) {
            if ($Printer.PrinterStatus -eq 'Paused') {
                Write-Host "  > $($Printer.Name) - Status: $($Printer.PrinterStatus)" -ForegroundColor Red
                $PausedPrinters += $Printer
            } else {
                Write-Host "  > $($Printer.Name) - Status: $($Printer.PrinterStatus)" -ForegroundColor Gray
            }
        }

        if ($PausedPrinters.Count -gt 0) {
            if (-not $SkipPrinterResume) {
                Write-Host ""
                Write-Host "Attempting to resume paused printers..." -ForegroundColor Yellow
                foreach ($Paused in $PausedPrinters) {
                    try {
                        $CimPrinter = Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop | Where-Object { $_.Name -eq $Paused.Name }
                        if ($CimPrinter) {
                            Invoke-CimMethod -InputObject $CimPrinter -MethodName Resume -ErrorAction Stop | Out-Null
                            Write-Host "  [OK] Resumed: $($Paused.Name)" -ForegroundColor Green
                        } else {
                            Write-Host "  [FAIL] Could not resume: $($Paused.Name) - WMI object not found." -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "  [FAIL] Could not resume: $($Paused.Name) - $($_.Exception.Message)" -ForegroundColor Red
                    }
                }

                Write-Host ""
                Write-Host "--- Final Printer Statuses ---" -ForegroundColor Cyan
                $FinalPrinters = Get-Printer -ErrorAction SilentlyContinue
                foreach ($Printer in $FinalPrinters) {
                    if ($Printer.PrinterStatus -eq 'Paused') {
                        Write-Host "  > $($Printer.Name) - Status: $($Printer.PrinterStatus)" -ForegroundColor Red
                    } else {
                        Write-Host "  > $($Printer.Name) - Status: $($Printer.PrinterStatus)" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host ""
                Write-Host "Skipping resume of paused printers (-SkipPrinterResume specified)." -ForegroundColor DarkGray
            }
        } else {
            Write-Host ""
            Write-Host "No paused printers detected." -ForegroundColor Green
        }
    } else {
        Write-Host "No printers found or unable to query printers." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Operation completed." -ForegroundColor Green
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "Operation failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    exit 1
}