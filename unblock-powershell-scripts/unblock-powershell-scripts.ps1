<#
.SYNOPSIS
    Unblocks PowerShell scripts (.ps1, .psm1, .psd1) in a specified directory recursively.
.DESCRIPTION
    This script removes the 'Zone.Identifier' alternate data stream (Mark of the Web) 
    from PowerShell files, allowing them to run without security warnings. It supports 
    both English and Polish Windows environments and checks for Administrative privileges.
.PARAMETER Path
    The target directory path where files should be unblocked.
.PARAMETER Force
    Bypasses the confirmation prompt before unblocking files.
.PARAMETER HelpMe
    Displays the custom help menu.
.EXAMPLE
    .\unblock-powershell-scripts.ps1 -Path "C:\Users\Roman\Downloads\Scripts"
.EXAMPLE
    .\unblock-powershell-scripts.ps1 -Path "." -Force
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [alias("h", "Help")]
    [switch]$HelpMe
)

# --- CONSTANTS & METADATA ---
$SCRIPT_VERSION = "1.0.0"
$AUTHOR_NAME    = "Roman Pindela"
$AUTHOR_EMAIL   = "roman.pindela@gmail.com"
$AUTHOR_GITHUB  = "https://github.com/romanpindela"

# --- FUNCTIONS ---

function Show-ScriptHelp {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " SKCRIPT: unblock-powershell-scripts.ps1" -ForegroundColor Cyan
    Write-Host " VERSION: $SCRIPT_VERSION" -ForegroundColor Cyan
    Write-Host " AUTHOR : $AUTHOR_NAME ($AUTHOR_EMAIL)" -ForegroundColor Cyan
    Write-Host " GITHUB : $AUTHOR_GITHUB" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "`nDescription:" -ForegroundColor Yellow
    Write-Host "  Recursively unblocks PowerShell files (.ps1, .psm1, .psd1) downloaded from"
    Write-Host "  the internet (removes Mark of the Web / Zone.Identifier)."
    
    Write-Host "`nUsage / Examples:" -ForegroundColor Yellow
    Write-Host "  1. Display help menu:"
    Write-Host "     .\unblock-powershell-scripts.ps1 -Help" -ForegroundColor Green
    
    Write-Host "`n  2. Unblock files in a specific directory (with confirmation):"
    Write-Host "     .\unblock-powershell-scripts.ps1 -Path 'C:\MyScripts'" -ForegroundColor Green
    
    Write-Host "`n  3. Unblock files in current directory silently (Force):"
    Write-Host "     .\unblock-powershell-scripts.ps1 -Path '.' -Force" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
}

function Test-IsAdministrator {
    <#
        Checks if the current user runs the session with Administrator privileges.
        Supports both English ("Administrators") and Polish ("Administratorzy") OS localization
        by utilizing well-known Security Identifiers (SID: S-1-5-32-544).
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
    return $principal.IsInRole($adminSid)
}

function Invoke-SecureUnblock {
    param (
        [string]$TargetFolder,
        [bool]$BypassConfirmation
    )

    # Input Sanitization & Validation
    if (-not (Test-Path -Path $TargetFolder -PathType Container)) {
        Write-Host "[ERROR] The specified path does not exist or is not a directory: $TargetFolder" -ForegroundColor Red
        return
    }

    # Safe resolving of absolute path to prevent traversal attacks
    $resolvedPath = (Resolve-Path -Path $TargetFolder).Path
    Write-Host "[INFO] Scanning directory: $resolvedPath" -ForegroundColor DarkCyan

    # Gather PowerShell script files
    $extensions = @('*.ps1', '*.psm1', '*.psd1')
    $files = Get-ChildItem -Path $resolvedPath -Include $extensions -Recurse -File -ErrorAction SilentlyContinue

    if ($files.Count -eq 0) {
        Write-Host "[INFO] No PowerShell files found to unblock." -ForegroundColor Yellow
        return
    }

    Write-Host "[INFO] Found $($files.Count) PowerShell file(s)." -ForegroundColor Gray

    # Security confirmation step
    if (-not $BypassConfirmation) {
        $confirmation = Read-Host "Are you sure you want to unblock $($files.Count) files in '$resolvedPath'? (y/n)"
        if ($confirmation -notmatch "^(y|yes)$") {
            Write-Host "[CANCELLED] Operation aborted by the user." -ForegroundColor Yellow
            return
        }
    }

    # Processing files
    foreach ($file in $files) {
        try {
            # Check if file actually has Zone.Identifier (is blocked)
            $blocked = Get-Item -Path $file.FullName -Stream "Zone.Identifier" -ErrorAction SilentlyContinue

            if ($blocked) {
                Unblock-File -Path $file.FullName -ErrorAction Stop
                Write-Host "[UNBLOCKED] Successfully cleared: $($file.FullName)" -ForegroundColor Green
            } else {
                Write-Host "[SKIPPED] Already safe (Not blocked): $($file.FullName)" -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Host "[FAILED] Could not unblock: $($file.FullName). Reason: $_" -ForegroundColor Red
        }
    }
    Write-Host "`n[SUCCESS] Script execution finished." -ForegroundColor Cyan
}

# --- MAIN EXECUTION LOGIC ---

# 1. Trigger Help if parameter passed or if script is executed completely empty
if ($HelpMe -or ($PSBoundParameters.Count -eq 0 -and [string]::IsNullOrEmpty($Path))) {
    Show-ScriptHelp
    Exit 0
}

# 2. Enforce Administrative privileges (Multi-language safe verification using SIDs)
if (-not (Test-IsAdministrator)) {
    Write-Host "[SECURITY WARNING] This script requires Administrative privileges to modify file streams safely." -ForegroundColor Red
    Write-Host "Please restart PowerShell as Administrator." -ForegroundColor Red
    Exit 1
}

# Default to current directory if Path is omitted but other parameters (like -Force) were used
if ([string]::IsNullOrEmpty($Path)) {
    $Path = "."
}

# 3. Execute the core unblocking logic
Invoke-SecureUnblock -TargetFolder $Path -BypassConfirmation $Force