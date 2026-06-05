<#
.SYNOPSIS
    Executes a local PowerShell script file on a remote machine.
.DESCRIPTION
    Reads the content of a local .ps1 script file and executes it on a 
    target remote computer using WinRM (PSSession) and provided credentials.
    It does not copy the file to the remote disk, executing it straight into memory.
.PARAMETER ComputerName
    The target remote computer hostname or IP address.
.PARAMETER ScriptPath
    The path to the local .ps1 script file that you want to execute.
.PARAMETER Credential
    Optional PSCredential object. If not provided, you will be prompted.
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.0.0
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$ComputerName,

    [Parameter(Mandatory=$false)]
    [string]$ScriptPath,

    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

$ScriptVersion = "1.0.0"

function Show-Help {
    Write-Host ""
    Write-Host "INVOKE-REMOTESCRIPT v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Execute local .ps1 scripts on remote machines via WinRM"
    Write-Host ""

    Write-Host "DESCRIPTION"
    Write-Host "    Reads a local script file and executes it securely on a remote"
    Write-Host "    target system within a WinRM session."
    Write-Host ""

    Write-Host "USAGE"
    Write-Host "    .\invoke-remote-script -ComputerName <String> -ScriptPath <String>"
    Write-Host ""

    Write-Host "PARAMETERS"
    Write-Host "    -ComputerName  Hostname or IP address of the target computer."
    Write-Host "    -ScriptPath    Path to the local .ps1 script to execute."
    Write-Host "    -Credential    Optional pre-defined network credentials."
    Write-Host "    -h, -Help      Display this structured help screen."
    Write-Host ""

    Write-Host "EXAMPLES"
    Write-Host "    .\invoke-remote-script -ComputerName 'SRV-PROD01' -ScriptPath 'C:\Scripts\Get-Audit.ps1'"
    Write-Host "    .\invoke-remote-script -ComputerName '10.10.1.5' -ScriptPath '.\HealthCheck.ps1'"
    Write-Host ""

    Write-Host "CONTACT & INFO"
    Write-Host "    Author : Roman Pindela"
    Write-Host "    Email  : roman.pindela@gmail.com"
    Write-Host "    GitHub : https://github.com/romanpindela"
    Write-Host ""
}

# 1. Input Validation & Help Trigger (Basic protection against empty execution)
if ($ShowHelp -or [string]::IsNullOrWhiteSpace($ComputerName) -or [string]::IsNullOrWhiteSpace($ScriptPath)) {
    Show-Help
    exit
}

# 2. Input Sanitize & Security Checks
if (-not (Test-Path -Path $ScriptPath -PathType Leaf)) {
    Write-Error "Security/IO Error: The local script file '$ScriptPath' was not found or is invalid."
    exit
}

if ($ScriptPath -notlike "*.ps1") {
    Write-Error "Validation Error: Target file must have a .ps1 extension."
    exit
}

try {
    Write-Host ""
    Write-Host "Invoke-RemoteScript v$ScriptVersion" -ForegroundColor Green
    Write-Host "Target: $ComputerName"
    Write-Host "Script: $ScriptPath"
    Write-Host ""

    # 3. Handle Credentials safely
    if (-not $Credential) { 
        $Credential = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message "Enter credentials for $ComputerName" 
    }

    # 4. Read local script and convert to a secure ScriptBlock
    Write-Host "Reading local script content..." -ForegroundColor Yellow
    $ScriptContent = Get-Content -Path $ScriptPath -Raw
    
    if ([string]::IsNullOrWhiteSpace($ScriptContent)) {
        throw "The script file is empty. Nothing to execute."
    }

    $ScriptBlock = [scriptblock]::Create($ScriptContent)

    # 5. Remote Execution
    Write-Host "Connecting and executing on $ComputerName..." -ForegroundColor Yellow
    
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $ScriptBlock -ErrorAction Stop

    Write-Host ""
    Write-Host "Remote execution completed successfully." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Error "Execution failed on $ComputerName. Reason: $($_.Exception.Message)"
    Write-Host ""
}