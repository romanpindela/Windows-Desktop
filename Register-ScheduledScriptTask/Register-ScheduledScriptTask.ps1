<#
.SYNOPSIS
    Registers, inspects, and removes Windows Task Scheduler tasks for arbitrary PowerShell scripts
    with support for daily, weekly, monthly, logon, startup, workstation unlock, wake-from-hibernation,
    and smart once-per-day guard triggers.

.DESCRIPTION
    Register-ScheduledScriptTask.ps1 is a universal enterprise automation tool for Windows 10,
    Windows 11, and Windows Server (dual-compatible with Windows PowerShell 5.1 and PowerShell 7+).

    It registers any target PowerShell script (.ps1) with custom arguments and working directory
    in Windows Task Scheduler using the native Task Scheduler 2.0 COM API combined with the
    ScheduledTasks module, ensuring full support for:
      1. Calendar schedules: Daily (-At), Weekly (-DaysOfWeek + -At), and Monthly (-DaysOfMonth 1..31
         and/or -LastDayOfMonth + -At) without PowerShell CIM UInt16 bitmask limitations.
      2. Session & Power event triggers: User Logon (-AtLogon), System Startup (-AtStartup),
         Workstation Unlock (-OnUnlock, including resume from Sleep/Hibernation), and Power Resume
         (-OnWake, System Event Log Power-Troubleshooter Event ID 1).
      3. Smart Once-Per-Day Execution Guard (-OncePerDay): Generates an auditable launcher wrapper
         that guarantees the target script executes at most once per calendar day. When combined
         with -At and -OnUnlock/-AtLogon/-OnWake, it enforces the optional earliest-time gate (-At)
         and day-of-week/day-of-month filters so laptops powered off or hibernated at the scheduled
         time automatically catch up on the first user logon or screen unlock of the day.

    Provides detailed color-coded console progress, Write-Progress indicators, full -WhatIf/-Confirm
    support, language-independent SID-based UAC elevation (S-1-5-32-544), structured PSCustomObject
    pipeline output (-PassThru), and microsecond-precision logging to C:\Logs\.

.PARAMETER TaskName
    Mandatory name of the scheduled task to register or remove (e.g., 'Update-AllGitRepos').

.PARAMETER ScriptPath
    Full or relative path to the target PowerShell script (.ps1) to execute.

.PARAMETER ScriptArguments
    Optional raw argument string forwarded verbatim to the target script (e.g., '-r' or '-Update -Prune').

.PARAMETER WorkingDirectory
    Optional working directory set before executing the target script.
    Defaults to the parent directory of -ScriptPath.

.PARAMETER TaskPath
    Task Scheduler folder path where tasks are stored. Default: '\CustomScripts\'.

.PARAMETER Description
    Optional human-readable description stored in Task Scheduler registration metadata.

.PARAMETER At
    Time of day in HH:mm or HH:mm:ss (24-hour format, e.g., '08:00').
    Used as the schedule time for Daily/Weekly/Monthly triggers, and as the earliest-run time gate
    when combined with -OncePerDay and event triggers (-AtLogon, -OnUnlock, -OnWake).

.PARAMETER DaysOfWeek
    One or more days of the week for a Weekly schedule (e.g., Monday, Tuesday, Wednesday, Thursday, Friday).
    Cannot be combined with -DaysOfMonth or -LastDayOfMonth.

.PARAMETER DaysOfMonth
    One or more day numbers (1..31) for a Monthly schedule (e.g., 1, 15, 28).
    Cannot be combined with -DaysOfWeek.

.PARAMETER LastDayOfMonth
    Adds the last calendar day of each month to a Monthly schedule.
    Cannot be combined with -DaysOfWeek.

.PARAMETER AtLogon
    Adds a trigger that fires when the target user logs on to Windows.

.PARAMETER AtStartup
    Adds a trigger that fires when Windows starts up (requires Administrator privileges).

.PARAMETER OnUnlock
    Adds a Workstation Unlock trigger (TASK_SESSION_UNLOCK, StateChange = 8), which fires
    whenever the user unlocks the screen, including after waking from Sleep or Hibernation.

.PARAMETER OnWake
    Adds a System Event trigger listening for Power-Troubleshooter Event ID 1 (resume from
    Sleep or Hibernation).

.PARAMETER OncePerDay
    Wraps target script execution in an auditable daily-guard launcher script that ensures the
    script runs at most once per calendar day (tracking last successful date in a .lastrun file).
    Ideal when combining -At with -AtLogon, -OnUnlock, or -OnWake.

.PARAMETER TriggerDelaySeconds
    Delay in seconds applied to event/session triggers (-AtLogon, -AtStartup, -OnUnlock, -OnWake)
    to allow network interfaces and user profiles to initialize. Default: 15.

.PARAMETER StartWhenAvailable
    Controls the Task Scheduler StartWhenAvailable setting so missed calendar runs catch up
    as soon as the system wakes or boots. Default: $true.

.PARAMETER PowerShellHost
    Selects which PowerShell host executes the scheduled task: Auto (prefers pwsh.exe if installed,
    falls back to powershell.exe), WindowsPowerShell, or PowerShell7. Default: Auto.

.PARAMETER WindowStyle
    Console window visibility when the scheduled task executes: Hidden, Minimized, or Normal.
    Default: Hidden.

.PARAMETER RunLevel
    Privilege level of the scheduled task: Highest or Limited. Default: Highest.

.PARAMETER RunAsUser
    Account under which the scheduled task runs (e.g., 'DOMAIN\User' or 'SYSTEM').
    Defaults to the current user (<USERDOMAIN>\<USERNAME>).

.PARAMETER Force
    Overwrites an existing scheduled task with the same TaskName and TaskPath.

.PARAMETER SkipPathValidation
    Skips checking whether -ScriptPath currently exists on disk.

.PARAMETER List
    Lists all scheduled tasks registered in -TaskPath with state, triggers, and run timestamps.

.PARAMETER Unregister
    Removes the scheduled task specified by -TaskName in -TaskPath and cleans up any generated
    daily-guard wrapper files.

.PARAMETER LogDirectory
    Directory where execution logs are written. Default: C:\Logs.

.PARAMETER SkipAdminCheck
    Bypasses automatic UAC elevation (useful for registering Limited user-scope tasks without admin rights).

.PARAMETER PassThru
    Emits structured PSCustomObject result records to the PowerShell pipeline.

.PARAMETER Help
    Displays the interactive console help guide and parameter documentation. Alias: -h.

.EXAMPLE
    .\Register-ScheduledScriptTask.ps1 -Help
    Displays syntax, parameter reference, and practical usage examples.

.EXAMPLE
    .\Register-ScheduledScriptTask.ps1 -TaskName "Update-AllGitRepos" -ScriptPath "C:\GitHub\Dev\Update-AllGitRepos\Update-AllGitRepos.ps1" -ScriptArguments "-r" -At "08:00" -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -AtLogon -OnUnlock -OncePerDay -Force
    Registers Update-AllGitRepos.ps1 (-r) to run weekdays at 08:00, and if the laptop was off or hibernated,
    automatically runs once per day on the first user logon or screen unlock at or after 08:00.

.EXAMPLE
    .\Register-ScheduledScriptTask.ps1 -TaskName "Monthly-GitSync" -ScriptPath "C:\GitHub\Dev\Update-AllGitRepos\Update-AllGitRepos.ps1" -ScriptArguments "-r" -At "09:30" -DaysOfMonth 1,15 -LastDayOfMonth -Force
    Registers a monthly task running on the 1st, 15th, and last day of every month at 09:30.

.EXAMPLE
    .\Register-ScheduledScriptTask.ps1 -TaskName "Update-AllGitRepos" -ScriptPath "C:\GitHub\Dev\Update-AllGitRepos\Update-AllGitRepos.ps1" -ScriptArguments "-r" -At "08:00" -OnUnlock -OncePerDay -WhatIf
    Performs a dry-run preview showing all resolved paths, triggers, and guard configuration without modifying Task Scheduler.

.EXAMPLE
    .\Register-ScheduledScriptTask.ps1 -List
    Lists all tasks registered in the default \CustomScripts\ Task Scheduler folder.

.EXAMPLE
    .\Register-ScheduledScriptTask.ps1 -Unregister -TaskName "Update-AllGitRepos"
    Unregisters the task and removes its generated daily-guard wrapper files.

.NOTES
    Author:        Roman Pindela
    Email:         roman.pindela@gmail.com
    GitHub:        https://github.com/romanpindela
    Repository:    Windows-Desktop
    Version:       1.0.0
    Last Modified: 2026-11-27
    Requires:      Windows 10/11 / Windows Server, PowerShell 5.1+ or PowerShell 7+
#>

[CmdletBinding(DefaultParameterSetName = 'Help', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Register')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Unregister')]
    [ValidateNotNullOrEmpty()]
    [string]$TaskName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Register')]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [string]$ScriptArguments = '',

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Unregister')]
    [Parameter(Mandatory = $false, ParameterSetName = 'List')]
    [ValidateNotNullOrEmpty()]
    [string]$TaskPath = '\CustomScripts\',

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [string]$Description,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [ValidatePattern('^([01]?\d|2[0-3]):[0-5]\d(:[0-5]\d)?$')]
    [string]$At,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [System.DayOfWeek[]]$DaysOfWeek,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [ValidateRange(1, 31)]
    [int[]]$DaysOfMonth,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [switch]$LastDayOfMonth,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [switch]$AtLogon,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [switch]$AtStartup,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [switch]$OnUnlock,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [switch]$OnWake,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [switch]$OncePerDay,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [ValidateRange(0, 3600)]
    [int]$TriggerDelaySeconds = 15,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [bool]$StartWhenAvailable = $true,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [ValidateSet('Auto', 'WindowsPowerShell', 'PowerShell7')]
    [string]$PowerShellHost = 'Auto',

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [ValidateSet('Hidden', 'Minimized', 'Normal')]
    [string]$WindowStyle = 'Hidden',

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [ValidateSet('Limited', 'Highest')]
    [string]$RunLevel = 'Highest',

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [string]$RunAsUser,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [switch]$Force,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register')]
    [switch]$SkipPathValidation,

    [Parameter(Mandatory = $true, ParameterSetName = 'List')]
    [switch]$List,

    [Parameter(Mandatory = $true, ParameterSetName = 'Unregister')]
    [switch]$Unregister,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false, ParameterSetName = 'Help')]
    [Alias('h')]
    [switch]$Help
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $Script:ScriptName    = 'Register-ScheduledScriptTask'
    $Script:ScriptVersion = '1.0.0'
    $Script:AuthorName    = 'Roman Pindela'
    $Script:AuthorEmail   = 'roman.pindela@gmail.com'
    $Script:AuthorGitHub  = 'https://github.com/romanpindela'
    $Script:StartTime     = Get-Date
    $Script:LogFilePath   = $null
    $Script:NormalizedTaskPath = $TaskPath

    #region Helper Functions

    function Show-ScriptHelp {
        [CmdletBinding()]
        param ()

        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host "  $($Script:ScriptName).ps1  (v$($Script:ScriptVersion))" -ForegroundColor White
        Write-Host '  Universal Windows Task Scheduler Registration & Smart Daily-Guard Manager' -ForegroundColor Gray
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host "  Author : $($Script:AuthorName) <$($Script:AuthorEmail)>" -ForegroundColor DarkGray
        Write-Host "  GitHub : $($Script:AuthorGitHub)" -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'DESCRIPTION' -ForegroundColor Yellow
        Write-Host '  Registers any PowerShell script (.ps1) with custom arguments and working'
        Write-Host '  directory in Windows Task Scheduler. Supports daily, weekly, monthly,'
        Write-Host '  logon, startup, workstation unlock, wake-from-hibernation, and smart'
        Write-Host '  once-per-day (-OncePerDay) catch-up triggers.'
        Write-Host ''
        Write-Host 'KEY PARAMETERS' -ForegroundColor Yellow
        Write-Host '  -TaskName <string>          Mandatory name of the scheduled task.'
        Write-Host '  -ScriptPath <string>        Path to the target PowerShell (.ps1) script.'
        Write-Host '  -ScriptArguments <string>   Arguments forwarded verbatim (e.g., "-r").'
        Write-Host '  -WorkingDirectory <string>  Working directory (defaults to script parent folder).'
        Write-Host '  -TaskPath <string>          Task Scheduler folder (default: \CustomScripts\).'
        Write-Host '  -At <HH:mm>                 Schedule time (or earliest-run gate with -OncePerDay).'
        Write-Host '  -DaysOfWeek <DayOfWeek[]>   Weekly schedule days (e.g., Monday,Tuesday,...).'
        Write-Host '  -DaysOfMonth <int[]>        Monthly schedule day numbers (1..31).'
        Write-Host '  -LastDayOfMonth             Include the last calendar day of every month.'
        Write-Host '  -AtLogon                    Trigger when the user logs on.'
        Write-Host '  -AtStartup                  Trigger at Windows system startup.'
        Write-Host '  -OnUnlock                   Trigger on workstation unlock (including after hibernation).'
        Write-Host '  -OnWake                     Trigger on resume from Sleep/Hibernation (Event ID 1).'
        Write-Host '  -OncePerDay                 Guarantee at most one successful execution per day.'
        Write-Host '  -TriggerDelaySeconds <int>  Delay after event triggers (default: 15s).'
        Write-Host '  -PowerShellHost <string>    Auto | WindowsPowerShell | PowerShell7 (default: Auto).'
        Write-Host '  -WindowStyle <string>       Hidden | Minimized | Normal (default: Hidden).'
        Write-Host '  -RunLevel <string>          Highest | Limited (default: Highest).'
        Write-Host '  -RunAsUser <string>         Target user account (default: current user).'
        Write-Host '  -Force                      Overwrite an existing task with the same name.'
        Write-Host '  -List                       List registered tasks in -TaskPath.'
        Write-Host '  -Unregister                 Remove -TaskName and clean up its guard files.'
        Write-Host '  -LogDirectory <string>      Log folder path (default: C:\Logs).'
        Write-Host '  -WhatIf / -Confirm          Preview or confirm changes safely.'
        Write-Host '  -PassThru                   Emit structured PSCustomObject results to pipeline.'
        Write-Host '  -Help / -h                  Display this help screen and exit.'
        Write-Host ''
        Write-Host 'USAGE EXAMPLES' -ForegroundColor Yellow
        Write-Host '  1. Weekdays at 08:00 + first logon/unlock after boot or hibernation (once per day):' -ForegroundColor Green
        Write-Host '     .\Register-ScheduledScriptTask.ps1 `' -ForegroundColor White
        Write-Host '       -TaskName "Update-AllGitRepos" `' -ForegroundColor White
        Write-Host '       -ScriptPath "C:\GitHub\Dev\Update-AllGitRepos\Update-AllGitRepos.ps1" `' -ForegroundColor White
        Write-Host '       -ScriptArguments "-r" `' -ForegroundColor White
        Write-Host '       -At "08:00" `' -ForegroundColor White
        Write-Host '       -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday `' -ForegroundColor White
        Write-Host '       -AtLogon -OnUnlock -OncePerDay -Force' -ForegroundColor White
        Write-Host ''
        Write-Host '  2. Monthly on 1st, 15th, and last day of month at 09:30:' -ForegroundColor Green
        Write-Host '     .\Register-ScheduledScriptTask.ps1 -TaskName "Monthly-GitSync" `' -ForegroundColor White
        Write-Host '       -ScriptPath "C:\GitHub\Dev\Update-AllGitRepos\Update-AllGitRepos.ps1" `' -ForegroundColor White
        Write-Host '       -ScriptArguments "-r" -At "09:30" -DaysOfMonth 1,15 -LastDayOfMonth -Force' -ForegroundColor White
        Write-Host ''
        Write-Host '  3. Dry-run simulation (-WhatIf):' -ForegroundColor Green
        Write-Host '     .\Register-ScheduledScriptTask.ps1 -TaskName "Update-AllGitRepos" `' -ForegroundColor White
        Write-Host '       -ScriptPath "C:\GitHub\Dev\Update-AllGitRepos\Update-AllGitRepos.ps1" `' -ForegroundColor White
        Write-Host '       -ScriptArguments "-r" -At "08:00" -OnUnlock -OncePerDay -WhatIf' -ForegroundColor White
        Write-Host ''
        Write-Host '  4. List or unregister tasks:' -ForegroundColor Green
        Write-Host '     .\Register-ScheduledScriptTask.ps1 -List' -ForegroundColor White
        Write-Host '     .\Register-ScheduledScriptTask.ps1 -Unregister -TaskName "Update-AllGitRepos"' -ForegroundColor White
        Write-Host ''
    }

    function Initialize-LogFile {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Directory
        )

        try {
            if (-not (Test-Path -LiteralPath $Directory)) {
                New-Item -Path $Directory -ItemType Directory -Force | Out-Null
            }
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $safeUser  = ($env:USERNAME -replace '[^\w\-]', '_')
            $fileName  = '{0}-{1}-{2}-{3}.logs' -f $timestamp, $Script:ScriptName, $env:COMPUTERNAME, $safeUser
            $Script:LogFilePath = Join-Path -Path $Directory -ChildPath $fileName

            $header = @(
                '================================================================================'
                "Log Start   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.ffffff')"
                "Script      : $($Script:ScriptName).ps1 v$($Script:ScriptVersion)"
                "Host        : $($env:COMPUTERNAME) | User: $($env:USERDOMAIN)\$($env:USERNAME)"
                "PS Version  : $($PSVersionTable.PSVersion)"
                '================================================================================'
            ) -join [Environment]::NewLine

            [System.IO.File]::WriteAllText($Script:LogFilePath, $header + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
        }
        catch {
            Write-Warning "Failed to initialize log file in '$Directory': $($_.Exception.Message)"
            $Script:LogFilePath = $null
        }
    }

    function Write-Log {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'STEP', 'OK', 'WARN', 'ERROR', 'DEBUG')]
            [string]$Level = 'INFO',

            [Parameter(Mandatory = $false)]
            [switch]$Silent
        )

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        $logLine   = '[{0}] [{1,-5}] {2}' -f $timestamp, $Level, $Message

        if ($Script:LogFilePath) {
            try {
                [System.IO.File]::AppendAllText($Script:LogFilePath, $logLine + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
            }
            catch {
                # Do not interrupt workflow on transient log write failure
                Write-Verbose "Log write warning: $($_.Exception.Message)"
            }
        }

        if ($Silent) {
            return
        }

        $colorMap = @{
            'INFO'  = 'Cyan'
            'STEP'  = 'Magenta'
            'OK'    = 'Green'
            'WARN'  = 'Yellow'
            'ERROR' = 'Red'
            'DEBUG' = 'DarkGray'
        }

        if ($Level -eq 'DEBUG') {
            Write-Verbose $Message
        }
        else {
            Write-Host ('[{0,-4}] ' -f $Level) -ForegroundColor $colorMap[$Level] -NoNewline
            Write-Host $Message -ForegroundColor White
        }
    }

    function Test-IsAdministrator {
        [CmdletBinding()]
        [OutputType([bool])]
        param ()

        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $adminSid  = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
        return $principal.IsInRole($adminSid)
    }

    function Invoke-SelfElevation {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [hashtable]$BoundParameters,

            [Parameter(Mandatory = $true)]
            [string]$ScriptFile
        )

        $pwshExe = (Get-Process -Id $PID).MainModule.FileName
        $argList = [System.Collections.Generic.List[string]]::new()
        $argList.Add('-NoProfile')
        $argList.Add('-ExecutionPolicy')
        $argList.Add('Bypass')
        $argList.Add('-File')
        $argList.Add(('"{0}"' -f $ScriptFile))

        foreach ($entry in $BoundParameters.GetEnumerator()) {
            $key = $entry.Key
            $val = $entry.Value

            if ($val -is [switch] -or $val -is [System.Management.Automation.SwitchParameter]) {
                if ($val.IsPresent) {
                    $argList.Add("-${key}")
                }
            }
            elseif ($val -is [bool]) {
                $boolToken = if ($val) { '$true' } else { '$false' }
                $argList.Add("-${key}:$boolToken")
            }
            elseif ($val -is [System.Array]) {
                $joined = ($val | ForEach-Object { $_.ToString() }) -join ','
                $argList.Add("-${key}")
                $argList.Add($joined)
            }
            else {
                $escaped = $val.ToString().Replace('"', '\"')
                $argList.Add("-${key}")
                $argList.Add(('"{0}"' -f $escaped))
            }
        }

        Write-Log -Level 'WARN' -Message 'Administrative privileges (SID S-1-5-32-544) are required. Requesting UAC elevation...'
        Start-Process -FilePath $pwshExe -ArgumentList ($argList -join ' ') -Verb RunAs
        exit 0
    }

    function Format-NormalizedTaskPath {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        $normalized = $Path.Trim()
        if (-not $normalized.StartsWith('\')) {
            $normalized = '\' + $normalized
        }
        if (-not $normalized.EndsWith('\')) {
            $normalized = $normalized + '\'
        }
        return $normalized
    }

    function Resolve-PowerShellExecutable {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [ValidateSet('Auto', 'WindowsPowerShell', 'PowerShell7')]
            [string]$HostPreference
        )

        $winPsPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $pwshCmd   = Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue

        switch ($HostPreference) {
            'WindowsPowerShell' {
                return $winPsPath
            }
            'PowerShell7' {
                if ($pwshCmd) {
                    return $pwshCmd.Source
                }
                throw 'PowerShell 7 (pwsh.exe) was requested via -PowerShellHost PowerShell7, but pwsh.exe was not found in PATH.'
            }
            'Auto' {
                if ($pwshCmd) {
                    return $pwshCmd.Source
                }
                return $winPsPath
            }
        }
    }

    function Get-GuardDirectory {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [bool]$IsElevated
        )

        if ($IsElevated) {
            return (Join-Path -Path $env:ProgramData -ChildPath 'ScheduledScriptTasks')
        }
        return (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'ScheduledScriptTasks')
    }

    function Get-SafeFileToken {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        return ($Name -replace '[^a-zA-Z0-9\-_]', '_')
    }

    function ConvertTo-Iso8601Duration {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [int]$Seconds
        )

        if ($Seconds -le 0) {
            return $null
        }
        return ('PT{0}S' -f $Seconds)
    }

    function New-DailyGuardWrapper {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$GuardDirectory,

            [Parameter(Mandatory = $true)]
            [string]$TaskName,

            [Parameter(Mandatory = $true)]
            [string]$TargetScriptPath,

            [Parameter(Mandatory = $false)]
            [string]$TargetScriptArguments = '',

            [Parameter(Mandatory = $true)]
            [string]$TargetWorkingDirectory,

            [Parameter(Mandatory = $true)]
            [string]$TargetPowerShellExe,

            [Parameter(Mandatory = $false)]
            [string]$NotBeforeTime = '',

            [Parameter(Mandatory = $false)]
            [System.DayOfWeek[]]$AllowedDaysOfWeek,

            [Parameter(Mandatory = $false)]
            [int[]]$AllowedDaysOfMonth,

            [Parameter(Mandatory = $false)]
            [switch]$IncludeLastDayOfMonth,

            [Parameter(Mandatory = $true)]
            [string]$TargetLogDirectory
        )

        $safeToken   = Get-SafeFileToken -Name $TaskName
        $wrapperPath = Join-Path -Path $GuardDirectory -ChildPath ("{0}-DailyGuard.ps1" -f $safeToken)
        $statePath   = Join-Path -Path $GuardDirectory -ChildPath ("{0}.lastrun" -f $safeToken)

        $daysOfWeekLiteral = if ($AllowedDaysOfWeek -and $AllowedDaysOfWeek.Count -gt 0) {
            '@(' + (($AllowedDaysOfWeek | ForEach-Object { "'{0}'" -f $_.ToString() }) -join ', ') + ')'
        }
        else {
            '@()'
        }

        $daysOfMonthLiteral = if ($AllowedDaysOfMonth -and $AllowedDaysOfMonth.Count -gt 0) {
            '@(' + ($AllowedDaysOfMonth -join ', ') + ')'
        }
        else {
            '@()'
        }

        $lastDayBoolLiteral = if ($IncludeLastDayOfMonth.IsPresent) { '$true' } else { '$false' }

        $escTaskName    = $TaskName.Replace("'", "''")
        $escScriptPath  = $TargetScriptPath.Replace("'", "''")
        $escScriptArgs  = $TargetScriptArguments.Replace("'", "''")
        $escWorkDir     = $TargetWorkingDirectory.Replace("'", "''")
        $escPsExe       = $TargetPowerShellExe.Replace("'", "''")
        $escStatePath   = $statePath.Replace("'", "''")
        $escLogDir      = $TargetLogDirectory.Replace("'", "''")
        $escNotBefore   = $NotBeforeTime.Replace("'", "''")

        $wrapperContent = @"
<#
.SYNOPSIS
    Auto-generated Once-Per-Day Execution Guard for scheduled task '$escTaskName'.
    Generated by Register-ScheduledScriptTask.ps1 v$($Script:ScriptVersion).
#>
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'

`$taskName       = '$escTaskName'
`$targetScript   = '$escScriptPath'
`$targetArgs     = '$escScriptArgs'
`$workDir        = '$escWorkDir'
`$psExe          = '$escPsExe'
`$stateFile      = '$escStatePath'
`$logDir         = '$escLogDir'
`$notBeforeTime  = '$escNotBefore'
`$allowedDow     = $daysOfWeekLiteral
`$allowedDom     = $daysOfMonthLiteral
`$includeLastDom = $lastDayBoolLiteral

if (-not (Test-Path -LiteralPath `$logDir)) {
    New-Item -Path `$logDir -ItemType Directory -Force | Out-Null
}

`$todayKey = Get-Date -Format 'yyyy-MM-dd'
`$safeTask = (`$taskName -replace '[^a-zA-Z0-9\-_]', '_')
`$logFile  = Join-Path -Path `$logDir -ChildPath ("{0}-TaskGuard-{1}-{2}.logs" -f `$todayKey, `$safeTask, `$env:COMPUTERNAME)

function Write-GuardLog {
    param([string]`$Level, [string]`$Message)
    `$line = '[{0}] [{1,-5}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), `$Level, `$Message
    [System.IO.File]::AppendAllText(`$logFile, `$line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
}

try {
    `$now = Get-Date

    # 1. Check if already completed successfully today
    if (Test-Path -LiteralPath `$stateFile) {
        `$lastRunDate = (Get-Content -LiteralPath `$stateFile -Raw -ErrorAction SilentlyContinue).Trim()
        if (`$lastRunDate -eq `$todayKey) {
            Write-GuardLog -Level 'SKIP' -Message "Task '`$taskName' already succeeded today (`$todayKey). Exiting."
            exit 0
        }
    }

    # 2. Enforce optional earliest time gate (-At)
    if (-not [string]::IsNullOrWhiteSpace(`$notBeforeTime)) {
        `$gateParts = `$notBeforeTime.Split(':')
        `$gateTime  = Get-Date -Hour ([int]`$gateParts[0]) -Minute ([int]`$gateParts[1]) -Second $(if (`$gateParts.Count -ge 3) { '[int]$gateParts[2]' } else { '0' })
        if (`$now -lt `$gateTime) {
            Write-GuardLog -Level 'SKIP' -Message ("Current time ({0}) is before earliest gate ({1}). Waiting for later trigger." -f `$now.ToString('HH:mm:ss'), `$notBeforeTime)
            exit 0
        }
    }

    # 3. Enforce optional day-of-week filter
    if (`$allowedDow.Count -gt 0) {
        `$todayDow = `$now.DayOfWeek.ToString()
        if (`$allowedDow -notcontains `$todayDow) {
            Write-GuardLog -Level 'SKIP' -Message ("Today (`$todayDow) is not in allowed days of week: {0}." -f (`$allowedDow -join ', '))
            exit 0
        }
    }

    # 4. Enforce optional day-of-month / last-day-of-month filter
    if (`$allowedDom.Count -gt 0 -or `$includeLastDom) {
        `$daysInMonth = [DateTime]::DaysInMonth(`$now.Year, `$now.Month)
        `$matchesDom  = (`$allowedDom -contains `$now.Day) -or (`$includeLastDom -and `$now.Day -eq `$daysInMonth)
        if (-not `$matchesDom) {
            Write-GuardLog -Level 'SKIP' -Message ("Today (day {0}) is not in allowed days of month." -f `$now.Day)
            exit 0
        }
    }

    # 5. Execute target script
    Write-GuardLog -Level 'INFO' -Message "Starting task '`$taskName' -> '`$targetScript' `$targetArgs (WorkDir: '`$workDir')"
    Set-Location -LiteralPath `$workDir

    `$invocationArgs = "-NoProfile -ExecutionPolicy Bypass -File `"`$targetScript`""
    if (-not [string]::IsNullOrWhiteSpace(`$targetArgs)) {
        `$invocationArgs = "`$invocationArgs `$targetArgs"
    }

    `$proc = Start-Process -FilePath `$psExe -ArgumentList `$invocationArgs -WorkingDirectory `$workDir -WindowStyle Hidden -Wait -PassThru
    `$exitCode = `$proc.ExitCode

    if (`$exitCode -eq 0) {
        [System.IO.File]::WriteAllText(`$stateFile, `$todayKey, [System.Text.Encoding]::UTF8)
        Write-GuardLog -Level 'OK' -Message "Task '`$taskName' completed with exit code 0. Recorded last run date: `$todayKey."
    }
    else {
        Write-GuardLog -Level 'ERROR' -Message "Task '`$taskName' exited with non-zero code `$exitCode. State file NOT updated so next trigger can retry."
    }

    exit `$exitCode
}
catch {
    Write-GuardLog -Level 'ERROR' -Message "Unhandled exception in DailyGuard: `$(`$_.Exception.Message)"
    exit 1
}
"@

        # Fix the minor inline subexpression in gateTime inside the generated guard script
        $wrapperContent = $wrapperContent.Replace(
            '$gateTime  = Get-Date -Hour ([int]$gateParts[0]) -Minute ([int]$gateParts[1]) -Second 0',
            '$gateSec   = if ($gateParts.Count -ge 3) { [int]$gateParts[2] } else { 0 }' + [Environment]::NewLine + '        $gateTime  = Get-Date -Hour ([int]$gateParts[0]) -Minute ([int]$gateParts[1]) -Second $gateSec'
        )
        $wrapperContent = $wrapperContent.Replace(
            '$gateTime  = Get-Date -Hour ([int]$gateParts[0]) -Minute ([int]$gateParts[1]) -Second [int]$gateParts[2]',
            '$gateSec   = if ($gateParts.Count -ge 3) { [int]$gateParts[2] } else { 0 }' + [Environment]::NewLine + '        $gateTime  = Get-Date -Hour ([int]$gateParts[0]) -Minute ([int]$gateParts[1]) -Second $gateSec'
        )

        if (-not (Test-Path -LiteralPath $GuardDirectory)) {
            New-Item -Path $GuardDirectory -ItemType Directory -Force | Out-Null
        }

        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($wrapperPath, $wrapperContent, $utf8Bom)

        return $wrapperPath
    }

    function New-TaskDefinitionXml {
        [CmdletBinding()]
        [OutputType([hashtable])]
        param (
            [Parameter(Mandatory = $true)]
            [string]$TaskDescription,

            [Parameter(Mandatory = $true)]
            [string]$ExecutablePath,

            [Parameter(Mandatory = $true)]
            [string]$ActionArguments,

            [Parameter(Mandatory = $true)]
            [string]$ActionWorkingDirectory,

            [Parameter(Mandatory = $true)]
            [string]$PrincipalUser,

            [Parameter(Mandatory = $true)]
            [ValidateSet('Limited', 'Highest')]
            [string]$PrincipalRunLevel,

            [Parameter(Mandatory = $false)]
            [string]$ScheduleAt,

            [Parameter(Mandatory = $false)]
            [System.DayOfWeek[]]$ScheduleDaysOfWeek,

            [Parameter(Mandatory = $false)]
            [int[]]$ScheduleDaysOfMonth,

            [Parameter(Mandatory = $false)]
            [switch]$ScheduleLastDayOfMonth,

            [Parameter(Mandatory = $false)]
            [switch]$IncludeAtLogon,

            [Parameter(Mandatory = $false)]
            [switch]$IncludeAtStartup,

            [Parameter(Mandatory = $false)]
            [switch]$IncludeOnUnlock,

            [Parameter(Mandatory = $false)]
            [switch]$IncludeOnWake,

            [Parameter(Mandatory = $true)]
            [int]$EventDelaySeconds,

            [Parameter(Mandatory = $true)]
            [bool]$EnableStartWhenAvailable
        )

        $scheduler = New-Object -ComObject 'Schedule.Service'
        $taskDef   = $scheduler.NewTask(0)
        $triggerSummaries = [System.Collections.Generic.List[string]]::new()

        # Registration Info
        $taskDef.RegistrationInfo.Author      = "$($env:USERDOMAIN)\$($env:USERNAME)"
        $taskDef.RegistrationInfo.Description = $TaskDescription
        $taskDef.RegistrationInfo.Date        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

        # Principal
        $isSystemAccount = ($PrincipalUser -match '^(NT AUTHORITY\\)?SYSTEM$')
        $taskDef.Principal.UserId    = if ($isSystemAccount) { 'NT AUTHORITY\SYSTEM' } else { $PrincipalUser }
        $taskDef.Principal.LogonType = if ($isSystemAccount) { 5 } else { 3 }
        $taskDef.Principal.RunLevel  = if ($PrincipalRunLevel -eq 'Highest') { 1 } else { 0 }

        # Settings
        $taskDef.Settings.Enabled                    = $true
        $taskDef.Settings.AllowDemandStart           = $true
        $taskDef.Settings.StartWhenAvailable         = $EnableStartWhenAvailable
        $taskDef.Settings.DisallowStartIfOnBatteries = $false
        $taskDef.Settings.StopIfGoingOnBatteries     = $false
        $taskDef.Settings.MultipleInstances          = 2 # TASK_INSTANCES_IGNORE_NEW
        $taskDef.Settings.ExecutionTimeLimit         = 'PT4H'
        $taskDef.Settings.Compatibility              = 4 # Windows 10+

        # Parse StartBoundary for calendar triggers
        $startBoundary = $null
        if (-not [string]::IsNullOrWhiteSpace($ScheduleAt)) {
            $parts = $ScheduleAt.Split(':')
            $hour  = [int]$parts[0]
            $min   = [int]$parts[1]
            $sec   = if ($parts.Count -ge 3) { [int]$parts[2] } else { 0 }
            $dt    = Get-Date -Hour $hour -Minute $min -Second $sec
            $startBoundary = $dt.ToString('yyyy-MM-ddTHH:mm:ss')
        }

        # 1. Calendar Triggers (Daily / Weekly / Monthly)
        if ($ScheduleDaysOfWeek -and $ScheduleDaysOfWeek.Count -gt 0) {
            $dowBitmask = 0
            $dowMap = @{
                'Sunday'    = 1
                'Monday'    = 2
                'Tuesday'   = 4
                'Wednesday' = 8
                'Thursday'  = 16
                'Friday'    = 32
                'Saturday'  = 64
            }
            foreach ($day in $ScheduleDaysOfWeek) {
                $dowBitmask = $dowBitmask -bor $dowMap[$day.ToString()]
            }

            $trigger = $taskDef.Triggers.Create(3) # TASK_TRIGGER_WEEKLY
            $trigger.StartBoundary = $startBoundary
            $trigger.WeeksInterval = 1
            $trigger.DaysOfWeek    = $dowBitmask
            $trigger.Enabled       = $true
            $triggerSummaries.Add("Weekly ($($ScheduleDaysOfWeek -join ', ')) at $ScheduleAt")
        }
        elseif (($ScheduleDaysOfMonth -and $ScheduleDaysOfMonth.Count -gt 0) -or $ScheduleLastDayOfMonth.IsPresent) {
            $domBitmask = 0
            if ($ScheduleDaysOfMonth) {
                foreach ($dayNum in ($ScheduleDaysOfMonth | Select-Object -Unique)) {
                    $domBitmask = $domBitmask -bor (1 -shl ($dayNum - 1))
                }
            }

            $trigger = $taskDef.Triggers.Create(4) # TASK_TRIGGER_MONTHLY
            $trigger.StartBoundary = $startBoundary
            $trigger.MonthsOfYear  = 4095 # All 12 months
            if ($domBitmask -gt 0) {
                $trigger.DaysOfMonth = $domBitmask
            }
            if ($ScheduleLastDayOfMonth.IsPresent) {
                $trigger.RunOnLastDayOfMonth = $true
            }
            $trigger.Enabled = $true

            $dayLabels = [System.Collections.Generic.List[string]]::new()
            if ($ScheduleDaysOfMonth) {
                foreach ($d in ($ScheduleDaysOfMonth | Sort-Object -Unique)) {
                    $dayLabels.Add($d.ToString())
                }
            }
            if ($ScheduleLastDayOfMonth.IsPresent) {
                $dayLabels.Add('Last')
            }
            $triggerSummaries.Add("Monthly (Days: $($dayLabels -join ', ')) at $ScheduleAt")
        }
        elseif (-not [string]::IsNullOrWhiteSpace($ScheduleAt)) {
            $trigger = $taskDef.Triggers.Create(2) # TASK_TRIGGER_DAILY
            $trigger.StartBoundary = $startBoundary
            $trigger.DaysInterval  = 1
            $trigger.Enabled       = $true
            $triggerSummaries.Add("Daily at $ScheduleAt")
        }

        $isoDelay = ConvertTo-Iso8601Duration -Seconds $EventDelaySeconds

        # 2. User Logon Trigger
        if ($IncludeAtLogon.IsPresent) {
            $trigger = $taskDef.Triggers.Create(9) # TASK_TRIGGER_LOGON
            if (-not $isSystemAccount) {
                $trigger.UserId = $PrincipalUser
            }
            if ($isoDelay) {
                $trigger.Delay = $isoDelay
            }
            $trigger.Enabled = $true
            $triggerSummaries.Add("AtLogon (User: $PrincipalUser, Delay: ${EventDelaySeconds}s)")
        }

        # 3. System Startup Trigger
        if ($IncludeAtStartup.IsPresent) {
            $trigger = $taskDef.Triggers.Create(8) # TASK_TRIGGER_BOOT
            if ($isoDelay) {
                $trigger.Delay = $isoDelay
            }
            $trigger.Enabled = $true
            $triggerSummaries.Add("AtStartup (Delay: ${EventDelaySeconds}s)")
        }

        # 4. Workstation Unlock Trigger (Covers interactive unlock & post-hibernation unlock)
        if ($IncludeOnUnlock.IsPresent) {
            $trigger = $taskDef.Triggers.Create(11) # TASK_TRIGGER_SESSION_STATE_CHANGE
            $trigger.StateChange = 8 # TASK_SESSION_UNLOCK
            if (-not $isSystemAccount) {
                $trigger.UserId = $PrincipalUser
            }
            if ($isoDelay) {
                $trigger.Delay = $isoDelay
            }
            $trigger.Enabled = $true
            $triggerSummaries.Add("OnWorkstationUnlock (User: $PrincipalUser, Delay: ${EventDelaySeconds}s)")
        }

        # 5. System Wake from Sleep/Hibernation Event Trigger
        if ($IncludeOnWake.IsPresent) {
            $trigger = $taskDef.Triggers.Create(0) # TASK_TRIGGER_EVENT
            $trigger.Subscription = '<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name=''Microsoft-Windows-Power-Troubleshooter''] and EventID=1]]</Select></Query></QueryList>'
            if ($isoDelay) {
                $trigger.Delay = $isoDelay
            }
            $trigger.Enabled = $true
            $triggerSummaries.Add("OnWake/ResumeFromHibernation (Power-Troubleshooter EventID 1, Delay: ${EventDelaySeconds}s)")
        }

        # Action
        $action = $taskDef.Actions.Create(0) # TASK_ACTION_EXEC
        $action.Path             = $ExecutablePath
        $action.Arguments        = $ActionArguments
        $action.WorkingDirectory = $ActionWorkingDirectory

        return @{
            Xml              = $taskDef.XmlText
            TriggerSummaries = $triggerSummaries.ToArray()
        }
    }

    function Get-RegisteredScriptTasks {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$FolderPath
        )

        Write-Log -Level 'STEP' -Message "Querying Windows Task Scheduler folder '$FolderPath'..."
        $tasks = @(Get-ScheduledTask -TaskPath $FolderPath -ErrorAction SilentlyContinue)

        if ($tasks.Count -eq 0) {
            Write-Log -Level 'WARN' -Message "No scheduled tasks found in '$FolderPath'."
            return @()
        }

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($task in $tasks) {
            $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
            $actionSummary = if ($task.Actions -and $task.Actions.Count -gt 0) {
                ('{0} {1}' -f $task.Actions[0].Execute, $task.Actions[0].Arguments).Trim()
            }
            else {
                'N/A'
            }

            $results.Add([PSCustomObject]@{
                TaskName       = $task.TaskName
                TaskPath       = $task.TaskPath
                State          = $task.State.ToString()
                TriggerCount   = @($task.Triggers).Count
                LastRunTime    = if ($info) { $info.LastRunTime } else { $null }
                LastTaskResult = if ($info) { $info.LastTaskResult } else { $null }
                NextRunTime    = if ($info) { $info.NextRunTime } else { $null }
                Action         = $actionSummary
            })
        }

        Write-Log -Level 'OK' -Message "Found $($results.Count) task(s) in '$FolderPath'."
        $results | Format-Table -Property TaskName, State, TriggerCount, NextRunTime, LastRunTime, LastTaskResult -AutoSize | Out-String | ForEach-Object {
            Write-Host $_
        }

        return $results.ToArray()
    }

    function Remove-ScriptScheduledTask {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Name,

            [Parameter(Mandatory = $true)]
            [string]$FolderPath,

            [Parameter(Mandatory = $true)]
            [bool]$IsElevated
        )

        Write-Log -Level 'STEP' -Message "Locating scheduled task '$FolderPath$Name'..."
        $existing = Get-ScheduledTask -TaskName $Name -TaskPath $FolderPath -ErrorAction SilentlyContinue
        if (-not $existing) {
            throw "Scheduled task '$FolderPath$Name' was not found."
        }

        $guardRemoved = $false
        $safeToken    = Get-SafeFileToken -Name $Name
        $candidateDirs = @(
            (Join-Path -Path $env:ProgramData -ChildPath 'ScheduledScriptTasks'),
            (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'ScheduledScriptTasks')
        ) | Select-Object -Unique

        if ($PSCmdlet.ShouldProcess("$FolderPath$Name", 'Unregister Scheduled Task and clean up DailyGuard wrapper files')) {
            Unregister-ScheduledTask -TaskName $Name -TaskPath $FolderPath -Confirm:$false
            Write-Log -Level 'OK' -Message "Unregistered scheduled task '$FolderPath$Name'."

            foreach ($dir in $candidateDirs) {
                foreach ($suffix in @('-DailyGuard.ps1', '.lastrun')) {
                    $filePath = Join-Path -Path $dir -ChildPath ($safeToken + $suffix)
                    if (Test-Path -LiteralPath $filePath) {
                        Remove-Item -LiteralPath $filePath -Force -ErrorAction SilentlyContinue
                        Write-Log -Level 'INFO' -Message "Removed guard artifact: '$filePath'"
                        $guardRemoved = $true
                    }
                }
            }
        }
        else {
            Write-Log -Level 'INFO' -Message "WhatIf/Confirm: Skipped unregistering '$FolderPath$Name'."
        }

        return [PSCustomObject]@{
            Action       = 'Unregister'
            TaskName     = $Name
            TaskPath     = $FolderPath
            Status       = if ($WhatIfPreference) { 'WhatIf' } else { 'Removed' }
            GuardCleaned = $guardRemoved
            LogFile      = $Script:LogFilePath
        }
    }

    #endregion Helper Functions

    # Handle -Help or invocation without parameters BEFORE UAC check or logging
    if ($Help.IsPresent -or $PSBoundParameters.Count -eq 0) {
        Show-ScriptHelp
        exit 0
    }

    $Script:NormalizedTaskPath = Format-NormalizedTaskPath -Path $TaskPath
    Initialize-LogFile -Directory $LogDirectory

    Write-Host ''
    Write-Host '================================================================================' -ForegroundColor Cyan
    Write-Host "  $($Script:ScriptName).ps1 v$($Script:ScriptVersion)" -ForegroundColor White
    Write-Host '================================================================================' -ForegroundColor Cyan
    Write-Log -Level 'INFO' -Message "Execution started. Mode: $($PSCmdlet.ParameterSetName) | TaskPath: $($Script:NormalizedTaskPath)"
    if ($Script:LogFilePath) {
        Write-Log -Level 'INFO' -Message "Log file: $($Script:LogFilePath)"
    }

    $Script:IsAdmin = Test-IsAdministrator
    $needsAdmin = $false
    if ($PSCmdlet.ParameterSetName -eq 'Register') {
        $needsAdmin = ($RunLevel -eq 'Highest') -or $AtStartup.IsPresent -or $OnWake.IsPresent -or ($RunAsUser -match '^(NT AUTHORITY\\)?SYSTEM$')
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Unregister') {
        $needsAdmin = $true
    }

    if ($needsAdmin -and -not $Script:IsAdmin -and -not $SkipAdminCheck.IsPresent -and -not $WhatIfPreference) {
        Invoke-SelfElevation -BoundParameters $PSBoundParameters -ScriptFile $PSCommandPath
    }
    elseif ($needsAdmin -and -not $Script:IsAdmin) {
        Write-Log -Level 'WARN' -Message 'Running without Administrator privileges (SID S-1-5-32-544). Elevated task operations may fail unless permitted.'
    }
}

process {
    try {
        switch ($PSCmdlet.ParameterSetName) {
            'List' {
                Write-Progress -Activity $Script:ScriptName -Status 'Listing scheduled tasks...' -PercentComplete 50
                $listed = Get-RegisteredScriptTasks -FolderPath $Script:NormalizedTaskPath
                Write-Progress -Activity $Script:ScriptName -Completed
                if ($PassThru.IsPresent) {
                    $listed
                }
            }

            'Unregister' {
                Write-Progress -Activity $Script:ScriptName -Status "Removing task '$TaskName'..." -PercentComplete 50
                $removedResult = Remove-ScriptScheduledTask -Name $TaskName -FolderPath $Script:NormalizedTaskPath -IsElevated $Script:IsAdmin
                Write-Progress -Activity $Script:ScriptName -Completed
                if ($PassThru.IsPresent) {
                    $removedResult
                }
            }

            'Register' {
                # Step 1: Validate parameters & schedule combinations
                Write-Progress -Activity $Script:ScriptName -Status 'Step 1/5: Validating parameters and schedule rules...' -PercentComplete 15
                Write-Log -Level 'STEP' -Message 'Step 1/5: Validating parameters and schedule combinations...'

                if ($DaysOfWeek -and ($DaysOfMonth -or $LastDayOfMonth.IsPresent)) {
                    throw 'Conflicting schedule parameters: -DaysOfWeek cannot be combined with -DaysOfMonth or -LastDayOfMonth.'
                }

                $hasCalendarFilter = ($DaysOfWeek -and $DaysOfWeek.Count -gt 0) -or ($DaysOfMonth -and $DaysOfMonth.Count -gt 0) -or $LastDayOfMonth.IsPresent
                $hasEventTrigger   = $AtLogon.IsPresent -or $AtStartup.IsPresent -or $OnUnlock.IsPresent -or $OnWake.IsPresent
                $hasTimeTrigger    = -not [string]::IsNullOrWhiteSpace($At)

                if ($hasCalendarFilter -and -not $hasTimeTrigger) {
                    throw 'When specifying -DaysOfWeek, -DaysOfMonth, or -LastDayOfMonth, you must also specify -At (e.g., -At "08:00").'
                }

                if (-not $hasTimeTrigger -and -not $hasEventTrigger) {
                    throw 'At least one trigger must be specified (-At, -AtLogon, -AtStartup, -OnUnlock, or -OnWake).'
                }

                $resolvedScriptPath = $ScriptPath
                if (-not $SkipPathValidation.IsPresent) {
                    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
                        throw "Target script file not found: '$ScriptPath'. Verify the path or pass -SkipPathValidation."
                    }
                    $resolvedScriptPath = (Resolve-Path -LiteralPath $ScriptPath).ProviderPath
                }

                $resolvedWorkDir = if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
                    $WorkingDirectory
                }
                else {
                    Split-Path -Path $resolvedScriptPath -Parent
                }

                if (-not $SkipPathValidation.IsPresent -and -not (Test-Path -LiteralPath $resolvedWorkDir -PathType Container)) {
                    throw "Working directory does not exist: '$resolvedWorkDir'."
                }

                $existingTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $Script:NormalizedTaskPath -ErrorAction SilentlyContinue
                if ($existingTask -and -not $Force.IsPresent) {
                    throw "Scheduled task '$($Script:NormalizedTaskPath)$TaskName' already exists. Use -Force to overwrite it."
                }

                $resolvedUser = if (-not [string]::IsNullOrWhiteSpace($RunAsUser)) {
                    $RunAsUser
                }
                else {
                    "$($env:USERDOMAIN)\$($env:USERNAME)"
                }

                $psExecutable = Resolve-PowerShellExecutable -HostPreference $PowerShellHost
                Write-Log -Level 'OK'   -Message "Target Script     : $resolvedScriptPath"
                Write-Log -Level 'INFO' -Message "Script Arguments  : $(if ([string]::IsNullOrWhiteSpace($ScriptArguments)) { '<none>' } else { $ScriptArguments })"
                Write-Log -Level 'INFO' -Message "Working Directory : $resolvedWorkDir"
                Write-Log -Level 'INFO' -Message "PowerShell Host   : $psExecutable ($PowerShellHost)"
                Write-Log -Level 'INFO' -Message "RunAs Principal   : $resolvedUser (RunLevel: $RunLevel)"

                # Step 2: Build action & optional DailyGuard wrapper
                Write-Progress -Activity $Script:ScriptName -Status 'Step 2/5: Preparing execution action and DailyGuard wrapper...' -PercentComplete 35
                Write-Log -Level 'STEP' -Message 'Step 2/5: Preparing execution action...'

                $guardWrapperPath = $null
                $actionArguments  = ''

                if ($OncePerDay.IsPresent) {
                    $guardDir = Get-GuardDirectory -IsElevated $Script:IsAdmin
                    if ($PSCmdlet.ShouldProcess($guardDir, "Generate Once-Per-Day guard wrapper for '$TaskName'")) {
                        $guardWrapperPath = New-DailyGuardWrapper `
                            -GuardDirectory $guardDir `
                            -TaskName $TaskName `
                            -TargetScriptPath $resolvedScriptPath `
                            -TargetScriptArguments $ScriptArguments `
                            -TargetWorkingDirectory $resolvedWorkDir `
                            -TargetPowerShellExe $psExecutable `
                            -NotBeforeTime $At `
                            -AllowedDaysOfWeek $DaysOfWeek `
                            -AllowedDaysOfMonth $DaysOfMonth `
                            -IncludeLastDayOfMonth:$LastDayOfMonth `
                            -TargetLogDirectory $LogDirectory
                        Write-Log -Level 'OK' -Message "Generated DailyGuard wrapper: $guardWrapperPath"
                    }
                    else {
                        $guardWrapperPath = Join-Path -Path $guardDir -ChildPath ("{0}-DailyGuard.ps1" -f (Get-SafeFileToken -Name $TaskName))
                        Write-Log -Level 'INFO' -Message "WhatIf: Would generate DailyGuard wrapper at '$guardWrapperPath'"
                    }
                    $actionArguments = "-NoProfile -NonInteractive -WindowStyle $WindowStyle -ExecutionPolicy Bypass -File `"$guardWrapperPath`""
                }
                else {
                    $actionArguments = "-NoProfile -NonInteractive -WindowStyle $WindowStyle -ExecutionPolicy Bypass -File `"$resolvedScriptPath`""
                    if (-not [string]::IsNullOrWhiteSpace($ScriptArguments)) {
                        $actionArguments = "$actionArguments $ScriptArguments"
                    }
                }

                # Step 3: Build Task Scheduler 2.0 XML definition & triggers
                Write-Progress -Activity $Script:ScriptName -Status 'Step 3/5: Building Task Scheduler triggers and XML definition...' -PercentComplete 55
                Write-Log -Level 'STEP' -Message 'Step 3/5: Constructing Task Scheduler triggers...'

                $resolvedDescription = if (-not [string]::IsNullOrWhiteSpace($Description)) {
                    $Description
                }
                else {
                    "Automated execution of '$(Split-Path -Path $resolvedScriptPath -Leaf)' registered by $($Script:ScriptName).ps1 v$($Script:ScriptVersion)."
                }

                $taskBuild = New-TaskDefinitionXml `
                    -TaskDescription $resolvedDescription `
                    -ExecutablePath $psExecutable `
                    -ActionArguments $actionArguments `
                    -ActionWorkingDirectory $resolvedWorkDir `
                    -PrincipalUser $resolvedUser `
                    -PrincipalRunLevel $RunLevel `
                    -ScheduleAt $At `
                    -ScheduleDaysOfWeek $DaysOfWeek `
                    -ScheduleDaysOfMonth $DaysOfMonth `
                    -ScheduleLastDayOfMonth:$LastDayOfMonth `
                    -IncludeAtLogon:$AtLogon `
                    -IncludeAtStartup:$AtStartup `
                    -IncludeOnUnlock:$OnUnlock `
                    -IncludeOnWake:$OnWake `
                    -EventDelaySeconds $TriggerDelaySeconds `
                    -EnableStartWhenAvailable $StartWhenAvailable

                foreach ($summary in $taskBuild.TriggerSummaries) {
                    Write-Log -Level 'OK' -Message "Trigger Configured: $summary"
                }
                if ($OncePerDay.IsPresent) {
                    Write-Log -Level 'INFO' -Message "OncePerDay Guard  : Enabled (Earliest gate: $(if ($At) { $At } else { 'None' }), StartWhenAvailable: $StartWhenAvailable)"
                }

                # Step 4: Register Task in Windows Task Scheduler
                Write-Progress -Activity $Script:ScriptName -Status "Step 4/5: Registering task '$TaskName'..." -PercentComplete 80
                Write-Log -Level 'STEP' -Message "Step 4/5: Registering scheduled task '$($Script:NormalizedTaskPath)$TaskName'..."

                $registeredTask = $null
                $taskInfo       = $null
                $statusLabel    = 'WhatIf'

                if ($PSCmdlet.ShouldProcess("$($Script:NormalizedTaskPath)$TaskName", "Register Scheduled Task executing '$resolvedScriptPath'")) {
                    $registeredTask = Register-ScheduledTask `
                        -Xml $taskBuild.Xml `
                        -TaskName $TaskName `
                        -TaskPath $Script:NormalizedTaskPath `
                        -Force:$Force

                    $taskInfo    = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath $Script:NormalizedTaskPath -ErrorAction SilentlyContinue
                    $statusLabel = 'Registered'
                    Write-Log -Level 'OK' -Message "Successfully registered task '$($Script:NormalizedTaskPath)$TaskName' (State: $($registeredTask.State))."
                }
                else {
                    Write-Log -Level 'INFO' -Message "WhatIf/Confirm: Skipped registering '$($Script:NormalizedTaskPath)$TaskName'."
                }

                # Step 5: Verification Summary
                Write-Progress -Activity $Script:ScriptName -Status 'Step 5/5: Finalizing summary...' -PercentComplete 100
                Write-Log -Level 'STEP' -Message 'Step 5/5: Verification Summary'

                $resultObject = [PSCustomObject]@{
                    Action           = 'Register'
                    TaskName         = $TaskName
                    TaskPath         = $Script:NormalizedTaskPath
                    Status           = $statusLabel
                    TaskState        = if ($registeredTask) { $registeredTask.State.ToString() } else { 'Preview' }
                    NextRunTime      = if ($taskInfo) { $taskInfo.NextRunTime } else { $null }
                    ScriptPath       = $resolvedScriptPath
                    ScriptArguments  = $ScriptArguments
                    WorkingDirectory = $resolvedWorkDir
                    PowerShellHost   = $psExecutable
                    RunAsUser        = $resolvedUser
                    RunLevel         = $RunLevel
                    OncePerDay       = $OncePerDay.IsPresent
                    GuardWrapperPath = $guardWrapperPath
                    Triggers         = $taskBuild.TriggerSummaries
                    LogFile          = $Script:LogFilePath
                }

                Write-Host ''
                Write-Host '--------------------------------------------------------------------------------' -ForegroundColor DarkCyan
                Write-Host "  Task Name         : $($resultObject.TaskPath)$($resultObject.TaskName)" -ForegroundColor White
                Write-Host "  Status            : $($resultObject.Status) ($($resultObject.TaskState))" -ForegroundColor Green
                Write-Host "  Next Run Time     : $(if ($resultObject.NextRunTime) { $resultObject.NextRunTime } else { 'Event-driven / Preview' })" -ForegroundColor White
                Write-Host "  Target Command    : $($resultObject.ScriptPath) $($resultObject.ScriptArguments)" -ForegroundColor White
                Write-Host "  Working Directory : $($resultObject.WorkingDirectory)" -ForegroundColor White
                Write-Host "  Triggers          : $($resultObject.Triggers -join ' | ')" -ForegroundColor White
                if ($resultObject.GuardWrapperPath) {
                    Write-Host "  DailyGuard Script : $($resultObject.GuardWrapperPath)" -ForegroundColor White
                }
                Write-Host "  Log File          : $($resultObject.LogFile)" -ForegroundColor DarkGray
                Write-Host '--------------------------------------------------------------------------------' -ForegroundColor DarkCyan
                Write-Host ''

                Write-Progress -Activity $Script:ScriptName -Completed

                if ($PassThru.IsPresent) {
                    $resultObject
                }
            }
        }
    }
    catch {
        Write-Progress -Activity $Script:ScriptName -Completed
        Write-Log -Level 'ERROR' -Message "Operation failed: $($_.Exception.Message)"
        throw
    }
}

end {
    $elapsed = (Get-Date) - $Script:StartTime
    Write-Log -Level 'INFO' -Message ("Execution completed in {0:N2} seconds." -f $elapsed.TotalSeconds)
}
