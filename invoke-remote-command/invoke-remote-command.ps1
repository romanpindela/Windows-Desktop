<#
.SYNOPSIS
    Executes a custom command on a remote machine.
.DESCRIPTION
    Connects to a remote machine, prompts for credentials, and executes
    a provided string command as an administrator.
.PARAMETER ComputerName
    The target remote computer hostname or IP.
.PARAMETER RemoteCommand
    The string command to execute (e.g., "whoami", "ipconfig").
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.0.0
#>

param (
    [Parameter(Mandatory=$true, HelpMessage="Target machine hostname or IP.")]
    [string]$ComputerName,

    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory=$false)]
    [string]$RemoteCommand,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

function Show-Help {
    Write-Host "`n=== Invoke-RemoteCommand ===" -ForegroundColor Cyan
    Write-Host "Description: Execute custom remote commands interactively."
    Write-Host "Author: Roman Pindela (roman.pindela@gmail.com)"
    Write-Host "Version: 1.0.0"
    Write-Host "`nUsage:"
    Write-Host "  .\Invoke-RemoteCommand.ps1 -ComputerName '10.10.1.4'"
    Write-Host "  .\Invoke-RemoteCommand.ps1 -ComputerName '10.10.1.4' -RemoteCommand 'whoami'"
}

if ($ShowHelp) { Show-Help; exit }

# 1. Credentials
if (-not $Credential) { 
    $Credential = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message "Enter credentials for $($ComputerName)" 
}

# 2. Command Prompt
if ([string]::IsNullOrWhiteSpace($RemoteCommand)) {
    $RemoteCommand = Read-Host "Enter the remote command to execute"
}

if ([string]::IsNullOrWhiteSpace($RemoteCommand)) {
    Write-Warning "No command provided. Exiting."
    exit
}

# 3. Execution
try {
    Write-Host "Executing '$RemoteCommand' on $($ComputerName)..." -ForegroundColor Yellow
    
    # Konwersja tekstu na ScriptBlock
    $block = [scriptblock]::Create($RemoteCommand)
    
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $block -ErrorAction Stop
    
    Write-Host "Execution successful." -ForegroundColor Green
} catch {
    # Używamy $($ComputerName) aby uniknąć błędów parsera
    Write-Error "Failed to execute on $($ComputerName): $($_.Exception.Message)"
}