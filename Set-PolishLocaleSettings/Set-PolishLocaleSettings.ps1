<#
.SYNOPSIS
    Audits and configures Windows System Locale to Polish (Poland) (pl-PL / CP1250) and disables Beta UTF-8.

.DESCRIPTION
    Set-PolishLocaleSettings.ps1 inspects and enforces Windows System Locale settings for non-Unicode
    programs to Polish (Poland) (pl-PL, LCID 1045) with Central European code pages:
      - System Locale : pl-PL (LCID 1045)
      - ANSI CodePage : 1250 (Windows-1250)
      - OEM CodePage  : 852  (DOS Central European)
      - MAC CodePage  : 10029
      - Beta UTF-8    : Disabled (ensures ACP/OEMCP/MACCP are not pinned to 65001)

    This eliminates garbled Polish diacritics when opening ANSI/Windows-1250 CSV files in Microsoft Excel
    and running legacy Polish accounting/ERP applications on English or misconfigured Windows installations.

    Features:
      - Read-only -AuditOnly mode (runs without Administrator privileges).
      - Idempotent -Apply mode with full -WhatIf / -Confirm (SupportsShouldProcess) support.
      - Language-independent UAC auto-elevation using Administrators SID (S-1-5-32-544).
      - Dual compatibility with Windows PowerShell 5.1 and PowerShell 7+.
      - Structured logging to C:\Logs\ and structured [PSCustomObject] output for automation pipelines.

.PARAMETER AuditOnly
    Performs a read-only audit of the current Windows System Locale, NLS code pages (ACP, OEMCP, MACCP),
    Beta UTF-8 status, and User Culture without making any changes or requiring UAC elevation.

.PARAMETER Apply
    Configures Windows System Locale to pl-PL and enforces ACP=1250, OEMCP=852, MACCP=10029
    (disabling Beta UTF-8 if enabled). Requires Administrator privileges (auto-elevates via UAC).

.PARAMETER Restart
    Automatically restarts the computer after changes are successfully applied. Ignored if no changes
    were required or when running with -WhatIf.

.PARAMETER NoElevation
    Disables automatic UAC relaunch in -Apply mode. Fails cleanly with an error if the current session
    is not elevated (recommended for headless RMM/CI pipelines).

.PARAMETER LogPath
    Directory path where timestamped execution logs are saved. Defaults to 'C:\Logs'.

.PARAMETER NoLog
    Disables writing execution logs to disk.

.PARAMETER Help
    Displays the interactive console help screen and exits cleanly (code 0). Aliased to -h.

.EXAMPLE
    .\Set-PolishLocaleSettings.ps1 -AuditOnly
    Audits current Windows System Locale and NLS CodePage settings without requiring Administrator rights.

.EXAMPLE
    .\Set-PolishLocaleSettings.ps1 -Apply -WhatIf
    Simulates configuring Polish System Locale (pl-PL / CP1250) without modifying the system.

.EXAMPLE
    .\Set-PolishLocaleSettings.ps1 -Apply
    Configures System Locale to pl-PL, sets ACP=1250, OEMCP=852, MACCP=10029, and disables Beta UTF-8.

.EXAMPLE
    .\Set-PolishLocaleSettings.ps1 -Apply -Restart
    Applies Polish System Locale settings and automatically restarts the workstation if changes were made.

.EXAMPLE
    .\Invoke-GitHubScript.ps1 -UrlToDownload "https://github.com/romanpindela/Windows-Desktop/blob/main/Set-PolishLocaleSettings/Set-PolishLocaleSettings.ps1" -ScriptArgs "-AuditOnly"
    Downloads and runs Set-PolishLocaleSettings.ps1 in audit mode directly from GitHub.

.NOTES
    Author:        Roman Pindela
    Email:         roman.pindela@gmail.com
    GitHub:        https://github.com/romanpindela
    Version:       1.0.0
    Last Modified: 2026-11-27
    Requirements:  Windows 10/11 or Windows Server 2019+, PowerShell 5.1+ / PowerShell 7+
#>

[CmdletBinding(DefaultParameterSetName = 'Help', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(ParameterSetName = 'Audit', Mandatory = $true, HelpMessage = 'Run read-only audit of System Locale and NLS CodePage settings.')]
    [Alias('Audit')]
    [switch]$AuditOnly,

    [Parameter(ParameterSetName = 'Apply', Mandatory = $true, HelpMessage = 'Apply Polish (pl-PL / CP1250) System Locale settings.')]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'Apply', Mandatory = $false, HelpMessage = 'Restart computer automatically if changes were applied.')]
    [switch]$Restart,

    [Parameter(ParameterSetName = 'Apply', Mandatory = $false, HelpMessage = 'Disable automatic UAC relaunch when not elevated.')]
    [switch]$NoElevation,

    [Parameter(ParameterSetName = 'Audit', Mandatory = $false, HelpMessage = 'Directory for log files.')]
    [Parameter(ParameterSetName = 'Apply', Mandatory = $false, HelpMessage = 'Directory for log files.')]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath = 'C:\Logs',

    [Parameter(ParameterSetName = 'Audit', Mandatory = $false, HelpMessage = 'Disable file logging.')]
    [Parameter(ParameterSetName = 'Apply', Mandatory = $false, HelpMessage = 'Disable file logging.')]
    [switch]$NoLog,

    [Parameter(ParameterSetName = 'Help', Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    #region Constants & Script State
    $Script:ScriptName      = 'Set-PolishLocaleSettings'
    $Script:ScriptVersion   = '1.0.0'
    $Script:TargetLocale    = 'pl-PL'
    $Script:TargetACP       = '1250'
    $Script:TargetOEMCP     = '852'
    $Script:TargetMACCP     = '10029'
    $Script:CodePageRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage'
    $Script:LogFilePath     = $null
    #endregion Constants & Script State

#region Helper Functions
function Initialize-LogFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DirectoryPath
    )

    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        New-Item -Path $DirectoryPath -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $fileName  = '{0}-{1}-{2}-{3}.log' -f $timestamp, $Script:ScriptName, $env:COMPUTERNAME, $env:USERNAME
    $Script:LogFilePath = Join-Path -Path $DirectoryPath -ChildPath $fileName

    $header = '[{0}] [INFO] Log initialized for {1} v{2} on {3} (User: {4})' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Script:ScriptName, $Script:ScriptVersion, $env:COMPUTERNAME, $env:USERNAME
    [System.IO.File]::AppendAllText($Script:LogFilePath, $header + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
}

function Write-Log {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive color-coded console UI is required by repository standard.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line      = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message

    $color = switch ($Level) {
        'INFO'    { 'Gray' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
    }

    Write-Host $line -ForegroundColor $color

    if (-not [string]::IsNullOrWhiteSpace($Script:LogFilePath)) {
        try {
            [System.IO.File]::AppendAllText($Script:LogFilePath, $line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
        }
        catch {
            Write-Warning ("Failed to write to log file '{0}': {1}" -f $Script:LogFilePath, $_.Exception.Message)
        }
    }
}

function Test-IsAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList $identity
    $adminSid  = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-32-544'
    return $principal.IsInRole($adminSid)
}

function Invoke-SelfElevation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$BoundParams
    )

    $pwshExe = (Get-Process -Id $PID).Path
    if ([string]::IsNullOrWhiteSpace($pwshExe)) {
        $pwshExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    }

    $argList = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $argList.Add('-NoProfile')
    $argList.Add('-ExecutionPolicy')
    $argList.Add('Bypass')
    $argList.Add('-File')
    $argList.Add(('"{0}"' -f $ScriptPath))

    foreach ($entry in $BoundParams.GetEnumerator()) {
        if ($entry.Value -is [switch]) {
            if ($entry.Value.IsPresent) {
                $argList.Add(('-{0}' -f $entry.Key))
            }
        }
        elseif ($null -ne $entry.Value) {
            $argList.Add(('-{0}' -f $entry.Key))
            $argList.Add(('"{0}"' -f ($entry.Value.ToString().Replace('"', '\"'))))
        }
    }

    Write-Log -Message 'Administrator privileges (SID S-1-5-32-544) are required for -Apply. Requesting UAC elevation...' -Level 'WARN'
    $proc = Start-Process -FilePath $pwshExe -ArgumentList ($argList -join ' ') -Verb RunAs -PassThru -Wait
    exit $proc.ExitCode
}

function Show-ScriptHelp {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive color-coded console help screen is required by repository standard.')]
    [CmdletBinding()]
    param ()

    Write-Host ''
    Write-Host '=========================================================================' -ForegroundColor Cyan
    Write-Host ("  {0} v{1} - Polish System Locale (pl-PL / CP1250) Utility" -f $Script:ScriptName, $Script:ScriptVersion) -ForegroundColor White
    Write-Host '=========================================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'DESCRIPTION:' -ForegroundColor Yellow
    Write-Host '  Audits and configures Windows System Locale (Language for non-Unicode programs)' -ForegroundColor Gray
    Write-Host '  to Polish (pl-PL) with ACP=1250, OEMCP=852, MACCP=10029 and disables Beta UTF-8.' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'USAGE:' -ForegroundColor Yellow
    Write-Host '  .\Set-PolishLocaleSettings.ps1 -AuditOnly [-LogPath <Dir>] [-NoLog]' -ForegroundColor Green
    Write-Host '  .\Set-PolishLocaleSettings.ps1 -Apply [-Restart] [-NoElevation] [-WhatIf] [-Confirm]' -ForegroundColor Green
    Write-Host '  .\Set-PolishLocaleSettings.ps1 -Help' -ForegroundColor Green
    Write-Host ''
    Write-Host 'PARAMETERS:' -ForegroundColor Yellow
    Write-Host '  -AuditOnly (-Audit)  Read-only inspection of System Locale, ACP/OEMCP/MACCP, and Beta UTF-8.' -ForegroundColor Gray
    Write-Host '  -Apply               Configure System Locale to pl-PL, ACP=1250, OEMCP=852, MACCP=10029.' -ForegroundColor Gray
    Write-Host '  -Restart             Automatically reboot if changes were applied (skipped on -WhatIf).' -ForegroundColor Gray
    Write-Host '  -NoElevation         Do not trigger UAC prompt; fail cleanly if not elevated.' -ForegroundColor Gray
    Write-Host '  -LogPath <String>    Target directory for log files (Default: C:\Logs).' -ForegroundColor Gray
    Write-Host '  -NoLog               Disable writing execution log files.' -ForegroundColor Gray
    Write-Host '  -Help (-h)           Display this help screen and exit.' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'EXAMPLES:' -ForegroundColor Yellow
    Write-Host '  .\Set-PolishLocaleSettings.ps1 -AuditOnly' -ForegroundColor White
    Write-Host '  .\Set-PolishLocaleSettings.ps1 -Apply -WhatIf' -ForegroundColor White
    Write-Host '  .\Set-PolishLocaleSettings.ps1 -Apply -Restart' -ForegroundColor White
    Write-Host ''
    Write-Host 'AUTHOR: Roman Pindela (roman.pindela@gmail.com) | https://github.com/romanpindela' -ForegroundColor DarkGray
    Write-Host ''
}

function Get-LocaleState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param ()

    if (-not (Get-Command -Name 'Get-WinSystemLocale' -ErrorAction SilentlyContinue)) {
        Import-Module -Name 'International' -ErrorAction Stop
    }

    $sysLocale   = Get-WinSystemLocale
    $userCulture = Get-Culture
    $codePage    = Get-ItemProperty -LiteralPath $Script:CodePageRegPath -ErrorAction Stop

    $acp   = [string]$codePage.ACP
    $oemcp = [string]$codePage.OEMCP
    $maccp = [string]$codePage.MACCP

    $utf8BetaEnabled = ($acp -eq '65001') -or ($oemcp -eq '65001')
    $isCompliant     = ($sysLocale.Name -ieq $Script:TargetLocale) -and
                       ($acp -eq $Script:TargetACP) -and
                       ($oemcp -eq $Script:TargetOEMCP) -and
                       ($maccp -eq $Script:TargetMACCP) -and
                       (-not $utf8BetaEnabled)

    return [PSCustomObject]@{
        SystemLocaleName        = $sysLocale.Name
        SystemLocaleDisplayName = $sysLocale.DisplayName
        SystemLocaleLCID        = $sysLocale.LCID
        ACP                     = $acp
        OEMCP                   = $oemcp
        MACCP                   = $maccp
        Utf8BetaEnabled         = $utf8BetaEnabled
        UserCulture             = $userCulture.Name
        IsCompliant             = $isCompliant
    }
}

function Write-LocaleStatusBanner {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive color-coded console UI is required by repository standard.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$State,

        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ''
    Write-Host ("--- {0} ---" -f $Title) -ForegroundColor Cyan
    Write-Host ("  System Locale : {0} ({1}, LCID: {2})" -f $State.SystemLocaleName, $State.SystemLocaleDisplayName, $State.SystemLocaleLCID) -ForegroundColor $(if ($State.SystemLocaleName -ieq $Script:TargetLocale) { 'Green' } else { 'Yellow' })
    Write-Host ("  ACP  (ANSI)   : {0} (Target: {1})" -f $State.ACP, $Script:TargetACP) -ForegroundColor $(if ($State.ACP -eq $Script:TargetACP) { 'Green' } else { 'Yellow' })
    Write-Host ("  OEMCP (OEM)   : {0} (Target: {1})" -f $State.OEMCP, $Script:TargetOEMCP) -ForegroundColor $(if ($State.OEMCP -eq $Script:TargetOEMCP) { 'Green' } else { 'Yellow' })
    Write-Host ("  MACCP (MAC)   : {0} (Target: {1})" -f $State.MACCP, $Script:TargetMACCP) -ForegroundColor $(if ($State.MACCP -eq $Script:TargetMACCP) { 'Green' } else { 'Yellow' })
    Write-Host ("  Beta UTF-8    : {0} (Target: False)" -f $State.Utf8BetaEnabled) -ForegroundColor $(if (-not $State.Utf8BetaEnabled) { 'Green' } else { 'Red' })
    Write-Host ("  User Culture  : {0}" -f $State.UserCulture) -ForegroundColor Gray
    Write-Host ("  Compliant     : {0}" -f $State.IsCompliant) -ForegroundColor $(if ($State.IsCompliant) { 'Green' } else { 'Yellow' })
    Write-Host ''
}
#endregion Helper Functions

    if ($PSCmdlet.ParameterSetName -eq 'Help' -or $Help.IsPresent -or $PSBoundParameters.Count -eq 0) {
        Show-ScriptHelp
        exit 0
    }

    if ($Apply.IsPresent -and -not (Test-IsAdministrator)) {
        if ($NoElevation.IsPresent) {
            throw 'Administrator privileges (SID S-1-5-32-544) are required for -Apply mode. Re-run from an elevated PowerShell session.'
        }
        Invoke-SelfElevation -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters
    }

    if (-not $NoLog.IsPresent) {
        try {
            Initialize-LogFile -DirectoryPath $LogPath
        }
        catch {
            Write-Warning ("Unable to initialize log directory '{0}': {1}. Continuing without file logging." -f $LogPath, $_.Exception.Message)
            $Script:LogFilePath = $null
        }
    }
}

process {
    try {
        $mode = if ($AuditOnly.IsPresent) { 'AuditOnly' } else { 'Apply' }
        Write-Log -Message ("Starting {0} v{1} in '{2}' mode." -f $Script:ScriptName, $Script:ScriptVersion, $mode) -Level 'INFO'

        $beforeState = Get-LocaleState
        Write-LocaleStatusBanner -State $beforeState -Title 'Current Windows Locale & CodePage State'
        Write-Log -Message ("Before: SystemLocale={0}, ACP={1}, OEMCP={2}, MACCP={3}, Utf8Beta={4}, Compliant={5}" -f `
            $beforeState.SystemLocaleName, $beforeState.ACP, $beforeState.OEMCP, $beforeState.MACCP, $beforeState.Utf8BetaEnabled, $beforeState.IsCompliant) -Level 'INFO'

        $changesApplied = $false
        $rebootRequired = $false

        if ($Apply.IsPresent) {
            if ($beforeState.IsCompliant) {
                Write-Log -Message 'System is already compliant with Polish System Locale (pl-PL / CP1250). No changes required.' -Level 'SUCCESS'
            }
            else {
                if ($beforeState.SystemLocaleName -ine $Script:TargetLocale) {
                    $targetDesc = "Windows System Locale on '$env:COMPUTERNAME'"
                    if ($PSCmdlet.ShouldProcess($targetDesc, ("Set System Locale from '{0}' to '{1}'" -f $beforeState.SystemLocaleName, $Script:TargetLocale))) {
                        Set-WinSystemLocale -SystemLocale $Script:TargetLocale
                        $changesApplied = $true
                        $rebootRequired = $true
                        Write-Log -Message ("Set Windows System Locale to '{0}'." -f $Script:TargetLocale) -Level 'SUCCESS'
                    }
                }

                $codePageTargets = [ordered]@{
                    ACP   = $Script:TargetACP
                    OEMCP = $Script:TargetOEMCP
                    MACCP = $Script:TargetMACCP
                }

                foreach ($cpName in $codePageTargets.Keys) {
                    $desiredVal = $codePageTargets[$cpName]
                    $currentVal = [string](Get-ItemPropertyValue -LiteralPath $Script:CodePageRegPath -Name $cpName)

                    if ($currentVal -ne $desiredVal) {
                        $regTarget = "{0}\{1}" -f $Script:CodePageRegPath, $cpName
                        if ($PSCmdlet.ShouldProcess($regTarget, ("Set registry value from '{0}' to '{1}'" -f $currentVal, $desiredVal))) {
                            Set-ItemProperty -LiteralPath $Script:CodePageRegPath -Name $cpName -Value $desiredVal -Type String
                            $changesApplied = $true
                            $rebootRequired = $true
                            Write-Log -Message ("Updated {0} from '{1}' to '{2}'." -f $cpName, $currentVal, $desiredVal) -Level 'SUCCESS'
                        }
                    }
                }
            }
        }

        $afterState = Get-LocaleState

        if ($Apply.IsPresent -and $changesApplied) {
            Write-LocaleStatusBanner -State $afterState -Title 'Updated Windows Locale & CodePage State'
            Write-Log -Message 'Polish System Locale configuration completed. A system restart is required for all applications to pick up CP1250.' -Level 'WARN'
        }
        elseif ($AuditOnly.IsPresent) {
            if ($afterState.IsCompliant) {
                Write-Log -Message 'Audit PASSED: System Locale is compliant with pl-PL / CP1250.' -Level 'SUCCESS'
            }
            else {
                Write-Log -Message 'Audit NON-COMPLIANT: Run with -Apply to configure Polish System Locale (pl-PL / CP1250).' -Level 'WARN'
            }
        }

        $result = [PSCustomObject]@{
            ComputerName       = $env:COMPUTERNAME
            Timestamp          = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Mode               = $mode
            SystemLocaleBefore = $beforeState.SystemLocaleName
            SystemLocaleAfter  = $afterState.SystemLocaleName
            ACPBefore          = $beforeState.ACP
            ACPAfter           = $afterState.ACP
            OEMCPBefore        = $beforeState.OEMCP
            OEMCPAfter         = $afterState.OEMCP
            MACCPBefore        = $beforeState.MACCP
            MACCPAfter         = $afterState.MACCP
            Utf8BetaBefore     = $beforeState.Utf8BetaEnabled
            Utf8BetaAfter      = $afterState.Utf8BetaEnabled
            UserCulture        = $afterState.UserCulture
            IsCompliant        = $afterState.IsCompliant
            ChangesApplied     = $changesApplied
            RebootRequired     = $rebootRequired
            LogFile            = $Script:LogFilePath
        }

        Write-Output $result

        if ($Apply.IsPresent -and $Restart.IsPresent -and $rebootRequired) {
            if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Restart computer to apply new System Locale and CodePage settings')) {
                Write-Log -Message 'Initiating system restart as requested via -Restart...' -Level 'WARN'
                Restart-Computer -Force
            }
        }
    }
    catch {
        Write-Log -Message ("Unhandled error: {0}" -f $_.Exception.Message) -Level 'ERROR'
        throw
    }
}

end {
    if (-not [string]::IsNullOrWhiteSpace($Script:LogFilePath)) {
        Write-Log -Message ("Execution finished. Log saved to: {0}" -f $Script:LogFilePath) -Level 'INFO'
    }
}
