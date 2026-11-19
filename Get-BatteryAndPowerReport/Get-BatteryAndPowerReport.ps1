<#
.SYNOPSIS
    Audits laptop battery health, Modern Standby (S0) sleep states, wake-armed devices, and recent
    wake causes, with optional remediation to disable unwanted wake devices.

.DESCRIPTION
    Get-BatteryAndPowerReport.ps1 is a Windows 10 and Windows 11 power and battery diagnostics tool
    focused on solving common Modern Standby (S0 Low Power Idle) battery drain, hot-bag wakeups,
    and battery cell wear issues.

    Core diagnostic capabilities:
      1. Battery Health & Cell Wear Telemetry:
         - Queries WMI root\WMI (BatteryStaticData, BatteryFullChargedCapacity, BatteryCycleCount,
           BatteryStatus) and Win32_Battery to compute DesignCapacity (mWh), FullChargeCapacity (mWh),
           HealthPercent, WearLevelPercent, CycleCount, and current charge/AC state.
         - Gracefully handles desktop PCs or VMs without an internal battery.
      2. Sleep States & Modern Standby (S0) Analysis:
         - Inspects supported sleep states via 'powercfg /a' (detecting S0 Low Power Idle vs S3
           Legacy Sleep, Hibernation, and Fast Startup) and active power scheme.
      3. Wake-Armed Devices & Wake Timers:
         - Enumerates all hardware devices currently permitted to wake the system
           ('powercfg /devicequery wake_armed') and active OS wake timers ('powercfg /waketimers').
      4. Last Wake & Recent Power Event History:
         - Captures 'powercfg /lastwake' output and queries the System Event Log for recent
           Power-Troubleshooter (Event ID 1) and Kernel-Power (Event IDs 42, 107, 506, 507) events.
      5. Wake Device Remediation:
         - Supports disabling wake capability for specific devices via -DisableWakeDevice or an
           interactive selection menu (-InteractiveDisableWake), using 'powercfg /devicedisablewake'
           with full SupportsShouldProcess (-WhatIf / -Confirm) and SID-based UAC elevation.
      6. Reporting:
         - Colorized console summary, standalone responsive Dark/Light HTML report, JSON export,
           optional native Windows 'powercfg /batteryreport' & '/sleepstudy' export, UTF-8 logging
           to C:\Logs\, and [PSCustomObject] pipeline output via -PassThru.

.PARAMETER Run
    Executes the full read-only battery health, Modern Standby, wake-armed devices, and wake history audit.
    Aliases: -Report, -Audit, -All

.PARAMETER DisableWakeDevice
    One or more exact device names (or wildcard patterns matching 'powercfg /devicequery wake_armed')
    to disable from waking the computer via 'powercfg /devicedisablewake'. Requires Administrator
    privileges (SID S-1-5-32-544) and supports -WhatIf / -Confirm.

.PARAMETER InteractiveDisableWake
    Lists all currently wake-armed devices and prompts interactively to select one or more devices
    to disable from waking the system. Requires Administrator privileges and supports -WhatIf / -Confirm.

.PARAMETER EventLookbackHours
    Number of hours to inspect in the System Event Log for Power-Troubleshooter and Kernel-Power
    Modern Standby events. Range: 1-720. Default: 72.

.PARAMETER IncludeNativePowerCfgReports
    Also generates native Windows 'powercfg /batteryreport' and (when elevated & S0 supported)
    'powercfg /sleepstudy' HTML files in the output directory.

.PARAMETER GenerateHtmlReport
    Generates a standalone responsive HTML battery & power diagnostic report.
    Aliases: -ExportHtml

.PARAMETER ReportPath
    Custom file path or directory for the HTML report.
    Aliases: -ExportPath

.PARAMETER OpenReport
    Automatically opens the generated HTML report in the default web browser upon completion.

.PARAMETER ExportJson
    Exports the full structured diagnostic report to a JSON file.

.PARAMETER JsonPath
    Custom file path or directory for the JSON export.

.PARAMETER PassThru
    Returns the structured diagnostic [PSCustomObject] to the PowerShell pipeline.

.PARAMETER EnableLogging
    Enables structured execution logging to C:\Logs\ (or -LogDirectory).
    Aliases: -Log

.PARAMETER LogDirectory
    Target directory for logs and default reports. Default: 'C:\Logs'.

.PARAMETER SkipAdminCheck
    Bypasses automatic UAC elevation check (useful for testing or -WhatIf previews).

.PARAMETER Help
    Displays the interactive console help screen and exits cleanly.
    Aliases: -h

.EXAMPLE
    .\Get-BatteryAndPowerReport.ps1 -Help
    Displays interactive help, parameter documentation, and usage examples.

.EXAMPLE
    .\Get-BatteryAndPowerReport.ps1 -Run
    Audits battery wear, cycle count, Modern Standby (S0), wake-armed devices, and recent wake causes.

.EXAMPLE
    .\Get-BatteryAndPowerReport.ps1 -Run -GenerateHtmlReport -OpenReport
    Runs the full audit and opens the standalone HTML dashboard in the default browser.

.EXAMPLE
    .\Get-BatteryAndPowerReport.ps1 -DisableWakeDevice "*Mouse*" -WhatIf
    Previews disabling wake capability for any wake-armed mouse device without applying changes.

.EXAMPLE
    .\Get-BatteryAndPowerReport.ps1 -InteractiveDisableWake -EnableLogging
    Displays an interactive picker to disable selected wake-armed devices and logs all actions.

.EXAMPLE
    .\Invoke-GitHubScript.ps1 -UrlToDownload "https://github.com/romanpindela/Windows-Desktop/blob/main/Get-BatteryAndPowerReport/Get-BatteryAndPowerReport.ps1" -ScriptArgs "-Run"
    Downloads and executes Get-BatteryAndPowerReport.ps1 directly from GitHub.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Date:         2026-11-19
    Requires:     Windows 10 / 11 / Windows Server 2016+, PowerShell 5.1+ or PowerShell 7+
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false)]
    [Alias('Report', 'Audit', 'All')]
    [switch]$Run,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$DisableWakeDevice,

    [Parameter(Mandatory = $false)]
    [switch]$InteractiveDisableWake,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 720)]
    [int]$EventLookbackHours = 72,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeNativePowerCfgReports,

    [Parameter(Mandatory = $false)]
    [Alias('ExportHtml')]
    [switch]$GenerateHtmlReport,

    [Parameter(Mandatory = $false)]
    [Alias('ExportPath')]
    [ValidateNotNullOrEmpty()]
    [string]$ReportPath,

    [Parameter(Mandatory = $false)]
    [switch]$OpenReport,

    [Parameter(Mandatory = $false)]
    [switch]$ExportJson,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$JsonPath,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [Alias('Log')]
    [switch]$EnableLogging,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $script:ScriptName       = 'Get-BatteryAndPowerReport'
    $script:ScriptVersion    = '1.0.0'
    $script:SessionTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFilePath      = $null
    $script:EffectiveLogDir  = $LogDirectory
    $script:ShouldExitEarly  = $false

    # --------------------------------------------------------------------------
    # Helper: Interactive Console Help
    # --------------------------------------------------------------------------
    function Show-ScriptHelp {
        [CmdletBinding()]
        param ()

        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host " $($script:ScriptName) v$($script:ScriptVersion) - Battery Health & Modern Standby Audit" -ForegroundColor White
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host 'Evaluates battery health (DesignCapacity vs FullChargeCapacity, cycle count),' -ForegroundColor Gray
        Write-Host 'Modern Standby (S0) status, wake-armed devices, and recent wake causes, with' -ForegroundColor Gray
        Write-Host 'safe options to disable unwanted wake devices.' -ForegroundColor Gray
        Write-Host ''
        Write-Host 'PARAMETERS:' -ForegroundColor Yellow
        Write-Host '  -Run, -Report, -Audit         Run full battery, Modern Standby & wake diagnostics.' -ForegroundColor White
        Write-Host '  -DisableWakeDevice <Str[]>    Disable wake for matching devices (Admin + -WhatIf).' -ForegroundColor White
        Write-Host '  -InteractiveDisableWake       Interactive menu to disable wake-armed devices.' -ForegroundColor White
        Write-Host '  -EventLookbackHours <Int>     Hours of System Event Log to scan (Default: 72).' -ForegroundColor White
        Write-Host '  -IncludeNativePowerCfgReports Export powercfg /batteryreport and /sleepstudy.' -ForegroundColor White
        Write-Host '  -GenerateHtmlReport           Export standalone HTML dashboard (-ExportHtml).' -ForegroundColor White
        Write-Host '  -ReportPath <Path>            Custom HTML output path (-ExportPath).' -ForegroundColor White
        Write-Host '  -OpenReport                   Open generated HTML report in default browser.' -ForegroundColor White
        Write-Host '  -ExportJson                   Export structured report to JSON.' -ForegroundColor White
        Write-Host '  -JsonPath <Path>              Custom JSON output path.' -ForegroundColor White
        Write-Host '  -PassThru                     Return [PSCustomObject] to the pipeline.' -ForegroundColor White
        Write-Host '  -EnableLogging, -Log          Write UTF-8 execution logs to C:\Logs\.' -ForegroundColor White
        Write-Host '  -LogDirectory <Path>          Override log/report directory (Default: C:\Logs).' -ForegroundColor White
        Write-Host '  -SkipAdminCheck               Bypass automatic UAC elevation check.' -ForegroundColor White
        Write-Host '  -Help, -h                     Display this help screen and exit.' -ForegroundColor White
        Write-Host ''
        Write-Host 'EXAMPLES:' -ForegroundColor Yellow
        Write-Host '  .\Get-BatteryAndPowerReport.ps1 -Run' -ForegroundColor Gray
        Write-Host '  .\Get-BatteryAndPowerReport.ps1 -Run -GenerateHtmlReport -OpenReport' -ForegroundColor Gray
        Write-Host '  .\Get-BatteryAndPowerReport.ps1 -DisableWakeDevice "*Mouse*" -WhatIf' -ForegroundColor Gray
        Write-Host '  .\Get-BatteryAndPowerReport.ps1 -InteractiveDisableWake -EnableLogging' -ForegroundColor Gray
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host ''
    }

    # --------------------------------------------------------------------------
    # Helper: Logging & Directory Setup
    # --------------------------------------------------------------------------
    function Initialize-LogDirectory {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$PreferredDirectory
        )

        try {
            if (-not (Test-Path -Path $PreferredDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $PreferredDirectory -Force | Out-Null
            }
            return $PreferredDirectory
        }
        catch {
            $fallback = Join-Path -Path $env:TEMP -ChildPath 'Logs'
            if (-not (Test-Path -Path $fallback -PathType Container)) {
                New-Item -ItemType Directory -Path $fallback -Force | Out-Null
            }
            return $fallback
        }
    }

    function Write-LogEntry {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
            [string]$Level = 'INFO'
        )

        Write-Verbose "[$Level] $Message"
        if (-not $EnableLogging -or [string]::IsNullOrWhiteSpace($script:LogFilePath)) {
            return
        }

        $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
        try {
            [System.IO.File]::AppendAllLines($script:LogFilePath, [string[]]@($line), [System.Text.Encoding]::UTF8)
        }
        catch {
            Write-Verbose "Failed to append log entry: $($_.Exception.Message)"
        }
    }

    # --------------------------------------------------------------------------
    # Helper: SID-Based Admin Check & UAC Elevation (S-1-5-32-544)
    # --------------------------------------------------------------------------
    function Test-IsAdministrator {
        [CmdletBinding()]
        [OutputType([bool])]
        param ()

        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $adminSid  = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
        return $principal.IsInRole($adminSid)
    }

    function Invoke-UacElevation {
        [CmdletBinding()]
        param ()

        $exePath = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
        $argList = New-Object System.Collections.Generic.List[string]
        $argList.Add('-NoProfile')
        $argList.Add('-ExecutionPolicy')
        $argList.Add('Bypass')
        $argList.Add('-File')
        $argList.Add("`"$PSCommandPath`"")

        foreach ($kvp in $PSBoundParameters.GetEnumerator()) {
            $key = $kvp.Key
            $val = $kvp.Value
            if ($val -is [switch]) {
                if ($val.IsPresent) { $argList.Add("-$key") }
            }
            elseif ($val -is [array]) {
                $joined = ($val | ForEach-Object { "`"$_`"" }) -join ','
                $argList.Add("-$key")
                $argList.Add($joined)
            }
            else {
                $argList.Add("-$key")
                $argList.Add("`"$val`"")
            }
        }

        Write-Host '[!] Administrator privileges (SID S-1-5-32-544) are required for wake-device modification. Requesting UAC elevation...' -ForegroundColor Yellow
        Start-Process -FilePath $exePath -ArgumentList ($argList -join ' ') -Verb RunAs
    }

    function ConvertTo-SafeHtml {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $false)]
            [AllowNull()]
            [string]$Text
        )

        if ($null -eq $Text) { return '' }
        return [System.Net.WebUtility]::HtmlEncode($Text)
    }

    # --------------------------------------------------------------------------
    # Module 1: Battery Health & Wear Analysis
    # --------------------------------------------------------------------------
    function Get-BatteryHealthSummary {
        [CmdletBinding()]
        param ()

        $batteries = @()
        $win32Batteries = @()
        $staticData     = @()
        $fullCharged    = @()
        $cycleCounts    = @()
        $liveStatus     = @()

        try {
            $win32Batteries = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)
        }
        catch {
            Write-Verbose "Win32_Battery query failed: $($_.Exception.Message)"
        }

        try {
            $staticData  = @(Get-CimInstance -Namespace 'root\WMI' -ClassName BatteryStaticData -ErrorAction SilentlyContinue)
            $fullCharged = @(Get-CimInstance -Namespace 'root\WMI' -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue)
            $cycleCounts = @(Get-CimInstance -Namespace 'root\WMI' -ClassName BatteryCycleCount -ErrorAction SilentlyContinue)
            $liveStatus  = @(Get-CimInstance -Namespace 'root\WMI' -ClassName BatteryStatus -ErrorAction SilentlyContinue)
        }
        catch {
            Write-LogEntry -Message "root\WMI battery telemetry requires elevation or is unavailable on this hardware: $($_.Exception.Message)" -Level 'WARN'
        }

        if ($staticData.Count -gt 0) {
            for ($i = 0; $i -lt $staticData.Count; $i++) {
                $s = $staticData[$i]
                $f = $fullCharged | Where-Object { $_.InstanceName -eq $s.InstanceName } | Select-Object -First 1
                $c = $cycleCounts | Where-Object { $_.InstanceName -eq $s.InstanceName } | Select-Object -First 1
                $l = $liveStatus  | Where-Object { $_.InstanceName -eq $s.InstanceName } | Select-Object -First 1
                $w = if ($i -lt $win32Batteries.Count) { $win32Batteries[$i] } else { $null }

                $designCap = [int64]$s.DesignedCapacity
                $fullCap   = if ($f) { [int64]$f.FullChargedCapacity } else { 0 }
                $cycles    = if ($c) { [int]$c.CycleCount } else { $null }

                $healthPct = if ($designCap -gt 0 -and $fullCap -gt 0) {
                    [math]::Round(($fullCap / $designCap) * 100, 1)
                } else { $null }

                $wearPct = if ($null -ne $healthPct) {
                    [math]::Round([math]::Max(0, 100 - $healthPct), 1)
                } else { $null }

                $status = if ($null -eq $healthPct) { 'INFO' }
                          elseif ($healthPct -ge 80) { 'PASS' }
                          elseif ($healthPct -ge 60) { 'WARN' }
                          else { 'FAIL' }

                $rating = if ($null -eq $healthPct) { 'Unknown' }
                          elseif ($healthPct -ge 80) { 'Healthy' }
                          elseif ($healthPct -ge 60) { 'Degraded' }
                          else { 'Critical Wear (Replace Recommended)' }

                $batteries += [PSCustomObject]@{
                    BatteryName              = if ($s.DeviceName) { $s.DeviceName } elseif ($w) { $w.Name } else { "Battery #$($i + 1)" }
                    Manufacturer             = if ($s.ManufactureName) { $s.ManufactureName } else { 'Unknown' }
                    SerialNumber             = if ($s.SerialNumber) { $s.SerialNumber } else { 'N/A' }
                    DesignCapacityMWh        = $designCap
                    FullChargeCapacityMWh    = $fullCap
                    HealthPercent            = $healthPct
                    WearLevelPercent         = $wearPct
                    CycleCount               = $cycles
                    EstimatedChargePercent   = if ($w) { $w.EstimatedChargeRemaining } else { $null }
                    PowerOnline              = if ($l) { [bool]$l.PowerOnline } else { $null }
                    Charging                 = if ($l) { [bool]$l.Charging } else { $null }
                    Discharging              = if ($l) { [bool]$l.Discharging } else { $null }
                    HealthRating             = $rating
                    Status                   = $status
                }
            }
        }
        elseif ($win32Batteries.Count -gt 0) {
            foreach ($w in $win32Batteries) {
                $batteries += [PSCustomObject]@{
                    BatteryName              = $w.Name
                    Manufacturer             = 'Unknown'
                    SerialNumber             = 'N/A'
                    DesignCapacityMWh        = $w.DesignCapacity
                    FullChargeCapacityMWh    = $null
                    HealthPercent            = $null
                    WearLevelPercent         = $null
                    CycleCount               = $null
                    EstimatedChargePercent   = $w.EstimatedChargeRemaining
                    PowerOnline              = ($w.BatteryStatus -in @(2, 6, 7, 8, 9))
                    Charging                 = ($w.BatteryStatus -in @(6, 7, 8, 9))
                    Discharging              = ($w.BatteryStatus -eq 1)
                    HealthRating             = 'Run Elevated for Full WMI Capacity Telemetry'
                    Status                   = 'INFO'
                }
            }
        }

        return [PSCustomObject]@{
            HasBattery = ($batteries.Count -gt 0)
            Batteries  = $batteries
            Status     = if ($batteries.Count -eq 0) { 'INFO' }
                         elseif (($batteries.Status) -contains 'FAIL') { 'FAIL' }
                         elseif (($batteries.Status) -contains 'WARN') { 'WARN' }
                         else { 'PASS' }
            Summary    = if ($batteries.Count -eq 0) { 'No internal battery detected (Desktop PC or VM).' }
                         else { "$($batteries.Count) battery unit(s) inspected." }
        }
    }

    # --------------------------------------------------------------------------
    # Module 2: Sleep States & Modern Standby (S0) Detection
    # --------------------------------------------------------------------------
    function Get-SleepAndStandbySummary {
        [CmdletBinding()]
        param ()

        $rawSleep = ''
        $activeScheme = 'Unknown'
        try {
            $rawSleep = (& powercfg.exe /a 2>&1 | Out-String).Trim()
        }
        catch {
            Write-LogEntry -Message "powercfg /a failed: $($_.Exception.Message)" -Level 'WARN'
        }

        try {
            $activeScheme = (& powercfg.exe /getactivescheme 2>&1 | Out-String).Trim()
        }
        catch {
            Write-Verbose "powercfg /getactivescheme failed."
        }

        # Language-independent token matching (works on EN and PL Windows)
        $hasS0ModernStandby = ($rawSleep -match 'S0\s+Low\s+Power\s+Idle') -or ($rawSleep -match 'S0\b.*(Idle|bezczynno|stanu\s+u)')
        $hasS3Sleep         = ($rawSleep -match '\(S3\)') -and ($rawSleep -notmatch 'S3[^\r\n]*(not\s+supported|nie\s+jest\s+obs)')
        $hasHibernate       = ($rawSleep -match '(Hibernate|Hibernacja)') -and ($rawSleep -notmatch '(Hibernate|Hibernacja)[^\r\n]*(not\s+enabled|nie\s+zosta)')
        $s0NetworkConnected = ($rawSleep -match 'Network\s+Connected') -or ($rawSleep -match 'po..czon.*sieci')

        $sleepMode = if ($hasS0ModernStandby) { 'Modern Standby (S0 Low Power Idle)' }
                     elseif ($hasS3Sleep) { 'Traditional Sleep (S3)' }
                     else { 'Other / Restricted' }

        $status = if ($hasS0ModernStandby -and $s0NetworkConnected) { 'WARN' } else { 'PASS' }
        $notes  = if ($hasS0ModernStandby -and $s0NetworkConnected) {
            'Modern Standby (S0) with Network Connected is active - common cause of bag heat and overnight battery drain.'
        }
        elseif ($hasS0ModernStandby) {
            'Modern Standby (S0) is active (Network Disconnected).'
        }
        elseif ($hasS3Sleep) {
            'Traditional ACPI S3 Sleep is supported.'
        }
        else {
            'Review raw powercfg /a output for firmware sleep capabilities.'
        }

        return [PSCustomObject]@{
            SleepMode          = $sleepMode
            ModernStandbyS0    = $hasS0ModernStandby
            S0NetworkConnected = $s0NetworkConnected
            LegacySleepS3      = $hasS3Sleep
            HibernateAvailable = $hasHibernate
            ActivePowerScheme  = $activeScheme
            Status             = $status
            Notes              = $notes
            RawOutput          = $rawSleep
        }
    }

    # --------------------------------------------------------------------------
    # Module 3: Wake-Armed Devices & Wake Timers
    # --------------------------------------------------------------------------
    function Get-WakeArmedDevicesAndTimers {
        [CmdletBinding()]
        param ()

        $devices = @()
        try {
            $rawDevices = @(& powercfg.exe /devicequery wake_armed 2>&1)
            foreach ($line in $rawDevices) {
                $trimmed = [string]$line
                $trimmed = $trimmed.Trim()
                if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
                if ($trimmed -match '^(NONE|BRAK)$') { continue }
                $devices += $trimmed
            }
        }
        catch {
            Write-LogEntry -Message "powercfg /devicequery wake_armed failed: $($_.Exception.Message)" -Level 'WARN'
        }

        $wakeTimersRaw = ''
        $hasTimers = $false
        try {
            $wakeTimersRaw = (& powercfg.exe /waketimers 2>&1 | Out-String).Trim()
            $hasTimers = -not ([string]::IsNullOrWhiteSpace($wakeTimersRaw) -or
                               ($wakeTimersRaw -match 'no active wake timers') -or
                               ($wakeTimersRaw -match 'brak aktywnych'))
        }
        catch {
            Write-Verbose "powercfg /waketimers failed."
        }

        $status = if ($devices.Count -gt 4 -or $hasTimers) { 'WARN' } else { 'PASS' }
        return [PSCustomObject]@{
            WakeArmedDevices = $devices
            DeviceCount      = $devices.Count
            HasActiveTimers  = $hasTimers
            WakeTimersRaw    = $wakeTimersRaw
            Status           = $status
        }
    }

    # --------------------------------------------------------------------------
    # Module 4: Last Wake & Recent Power Events (Power-Troubleshooter / Kernel-Power)
    # --------------------------------------------------------------------------
    function Get-WakeHistoryAndEvents {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [int]$LookbackHours
        )

        $lastWakeRaw = ''
        try {
            $lastWakeRaw = (& powercfg.exe /lastwake 2>&1 | Out-String).Trim()
        }
        catch {
            Write-LogEntry -Message "powercfg /lastwake failed: $($_.Exception.Message)" -Level 'WARN'
        }

        $startTime = (Get-Date).AddHours(-$LookbackHours)
        $events = @()

        try {
            $filter = @{
                LogName      = 'System'
                ProviderName = @('Microsoft-Windows-Power-Troubleshooter', 'Microsoft-Windows-Kernel-Power')
                Id           = @(1, 42, 107, 506, 507)
                StartTime    = $startTime
            }
            $rawEvents = @(Get-WinEvent -FilterHashtable $filter -MaxEvents 25 -ErrorAction SilentlyContinue)
            foreach ($ev in $rawEvents) {
                $shortMsg = if ($ev.Message) {
                    ($ev.Message -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 2) -join ' | '
                } else { '' }
                if ($shortMsg.Length -gt 220) {
                    $shortMsg = $shortMsg.Substring(0, 217) + '...'
                }

                $events += [PSCustomObject]@{
                    TimeCreated = $ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
                    Provider    = $ev.ProviderName
                    EventId     = $ev.Id
                    Summary     = $shortMsg
                }
            }
        }
        catch {
            Write-Verbose "Get-WinEvent power history query returned no events or failed: $($_.Exception.Message)"
        }

        return [PSCustomObject]@{
            LastWakeRaw   = $lastWakeRaw
            LookbackHours = $LookbackHours
            EventCount    = $events.Count
            RecentEvents  = $events
        }
    }

    # --------------------------------------------------------------------------
    # Remediation: Disable Wake Capability for Selected Devices
    # --------------------------------------------------------------------------
    function Disable-SelectedWakeDevices {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [Parameter(Mandatory = $true)]
            [string[]]$TargetDevices
        )

        $results = @()
        foreach ($dev in $TargetDevices) {
            if ($PSCmdlet.ShouldProcess($dev, 'powercfg /devicedisablewake')) {
                try {
                    $out = & powercfg.exe /devicedisablewake $dev 2>&1
                    $code = $LASTEXITCODE
                    if ($code -eq 0) {
                        Write-LogEntry -Message "Disabled wake capability for device: '$dev'" -Level 'SUCCESS'
                        $results += [PSCustomObject]@{ Device = $dev; Status = 'SUCCESS'; Notes = 'Wake capability disabled.' }
                    }
                    else {
                        $msg = ($out | Out-String).Trim()
                        Write-LogEntry -Message "Failed to disable wake for '$dev' (exit $code): $msg" -Level 'ERROR'
                        $results += [PSCustomObject]@{ Device = $dev; Status = 'FAIL'; Notes = $msg }
                    }
                }
                catch {
                    Write-LogEntry -Message "Exception disabling wake for '$dev': $($_.Exception.Message)" -Level 'ERROR'
                    $results += [PSCustomObject]@{ Device = $dev; Status = 'FAIL'; Notes = $_.Exception.Message }
                }
            }
            else {
                $results += [PSCustomObject]@{ Device = $dev; Status = 'WHATIF'; Notes = 'Skipped due to -WhatIf / user declined.' }
            }
        }
        return $results
    }

    # --------------------------------------------------------------------------
    # Optional Native Windows PowerCfg Reports
    # --------------------------------------------------------------------------
    function Export-NativePowerCfgReports {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$OutputDirectory,

            [Parameter(Mandatory = $true)]
            [bool]$SupportsS0
        )

        $generated = @()
        $batPath = Join-Path -Path $OutputDirectory -ChildPath "powercfg-batteryreport_$($env:COMPUTERNAME)_$($script:SessionTimestamp).html"
        try {
            & powercfg.exe /batteryreport /output $batPath 2>&1 | Out-Null
            if (Test-Path -Path $batPath) {
                $generated += $batPath
                Write-LogEntry -Message "Generated native powercfg /batteryreport at $batPath" -Level 'SUCCESS'
            }
        }
        catch {
            Write-LogEntry -Message "powercfg /batteryreport failed: $($_.Exception.Message)" -Level 'WARN'
        }

        if ($SupportsS0 -and (Test-IsAdministrator)) {
            $sleepPath = Join-Path -Path $OutputDirectory -ChildPath "powercfg-sleepstudy_$($env:COMPUTERNAME)_$($script:SessionTimestamp).html"
            try {
                & powercfg.exe /sleepstudy /output $sleepPath 2>&1 | Out-Null
                if (Test-Path -Path $sleepPath) {
                    $generated += $sleepPath
                    Write-LogEntry -Message "Generated native powercfg /sleepstudy at $sleepPath" -Level 'SUCCESS'
                }
            }
            catch {
                Write-LogEntry -Message "powercfg /sleepstudy failed: $($_.Exception.Message)" -Level 'WARN'
            }
        }

        return $generated
    }

    # --------------------------------------------------------------------------
    # Reporting: Console Output
    # --------------------------------------------------------------------------
    function Write-ConsoleReport {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Report
        )

        $colors = @{
            'PASS'    = 'Green'
            'SUCCESS' = 'Green'
            'WARN'    = 'Yellow'
            'FAIL'    = 'Red'
            'INFO'    = 'Cyan'
            'WHATIF'  = 'Magenta'
        }

        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host " BATTERY & MODERN STANDBY REPORT | $($Report.ComputerName) | $($Report.Timestamp)" -ForegroundColor White
        Write-Host '================================================================================' -ForegroundColor Cyan

        # 1. Battery Health
        Write-Host "`n[1] BATTERY HEALTH & WEAR ANALYSIS" -ForegroundColor Yellow
        if (-not $Report.BatterySummary.HasBattery) {
            Write-Host "    [INFO] $($Report.BatterySummary.Summary)" -ForegroundColor Cyan
        }
        else {
            foreach ($b in $Report.BatterySummary.Batteries) {
                $c = $colors[$b.Status]
                Write-Host ("    [{0,-4}] {1} ({2})" -f $b.Status, $b.BatteryName, $b.Manufacturer) -ForegroundColor $c
                Write-Host ("           Design Capacity : {0} mWh | Full Charge: {1} mWh" -f $b.DesignCapacityMWh, $b.FullChargeCapacityMWh) -ForegroundColor White
                Write-Host ("           Health / Wear   : {0}% health / {1}% wear | Cycles: {2} | Rating: {3}" -f $(if ($null -ne $b.HealthPercent) { $b.HealthPercent } else { 'N/A' }), $(if ($null -ne $b.WearLevelPercent) { $b.WearLevelPercent } else { 'N/A' }), $(if ($null -ne $b.CycleCount) { $b.CycleCount } else { 'N/A' }), $b.HealthRating) -ForegroundColor Gray
                Write-Host ("           Current Charge  : {0}% | AC Online: {1}" -f $(if ($null -ne $b.EstimatedChargePercent) { $b.EstimatedChargePercent } else { 'N/A' }), $b.PowerOnline) -ForegroundColor Gray
            }
        }

        # 2. Modern Standby & Sleep States
        Write-Host "`n[2] SLEEP STATES & MODERN STANDBY (S0)" -ForegroundColor Yellow
        $sc = $colors[$Report.SleepSummary.Status]
        Write-Host ("    [{0,-4}] Sleep Mode       : {1}" -f $Report.SleepSummary.Status, $Report.SleepSummary.SleepMode) -ForegroundColor $sc
        Write-Host ("           S0 Net Connected : {0} | Legacy S3: {1} | Hibernate: {2}" -f $Report.SleepSummary.S0NetworkConnected, $Report.SleepSummary.LegacySleepS3, $Report.SleepSummary.HibernateAvailable) -ForegroundColor Gray
        Write-Host ("           Active Scheme    : {0}" -f $Report.SleepSummary.ActivePowerScheme) -ForegroundColor Gray
        Write-Host ("           Assessment       : {0}" -f $Report.SleepSummary.Notes) -ForegroundColor $sc

        # 3. Wake-Armed Devices & Timers
        Write-Host "`n[3] WAKE-ARMED DEVICES ($($Report.WakeSummary.DeviceCount))" -ForegroundColor Yellow
        if ($Report.WakeSummary.DeviceCount -eq 0) {
            Write-Host '    [PASS] No hardware devices are currently armed to wake the system.' -ForegroundColor Green
        }
        else {
            $idx = 1
            foreach ($dev in $Report.WakeSummary.WakeArmedDevices) {
                Write-Host ("    [{0,2}] {1}" -f $idx, $dev) -ForegroundColor White
                $idx++
            }
        }
        $tc = if ($Report.WakeSummary.HasActiveTimers) { 'Yellow' } else { 'Green' }
        Write-Host ("    [INFO] Active Wake Timers: {0}" -f $(if ($Report.WakeSummary.HasActiveTimers) { 'YES (see report details)' } else { 'None' })) -ForegroundColor $tc

        # 4. Last Wake & Recent Events
        Write-Host "`n[4] LAST WAKE & RECENT POWER EVENTS (Last $($Report.WakeHistory.LookbackHours)h)" -ForegroundColor Yellow
        foreach ($line in ($Report.WakeHistory.LastWakeRaw -split "`r?`n" | Select-Object -First 6)) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-Host "    $line" -ForegroundColor Gray
            }
        }
        if ($Report.WakeHistory.EventCount -gt 0) {
            Write-Host "    Recent System Power Events ($($Report.WakeHistory.EventCount) shown):" -ForegroundColor Cyan
            foreach ($ev in ($Report.WakeHistory.RecentEvents | Select-Object -First 8)) {
                Write-Host ("      - {0} | ID {1,-3} | {2}" -f $ev.TimeCreated, $ev.EventId, $ev.Summary) -ForegroundColor DarkGray
            }
        }

        # 5. Remediation Actions
        if ($Report.DisabledWakeActions -and $Report.DisabledWakeActions.Count -gt 0) {
            Write-Host "`n[5] WAKE DEVICE REMEDIATION RESULTS" -ForegroundColor Yellow
            foreach ($act in $Report.DisabledWakeActions) {
                $ac = $colors[$act.Status]
                Write-Host ("    [{0,-7}] {1} -> {2}" -f $act.Status, $act.Device, $act.Notes) -ForegroundColor $ac
            }
        }

        $oc = $colors[$Report.OverallStatus]
        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host " OVERALL POWER & BATTERY VERDICT: [$($Report.OverallStatus)]" -ForegroundColor $oc
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host ''
    }

    # --------------------------------------------------------------------------
    # Reporting: Standalone Responsive HTML Dashboard
    # --------------------------------------------------------------------------
    function Export-HtmlPowerReport {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Report,

            [Parameter(Mandatory = $true)]
            [string]$DestinationPath
        )

        $badgeClass = {
            param([string]$S)
            switch ($S) {
                'PASS'    { 'badge-pass' }
                'SUCCESS' { 'badge-pass' }
                'WARN'    { 'badge-warn' }
                'FAIL'    { 'badge-fail' }
                default   { 'badge-info' }
            }
        }

        $batteryRows = if ($Report.BatterySummary.HasBattery) {
            ($Report.BatterySummary.Batteries | ForEach-Object {
                "<tr><td><span class=`"badge $(& $badgeClass $_.Status)`">$($_.Status)</span></td><td>$(ConvertTo-SafeHtml $_.BatteryName)</td><td>$($_.DesignCapacityMWh) mWh</td><td>$($_.FullChargeCapacityMWh) mWh</td><td>$($_.HealthPercent)%</td><td>$($_.WearLevelPercent)%</td><td>$($_.CycleCount)</td><td>$(ConvertTo-SafeHtml $_.HealthRating)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="8">No internal battery detected (Desktop PC or VM).</td></tr>'
        }

        $wakeRows = if ($Report.WakeSummary.DeviceCount -gt 0) {
            ($Report.WakeSummary.WakeArmedDevices | ForEach-Object {
                "<tr><td>$(ConvertTo-SafeHtml $_)</td><td>Wake Armed</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="2">No wake-armed devices found.</td></tr>'
        }

        $eventRows = if ($Report.WakeHistory.EventCount -gt 0) {
            ($Report.WakeHistory.RecentEvents | ForEach-Object {
                "<tr><td>$(ConvertTo-SafeHtml $_.TimeCreated)</td><td>$(ConvertTo-SafeHtml $_.Provider)</td><td>$($_.EventId)</td><td>$(ConvertTo-SafeHtml $_.Summary)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="4">No Power-Troubleshooter or Kernel-Power wake events in the selected lookback window.</td></tr>'
        }

        $html = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Battery &amp; Power Report - $(ConvertTo-SafeHtml $Report.ComputerName)</title>
<style>
  :root { --bg:#0f172a; --card:#1e293b; --text:#e2e8f0; --muted:#94a3b8; --border:#334155; --accent:#38bdf8; }
  [data-theme="light"] { --bg:#f8fafc; --card:#ffffff; --text:#0f172a; --muted:#475569; --border:#e2e8f0; --accent:#0284c7; }
  body { font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background:var(--bg); color:var(--text); margin:0; padding:24px; line-height:1.5; }
  .container { max-width:1200px; margin:0 auto; }
  header { display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; margin-bottom:20px; border-bottom:1px solid var(--border); padding-bottom:16px; }
  h1 { margin:0; font-size:1.5rem; }
  h2 { margin-top:0; font-size:1.1rem; color:var(--accent); }
  .meta { color:var(--muted); font-size:0.9rem; }
  .btn { background:var(--card); color:var(--text); border:1px solid var(--border); padding:8px 14px; border-radius:6px; cursor:pointer; font-size:0.85rem; }
  .grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(220px, 1fr)); gap:14px; margin-bottom:20px; }
  .kpi { background:var(--card); border:1px solid var(--border); border-radius:10px; padding:16px; }
  .kpi-label { font-size:0.8rem; color:var(--muted); text-transform:uppercase; }
  .kpi-val { font-size:1.2rem; font-weight:700; margin-top:4px; }
  .card { background:var(--card); border:1px solid var(--border); border-radius:10px; padding:18px; margin-bottom:18px; overflow-x:auto; }
  table { width:100%; border-collapse:collapse; font-size:0.88rem; }
  th, td { text-align:left; padding:9px 10px; border-bottom:1px solid var(--border); }
  th { color:var(--muted); font-weight:600; }
  pre { background:rgba(0,0,0,0.2); padding:12px; border-radius:8px; overflow-x:auto; font-size:0.82rem; white-space:pre-wrap; }
  .badge { display:inline-block; padding:2px 8px; border-radius:999px; font-size:0.75rem; font-weight:700; }
  .badge-pass { background:#14532d; color:#86efac; }
  .badge-warn { background:#713f12; color:#fde047; }
  .badge-fail { background:#7f1d1d; color:#fca5a5; }
  .badge-info { background:#0c4a6e; color:#7dd3fc; }
  footer { text-align:center; color:var(--muted); font-size:0.8rem; margin-top:24px; }
</style>
</head>
<body>
<div class="container">
  <header>
    <div>
      <h1>Battery &amp; Modern Standby Power Report</h1>
      <div class="meta">Host: <strong>$(ConvertTo-SafeHtml $Report.ComputerName)</strong> | Generated: $(ConvertTo-SafeHtml $Report.Timestamp) | Script v$($script:ScriptVersion)</div>
    </div>
    <div>
      <button class="btn" onclick="document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'">Toggle Theme</button>
      <button class="btn" onclick="window.print()">Print</button>
    </div>
  </header>

  <div class="grid">
    <div class="kpi"><div class="kpi-label">Overall Verdict</div><div class="kpi-val"><span class="badge $(& $badgeClass $Report.OverallStatus)">$($Report.OverallStatus)</span></div></div>
    <div class="kpi"><div class="kpi-label">Sleep Mode</div><div class="kpi-val">$(ConvertTo-SafeHtml $Report.SleepSummary.SleepMode)</div></div>
    <div class="kpi"><div class="kpi-label">Wake-Armed Devices</div><div class="kpi-val">$($Report.WakeSummary.DeviceCount)</div></div>
    <div class="kpi"><div class="kpi-label">Power Events ($($Report.WakeHistory.LookbackHours)h)</div><div class="kpi-val">$($Report.WakeHistory.EventCount)</div></div>
  </div>

  <section class="card">
    <h2>Battery Health &amp; Wear</h2>
    <table>
      <thead><tr><th>Status</th><th>Battery</th><th>Design</th><th>Full Charge</th><th>Health</th><th>Wear</th><th>Cycles</th><th>Rating</th></tr></thead>
      <tbody>$batteryRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>Modern Standby &amp; Sleep Capabilities</h2>
    <p class="meta"><strong>Assessment:</strong> $(ConvertTo-SafeHtml $Report.SleepSummary.Notes)</p>
    <p class="meta"><strong>Active Power Scheme:</strong> $(ConvertTo-SafeHtml $Report.SleepSummary.ActivePowerScheme)</p>
    <pre>$(ConvertTo-SafeHtml $Report.SleepSummary.RawOutput)</pre>
  </section>

  <section class="card">
    <h2>Wake-Armed Devices</h2>
    <table>
      <thead><tr><th>Device Name</th><th>State</th></tr></thead>
      <tbody>$wakeRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>Last Wake Source &amp; Recent System Power Events</h2>
    <pre>$(ConvertTo-SafeHtml $Report.WakeHistory.LastWakeRaw)</pre>
    <table>
      <thead><tr><th>Timestamp</th><th>Provider</th><th>Event ID</th><th>Summary</th></tr></thead>
      <tbody>$eventRows</tbody>
    </table>
  </section>

  <footer>Generated by Get-BatteryAndPowerReport.ps1 v$($script:ScriptVersion) | Roman Pindela (github.com/romanpindela)</footer>
</div>
</body>
</html>
"@

        $parentDir = Split-Path -Path $DestinationPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -Path $parentDir -PathType Container)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($DestinationPath, $html, [System.Text.Encoding]::UTF8)
    }

    # --------------------------------------------------------------------------
    # Entry Guard: -Help or Zero Arguments
    # --------------------------------------------------------------------------
    if ($Help -or $PSBoundParameters.Count -eq 0) {
        Show-ScriptHelp
        $script:ShouldExitEarly = $true
        return
    }

    $needsElevation = ($null -ne $DisableWakeDevice -and $DisableWakeDevice.Count -gt 0) -or $InteractiveDisableWake
    if ($needsElevation -and -not $SkipAdminCheck -and -not (Test-IsAdministrator)) {
        Invoke-UacElevation
        $script:ShouldExitEarly = $true
        return
    }

    if ($EnableLogging -or $GenerateHtmlReport -or $ExportJson -or $IncludeNativePowerCfgReports) {
        $script:EffectiveLogDir = Initialize-LogDirectory -PreferredDirectory $LogDirectory
    }

    if ($EnableLogging) {
        $script:LogFilePath = Join-Path -Path $script:EffectiveLogDir -ChildPath "$($script:SessionTimestamp)-$($script:ScriptName)-$($env:COMPUTERNAME)-$($env:USERNAME).log"
        Write-LogEntry -Message "Started $($script:ScriptName) v$($script:ScriptVersion) on $($env:COMPUTERNAME)." -Level 'INFO'
    }
}

process {
    if ($script:ShouldExitEarly) {
        return
    }

    try {
        Write-Progress -Activity 'Battery & Power Diagnostics' -Status 'Reading battery capacity and cycle count...' -PercentComplete 20
        $batterySummary = Get-BatteryHealthSummary

        Write-Progress -Activity 'Battery & Power Diagnostics' -Status 'Inspecting sleep states and Modern Standby (S0)...' -PercentComplete 45
        $sleepSummary = Get-SleepAndStandbySummary

        Write-Progress -Activity 'Battery & Power Diagnostics' -Status 'Querying wake-armed devices and wake timers...' -PercentComplete 65
        $wakeSummary = Get-WakeArmedDevicesAndTimers

        Write-Progress -Activity 'Battery & Power Diagnostics' -Status 'Collecting last wake source and power event logs...' -PercentComplete 85
        $wakeHistory = Get-WakeHistoryAndEvents -LookbackHours $EventLookbackHours

        Write-Progress -Activity 'Battery & Power Diagnostics' -Completed

        # Handle wake-device disabling (explicit or interactive)
        $disabledActions = @()
        $devicesToDisable = New-Object System.Collections.Generic.List[string]

        if ($DisableWakeDevice -and $DisableWakeDevice.Count -gt 0) {
            foreach ($pattern in $DisableWakeDevice) {
                $matched = @($wakeSummary.WakeArmedDevices | Where-Object { $_ -like $pattern })
                if ($matched.Count -gt 0) {
                    foreach ($m in $matched) {
                        if (-not $devicesToDisable.Contains($m)) { $devicesToDisable.Add($m) }
                    }
                }
                else {
                    Write-Host "[WARN] No currently wake-armed device matched pattern: '$pattern'" -ForegroundColor Yellow
                    Write-LogEntry -Message "No wake-armed device matched pattern '$pattern'." -Level 'WARN'
                }
            }
        }

        if ($InteractiveDisableWake) {
            if ($wakeSummary.DeviceCount -eq 0) {
                Write-Host '[i] No wake-armed devices available to disable.' -ForegroundColor Cyan
            }
            else {
                Write-Host "`nSelect wake-armed devices to DISABLE (comma-separated numbers, or press Enter to cancel):" -ForegroundColor Yellow
                for ($i = 0; $i -lt $wakeSummary.WakeArmedDevices.Count; $i++) {
                    Write-Host ("  [{0}] {1}" -f ($i + 1), $wakeSummary.WakeArmedDevices[$i]) -ForegroundColor White
                }
                $selection = Read-Host 'Selection (e.g. 1,3)'
                if (-not [string]::IsNullOrWhiteSpace($selection)) {
                    foreach ($tok in ($selection -split ',')) {
                        $idx = 0
                        if ([int]::TryParse($tok.Trim(), [ref]$idx) -and $idx -ge 1 -and $idx -le $wakeSummary.WakeArmedDevices.Count) {
                            $chosen = $wakeSummary.WakeArmedDevices[$idx - 1]
                            if (-not $devicesToDisable.Contains($chosen)) { $devicesToDisable.Add($chosen) }
                        }
                    }
                }
            }
        }

        if ($devicesToDisable.Count -gt 0) {
            $disabledActions = @(Disable-SelectedWakeDevices -TargetDevices $devicesToDisable.ToArray())
            # Refresh wake-armed device list after modification
            $wakeSummary = Get-WakeArmedDevicesAndTimers
        }

        $nativeReports = @()
        if ($IncludeNativePowerCfgReports) {
            $nativeReports = @(Export-NativePowerCfgReports -OutputDirectory $script:EffectiveLogDir -SupportsS0 $sleepSummary.ModernStandbyS0)
        }

        $statuses = @($batterySummary.Status, $sleepSummary.Status, $wakeSummary.Status)
        $overallStatus = if ($statuses -contains 'FAIL') { 'FAIL' }
                         elseif ($statuses -contains 'WARN') { 'WARN' }
                         else { 'PASS' }

        $reportObject = [PSCustomObject]@{
            ComputerName        = $env:COMPUTERNAME
            UserName            = $env:USERNAME
            Timestamp           = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            OverallStatus       = $overallStatus
            BatterySummary      = $batterySummary
            SleepSummary        = $sleepSummary
            WakeSummary         = $wakeSummary
            WakeHistory         = $wakeHistory
            DisabledWakeActions = $disabledActions
            NativePowerCfgFiles = $nativeReports
        }

        Write-ConsoleReport -Report $reportObject

        foreach ($nf in $nativeReports) {
            Write-Host "[+] Native powercfg report saved to: $nf" -ForegroundColor Green
        }

        if ($GenerateHtmlReport -or -not [string]::IsNullOrWhiteSpace($ReportPath)) {
            $defaultHtml = Join-Path -Path $script:EffectiveLogDir -ChildPath "$($script:ScriptName)_$($env:COMPUTERNAME)_$($script:SessionTimestamp).html"
            $finalHtml = if ([string]::IsNullOrWhiteSpace($ReportPath)) {
                $defaultHtml
            }
            elseif (Test-Path -Path $ReportPath -PathType Container) {
                Join-Path -Path $ReportPath -ChildPath (Split-Path -Path $defaultHtml -Leaf)
            }
            else {
                $ReportPath
            }

            Export-HtmlPowerReport -Report $reportObject -DestinationPath $finalHtml
            Write-Host "[+] HTML report saved to: $finalHtml" -ForegroundColor Green
            Write-LogEntry -Message "HTML report exported to $finalHtml" -Level 'SUCCESS'

            if ($OpenReport) {
                Start-Process -FilePath $finalHtml
            }
        }

        if ($ExportJson -or -not [string]::IsNullOrWhiteSpace($JsonPath)) {
            $defaultJson = Join-Path -Path $script:EffectiveLogDir -ChildPath "$($script:ScriptName)_$($env:COMPUTERNAME)_$($script:SessionTimestamp).json"
            $finalJson = if ([string]::IsNullOrWhiteSpace($JsonPath)) {
                $defaultJson
            }
            elseif (Test-Path -Path $JsonPath -PathType Container) {
                Join-Path -Path $JsonPath -ChildPath (Split-Path -Path $defaultJson -Leaf)
            }
            else {
                $JsonPath
            }

            $parentJson = Split-Path -Path $finalJson -Parent
            if (-not [string]::IsNullOrWhiteSpace($parentJson) -and -not (Test-Path -Path $parentJson -PathType Container)) {
                New-Item -ItemType Directory -Path $parentJson -Force | Out-Null
            }
            $jsonContent = $reportObject | ConvertTo-Json -Depth 6
            [System.IO.File]::WriteAllText($finalJson, $jsonContent, [System.Text.Encoding]::UTF8)
            Write-Host "[+] JSON report saved to: $finalJson" -ForegroundColor Green
            Write-LogEntry -Message "JSON report exported to $finalJson" -Level 'SUCCESS'
        }

        if ($PassThru) {
            Write-Output $reportObject
        }
    }
    catch {
        Write-LogEntry -Message "Unhandled error during execution: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

end {
    if (-not $script:ShouldExitEarly -and $EnableLogging) {
        Write-LogEntry -Message "Completed $($script:ScriptName) execution." -Level 'INFO'
        Write-Host "[i] Log file: $($script:LogFilePath)" -ForegroundColor DarkGray
    }
}
