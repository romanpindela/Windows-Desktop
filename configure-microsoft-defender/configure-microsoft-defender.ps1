<#
.SYNOPSIS
    Hardening, repair, and configuration script for Microsoft Defender Antivirus and Windows Security.

.DESCRIPTION
    Configures and enforces enterprise-grade security policies for Microsoft Defender, 
    repairs underlying services (WinDefend), clears restrictive policy overrides, activates
    Cloud/MAPS protection, PUA blocking, Controlled Folder Access (Ransomware protection), 
    Windows Defender Firewall across all profiles, and SmartScreen.

.PARAMETER Run
    Mandatory switch required to apply changes to the system. If omitted, the script displays help.

.PARAMETER EnableLog
    Switch to output a detailed execution log to a text file.

.PARAMETER LogDirectory
    Target directory for execution logs. Defaults to 'C:\Logs'.

.PARAMETER Help
    Displays help and usage instructions.

.EXAMPLE
    .\configure-microsoft-defender.ps1 -Help
    Displays help and execution guidelines.

.EXAMPLE
    .\configure-microsoft-defender.ps1 -Run
    Applies configurations directly to the console without persistent file logging.

.EXAMPLE
    .\configure-microsoft-defender.ps1 -Run -EnableLog
    Applies configurations and writes a detailed log file to 'C:\Logs'.

.EXAMPLE
    .\configure-microsoft-defender.ps1 -Run -EnableLog -LogDirectory "D:\SecurityLogs"
    Applies configurations and stores the log file in a custom directory.

.NOTES
    Author:        Roman Pindela
    GitHub:        https://github.com/romanpindela
    Contact:       roman.pindela@gmail.com
    Version:       2.0.2
    Requirements:  PowerShell 5.1+, Windows 10/11 / Windows Server 2019+, Run as Administrator
#>

[CmdletBinding(DefaultParameterSetName = 'Help')]
param (
    [Parameter(ParameterSetName = 'Execute', Mandatory = $true)]
    [switch]$Run,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false)]
    [switch]$EnableLog,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(ParameterSetName = 'Help', Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ==============================================================================
# SCRIPT CONFIGURATION & METADATA
# ==============================================================================
$Script:Metadata = @{
    Name        = 'configure-microsoft-defender.ps1'
    Version     = '2.0.2'
    Author      = 'Roman Pindela'
    Company     = 'GitHub'
    GitHub      = 'https://github.com/romanpindela'
    ExecutionId = (Get-Date -Format 'yyyyMMdd_HHmmss')
}

$Script:LogFilePath = $null

# ==============================================================================
# HELP & USAGE DISPLAY
# ==============================================================================
function Show-ScriptHelp {
    [CmdletBinding()]
    param ()

    Write-Host @"
================================================================================
MICROSOFT DEFENDER HARDENING SCRIPT - HELP & USAGE
Author : Roman Pindela
Version: $($Script:Metadata.Version)
GitHub : $($Script:Metadata.GitHub)
================================================================================

SYNTAX:
    .\configure-microsoft-defender.ps1 [-Help | -h]
    .\configure-microsoft-defender.ps1 -Run [-EnableLog] [-LogDirectory <path>]

PARAMETERS:
    -Run
        Executes the remediation and configuration actions.
        Required to make any changes to the system.

    -EnableLog
        Saves a timestamped execution log to disk.
        Naming convention: yyyyMMdd_HHmmss_<Script>_<Computer>_<User>.txt

    -LogDirectory <string>
        Directory where log files will be saved. Default is 'C:\Logs'.

    -Help, -h
        Displays this help message.

EXAMPLES:
    # 1. Show Help
    .\configure-microsoft-defender.ps1 -Help

    # 2. Run remediation directly in console
    .\configure-microsoft-defender.ps1 -Run

    # 3. Run remediation and generate detailed log in C:\Logs
    .\configure-microsoft-defender.ps1 -Run -EnableLog

    # 4. Run remediation with custom log destination
    .\configure-microsoft-defender.ps1 -Run -EnableLog -LogDirectory "D:\SecurityLogs"

================================================================================
"@ -ForegroundColor Cyan
}

# ==============================================================================
# LOGGING & CONSOLE OUTPUT HELPERS
# ==============================================================================
function Initialize-Logging {
    [CmdletBinding()]
    param ()

    if (-not $EnableLog) { return }

    try {
        if (-not (Test-Path -LiteralPath $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
        }

        # Naming convention: yyyyMMdd_HHmmss_<ScriptName>_<ComputerName>_<UserName>.txt
        $sanitizedScriptName = [System.IO.Path]::GetFileNameWithoutExtension($Script:Metadata.Name)
        $fileName = "{0}_{1}_{2}_{3}.txt" -f $Script:Metadata.ExecutionId, $sanitizedScriptName, $env:COMPUTERNAME, $env:USERNAME
        $Script:LogFilePath = Join-Path -Path $LogDirectory -ChildPath $fileName

        $header = @"
================================================================================
MICROSOFT DEFENDER HARDENING AND CONFIGURATION LOG
Script Name    : $($Script:Metadata.Name)
Version        : $($Script:Metadata.Version)
Author         : $($Script:Metadata.Author)
GitHub         : $($Script:Metadata.GitHub)
Host Computer  : $env:COMPUTERNAME
User Account   : $env:USERDOMAIN\$env:USERNAME
Start Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz')
Log File Path  : $Script:LogFilePath
================================================================================
"@
        Set-Content -LiteralPath $Script:LogFilePath -Value $header -Encoding UTF8 -Force
    }
    catch {
        Write-Warning "Failed to initialize logging file at '$LogDirectory': $($_.Exception.Message). Falling back to console output only."
        $Script:LogFilePath = $null
    }
}

function Write-LogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'TITLE')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logLine = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'TITLE'   { Write-Host $Message -ForegroundColor Cyan }
        'SUCCESS' { Write-Host "  [OK] $Message" -ForegroundColor Green }
        'WARN'    { Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
        'ERROR'   { Write-Host "  [FAIL] $Message" -ForegroundColor Red }
        Default   { Write-Host "  $Message" -ForegroundColor White }
    }

    if ($Script:LogFilePath) {
        Add-Content -LiteralPath $Script:LogFilePath -Value $logLine -Encoding UTF8
    }
}

# ==============================================================================
# PRIVILEGE VERIFICATION
# ==============================================================================
function Test-IsAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ==============================================================================
# AUDIT & REMEDIATION FUNCTIONS
# ==============================================================================
function Test-InstalledAntivirusProducts {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[1/9] Inspecting registered Antivirus products..." -Level INFO

    try {
        $avProducts = Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -ErrorAction Stop

        if ($avProducts) {
            foreach ($product in $avProducts) {
                Write-LogMessage -Message "Detected security suite: $($product.displayName)" -Level INFO
            }

            $thirdParty = $avProducts | Where-Object { $_.displayName -notmatch 'Microsoft Defender|Windows Defender' }
            if ($thirdParty) {
                Write-LogMessage -Message "Third-party Antivirus detected. Windows may suppress Defender realtime modules." -Level WARN
            }
            else {
                Write-LogMessage -Message "No third-party Antivirus suites detected." -Level SUCCESS
            }
        }
        else {
            Write-LogMessage -Message "No registered Antivirus found in SecurityCenter2 namespace." -Level WARN
        }
    }
    catch {
        Write-LogMessage -Message "Unable to query SecurityCenter2 WMI/CIM namespace: $($_.Exception.Message)" -Level WARN
    }
}

function Repair-DefenderService {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[2/9] Inspecting and remediating 'WinDefend' service status..." -Level INFO

    try {
        $service = Get-Service -Name 'WinDefend' -ErrorAction Stop
        Write-LogMessage -Message "Service 'WinDefend' Current State: $($service.Status), StartupType: $($service.StartType)" -Level INFO

        if ($service.StartType -eq 'Disabled') {
            Write-LogMessage -Message "Restoring 'WinDefend' startup type to Automatic..." -Level INFO
            Set-Service -Name 'WinDefend' -StartupType Automatic -ErrorAction Stop
            Write-LogMessage -Message "'WinDefend' startup type reset to Automatic." -Level SUCCESS
        }

        if ($service.Status -ne 'Running') {
            Write-LogMessage -Message "Starting 'WinDefend' service..." -Level INFO
            Start-Service -Name 'WinDefend' -ErrorAction Stop
            Start-Sleep -Seconds 3
            Write-LogMessage -Message "'WinDefend' service is now running." -Level SUCCESS
        }
    }
    catch {
        Write-LogMessage -Message "Error inspecting or starting 'WinDefend' service: $($_.Exception.Message)" -Level ERROR
    }
}

function Remove-ObsoleteDefenderPolicies {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[3/9] Auditing restrictive registry policies and overrides..." -Level INFO

    $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
    $restrictedValues = @('DisableAntiSpyware', 'DisableAntiVirus', 'DisableRealtimeMonitoring')

    if (Test-Path -LiteralPath $policyPath) {
        $properties = Get-ItemProperty -LiteralPath $policyPath -ErrorAction SilentlyContinue

        if ($properties) {
            foreach ($val in $restrictedValues) {
                if ($properties.PSObject.Properties.Match($val).Count -gt 0) {
                    try {
                        Remove-ItemProperty -LiteralPath $policyPath -Name $val -Force -ErrorAction Stop
                        Write-LogMessage -Message "Removed restrictive registry value: $val" -Level SUCCESS
                    }
                    catch {
                        Write-LogMessage -Message "Could not remove '$val' (Check Tamper Protection): $($_.Exception.Message)" -Level WARN
                    }
                }
            }
        }
        Write-LogMessage -Message "Policy check completed for '$policyPath'." -Level SUCCESS
    }
    else {
        Write-LogMessage -Message "No disabling policy path found at '$policyPath'." -Level SUCCESS
    }
}

function Set-DefenderProtectionEngines {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[4/9] Activating core Defender protection engines..." -Level INFO

    $params = @{
        DisableRealtimeMonitoring     = $false
        DisableBehaviorMonitoring     = $false
        DisableIOAVProtection         = $false
        DisableScriptScanning         = $false
        DisableArchiveScanning        = $false
        DisableRemovableDriveScanning = $false
        DisableBlockAtFirstSeen       = $false
    }

    try {
        Set-MpPreference @params -ErrorAction Stop
        Write-LogMessage -Message "Core realtime, IOAV, behavior, and script monitoring activated." -Level SUCCESS
    }
    catch {
        Write-LogMessage -Message "Failed to apply core MpPreference settings: $($_.Exception.Message)" -Level ERROR
    }
}

function Set-CloudAndPuaProtection {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[5/9] Configuring Cloud Protection (MAPS) and PUA blocking..." -Level INFO

    try {
        Set-MpPreference -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples -PUAProtection Enabled -ErrorAction Stop
        Write-LogMessage -Message "Configured MAPS Reporting (Advanced), Sample Consent, and PUA blocking." -Level SUCCESS
    }
    catch {
        Write-LogMessage -Message "Failed to apply Cloud/PUA preferences: $($_.Exception.Message)" -Level ERROR
    }
}

function Enable-RansomwareProtection {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[6/9] Enabling Controlled Folder Access (Ransomware protection)..." -Level INFO

    try {
        Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction Stop
        Write-LogMessage -Message "Controlled Folder Access successfully enabled." -Level SUCCESS
    }
    catch {
        Write-LogMessage -Message "Failed to configure Controlled Folder Access: $($_.Exception.Message)" -Level ERROR
    }
}

function Enable-WindowsFirewallProfiles {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[7/9] Enabling Windows Defender Firewall across all network profiles..." -Level INFO

    try {
        Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True -ErrorAction Stop
        Write-LogMessage -Message "Firewall enabled on Domain, Private, and Public profiles." -Level SUCCESS
    }
    catch {
        Write-LogMessage -Message "Failed to configure Windows Firewall profiles: $($_.Exception.Message)" -Level ERROR
    }
}

function Set-SmartScreenEnforcement {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[8/9] Enforcing Windows SmartScreen policy..." -Level INFO

    $explorerRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'

    try {
        if (-not (Test-Path -LiteralPath $explorerRegPath)) {
            New-Item -Path $explorerRegPath -Force -ErrorAction Stop | Out-Null
        }

        Set-ItemProperty -LiteralPath $explorerRegPath -Name 'SmartScreenEnabled' -Type String -Value 'RequireAdmin' -Force -ErrorAction Stop
        Write-LogMessage -Message "SmartScreen set to 'RequireAdmin'." -Level SUCCESS
    }
    catch {
        Write-LogMessage -Message "Failed to set SmartScreen registry key: $($_.Exception.Message)" -Level ERROR
    }
}

function Update-DefenderSignatures {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "[9/9] Checking and triggering signature update..." -Level INFO

    try {
        Update-MpSignature -ErrorAction Stop
        Write-LogMessage -Message "Security intelligence definitions updated." -Level SUCCESS
    }
    catch {
        Write-LogMessage -Message "Signature update encountered an issue: $($_.Exception.Message)" -Level WARN
    }
}

function Test-FinalCompliance {
    [CmdletBinding()]
    param ()

    Write-LogMessage -Message "============================================" -Level TITLE
    Write-LogMessage -Message " FINAL COMPLIANCE AND STATUS VERIFICATION" -Level TITLE
    Write-LogMessage -Message "============================================" -Level TITLE

    Start-Sleep -Seconds 2

    $status = $null
    try {
        $status = Get-MpComputerStatus -ErrorAction Stop
        Write-LogMessage -Message "Defender Antivirus Enabled       : $($status.AntivirusEnabled)" -Level INFO
        Write-LogMessage -Message "Defender Antispyware Enabled     : $($status.AntispywareEnabled)" -Level INFO
        Write-LogMessage -Message "Real-Time Protection Active      : $($status.RealTimeProtectionEnabled)" -Level INFO
        Write-LogMessage -Message "Behavior Monitor Active          : $($status.BehaviorMonitorEnabled)" -Level INFO
        Write-LogMessage -Message "IOAV Protection Active           : $($status.IOAVProtectionEnabled)" -Level INFO
        Write-LogMessage -Message "AM Running Mode                  : $($status.AMRunningMode)" -Level INFO
        Write-LogMessage -Message "Tamper Protection Status         : $($status.IsTamperProtected)" -Level INFO
    }
    catch {
        Write-LogMessage -Message "Could not retrieve Get-MpComputerStatus: $($_.Exception.Message)" -Level WARN
    }

    try {
        $pref = Get-MpPreference -ErrorAction Stop
        Write-LogMessage -Message "PUA Protection                   : $($pref.PUAProtection)" -Level INFO
        Write-LogMessage -Message "Cloud Protection (MAPS) Level    : $($pref.MAPSReporting)" -Level INFO
        Write-LogMessage -Message "Controlled Folder Access         : $($pref.EnableControlledFolderAccess)" -Level INFO
    }
    catch {
        Write-LogMessage -Message "Could not retrieve Get-MpPreference: $($_.Exception.Message)" -Level WARN
    }

    if ($null -ne $status -and $status.AntivirusEnabled -and $status.RealTimeProtectionEnabled -and $status.AntispywareEnabled) {
        Write-LogMessage -Message "STATUS VERIFIED: MICROSOFT DEFENDER IS FULLY ACTIVE AND SECURING THIS WORKSTATION." -Level SUCCESS
    }
    else {
        Write-LogMessage -Message "STATUS WARNING: DEFENDER IS NOT FULLY ACTIVE. COEXISTING THIRD-PARTY ANTIVIRUS OR ENTERPRISE GPO MAY BE OVERRIDING." -Level WARN
    }

    Write-LogMessage -Message "Recommended action: Reboot the machine if service states were modified." -Level INFO
}

# ==============================================================================
# MAIN EXECUTION ENTRYPOINT
# ==============================================================================
if ($PSCmdlet.ParameterSetName -eq 'Help' -or $Help -or (-not $Run)) {
    Show-ScriptHelp
    return
}

if (-not (Test-IsAdministrator)) {
    Write-Error "CRITICAL: This script requires elevated administrative privileges. Please launch PowerShell as an Administrator."
    exit 1
}

Initialize-Logging

Write-LogMessage -Message "============================================================" -Level TITLE
Write-LogMessage -Message " MICROSOFT DEFENDER - HARDENING & REMEDIATION PIPELINE" -Level TITLE
Write-LogMessage -Message " Version $($Script:Metadata.Version) | $($Script:Metadata.Author) | $($Script:Metadata.Company)" -Level TITLE
Write-LogMessage -Message "============================================================" -Level TITLE

try {
    Test-InstalledAntivirusProducts
    Repair-DefenderService
    Remove-ObsoleteDefenderPolicies
    Set-DefenderProtectionEngines
    Set-CloudAndPuaProtection
    Enable-RansomwareProtection
    Enable-WindowsFirewallProfiles
    Set-SmartScreenEnforcement
    Update-DefenderSignatures
    Test-FinalCompliance
}
catch {
    Write-LogMessage -Message "Fatal unexpected execution failure: $($_.Exception.Message)" -Level ERROR
    exit 1
}
finally {
    if ($Script:LogFilePath) {
        Write-Host ""
        Write-Host "Detailed execution log saved to: $Script:LogFilePath" -ForegroundColor Cyan
    }
}