<#
.SYNOPSIS
    Schedules, idempotently updates, inspects, or cancels a one-time Windows hibernation task
    without requiring administrator (UAC) elevation.

.DESCRIPTION
    Set-ScheduledHibernation.ps1 automates one-time hibernation scheduling via Windows Task Scheduler
    (C:\Windows\System32\shutdown.exe /h) for the currently logged-on interactive user.

    Unlike 'shutdown.exe /s /t' or '/r /t', Windows 'shutdown.exe /h' does not support a built-in
    delay timer. Manual Task Scheduler configuration also blocks execution on laptop battery power
    by default and leaves stale task entries behind after one-time execution.

    Core capabilities:
      1. Automatic Registration & Idempotent Rescheduling:
         - First invocation registers a one-time scheduled task bound to the current user's SID
           (LogonType Interactive, RunLevel Limited — no UAC elevation required).
         - Subsequent invocations with a new relative delay (-In "+2h") or absolute time/date
           (-At "22:30" or -At "2026-11-27 01:15") automatically update the existing task in place
           and display both the previous and newly scheduled execution timestamps.
      2. Flexible Time Specification:
         - Relative offsets (-In): supports composite tokens and decimals with optional '+' prefix
           (e.g., "+2h", "45m", "+1h30m", "1.5h", "+1d 2h").
         - Absolute timestamps (-At): supports ISO-8601, European (dd.MM.yyyy HH:mm), and time-only
           values (HH:mm) with smart next-day rollover when the time has already passed today.
      3. Laptop-Safe Task Scheduler Policy:
         - Runs on battery power by default (override with -DisallowOnBattery).
         - Never executes missed triggers retroactively (StartWhenAvailable = $false).
         - Automatically expires and deletes itself after the configured expiration window.
         - Optional -WakeToRun switch (disabled by default for laptop-in-bag safety).
      4. OS Language-Independent Hibernation Verification:
         - Checks HKLM:\SYSTEM\CurrentControlSet\Control\Power (HibernateEnabled) and hiberfil.sys
           existence without parsing localized powercfg text (works identically on PL/EN Windows).
      5. Inspection, Cancellation, Simulation & Logging:
         - Full -Status inspection, -Remove (-Cancel) unregistration, -WhatIf / -Confirm support,
           pipeline output via -PassThru, and default UTF-8 logging to C:\Logs\ (with automatic
           fallback to %TEMP%\Logs when C:\Logs is not writable).

.PARAMETER In
    Relative delay from now until hibernation. Supports optional '+' prefix, spaces, decimals,
    and unit tokens 'd' (days), 'h' (hours), 'm' (minutes), 's' (seconds).
    Examples: "+2h", "45m", "+1h30m", "1.5h", "+1d 2h".
    Aliases: -Delay, -After, -Offset

.PARAMETER At
    Absolute target time or date and time for hibernation.
    Supports time-only values ("22:30", "01:15:00" — automatically schedules for tomorrow if the
    clock time has already passed today) and full timestamps ("2026-11-26 22:30",
    "2026-11-26T22:30", "26.11.2026 22:30").
    Aliases: -Time, -DateTime

.PARAMETER Status
    Displays the current state, scheduled execution time, remaining countdown, battery/expiration
    settings, and system hibernation readiness for the scheduled hibernation task.
    Aliases: -Show, -Info

.PARAMETER Remove
    Cancels and unregisters the scheduled hibernation task from Windows Task Scheduler.
    Supports -WhatIf and -Confirm.
    Aliases: -Cancel, -Delete, -Unregister

.PARAMETER TaskName
    Name of the Windows Task Scheduler task registered in the root task folder ('\').
    Default: 'ScheduledHibernation'.
    Aliases: -Name

.PARAMETER ExpirationMinutes
    Number of minutes after the scheduled run time when the one-time trigger expires (EndBoundary)
    and Task Scheduler automatically removes the expired task (DeleteExpiredTaskAfter = PT1M).
    Valid range: 1 to 1440. Default: 5.
    Aliases: -ExpireAfter

.PARAMETER DisallowOnBattery
    Prevents the scheduled hibernation task from starting if the computer is running on battery
    power. By default, battery execution is enabled for laptops and notebooks.

.PARAMETER WakeToRun
    Configures Windows Task Scheduler to attempt waking the system from Sleep (S3/S0) at the
    scheduled time to transition into Hibernation. Disabled by default for bag safety.

.PARAMETER Force
    Bypasses interactive confirmation prompts and permits task registration even if the system
    hibernation readiness check indicates that hibernation is currently disabled.

.PARAMETER LogDirectory
    Target directory for UTF-8 execution logs. Falls back automatically to '%TEMP%\Logs' if the
    preferred directory cannot be created or written to by the current user.
    Default: 'C:\Logs'.
    Aliases: -LogPath

.PARAMETER NoLog
    Disables writing execution log files (file logging to C:\Logs\ is enabled by default).

.PARAMETER PassThru
    Emits the structured [PSCustomObject] result to the PowerShell output pipeline in addition to
    the formatted console summary.

.PARAMETER Help
    Displays the interactive colorized console help screen and exits cleanly without modifying
    system state or writing log files. Also displayed when invoked with zero parameters.
    Aliases: -h

.EXAMPLE
    .\Set-ScheduledHibernation.ps1
    Displays interactive console help, parameter summary, and usage examples.

.EXAMPLE
    .\Set-ScheduledHibernation.ps1 -In "+2h"
    Registers (or updates) the 'ScheduledHibernation' task to hibernate the computer in 2 hours.

.EXAMPLE
    .\Set-ScheduledHibernation.ps1 -In "+1h30m"
    Updates the existing scheduled hibernation task to 1 hour and 30 minutes from now and displays
    both the previous and updated execution timestamps.

.EXAMPLE
    .\Set-ScheduledHibernation.ps1 -At "23:30"
    Schedules hibernation for 23:30 today (or 23:30 tomorrow if 23:30 has already passed).

.EXAMPLE
    .\Set-ScheduledHibernation.ps1 -At "2026-11-27 01:15" -DisallowOnBattery
    Schedules hibernation for a specific date and time, running only when connected to AC power.

.EXAMPLE
    .\Set-ScheduledHibernation.ps1 -Status
    Displays the active scheduled hibernation task status, countdown, and hibernation readiness.

.EXAMPLE
    .\Set-ScheduledHibernation.ps1 -Remove
    Cancels and removes the scheduled hibernation task.

.EXAMPLE
    .\Set-ScheduledHibernation.ps1 -In "+45m" -WhatIf
    Previews the exact target time and Task Scheduler configuration without making system changes.

.EXAMPLE
    $result = .\Set-ScheduledHibernation.ps1 -In "+2h" -PassThru
    $result | Select-Object Action, TaskName, ScheduledRunTime, RemainingTime
    Schedules hibernation and captures the structured result object from the pipeline.

.EXAMPLE
    .\Invoke-GitHubScript.ps1 -UrlToDownload "https://github.com/romanpindela/Windows-Desktop/blob/main/Set-ScheduledHibernation/Set-ScheduledHibernation.ps1" -ScriptArgs "-In '+2h'"
    Downloads and executes Set-ScheduledHibernation.ps1 directly from GitHub.

.NOTES
    Author        : Roman Pindela
    Email         : roman.pindela@gmail.com
    GitHub        : https://github.com/romanpindela
    Version       : 1.0.0
    Last Modified : 2026-11-26
    License       : MIT
    Compatibility : Windows PowerShell 5.1 & PowerShell 7+ (Windows 10 / 11 / Server)
#>

[CmdletBinding(DefaultParameterSetName = 'Default', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Relative', Position = 0)]
    [Alias('Delay', 'After', 'Offset')]
    [ValidateNotNullOrEmpty()]
    [string]$In,

    [Parameter(Mandatory = $true, ParameterSetName = 'Absolute')]
    [Alias('Time', 'DateTime')]
    [ValidateNotNullOrEmpty()]
    [string]$At,

    [Parameter(Mandatory = $true, ParameterSetName = 'Status')]
    [Alias('Show', 'Info')]
    [switch]$Status,

    [Parameter(Mandatory = $true, ParameterSetName = 'Remove')]
    [Alias('Cancel', 'Delete', 'Unregister')]
    [switch]$Remove,

    [Parameter(Mandatory = $false, ParameterSetName = 'Relative')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Absolute')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Status')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Remove')]
    [Alias('Name')]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[^\\/:*?"<>|]+$')]
    [string]$TaskName = 'ScheduledHibernation',

    [Parameter(Mandatory = $false, ParameterSetName = 'Relative')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Absolute')]
    [Alias('ExpireAfter')]
    [ValidateRange(1, 1440)]
    [int]$ExpirationMinutes = 5,

    [Parameter(Mandatory = $false, ParameterSetName = 'Relative')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Absolute')]
    [switch]$DisallowOnBattery,

    [Parameter(Mandatory = $false, ParameterSetName = 'Relative')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Absolute')]
    [switch]$WakeToRun,

    [Parameter(Mandatory = $false, ParameterSetName = 'Relative')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Absolute')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Remove')]
    [switch]$Force,

    [Parameter(Mandatory = $false, ParameterSetName = 'Relative')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Absolute')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Status')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Remove')]
    [Alias('LogPath')]
    [ValidateNotNullOrEmpty()]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(Mandatory = $false, ParameterSetName = 'Relative')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Absolute')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Status')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Remove')]
    [switch]$NoLog,

    [Parameter(Mandatory = $false, ParameterSetName = 'Relative')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Absolute')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Status')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Remove')]
    [switch]$PassThru,

    [Parameter(Mandatory = $false, ParameterSetName = 'Help')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
    [Alias('h')]
    [switch]$Help
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $script:ScriptName       = 'Set-ScheduledHibernation'
    $script:ScriptVersion    = '1.0.0'
    $script:ScriptAuthor     = 'Roman Pindela'
    $script:ScriptEmail      = 'roman.pindela@gmail.com'
    $script:ScriptGitHub     = 'https://github.com/romanpindela'
    $script:LastModified     = '2026-11-26'
    $script:SessionTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFilePath      = $null
    $script:ShouldExitEarly  = $false
    $script:TaskRootPath     = '\'
    $script:ShutdownBinary   = Join-Path -Path $env:SystemRoot -ChildPath 'System32\shutdown.exe'

    # --------------------------------------------------------------------------
    # Helper: Interactive Console Help
    # --------------------------------------------------------------------------
    function Show-ScriptHelp {
        [CmdletBinding()]
        param ()

        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host " $($script:ScriptName).ps1 v$($script:ScriptVersion) - One-Time Windows Hibernation Scheduler" -ForegroundColor White
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host "Author: $($script:ScriptAuthor) | Email: $($script:ScriptEmail) | GitHub: $($script:ScriptGitHub)" -ForegroundColor DarkGray
        Write-Host "Version: $($script:ScriptVersion) | Last Modified: $($script:LastModified) | License: MIT" -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Schedules, idempotently updates, inspects, or cancels a one-time hibernation' -ForegroundColor Gray
        Write-Host 'task in Windows Task Scheduler (shutdown.exe /h) for the current user without' -ForegroundColor Gray
        Write-Host 'requiring UAC elevation. Battery execution is enabled by default for laptops.' -ForegroundColor Gray
        Write-Host ''
        Write-Host 'MODES (choose one):' -ForegroundColor Yellow
        Write-Host '  -In <Duration>           Relative delay from now (Aliases: -Delay, -After, -Offset).' -ForegroundColor White
        Write-Host '                           Examples: "+2h", "45m", "+1h30m", "1.5h", "+1d 2h"' -ForegroundColor DarkGray
        Write-Host '  -At <DateTime|Time>      Specific clock time or date+time (Aliases: -Time, -DateTime).' -ForegroundColor White
        Write-Host '                           Examples: "22:30", "2026-11-27 01:15", "27.11.2026 01:15"' -ForegroundColor DarkGray
        Write-Host '  -Status                  Inspect current task schedule & hibernation readiness.' -ForegroundColor White
        Write-Host '  -Remove                  Cancel and remove the scheduled hibernation task (-Cancel).' -ForegroundColor White
        Write-Host ''
        Write-Host 'OPTIONS:' -ForegroundColor Yellow
        Write-Host '  -TaskName <String>       Task Scheduler name (Default: ScheduledHibernation).' -ForegroundColor White
        Write-Host '  -ExpirationMinutes <Int> Auto-expire window after run time (1-1440, Default: 5).' -ForegroundColor White
        Write-Host '  -DisallowOnBattery       Only hibernate when connected to AC power.' -ForegroundColor White
        Write-Host '  -WakeToRun               Attempt waking from Sleep (S3/S0) to hibernate.' -ForegroundColor White
        Write-Host '  -Force                   Bypass confirmations & hibernation readiness abort.' -ForegroundColor White
        Write-Host '  -LogDirectory <Path>     Log folder path (Default: C:\Logs, fallback: %TEMP%\Logs).' -ForegroundColor White
        Write-Host '  -NoLog                   Disable default file logging.' -ForegroundColor White
        Write-Host '  -PassThru                Return structured [PSCustomObject] to the pipeline.' -ForegroundColor White
        Write-Host '  -WhatIf / -Confirm       Preview changes safely or require confirmation.' -ForegroundColor White
        Write-Host '  -Help, -h                Display this help screen and exit.' -ForegroundColor White
        Write-Host ''
        Write-Host 'EXAMPLES:' -ForegroundColor Yellow
        Write-Host '  .\Set-ScheduledHibernation.ps1 -In "+2h"' -ForegroundColor Gray
        Write-Host '  .\Set-ScheduledHibernation.ps1 -In "+1h30m"' -ForegroundColor Gray
        Write-Host '  .\Set-ScheduledHibernation.ps1 -At "23:30"' -ForegroundColor Gray
        Write-Host '  .\Set-ScheduledHibernation.ps1 -At "2026-11-27 01:15" -DisallowOnBattery' -ForegroundColor Gray
        Write-Host '  .\Set-ScheduledHibernation.ps1 -Status' -ForegroundColor Gray
        Write-Host '  .\Set-ScheduledHibernation.ps1 -Remove' -ForegroundColor Gray
        Write-Host '  .\Set-ScheduledHibernation.ps1 -In "+45m" -WhatIf' -ForegroundColor Gray
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host ''
    }

    # --------------------------------------------------------------------------
    # Helper: SID-Based Administrator Check (Language-Independent PL/EN)
    # --------------------------------------------------------------------------
    function Test-IsAdministrator {
        [CmdletBinding()]
        [OutputType([bool])]
        param ()

        $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList $identity
        $adminSid  = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-32-544'
        return $principal.IsInRole($adminSid)
    }

    # --------------------------------------------------------------------------
    # Helper: Logging Initialization & Writer
    # --------------------------------------------------------------------------
    function Initialize-LogFile {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$PreferredDirectory
        )

        $safeComputer = ($env:COMPUTERNAME -replace '[^a-zA-Z0-9._-]', '_')
        $safeUser     = ($env:USERNAME -replace '[^a-zA-Z0-9._-]', '_')
        $fileName     = '{0}-{1}-{2}-{3}.log' -f $script:SessionTimestamp, $script:ScriptName, $safeComputer, $safeUser

        $candidates = @(
            $PreferredDirectory,
            (Join-Path -Path $env:TEMP -ChildPath 'Logs')
        )

        foreach ($dir in $candidates) {
            try {
                if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }

                $candidatePath = Join-Path -Path $dir -ChildPath $fileName
                $utf8NoBom     = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
                [System.IO.File]::AppendAllText(
                    $candidatePath,
                    ("[{0}] [INFO] Session started ({1} v{2})`r`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $script:ScriptName, $script:ScriptVersion),
                    $utf8NoBom
                )
                return $candidatePath
            }
            catch {
                Write-Verbose ("Unable to initialize log file in '{0}': {1}" -f $dir, $_.Exception.Message)
            }
        }

        return $null
    }

    function Write-Log {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
            [string]$Level = 'INFO'
        )

        Write-Verbose ("[{0}] {1}" -f $Level, $Message)

        if ([string]::IsNullOrWhiteSpace($script:LogFilePath)) {
            return
        }

        try {
            $utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
            $line      = "[{0}] [{1}] {2}`r`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
            [System.IO.File]::AppendAllText($script:LogFilePath, $line, $utf8NoBom)
        }
        catch {
            Write-Verbose ("Failed to append log entry: {0}" -f $_.Exception.Message)
        }
    }

    # --------------------------------------------------------------------------
    # Helper: OS Language-Independent Hibernation Capability Check
    # --------------------------------------------------------------------------
    function Test-HibernationCapability {
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param ()

        $powerRegPath     = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
        $hibernateEnabled = $null
        $hiberFilePath    = Join-Path -Path ($env:SystemDrive + '\') -ChildPath 'hiberfil.sys'
        $hiberFileExists  = $false

        try {
            $powerProps = Get-ItemProperty -LiteralPath $powerRegPath -ErrorAction Stop
            if ($null -ne $powerProps.PSObject.Properties['HibernateEnabled']) {
                $hibernateEnabled = ([int]$powerProps.HibernateEnabled -eq 1)
            }
        }
        catch {
            Write-Log -Message ("Failed to read registry key '{0}': {1}" -f $powerRegPath, $_.Exception.Message) -Level 'WARN'
        }

        try {
            $hiberFileExists = [System.IO.File]::Exists($hiberFilePath)
        }
        catch {
            Write-Log -Message ("Failed to verify '{0}': {1}" -f $hiberFilePath, $_.Exception.Message) -Level 'WARN'
        }

        $isReady = $false
        if ($hibernateEnabled -eq $true -and $hiberFileExists) {
            $isReady = $true
        }
        elseif ($null -eq $hibernateEnabled -and $hiberFileExists) {
            $isReady = $true
        }

        return [PSCustomObject]@{
            IsReady          = $isReady
            HibernateEnabled = $hibernateEnabled
            HiberFileExists  = $hiberFileExists
            HiberFilePath    = $hiberFilePath
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Human-Readable Countdown Formatting
    # --------------------------------------------------------------------------
    function Format-TimeRemaining {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [timespan]$Duration
        )

        if ($Duration.TotalSeconds -le 0) {
            return 'Expired / Due now'
        }

        $parts = New-Object -TypeName System.Collections.Generic.List[string]
        if ($Duration.Days -gt 0) {
            $parts.Add(('{0}d' -f $Duration.Days))
        }
        if ($Duration.Hours -gt 0) {
            $parts.Add(('{0}h' -f $Duration.Hours))
        }
        if ($Duration.Minutes -gt 0) {
            $parts.Add(('{0}m' -f $Duration.Minutes))
        }
        if ($Duration.Seconds -gt 0 -or $parts.Count -eq 0) {
            $parts.Add(('{0}s' -f $Duration.Seconds))
        }

        return ($parts -join ' ')
    }

    # --------------------------------------------------------------------------
    # Helper: Parse Relative (-In) or Absolute (-At) Target DateTime
    # --------------------------------------------------------------------------
    function Resolve-TargetDateTime {
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param (
            [Parameter(Mandatory = $true)]
            [ValidateSet('Relative', 'Absolute')]
            [string]$Mode,

            [Parameter(Mandatory = $true)]
            [string]$Expression,

            [Parameter(Mandatory = $true)]
            [datetime]$ReferenceTime
        )

        $trimmed = $Expression.Trim()
        $rolledOverToTomorrow = $false
        $parsedTarget = $null

        if ($Mode -eq 'Relative') {
            if ($trimmed.StartsWith('-')) {
                throw "Relative delay '$Expression' cannot be negative. Provide a positive duration such as '+2h', '45m', or '+1h30m'."
            }

            if ($trimmed -match '^\+?\s*\d+(?:[.,]\d+)?$') {
                throw "Relative delay '$Expression' is missing a time unit. Specify units such as '+2h', '45m', '+1h30m', or '+1d'."
            }

            if ($trimmed -notmatch '^\+?\s*(?:(?:\d+(?:[.,]\d+)?)\s*[dhmsDHMS]\s*)+$') {
                throw "Invalid relative delay format '$Expression'. Supported examples: '+2h', '45m', '+1h30m', '1.5h', '+1d 2h'."
            }

            $tokenMatches = [regex]::Matches($trimmed, '(?<value>\d+(?:[.,]\d+)?)\s*(?<unit>[dhmsDHMS])')
            $totalSpan    = [timespan]::Zero

            foreach ($match in $tokenMatches) {
                $numericText = $match.Groups['value'].Value.Replace(',', '.')
                $numericVal  = [double]::Parse($numericText, [System.Globalization.CultureInfo]::InvariantCulture)
                $unitChar    = $match.Groups['unit'].Value.ToLowerInvariant()

                switch ($unitChar) {
                    'd' { $totalSpan = $totalSpan.Add([timespan]::FromDays($numericVal)) }
                    'h' { $totalSpan = $totalSpan.Add([timespan]::FromHours($numericVal)) }
                    'm' { $totalSpan = $totalSpan.Add([timespan]::FromMinutes($numericVal)) }
                    's' { $totalSpan = $totalSpan.Add([timespan]::FromSeconds($numericVal)) }
                }
            }

            if ($totalSpan.TotalSeconds -lt 10) {
                throw "Relative delay '$Expression' resolves to less than 10 seconds. Provide a delay of at least 10 seconds."
            }

            $rawTarget    = $ReferenceTime.Add($totalSpan)
            $parsedTarget = New-Object -TypeName System.DateTime -ArgumentList $rawTarget.Year, $rawTarget.Month, $rawTarget.Day, $rawTarget.Hour, $rawTarget.Minute, $rawTarget.Second, $rawTarget.Kind
        }
        else {
            if ($trimmed -notmatch ':') {
                throw "Absolute schedule '$Expression' must include a clock time (HH:mm). Examples: '22:30', '2026-11-27 01:15', '27.11.2026 01:15'."
            }

            $invariant = [System.Globalization.CultureInfo]::InvariantCulture
            $styles    = [System.Globalization.DateTimeStyles]::None

            if ($trimmed -match '^\d{1,2}:\d{2}(?::\d{2})?$') {
                [string[]]$timeFormats = @('H:mm', 'HH:mm', 'H:mm:ss', 'HH:mm:ss')
                $timeParsed            = [datetime]::MinValue

                if (-not [datetime]::TryParseExact($trimmed, $timeFormats, $invariant, $styles, [ref]$timeParsed)) {
                    throw "Invalid clock time '$Expression'. Use 24-hour format such as '22:30' or '01:15:00'."
                }

                $candidate = New-Object -TypeName System.DateTime -ArgumentList $ReferenceTime.Year, $ReferenceTime.Month, $ReferenceTime.Day, $timeParsed.Hour, $timeParsed.Minute, $timeParsed.Second, $ReferenceTime.Kind
                if ($candidate -le $ReferenceTime) {
                    $candidate            = $candidate.AddDays(1)
                    $rolledOverToTomorrow = $true
                }

                $parsedTarget = $candidate
            }
            else {
                [string[]]$dateTimeFormats = @(
                    'yyyy-MM-dd HH:mm:ss',
                    'yyyy-MM-dd HH:mm',
                    'yyyy-MM-ddTHH:mm:ss',
                    'yyyy-MM-ddTHH:mm',
                    'yyyy/MM/dd HH:mm:ss',
                    'yyyy/MM/dd HH:mm',
                    'dd.MM.yyyy HH:mm:ss',
                    'dd.MM.yyyy HH:mm',
                    'dd-MM-yyyy HH:mm:ss',
                    'dd-MM-yyyy HH:mm',
                    'dd/MM/yyyy HH:mm:ss',
                    'dd/MM/yyyy HH:mm'
                )

                $dtParsed = [datetime]::MinValue
                $ok = [datetime]::TryParseExact($trimmed, $dateTimeFormats, $invariant, $styles, [ref]$dtParsed)

                if (-not $ok) {
                    $ok = [datetime]::TryParse($trimmed, [System.Globalization.CultureInfo]::CurrentCulture, $styles, [ref]$dtParsed)
                }

                if (-not $ok) {
                    $ok = [datetime]::TryParse($trimmed, $invariant, $styles, [ref]$dtParsed)
                }

                if (-not $ok) {
                    throw "Unable to parse date/time '$Expression'. Supported examples: '22:30', '2026-11-27 01:15', '27.11.2026 01:15'."
                }

                $parsedTarget = New-Object -TypeName System.DateTime -ArgumentList $dtParsed.Year, $dtParsed.Month, $dtParsed.Day, $dtParsed.Hour, $dtParsed.Minute, $dtParsed.Second, $ReferenceTime.Kind
            }

            if ($parsedTarget -le $ReferenceTime.AddSeconds(5)) {
                throw ("Target date/time '{0}' is in the past (current local time: '{1}'). Provide a future timestamp." -f $parsedTarget.ToString('yyyy-MM-dd HH:mm:ss'), $ReferenceTime.ToString('yyyy-MM-dd HH:mm:ss'))
            }
        }

        return [PSCustomObject]@{
            TargetDateTime       = $parsedTarget
            Remaining            = ($parsedTarget - $ReferenceTime)
            RolledOverToTomorrow = $rolledOverToTomorrow
            InputExpression      = $trimmed
            InputMode            = $Mode
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Inspect Existing Scheduled Hibernation Task
    # --------------------------------------------------------------------------
    function Get-HibernationTaskStatus {
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Name,

            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Capability,

            [Parameter(Mandatory = $true)]
            [string]$CurrentUserName,

            [Parameter(Mandatory = $true)]
            [bool]$IsAdmin
        )

        $cancelCmd = '.\Set-ScheduledHibernation.ps1 -Remove'
        if ($Name -ne 'ScheduledHibernation') {
            $cancelCmd = ".\Set-ScheduledHibernation.ps1 -Remove -TaskName '$Name'"
        }

        $task = Get-ScheduledTask -TaskName $Name -TaskPath $script:TaskRootPath -ErrorAction SilentlyContinue
        if ($null -eq $task) {
            return [PSCustomObject]@{
                Action             = 'NotFound'
                TaskName           = $Name
                TaskState          = 'NotRegistered'
                ScheduledRunTime   = $null
                PreviousRunTime    = $null
                RemainingTime      = $null
                ExpiresAt          = $null
                AllowOnBattery     = $null
                WakeToRun          = $null
                StartWhenAvailable = $null
                HibernationEnabled = $Capability.HibernateEnabled
                HiberFileExists    = $Capability.HiberFileExists
                HibernationReady   = $Capability.IsReady
                ExecutedAsUser     = $CurrentUserName
                IsAdministrator    = $IsAdmin
                Command            = $null
                CancelCommand      = $cancelCmd
                LogFilePath        = $script:LogFilePath
                Timestamp          = Get-Date
            }
        }

        $taskInfo = Get-ScheduledTaskInfo -TaskName $Name -TaskPath $script:TaskRootPath -ErrorAction SilentlyContinue
        $nextRun  = $null
        if ($null -ne $taskInfo -and $null -ne $taskInfo.NextRunTime -and $taskInfo.NextRunTime.Year -gt 2000) {
            $nextRun = $taskInfo.NextRunTime
        }

        $expiresAt = $null
        $triggers  = @($task.Triggers)
        if ($triggers.Count -gt 0 -and $null -ne $triggers[0].PSObject.Properties['EndBoundary']) {
            $rawBoundary = $triggers[0].EndBoundary
            if (-not [string]::IsNullOrWhiteSpace($rawBoundary)) {
                $parsedBoundary = [datetime]::MinValue
                if ([datetime]::TryParse($rawBoundary, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsedBoundary)) {
                    if ($parsedBoundary.Kind -eq [System.DateTimeKind]::Utc) {
                        $expiresAt = $parsedBoundary.ToLocalTime()
                    }
                    else {
                        $expiresAt = $parsedBoundary
                    }
                }
            }
        }

        $commandText = $null
        $actions     = @($task.Actions)
        if ($actions.Count -gt 0) {
            $exec       = $actions[0].Execute
            $actionArgs = $actions[0].Arguments
            $commandText = ('{0} {1}' -f $exec, $actionArgs).Trim()
        }

        $remainingText = $null
        if ($null -ne $nextRun) {
            $remainingText = Format-TimeRemaining -Duration ($nextRun - (Get-Date))
        }

        return [PSCustomObject]@{
            Action             = 'Active'
            TaskName           = $task.TaskName
            TaskState          = [string]$task.State
            ScheduledRunTime   = $nextRun
            PreviousRunTime    = $null
            RemainingTime      = $remainingText
            ExpiresAt          = $expiresAt
            AllowOnBattery     = (-not [bool]$task.Settings.DisallowStartIfOnBatteries)
            WakeToRun          = [bool]$task.Settings.WakeToRun
            StartWhenAvailable = [bool]$task.Settings.StartWhenAvailable
            HibernationEnabled = $Capability.HibernateEnabled
            HiberFileExists    = $Capability.HiberFileExists
            HibernationReady   = $Capability.IsReady
            ExecutedAsUser     = $CurrentUserName
            IsAdministrator    = $IsAdmin
            Command            = $commandText
            CancelCommand      = $cancelCmd
            LogFilePath        = $script:LogFilePath
            Timestamp          = Get-Date
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Register or Update One-Time Scheduled Hibernation Task
    # --------------------------------------------------------------------------
    function Set-HibernationTask {
        [CmdletBinding(SupportsShouldProcess = $true)]
        [OutputType([PSCustomObject])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Name,

            [Parameter(Mandatory = $true)]
            [datetime]$TargetDateTime,

            [Parameter(Mandatory = $true)]
            [int]$ExpireWindowMinutes,

            [Parameter(Mandatory = $true)]
            [bool]$AllowBattery,

            [Parameter(Mandatory = $true)]
            [bool]$EnableWakeToRun,

            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Capability,

            [Parameter(Mandatory = $true)]
            [string]$CurrentUserName,

            [Parameter(Mandatory = $true)]
            [string]$CurrentUserSid,

            [Parameter(Mandatory = $true)]
            [bool]$IsAdmin
        )

        $existingStatus  = Get-HibernationTaskStatus -Name $Name -Capability $Capability -CurrentUserName $CurrentUserName -IsAdmin $IsAdmin
        $isUpdate        = ($existingStatus.Action -eq 'Active')
        $previousRunTime = $existingStatus.ScheduledRunTime
        $expiresAt       = $TargetDateTime.AddMinutes($ExpireWindowMinutes)
        $actionLabel     = if ($isUpdate) { 'Update one-time hibernation task' } else { 'Register one-time hibernation task' }
        $targetLabel     = "ScheduledTask '\$Name' at $($TargetDateTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        $commandString   = "$($script:ShutdownBinary) /h"

        $cancelCmd = '.\Set-ScheduledHibernation.ps1 -Remove'
        if ($Name -ne 'ScheduledHibernation') {
            $cancelCmd = ".\Set-ScheduledHibernation.ps1 -Remove -TaskName '$Name'"
        }

        if (-not $PSCmdlet.ShouldProcess($targetLabel, $actionLabel)) {
            $previewAction = if ($WhatIfPreference) { 'WhatIfPreview' } else { 'Skipped' }
            Write-Log -Message ("{0}: {1} -> {2}" -f $previewAction, $actionLabel, $targetLabel) -Level 'INFO'

            return [PSCustomObject]@{
                Action             = $previewAction
                TaskName           = $Name
                TaskState          = if ($isUpdate) { $existingStatus.TaskState } else { 'NotRegistered' }
                ScheduledRunTime   = $TargetDateTime
                PreviousRunTime    = $previousRunTime
                RemainingTime      = Format-TimeRemaining -Duration ($TargetDateTime - (Get-Date))
                ExpiresAt          = $expiresAt
                AllowOnBattery     = $AllowBattery
                WakeToRun          = $EnableWakeToRun
                StartWhenAvailable = $false
                HibernationEnabled = $Capability.HibernateEnabled
                HiberFileExists    = $Capability.HiberFileExists
                HibernationReady   = $Capability.IsReady
                ExecutedAsUser     = $CurrentUserName
                IsAdministrator    = $IsAdmin
                Command            = $commandString
                CancelCommand      = $cancelCmd
                LogFilePath        = $script:LogFilePath
                Timestamp          = Get-Date
            }
        }

        $taskAction  = New-ScheduledTaskAction -Execute $script:ShutdownBinary -Argument '/h'
        $taskTrigger = New-ScheduledTaskTrigger -Once -At $TargetDateTime
        $taskTrigger.EndBoundary = $expiresAt.ToString('yyyy-MM-ddTHH:mm:sszzz')

        $settingsParams = @{
            ExecutionTimeLimit       = New-TimeSpan -Minutes 5
            DeleteExpiredTaskAfter   = New-TimeSpan -Minutes 1
            AllowStartIfOnBatteries  = $AllowBattery
            DontStopIfGoingOnBatteries = $AllowBattery
            WakeToRun                = $EnableWakeToRun
            StartWhenAvailable       = $false
        }
        $taskSettings  = New-ScheduledTaskSettingsSet @settingsParams
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId $CurrentUserSid -LogonType Interactive -RunLevel Limited

        $description = 'One-time Windows hibernation scheduled by {0} v{1} for {2}.' -f $script:ScriptName, $script:ScriptVersion, $TargetDateTime.ToString('yyyy-MM-dd HH:mm:ss')

        Register-ScheduledTask `
            -TaskName $Name `
            -TaskPath $script:TaskRootPath `
            -Action $taskAction `
            -Trigger $taskTrigger `
            -Settings $taskSettings `
            -Principal $taskPrincipal `
            -Description $description `
            -Force | Out-Null

        $verifiedStatus = Get-HibernationTaskStatus -Name $Name -Capability $Capability -CurrentUserName $CurrentUserName -IsAdmin $IsAdmin
        $resultAction   = if ($isUpdate) { 'Updated' } else { 'Created' }
        $loggedRunTime  = if ($null -ne $verifiedStatus.ScheduledRunTime) { $verifiedStatus.ScheduledRunTime } else { $TargetDateTime }

        Write-Log -Message ("Task '\{0}' {1}. ScheduledRunTime={2}; PreviousRunTime={3}; AllowOnBattery={4}; WakeToRun={5}" -f `
            $Name, `
            $resultAction, `
            $loggedRunTime.ToString('yyyy-MM-dd HH:mm:ss'), `
            $(if ($null -ne $previousRunTime) { $previousRunTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'None' }), `
            $AllowBattery, `
            $EnableWakeToRun) -Level 'SUCCESS'

        return [PSCustomObject]@{
            Action             = $resultAction
            TaskName           = $verifiedStatus.TaskName
            TaskState          = $verifiedStatus.TaskState
            ScheduledRunTime   = $loggedRunTime
            PreviousRunTime    = $previousRunTime
            RemainingTime      = Format-TimeRemaining -Duration ($loggedRunTime - (Get-Date))
            ExpiresAt          = $verifiedStatus.ExpiresAt
            AllowOnBattery     = $verifiedStatus.AllowOnBattery
            WakeToRun          = $verifiedStatus.WakeToRun
            StartWhenAvailable = $verifiedStatus.StartWhenAvailable
            HibernationEnabled = $Capability.HibernateEnabled
            HiberFileExists    = $Capability.HiberFileExists
            HibernationReady   = $Capability.IsReady
            ExecutedAsUser     = $CurrentUserName
            IsAdministrator    = $IsAdmin
            Command            = $verifiedStatus.Command
            CancelCommand      = $cancelCmd
            LogFilePath        = $script:LogFilePath
            Timestamp          = Get-Date
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Remove Existing Scheduled Hibernation Task
    # --------------------------------------------------------------------------
    function Remove-HibernationTask {
        [CmdletBinding(SupportsShouldProcess = $true)]
        [OutputType([PSCustomObject])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Name,

            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Capability,

            [Parameter(Mandatory = $true)]
            [string]$CurrentUserName,

            [Parameter(Mandatory = $true)]
            [bool]$IsAdmin
        )

        $existingStatus = Get-HibernationTaskStatus -Name $Name -Capability $Capability -CurrentUserName $CurrentUserName -IsAdmin $IsAdmin
        if ($existingStatus.Action -eq 'NotFound') {
            Write-Log -Message ("Task '\{0}' was not found; nothing to remove." -f $Name) -Level 'INFO'
            return $existingStatus
        }

        $targetLabel = "ScheduledTask '\$Name'"
        if (-not $PSCmdlet.ShouldProcess($targetLabel, 'Unregister one-time hibernation task')) {
            $previewAction = if ($WhatIfPreference) { 'WhatIfPreview' } else { 'Skipped' }
            Write-Log -Message ("{0}: Unregister {1}" -f $previewAction, $targetLabel) -Level 'INFO'

            return [PSCustomObject]@{
                Action             = $previewAction
                TaskName           = $existingStatus.TaskName
                TaskState          = $existingStatus.TaskState
                ScheduledRunTime   = $existingStatus.ScheduledRunTime
                PreviousRunTime    = $existingStatus.ScheduledRunTime
                RemainingTime      = $existingStatus.RemainingTime
                ExpiresAt          = $existingStatus.ExpiresAt
                AllowOnBattery     = $existingStatus.AllowOnBattery
                WakeToRun          = $existingStatus.WakeToRun
                StartWhenAvailable = $existingStatus.StartWhenAvailable
                HibernationEnabled = $Capability.HibernateEnabled
                HiberFileExists    = $Capability.HiberFileExists
                HibernationReady   = $Capability.IsReady
                ExecutedAsUser     = $CurrentUserName
                IsAdministrator    = $IsAdmin
                Command            = $existingStatus.Command
                CancelCommand      = $existingStatus.CancelCommand
                LogFilePath        = $script:LogFilePath
                Timestamp          = Get-Date
            }
        }

        Unregister-ScheduledTask -TaskName $Name -TaskPath $script:TaskRootPath -Confirm:$false
        Write-Log -Message ("Task '\{0}' successfully removed." -f $Name) -Level 'SUCCESS'

        return [PSCustomObject]@{
            Action             = 'Removed'
            TaskName           = $Name
            TaskState          = 'Removed'
            ScheduledRunTime   = $null
            PreviousRunTime    = $existingStatus.ScheduledRunTime
            RemainingTime      = $null
            ExpiresAt          = $null
            AllowOnBattery     = $null
            WakeToRun          = $null
            StartWhenAvailable = $null
            HibernationEnabled = $Capability.HibernateEnabled
            HiberFileExists    = $Capability.HiberFileExists
            HibernationReady   = $Capability.IsReady
            ExecutedAsUser     = $CurrentUserName
            IsAdministrator    = $IsAdmin
            Command            = $existingStatus.Command
            CancelCommand      = $existingStatus.CancelCommand
            LogFilePath        = $script:LogFilePath
            Timestamp          = Get-Date
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Render Colorized Console Summary
    # --------------------------------------------------------------------------
    function Show-HibernationSummary {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Result
        )

        $statusColor = 'White'
        $headline    = ''

        switch ($Result.Action) {
            'Created'       { $statusColor = 'Green';  $headline = 'ONE-TIME HIBERNATION SCHEDULED (NEW TASK CREATED)' }
            'Updated'       { $statusColor = 'Green';  $headline = 'ONE-TIME HIBERNATION RESCHEDULED (EXISTING TASK UPDATED)' }
            'Active'        { $statusColor = 'Cyan';   $headline = 'SCHEDULED HIBERNATION STATUS (ACTIVE)' }
            'Removed'       { $statusColor = 'Yellow'; $headline = 'SCHEDULED HIBERNATION CANCELLED (TASK REMOVED)' }
            'NotFound'      { $statusColor = 'Yellow'; $headline = 'NO SCHEDULED HIBERNATION TASK FOUND' }
            'WhatIfPreview' { $statusColor = 'Cyan';   $headline = 'DRY-RUN PREVIEW (-WhatIf, NO SYSTEM CHANGES MADE)' }
            default         { $statusColor = 'Gray';   $headline = ("OPERATION STATUS: {0}" -f $Result.Action) }
        }

        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host (" {0} v{1}" -f $script:ScriptName, $script:ScriptVersion) -ForegroundColor White
        Write-Host (" {0}" -f $headline) -ForegroundColor $statusColor
        Write-Host '================================================================================' -ForegroundColor Cyan

        Write-Host ('  {0,-22}: {1}' -f 'Action', $Result.Action) -ForegroundColor $statusColor
        Write-Host ('  {0,-22}: \{1}' -f 'Task Name', $Result.TaskName) -ForegroundColor White
        Write-Host ('  {0,-22}: {1}' -f 'Task State', $Result.TaskState) -ForegroundColor White

        $invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

        if ($null -ne $Result.PreviousRunTime) {
            Write-Host ('  {0,-22}: {1}' -f 'Previous Schedule', $Result.PreviousRunTime.ToString('yyyy-MM-dd HH:mm:ss (dddd)', $invariantCulture)) -ForegroundColor DarkYellow
        }

        if ($null -ne $Result.ScheduledRunTime) {
            Write-Host ('  {0,-22}: {1}' -f 'Scheduled Run Time', $Result.ScheduledRunTime.ToString('yyyy-MM-dd HH:mm:ss (dddd)', $invariantCulture)) -ForegroundColor Green
            Write-Host ('  {0,-22}: {1}' -f 'Time Remaining', $Result.RemainingTime) -ForegroundColor Cyan
        }

        if ($null -ne $Result.ExpiresAt) {
            Write-Host ('  {0,-22}: {1} (auto-deletes after expiry)' -f 'Trigger Expires At', $Result.ExpiresAt.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Gray
        }

        if ($null -ne $Result.Command) {
            Write-Host ('  {0,-22}: {1}' -f 'Action Command', $Result.Command) -ForegroundColor Gray
        }

        if ($null -ne $Result.AllowOnBattery) {
            $batteryText  = if ($Result.AllowOnBattery) { 'Allowed (runs on battery & AC)' } else { 'Disallowed (AC power only)' }
            $batteryColor = if ($Result.AllowOnBattery) { 'White' } else { 'Yellow' }
            Write-Host ('  {0,-22}: {1}' -f 'Battery Policy', $batteryText) -ForegroundColor $batteryColor
        }

        if ($null -ne $Result.WakeToRun) {
            $wakeText = if ($Result.WakeToRun) { 'Enabled (attempts wake from Sleep to hibernate)' } else { 'Disabled (safe if laptop is asleep)' }
            Write-Host ('  {0,-22}: {1}' -f 'Wake To Run', $wakeText) -ForegroundColor Gray
        }

        $hibStatusText  = if ($Result.HibernationReady) { 'Ready (HibernateEnabled=1, hiberfil.sys present)' } else { 'NOT READY (hibernation appears disabled on this system)' }
        $hibStatusColor = if ($Result.HibernationReady) { 'Green' } else { 'Red' }
        Write-Host ('  {0,-22}: {1}' -f 'System Hibernation', $hibStatusText) -ForegroundColor $hibStatusColor

        $roleLabel = if ($Result.IsAdministrator) { 'Administrator' } else { 'Standard User (No UAC required)' }
        Write-Host ('  {0,-22}: {1} [{2}]' -f 'Execution Context', $Result.ExecutedAsUser, $roleLabel) -ForegroundColor DarkGray

        if (-not [string]::IsNullOrWhiteSpace($Result.LogFilePath)) {
            Write-Host ('  {0,-22}: {1}' -f 'Log File', $Result.LogFilePath) -ForegroundColor DarkGray
        }

        if ($Result.Action -in @('Created', 'Updated', 'Active')) {
            Write-Host ''
            Write-Host '  Cancel Command:' -ForegroundColor Yellow
            Write-Host ("    {0}" -f $Result.CancelCommand) -ForegroundColor Gray
        }

        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host ''
    }

    # --------------------------------------------------------------------------
    # Begin Execution: Early Help Check & Log Initialization
    # --------------------------------------------------------------------------
    if ($Help -or $PSBoundParameters.Count -eq 0) {
        Show-ScriptHelp
        $script:ShouldExitEarly = $true
        return
    }

    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
        $ConfirmPreference = 'None'
    }

    if (-not $NoLog) {
        $script:LogFilePath = Initialize-LogFile -PreferredDirectory $LogDirectory
    }
}

process {
    if ($script:ShouldExitEarly) {
        return
    }

    $resultObject = $null

    try {
        $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $currentUserName = $currentIdentity.Name
        $currentUserSid  = $currentIdentity.User.Value
        $isAdmin         = Test-IsAdministrator
        $capability      = Test-HibernationCapability

        Write-Log -Message ("Mode={0}; TaskName={1}; User={2}; IsAdmin={3}; HibernationReady={4}" -f `
            $PSCmdlet.ParameterSetName, $TaskName, $currentUserName, $isAdmin, $capability.IsReady) -Level 'INFO'

        switch ($PSCmdlet.ParameterSetName) {
            'Status' {
                if ($Status) {
                    $resultObject = Get-HibernationTaskStatus `
                        -Name $TaskName `
                        -Capability $capability `
                        -CurrentUserName $currentUserName `
                        -IsAdmin $isAdmin
                }
            }

            'Remove' {
                if ($Remove) {
                    $resultObject = Remove-HibernationTask `
                        -Name $TaskName `
                        -Capability $capability `
                        -CurrentUserName $currentUserName `
                        -IsAdmin $isAdmin
                }
            }

            { $_ -in @('Relative', 'Absolute') } {
                if (-not $capability.IsReady) {
                    $remediationHint = "Windows hibernation appears disabled (HibernateEnabled=$($capability.HibernateEnabled), hiberfil.sys=$($capability.HiberFileExists)). Enable it as Administrator via 'powercfg /hibernate on' or 'Enable-Hibernation.ps1 -EnableHibernation'."
                    if (-not $Force) {
                        Write-Log -Message $remediationHint -Level 'ERROR'
                        throw "$remediationHint Use -Force to schedule the task anyway."
                    }

                    Write-Log -Message ("Proceeding due to -Force: {0}" -f $remediationHint) -Level 'WARN'
                    Write-Host ("[WARN] {0}" -f $remediationHint) -ForegroundColor Yellow
                }

                $now        = Get-Date
                $expression = if ($PSCmdlet.ParameterSetName -eq 'Relative') { $In } else { $At }
                $resolved   = Resolve-TargetDateTime -Mode $PSCmdlet.ParameterSetName -Expression $expression -ReferenceTime $now

                if ($resolved.RolledOverToTomorrow) {
                    $rolloverMsg = "Clock time '$($resolved.InputExpression)' has already passed today; scheduling for tomorrow ($($resolved.TargetDateTime.ToString('yyyy-MM-dd HH:mm:ss')))."
                    Write-Log -Message $rolloverMsg -Level 'INFO'
                    Write-Host ("[INFO] {0}" -f $rolloverMsg) -ForegroundColor Cyan
                }

                if ($resolved.Remaining.TotalSeconds -lt 60) {
                    $shortDelayMsg = "Scheduled hibernation is less than 1 minute away ($([int][Math]::Round($resolved.Remaining.TotalSeconds))s). Save your work immediately."
                    Write-Log -Message $shortDelayMsg -Level 'WARN'
                    Write-Host ("[WARN] {0}" -f $shortDelayMsg) -ForegroundColor Yellow
                }

                $resultObject = Set-HibernationTask `
                    -Name $TaskName `
                    -TargetDateTime $resolved.TargetDateTime `
                    -ExpireWindowMinutes $ExpirationMinutes `
                    -AllowBattery (-not [bool]$DisallowOnBattery) `
                    -EnableWakeToRun ([bool]$WakeToRun) `
                    -Capability $capability `
                    -CurrentUserName $currentUserName `
                    -CurrentUserSid $currentUserSid `
                    -IsAdmin $isAdmin
            }

            default {
                Show-ScriptHelp
                $script:ShouldExitEarly = $true
                return
            }
        }

        if ($null -ne $resultObject) {
            Show-HibernationSummary -Result $resultObject
            if ($PassThru) {
                Write-Output $resultObject
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log -Message ("Unhandled error: {0}" -f $errorMsg) -Level 'ERROR'
        Write-Host ''
        Write-Host ("[ERROR] {0}" -f $errorMsg) -ForegroundColor Red
        Write-Host ''
        throw
    }
    finally {
        Write-Log -Message 'Execution cycle completed.' -Level 'INFO'
    }
}

end {
    if ($script:ShouldExitEarly) {
        return
    }
}
