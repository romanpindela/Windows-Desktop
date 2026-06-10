# Script: enable-remote-management.ps1

<#
.SYNOPSIS
    Enables local PowerShell Remoting and provisions remote access permissions for a specific user.
.DESCRIPTION
    Executes locally to enable WinRM (PSRemoting) using default firewall rules, validates
    the existence of the target user account, grants explicit Remote Management access rights,
    and outputs a final summary of all authorized users.
.PARAMETER TargetUser
    The SamAccountName or Domain\User string of the user who needs to be granted remote access capabilities.
    Defaults to 'Administrator'.
.PARAMETER TrustedHostPattern
    The IP or hostname pattern to add to the WinRM TrustedHosts list (e.g., '*', '10.10.1.*').
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.5.0
    ATTENTION: This script provisions WinRM with default firewall scope (Any/Any). 
    If subnet restrictions are required, custom network firewall inbound rules must be manually deployed.
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$TargetUser = "Administrator",

    [Parameter(Mandatory=$false)]
    [string]$TrustedHostPattern,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

$ScriptVersion = "1.5.0"

function Show-Help {
    Write-Host ""
    Write-Host "enable-remote-management v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Local PSRemoting Setup & User Access Provisioning Utility"
    Write-Host ""
    Write-Host "DESCRIPTION"
    Write-Host "    Enables the local WinRM infrastructure, verifies user account existence,"
    Write-Host "    grants remote entry rights, and displays a summary of all authorized accounts."
    Write-Host ""
    Write-Host "USAGE"
    Write-Host "    .\enable-remote-management.ps1 -TargetUser <String> -TrustedHostPattern <String>"
    Write-Host ""
    Write-Host "PARAMETERS"
    Write-Host "    -TargetUser          The user account to authorize (Local or Domain\User). Defaults to 'Administrator'."
    Write-Host "    -TrustedHostPattern  Optional WSMan client routing trust pattern (e.g., '10.10.1.*')."
    Write-Host "    -h, -Help            Display this structured help screen."
    Write-Host ""
    Write-Host "ATTENTION / REMARKS"
    Write-Host "    * Accounts are strictly validated. If the specified user does not exist, execution terminates immediately."
    Write-Host "    * By default, Windows Firewall settings allow traffic from Any source."
    Write-Host "    * If network-level restrictions are required, you must deploy a custom inbound rule in Windows Firewall."
    Write-Host ""
    Write-Host "EXAMPLES"
    Write-Host "    # Enable PSRemoting and grant access to the default Administrator:"
    Write-Host "    .\enable-remote-management.ps1"
    Write-Host ""
    Write-Host "    # Grant remote access to a specific account (verifies existence first):"
    Write-Host "    .\enable-remote-management.ps1 -TargetUser 'rpindela'"
    Write-Host ""
    Write-Host "CONTACT & INFO"
    Write-Host "    Author : Roman Pindela"
    Write-Host "    Email  : roman.pindela@gmail.com"
    Write-Host "    GitHub : https://github.com/romanpindela"
    Write-Host ""
}

# 1. Standard Help and Self-Protection Trigger
if ($ShowHelp) {
    Show-Help
    exit
}

# 2. Strict Administrative Rights & Security Token Verification
$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
$IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # If not running as Admin, prompt for UAC consent and relaunch the script with elevated privileges
    Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

$ScriptSuccess = $false

try {
    Write-Host ""
    Write-Host "enable-remote-management v$ScriptVersion" -ForegroundColor Green
    Write-Host "Target Authorization User: $TargetUser"
    Write-Host "--------------------------------------------------"

    # 3. Execution Policy Configuration
    Write-Host "[1/5] Setting Execution Policy to RemoteSigned for CurrentUser..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    
    Write-Host "--- Execution Policy List ---" -ForegroundColor Cyan
    $Policies = Get-ExecutionPolicy -List
    foreach ($Policy in $Policies) {
        if ($Policy.ExecutionPolicy -eq 'Undefined') {
            Write-Host "  > $($Policy.Scope): $($Policy.ExecutionPolicy)" -ForegroundColor DarkGray
        } elseif ($Policy.ExecutionPolicy -eq 'RemoteSigned' -or $Policy.ExecutionPolicy -eq 'Bypass' -or $Policy.ExecutionPolicy -eq 'Unrestricted') {
            Write-Host "  > $($Policy.Scope): $($Policy.ExecutionPolicy)" -ForegroundColor Green
        } else {
            Write-Host "  > $($Policy.Scope): $($Policy.ExecutionPolicy)" -ForegroundColor Yellow
        }
    }

    # 3. User Existence Verification Block
    Write-Host "`n[2/5] Verifying account existence for '$TargetUser'..." -ForegroundColor Yellow
    
    $UserExists = $false
    if ($TargetUser -like "*\*") {
        # Active Directory / Domain Account Format Validation check
        try {
            $Domain, $User = $TargetUser -split '\\'
            $Context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $Domain)
            $DomainUser = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($Context, $User)
            if ($DomainUser) { $UserExists = $true }
        } catch {
            $UserExists = $false
        }
    } else {
        # Local Account Check
        $LocalCheck = Get-LocalUser -Name $TargetUser -ErrorAction SilentlyContinue
        if ($LocalCheck) { $UserExists = $true }
    }

    if (-not $UserExists) {
        Write-Host "" -BackgroundColor Black
        Write-Host "ERROR: User account '$TargetUser' does not exist in the system or accessible domain context." -ForegroundColor Red -BackgroundColor Black
        Write-Host "Execution aborted to protect system consistency." -ForegroundColor Red
        Write-Host ""
        exit
    }
    Write-Host "Account validated successfully." -ForegroundColor Green

    # 4. Explicitly Turning on PowerShell Remoting locally
    Write-Host "`n[3/5] Enabling local PowerShell Remoting infrastructure..." -ForegroundColor Yellow
    Enable-PSRemoting -Force -ErrorAction Stop

    # 5. Adding Specified User to the Security Group
    Write-Host "[4/5] Provisioning access rights for user '$TargetUser'..." -ForegroundColor Yellow
    # Resolving local group dynamically via SID (S-1-5-32-580) to support Polish/English OS
    $TargetGroupObj = Get-LocalGroup -SID "S-1-5-32-580" -ErrorAction Stop
    $TargetGroupName = $TargetGroupObj.Name
    
    # Check if user is already a member to prevent non-breaking noise errors
    $GroupCheck = Get-LocalGroupMember -Group $TargetGroupName -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$TargetUser*" }

    if (-not $GroupCheck) {
        Add-LocalGroupMember -Group $TargetGroupName -Member $TargetUser -ErrorAction Stop
        Write-Host "STATUS: User '$TargetUser' successfully assigned to the '$TargetGroupName' group." -ForegroundColor Green
    } else {
        Write-Host "STATUS: User '$TargetUser' is already a member of '$TargetGroupName'." -ForegroundColor Cyan
    }

    # 6. Optional TrustedHosts Configuration Matrix
    if (-not [string]::IsNullOrWhiteSpace($TrustedHostPattern)) {
        Write-Host "[5/5] Committing TrustedHosts client pattern: $TrustedHostPattern" -ForegroundColor Yellow
        Set-Item -Path "WSMan:\localhost\Client\TrustedHosts" -Value $TrustedHostPattern -Force -ErrorAction Stop
    } else {
        Write-Host "[5/5] Skipping TrustedHosts client step (No pattern specified)." -ForegroundColor Gray
    }

    $ScriptSuccess = $true
}
catch {
    Write-Host ""
    Write-Host "STATUS: FAILED" -ForegroundColor Red
    Write-Error "Infrastructure Management Fault: $($_.Exception.Message)"
}
finally {
    # 7. Final Summary of Authorized Accounts
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "AUTHORIZED REMOTE MANAGEMENT USERS SUMMARY" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    
    Write-Host "The following local/domain accounts have native rights to start remote sessions:" -ForegroundColor Gray
    Write-Host ""
    
    $RemoteGroupObj = Get-LocalGroup -SID "S-1-5-32-580" -ErrorAction SilentlyContinue
    if ($RemoteGroupObj) {
        Write-Host "--- [Group: $($RemoteGroupObj.Name)] ---" -ForegroundColor Yellow
        $RemoteUsers = Get-LocalGroupMember -Group $RemoteGroupObj.Name -ErrorAction SilentlyContinue
        if ($RemoteUsers) {
            foreach ($User in $RemoteUsers) {
                Write-Host "  > $($User.Name) ($($User.PrincipalSource))" -ForegroundColor Green
            }
        } else {
            Write-Host "  (No explicit members found in this group)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    $AdminGroupObj = Get-LocalGroup -SID "S-1-5-32-544" -ErrorAction SilentlyContinue
    if ($AdminGroupObj) {
        Write-Host "--- [Group: $($AdminGroupObj.Name) (Implicit Access)] ---" -ForegroundColor Yellow
        $AdminUsers = Get-LocalGroupMember -Group $AdminGroupObj.Name -ErrorAction SilentlyContinue
        if ($AdminUsers) {
            foreach ($Admin in $AdminUsers) {
                Write-Host "  > $($Admin.Name) ($($Admin.PrincipalSource))" -ForegroundColor Cyan
            }
        }
    }
    
    Write-Host ""
    if ($ScriptSuccess) {
        Write-Host "SUCCESS: Execution completed without fatal interruptions." -ForegroundColor Green
    } else {
        Write-Host "TERMINATED: Execution finished with errors or was aborted." -ForegroundColor Red
    }
    Write-Host ""
}
