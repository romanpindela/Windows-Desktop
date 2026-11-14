<#
.SYNOPSIS
    Open an interactive PowerShell Remoting session.

.DESCRIPTION
    Creates an interactive PowerShell Remoting (WinRM) session
    with a remote Windows computer using supplied credentials.

.PARAMETER ComputerName
    Hostname or IP address of the target computer.

.PARAMETER Help
    Displays this help screen and exits.

.PARAMETER H
    Short switch to display help and exit.

.EXAMPLE
    .\Open-Session.ps1 SERVER01

.EXAMPLE
    .\Open-Session.ps1 10.10.1.4

.EXAMPLE
    .\Open-Session.ps1 -Help

.NOTES
    Version : 1.0.0
    Author  : Roman Pindela
    Email   : roman.pindela@gmail.com
    GitHub  : https://github.com/romanpindela
#>

param(
    [string]$ComputerName,
    [switch]$Help,
    [switch]$H
)

$ScriptVersion = "1.0.0"

function Show-Help {

    Write-Host ""
    Write-Host "Open-Session v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Interactive PowerShell Remoting Session Utility"
    Write-Host ""

    Write-Host "DESCRIPTION"
    Write-Host "    Creates an interactive PowerShell Remoting session"
    Write-Host "    with a remote Windows computer."
    Write-Host ""

    Write-Host "USAGE"
    Write-Host "    .\Open-Session.ps1 <ComputerName>"
    Write-Host ""

    Write-Host "PARAMETERS"
    Write-Host "    ComputerName"
    Write-Host "        Hostname or IP address of the target computer."
    Write-Host ""

    Write-Host "EXAMPLES"
    Write-Host "    .\Open-Session.ps1 SERVER01"
    Write-Host "    .\Open-Session.ps1 10.10.1.4"
    Write-Host ""

    Write-Host "OPTIONS"
    Write-Host "    -Help"
    Write-Host "    -H"
    Write-Host "        Display this help screen."
    Write-Host ""

    Write-Host "REQUIREMENTS"
    Write-Host "    - PowerShell Remoting (WinRM) enabled"
    Write-Host "    - Network connectivity"
    Write-Host "    - Appropriate user permissions"
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

if ($Help -or $H -or [string]::IsNullOrWhiteSpace($ComputerName)) {
    Show-Help
    exit
}

try {

    Write-Host ""
    Write-Host "Open-Session v$ScriptVersion" -ForegroundColor Green
    Write-Host "Target: $ComputerName"
    Write-Host ""

    $Credential = Get-Credential

    Write-Host "Connecting to $ComputerName..." -ForegroundColor Yellow

    Enter-PSSession `
        -ComputerName $ComputerName `
        -Credential $Credential

}
catch {

    Write-Host ""
    Write-Host "Connection failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

}