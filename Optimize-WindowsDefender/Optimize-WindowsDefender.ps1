<#
.SYNOPSIS
    Optimizes Microsoft Defender Antivirus performance, resets definition caches, manages developer/operational exclusions,
    analyzes top resource-hogging files, and enforces intelligent CPU/battery scheduling policies.

.DESCRIPTION
    Optimize-WindowsDefender.ps1 is an all-in-one performance tuning, diagnostics, and maintenance suite for Microsoft Defender
    Antivirus (WinDefend / MsMpEng.exe). It resolves excessive CPU consumption and I/O bottlenecks without violating kernel-level
    Protected Process Light (PPL) or Tamper Protection barriers.

    Key capabilities include:
      1. Safe Cache & Signature Hygiene: Purges definitions (-RemoveDefinitions) and pulls fresh signatures via MpCmdRun.exe.
      2. Safe Platform Reload: Signals service reload (-RestartPlatform) compliant with PPL.
      3. CPU & Scan Throttling: Configures scan CPU load caps, archive decompression bypass, and low-priority I/O.
      4. Idempotent Exclusions: Adds self-exclusions and developer workspace/tool exclusions (Node, .NET, Rust, Python, Java, Go).
      5. Process Exclusions: Excludes high-frequency developer binaries (git, node, cargo, dotnet, python, msbuild, etc.).
      6. Dev Drive Performance Mode: Detects ReFS volumes and enables asynchronous Dev Drive protection.
      7. Scheduled Task & Battery Optimization: Enforces idle-only scanning and disables wake-ups / scans on battery.
      8. Performance Profiler (-Analyze): Records ETW traces and generates top-offenders reports (Top Files/Processes/Extensions).
      9. Config Backup & Restore: Exports/imports configuration snapshots to/from JSON and supports factory reset.
     10. Health Check & Audit: Non-destructive health assessment with Event Log analysis and rating dashboard.

.PARAMETER All
    Executes the complete optimization workflow in a single sequence (backup, signatures, reload, CPU limit 20%, archive bypass,
    idle-only scan, battery safeguards, self-exclusions, dev exclusions, dev processes, dev drive, and history cleanup).

.PARAMETER Audit
    Runs a non-destructive read-only health check assessing signature age, engine status, active exclusions, and recent Defender events. Alias: -HealthCheck.

.PARAMETER Analyze
    Records a live ETW performance trace and displays the top resource-consuming files, processes, and file extensions. Alias: -TopOffenders.

.PARAMETER AnalyzeDurationSeconds
    Duration in seconds for the live performance recording when using -Analyze. Default: 15.

.PARAMETER ResetSignatures
    Purges definition caches (-RemoveDefinitions -All) and downloads fresh antimalware/NIS updates (-SignatureUpdate).

.PARAMETER RestartEngine
    Safely reloads Defender platform services via MpCmdRun.exe (-RestartPlatform).

.PARAMETER CpuLimit
    Specifies maximum average CPU percentage Microsoft Defender can consume during scans (5-100%). Default: 20.

.PARAMETER DisableArchiveScanning
    Disables deep scanning of large archive files (.zip, .cab, .iso) during scans to avoid severe CPU lockups.

.PARAMETER ApplySelfExclusion
    Excludes MsMpEng.exe and %ProgramData%\Microsoft\Windows Defender directory to prevent scanning feedback loops.

.PARAMETER ApplyDeveloperExclusions
    Automatically detects and excludes common developer package caches and workspaces (npm, pnpm, yarn, nuget, cargo, pip, gradle, m2, go, jetbrains).

.PARAMETER DevProfiles
    Specific developer profiles to apply with -ApplyDeveloperExclusions. Valid values: 'All', 'Node', 'DotNet', 'Rust', 'Python', 'Java', 'Go', 'IDE'. Default: 'All'.

.PARAMETER ExcludeDevProcesses
    Excludes high-throughput developer processes (git.exe, node.exe, cargo.exe, rustc.exe, dotnet.exe, python.exe, msbuild.exe, etc.).

.PARAMETER CustomExclusionProcesses
    Optional array of custom process executable names to exclude (e.g., 'myapp.exe', 'custom-build.exe').

.PARAMETER CustomExclusionPaths
    Optional array of folder paths to exclude from real-time monitoring (e.g., Git repos, build caches).

.PARAMETER OptimizeScheduledTasks
    Enforces Idle-only scanning, low CPU priority, and configures Defender scheduled tasks to respect battery power and avoid catchup scan spikes.

.PARAMETER OptimizeDevDrive
    Detects ReFS Dev Drive volumes and enables Defender asynchronous Performance Mode.

.PARAMETER CleanDetectionHistory
    Cleans stale and unlocked detection event logs from the DetectionHistory directory to resolve persistent false-positive GUI notifications.

.PARAMETER BackupConfig
    Exports the current Defender preferences to a timestamped JSON file in C:\Logs (or -LogPath).

.PARAMETER RestoreConfig
    Restores Defender preferences and exclusions from a specified JSON configuration backup file.

.PARAMETER ResetToDefaults
    Restores Microsoft Defender default factory preferences (CPU 50%, archive scanning enabled, idle scan disabled, low priority disabled).

.PARAMETER LogPath
    Custom file path for the execution log file. Default: C:\Logs\<yyyyMMdd_HHmmss>-Optimize-WindowsDefender-<ComputerName>-<UserName>.log.

.PARAMETER SkipAdminCheck
    Bypasses automatic UAC elevation check (ideal for unattended CI/CD or automation runners).

.PARAMETER PassThru
    Outputs a structured PSCustomObject containing the execution results and configuration metrics to the pipeline.

.PARAMETER Help
    Displays the console help screen and parameter details. Alias: -h.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -Help
    Displays detailed parameter descriptions, syntax, and operational warnings.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -All
    Runs the full optimization workflow including backup, signatures, reload, 20% CPU limit, self/dev exclusions, and battery safeguards.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -Audit
    Performs a non-destructive health audit and displays a color-coded Defender status dashboard.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -Analyze -AnalyzeDurationSeconds 20
    Profiles live Defender I/O for 20 seconds and outputs the Top 10 files, processes, and extensions causing scan latency.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -BackupConfig
    Exports the current configuration snapshot to a JSON backup file.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -RestoreConfig "C:\Logs\20261107-DefenderConfig-Backup.json"
    Restores preferences and exclusions from a previously saved JSON snapshot.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      2.0.0
    LastModified: 2026-11-07
    Requires:     RunAsAdministrator (Elevated Token for write tasks), Windows 10/11 / Windows Server, PowerShell 5.1+
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false)]
    [switch]$All,

    [Parameter(Mandatory = $false)]
    [Alias('HealthCheck')]
    [switch]$Audit,

    [Parameter(Mandatory = $false)]
    [Alias('TopOffenders')]
    [switch]$Analyze,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 120)]
    [int]$AnalyzeDurationSeconds = 15,

    [Parameter(Mandatory = $false)]
    [switch]$ResetSignatures,

    [Parameter(Mandatory = $false)]
    [switch]$RestartEngine,

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 100)]
    [int]$CpuLimit = 20,

    [Parameter(Mandatory = $false)]
    [switch]$DisableArchiveScanning,

    [Parameter(Mandatory = $false)]
    [switch]$ApplySelfExclusion,

    [Parameter(Mandatory = $false)]
    [switch]$ApplyDeveloperExclusions,

    [Parameter(Mandatory = $false)]
    [ValidateSet('All', 'Node', 'DotNet', 'Rust', 'Python', 'Java', 'Go', 'IDE')]
    [string[]]$DevProfiles = @('All'),

    [Parameter(Mandatory = $false)]
    [switch]$ExcludeDevProcesses,

    [Parameter(Mandatory = $false)]
    [string[]]$CustomExclusionProcesses,

    [Parameter(Mandatory = $false)]
    [string[]]$CustomExclusionPaths,

    [Parameter(Mandatory = $false)]
    [switch]$OptimizeScheduledTasks,

    [Parameter(Mandatory = $false)]
    [switch]$OptimizeDevDrive,

    [Parameter(Mandatory = $false)]
    [switch]$CleanDetectionHistory,

    [Parameter(Mandatory = $false)]
    [switch]$BackupConfig,

    [Parameter(Mandatory = $false)]
    [string]$RestoreConfig,

    [Parameter(Mandatory = $false)]
    [switch]$ResetToDefaults,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ==============================================================================
# Helper Functions
# ==============================================================================

function Show-ScriptHelp {
    [CmdletBinding()]
    param()

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host " Optimize-WindowsDefender.ps1 - Architecture, Diagnostics & Tuning Suite" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Version: 2.0.0 | Author: Roman Pindela | Repository: Windows-Desktop`n" -ForegroundColor DarkGray

    Write-Host "DESCRIPTION:" -ForegroundColor Green
    Write-Host "  Enterprise-grade performance tuning, diagnostics, and maintenance suite for"
    Write-Host "  Microsoft Defender Antivirus (WinDefend / MsMpEng.exe). Regulates CPU/battery load,"
    Write-Host "  cleans caches, profiles active I/O latency, and manages intelligent exclusions"
    Write-Host "  without violating Protected Process Light (PPL) or Tamper Protection barriers.`n"

    Write-Host "PRIMARY WORKFLOWS:" -ForegroundColor Green
    Write-Host "  -All                        Runs full maintenance: backup, signatures, reload, 20% CPU limit,"
    Write-Host "                              archive bypass, idle scans, battery guards, self/dev exclusions."
    Write-Host "  -Audit (-HealthCheck)       Read-only assessment: status, signature age, exclusions, events."
    Write-Host "  -Analyze (-TopOffenders)    Live ETW profiling: reports top 10 files, processes, extensions."
    Write-Host "  -BackupConfig               Exports Defender configuration snapshot to JSON."
    Write-Host "  -RestoreConfig <path>       Restores preferences and exclusions from JSON snapshot."
    Write-Host "  -ResetToDefaults            Restores Microsoft Defender factory default settings.`n"

    Write-Host "TARGETED TUNING SWITCHES:" -ForegroundColor Green
    Write-Host "  -ResetSignatures            Purges definition cache and downloads fresh threat signatures."
    Write-Host "  -RestartEngine              Safely reloads Defender engine via platform CLI (-RestartPlatform)."
    Write-Host "  -CpuLimit <int>             Limits average scan CPU utilization factor (Default: 20%)."
    Write-Host "  -DisableArchiveScanning     Disables deep archive inspection during scans to avoid CPU spikes."
    Write-Host "  -OptimizeScheduledTasks     Configures idle-only scans, low CPU priority, and battery guards."
    Write-Host "  -OptimizeDevDrive           Detects ReFS volumes and activates asynchronous Performance Mode."
    Write-Host "  -ApplySelfExclusion         Excludes MsMpEng.exe and %ProgramData% Defender directories."
    Write-Host "  -ApplyDeveloperExclusions   Excludes active developer package caches (npm, nuget, cargo, etc.)."
    Write-Host "  -DevProfiles <string[]>     Filter dev profiles: All, Node, DotNet, Rust, Python, Java, Go, IDE."
    Write-Host "  -ExcludeDevProcesses        Excludes dev binaries (git, node, dotnet, cargo, python, msbuild)."
    Write-Host "  -CustomExclusionProcesses   Additional custom process names to exclude."
    Write-Host "  -CustomExclusionPaths       Array of high-I/O directories to exclude."
    Write-Host "  -CleanDetectionHistory      Removes stale entries from DetectionHistory folder."
    Write-Host "  -LogPath <string>           Custom file path for the execution log."
    Write-Host "  -SkipAdminCheck             Bypasses automatic UAC elevation check."
    Write-Host "  -PassThru                   Emits a PSCustomObject summary to the pipeline."
    Write-Host "  -WhatIf / -Confirm          Standard PowerShell impact mitigation switches."
    Write-Host "  -Help (-h)                  Displays this console guide.`n"

    Write-Host "EXAMPLES:" -ForegroundColor Green
    Write-Host "  .\Optimize-WindowsDefender.ps1 -All"
    Write-Host "  .\Optimize-WindowsDefender.ps1 -Audit"
    Write-Host "  .\Optimize-WindowsDefender.ps1 -Analyze -AnalyzeDurationSeconds 20"
    Write-Host "  .\Optimize-WindowsDefender.ps1 -ApplyDeveloperExclusions -ExcludeDevProcesses -CpuLimit 15"
    Write-Host "  .\Optimize-WindowsDefender.ps1 -BackupConfig"
    Write-Host "  .\Optimize-WindowsDefender.ps1 -RestoreConfig 'C:\Logs\DefenderBackup.json'`n"
}

function Test-IsElevated {
    [CmdletBinding()]
    param()
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
    return $principal.IsInRole($adminSid)
}

function Invoke-ElevationRelaunch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$BoundParameters = @{}
    )

    Write-Host "[!] Administrative privileges required. Requesting elevation via UAC..." -ForegroundColor Yellow
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptPath = $MyInvocation.PSCommandPath
    }

    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add("-NoProfile")
    $argList.Add("-ExecutionPolicy Bypass")
    $argList.Add("-File `"$scriptPath`"")

    foreach ($key in $BoundParameters.Keys) {
        $val = $BoundParameters[$key]
        if ($val -is [System.Management.Automation.SwitchParameter]) {
            if ($val.IsPresent -and $val.ToBool()) {
                $argList.Add("-$key")
            }
        }
        elseif ($val -is [bool]) {
            if ($val) {
                $argList.Add("-$key")
            }
        }
        elseif ($val -is [array]) {
            $argList.Add("-$key")
            $itemsJoined = ($val | ForEach-Object { "`"$_`"" }) -join ","
            $argList.Add($itemsJoined)
        }
        else {
            $argList.Add("-$key")
            $argList.Add("`"$val`"")
        }
    }

    try {
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList ($argList -join ' ') -Verb RunAs -PassThru
        Exit 0
    }
    catch {
        Write-Error "Failed to elevate process: $($_.Exception.Message). Please run PowerShell as Administrator."
        Exit 1
    }
}

function Write-ScriptLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'VERBOSE', 'HEADER')]
        [string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logLine = "[$timestamp] [$Level] $Message"

    # Console Output
    switch ($Level) {
        'HEADER'  { Write-Host "`n$Message" -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logLine -ForegroundColor Green }
        'WARN'    { Write-Warning $Message }
        'ERROR'   { Write-Host $logLine -ForegroundColor Red }
        'VERBOSE' { Write-Verbose $Message }
        Default   { Write-Host $logLine -ForegroundColor Cyan }
    }

    # Persistent File Logging
    if ($script:LogFilePath) {
        try {
            [System.IO.File]::AppendAllText($script:LogFilePath, "$logLine`r`n", [System.Text.Encoding]::UTF8)
        }
        catch {}
    }
}

function Get-MpCmdRunPath {
    [CmdletBinding()]
    param()

    # 1. Search CurrentVersion junction in ProgramData Platform
    $currentVersionExe = "$env:ProgramData\Microsoft\Windows Defender\Platform\CurrentVersion\MpCmdRun.exe"
    if (Test-Path -Path $currentVersionExe) {
        return $currentVersionExe
    }

    # 2. Search latest numbered platform version in ProgramData
    $platformBase = "$env:ProgramData\Microsoft\Windows Defender\Platform"
    if (Test-Path -Path $platformBase) {
        $latestPlatform = Get-ChildItem -Path $platformBase -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+(\.\d+)+' } |
            Sort-Object -Property @{ Expression = {
                try { [version]($_.Name.Split('-')[0]) } catch { [version]'0.0.0.0' }
            }}, LastWriteTime -Descending |
            Select-Object -First 1

        if ($latestPlatform) {
            $platformExe = Join-Path -Path $latestPlatform.FullName -ChildPath "MpCmdRun.exe"
            if (Test-Path -Path $platformExe) {
                return $platformExe
            }
        }
    }

    # 3. Fallback to ProgramFiles default location
    $defaultExe = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    if (Test-Path -Path $defaultExe) {
        return $defaultExe
    }

    # 4. Fallback to PATH lookup
    $cmd = Get-Command -Name "MpCmdRun.exe" -ErrorAction SilentlyContinue
    if ($cmd -and (Test-Path -Path $cmd.Source)) {
        return $cmd.Source
    }

    # 5. Fallback to 32-bit Program Files (WOW64)
    if (${env:ProgramFiles(x86)}) {
        $wowExe = "${env:ProgramFiles(x86)}\Windows Defender\MpCmdRun.exe"
        if (Test-Path -Path $wowExe) {
            return $wowExe
        }
    }

    throw "MpCmdRun.exe utility could not be located on this system."
}

# ==============================================================================
# Initialization & Elevation Verification
# ==============================================================================

if ($Help -or ($PSBoundParameters.Count -eq 0)) {
    Show-ScriptHelp
    Exit 0
}

# Audit mode can run without elevation
$isAuditOnly = $Audit -and ($PSBoundParameters.Count -eq 1 -or ($PSBoundParameters.Count -eq 2 -and $PSBoundParameters.ContainsKey('PassThru')))

if (-not $isAuditOnly -and -not (Test-IsElevated) -and -not $SkipAdminCheck) {
    Invoke-ElevationRelaunch -BoundParameters $PSBoundParameters
}

# Stopwatch for performance measurement
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Initialize Log File
if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $script:LogFilePath = $LogPath
    $parentDir = [System.IO.Path]::GetDirectoryName($LogPath)
    if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
}
else {
    $logDir = "C:\Logs"
    try {
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        $timestampFormatted = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $script:LogFilePath = Join-Path -Path $logDir -ChildPath "$timestampFormatted-Optimize-WindowsDefender-$env:COMPUTERNAME-$env:USERNAME.log"
    }
    catch {
        $script:LogFilePath = $null
        Write-Warning "Could not initialize file logging in C:\Logs\. Continuing with console output only."
    }
}

Write-ScriptLog -Message "Starting Optimize-WindowsDefender.ps1 execution on $env:COMPUTERNAME." -Level 'INFO'

# Unpack -All parameter switches
if ($All) {
    $BackupConfig             = $true
    $ResetSignatures          = $true
    $RestartEngine            = $true
    $ApplySelfExclusion       = $true
    $ApplyDeveloperExclusions = $true
    $ExcludeDevProcesses      = $true
    $OptimizeScheduledTasks   = $true
    $OptimizeDevDrive         = $true
    $CleanDetectionHistory    = $true
    $DisableArchiveScanning   = $true
}

# Resolve Defender CLI Tool
$mpCmdRun = $null
try {
    $mpCmdRun = Get-MpCmdRunPath
    Write-ScriptLog -Message "Detected platform utility: $mpCmdRun" -Level 'VERBOSE'
}
catch {
    if (-not $isAuditOnly) {
        Write-ScriptLog -Message $_.Exception.Message -Level 'ERROR'
        Exit 1
    }
}

# ==============================================================================
# WORKFLOW A: HEALTH CHECK & AUDIT MODE (-Audit)
# ==============================================================================

if ($Audit) {
    Write-ScriptLog -Message "Executing Microsoft Defender Health & Configuration Audit..." -Level 'HEADER'
    
    $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    $mpPrefs  = Get-MpPreference -ErrorAction SilentlyContinue

    # Calculate Health Scores
    $issues = [System.Collections.Generic.List[string]]::new()
    $recommendations = [System.Collections.Generic.List[string]]::new()

    if ($null -ne $mpStatus) {
        if (-not $mpStatus.RealTimeProtectionEnabled) {
            $issues.Add("RealTimeProtection is DISABLED.")
        }
        if ($mpStatus.AntivirusSignatureAge -gt 3) {
            $issues.Add("Antivirus signatures are outdated ($($mpStatus.AntivirusSignatureAge) days old).")
            $recommendations.Add("Run 'Optimize-WindowsDefender.ps1 -ResetSignatures' to download fresh definitions.")
        }
    }

    if ($null -ne $mpPrefs) {
        if ($mpPrefs.ScanAvgCPULoadFactor -gt 30) {
            $recommendations.Add("ScanAvgCPULoadFactor is high ($($mpPrefs.ScanAvgCPULoadFactor)%). Lowering to 15-20% reduces scan freeze.")
        }
        if (-not $mpPrefs.DisableArchiveScanning) {
            $recommendations.Add("Archive scanning is active. Run with -DisableArchiveScanning to mitigate multi-GB archive scan spikes.")
        }
        $excludedProcs = @($mpPrefs.ExclusionProcess)
        if ($excludedProcs -notcontains "MsMpEng.exe") {
            $recommendations.Add("MsMpEng.exe is not self-excluded. Run with -ApplySelfExclusion to avoid feedback loops.")
        }
    }

    $overallRating = if ($issues.Count -eq 0 -and $recommendations.Count -eq 0) { "OPTIMAL" }
                     elseif ($issues.Count -eq 0) { "GOOD (Optimization Recommended)" }
                     else { "ATTENTION NEEDED" }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host " Microsoft Defender Health & Posture Dashboard" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan

    $auditSummary = [PSCustomObject]@{
        ComputerName             = $env:COMPUTERNAME
        HealthRating             = $overallRating
        RealTimeProtection       = if ($null -ne $mpStatus) { $mpStatus.RealTimeProtectionEnabled } else { "Unknown" }
        AntivirusSignatureVer    = if ($null -ne $mpStatus) { $mpStatus.AntivirusSignatureVersion } else { "Unknown" }
        AntivirusSignatureAge    = if ($null -ne $mpStatus) { "$($mpStatus.AntivirusSignatureAge) day(s)" } else { "Unknown" }
        EngineVersion            = if ($null -ne $mpStatus) { $mpStatus.AMEngineVersion } else { "Unknown" }
        ScanAvgCPULoadFactor     = if ($null -ne $mpPrefs) { "$($mpPrefs.ScanAvgCPULoadFactor)%" } else { "Unknown" }
        DisableArchiveScanning   = if ($null -ne $mpPrefs) { $mpPrefs.DisableArchiveScanning } else { "Unknown" }
        ScanOnlyIfIdle           = if ($null -ne $mpPrefs -and (Get-Member -InputObject $mpPrefs -Name 'ScanOnlyIfIdleEnabled')) { $mpPrefs.ScanOnlyIfIdleEnabled } else { "N/A" }
        LowCpuPriority           = if ($null -ne $mpPrefs -and (Get-Member -InputObject $mpPrefs -Name 'EnableLowCpuPriority')) { $mpPrefs.EnableLowCpuPriority } else { "N/A" }
        ExcludedProcessesCount   = if ($null -ne $mpPrefs -and $null -ne $mpPrefs.ExclusionProcess) { @($mpPrefs.ExclusionProcess).Count } else { 0 }
        ExcludedPathsCount       = if ($null -ne $mpPrefs -and $null -ne $mpPrefs.ExclusionPath) { @($mpPrefs.ExclusionPath).Count } else { 0 }
    }

    $auditSummary | Format-List | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor White }

    # Query recent Operational Event Logs
    Write-Host "`n[Recent Defender Operational Events (Last 5)]:" -ForegroundColor Green
    try {
        $recentEvents = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -MaxEvents 5 -ErrorAction SilentlyContinue
        if ($recentEvents) {
            $recentEvents | Select-Object TimeCreated, Id, @{ Name = 'Message'; Expression = { $_.Message.Split("`n")[0].Trim() } } | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor DarkCyan }
        }
        else {
            Write-Host "  No recent operational events found." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "  Event log query requires elevated Administrator privileges." -ForegroundColor DarkGray
    }

    if ($recommendations.Count -gt 0) {
        Write-Host "`n[Optimization Recommendations]:" -ForegroundColor Yellow
        foreach ($rec in $recommendations) {
            Write-Host "  * $rec" -ForegroundColor White
        }
    }

    if ($PassThru) { return $auditSummary }
    Exit 0
}

# ==============================================================================
# WORKFLOW B: LIVE PERFORMANCE PROFILER & TOP OFFENDERS (-Analyze)
# ==============================================================================

if ($Analyze) {
    Write-ScriptLog -Message "Starting live Defender performance trace ($AnalyzeDurationSeconds seconds)..." -Level 'HEADER'

    $newPerfCmd = Get-Command -Name "New-MpPerformanceRecording" -ErrorAction SilentlyContinue
    $getPerfCmd = Get-Command -Name "Get-MpPerformanceReport" -ErrorAction SilentlyContinue

    if (-not $newPerfCmd -or -not $getPerfCmd) {
        Write-ScriptLog -Message "Performance recording cmdlets (DefenderPerformance module) are not supported on this Windows build." -Level 'ERROR'
        Exit 1
    }

    $tempTraceFile = Join-Path -Path $env:TEMP -ChildPath "Defender-Trace-$((Get-Date).ToString('yyyyMMdd-HHmmss')).etl"

    if ($PSCmdlet.ShouldProcess("Microsoft Defender ETW Engine", "Record $AnalyzeDurationSeconds-second trace to $tempTraceFile")) {
        try {
            Write-ScriptLog -Message "Recording in progress... Please generate disk/code activity (e.g. git status, build, file operations)..." -Level 'INFO'
            & $newPerfCmd.Name -RecordTo $tempTraceFile -Seconds $AnalyzeDurationSeconds -ErrorAction Stop

            if (Test-Path -Path $tempTraceFile) {
                Write-ScriptLog -Message "Trace completed. Generating top-offender analytics report..." -Level 'SUCCESS'

                Write-Host "`n================================================================================" -ForegroundColor Cyan
                Write-Host " Top Resource-Consuming Files (Duration / Scans)" -ForegroundColor Yellow
                Write-Host "================================================================================" -ForegroundColor Cyan
                & $getPerfCmd.Name -Path $tempTraceFile -TopFiles 10 | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor White }

                Write-Host "`n================================================================================" -ForegroundColor Cyan
                Write-Host " Top Scanning Processes (Initiators)" -ForegroundColor Yellow
                Write-Host "================================================================================" -ForegroundColor Cyan
                & $getPerfCmd.Name -Path $tempTraceFile -TopProcesses 10 | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor White }

                Write-Host "`n================================================================================" -ForegroundColor Cyan
                Write-Host " Top Scanned File Extensions" -ForegroundColor Yellow
                Write-Host "================================================================================" -ForegroundColor Cyan
                & $getPerfCmd.Name -Path $tempTraceFile -TopExtensions 10 | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor White }

                # Cleanup trace file
                Remove-Item -Path $tempTraceFile -Force -ErrorAction SilentlyContinue
                Write-ScriptLog -Message "Temporary trace file cleaned up." -Level 'INFO'
            }
        }
        catch {
            Write-ScriptLog -Message "Performance trace failed: $_" -Level 'ERROR'
        }
    }

    Exit 0
}

# ==============================================================================
# WORKFLOW C: BACKUP, RESTORE & FACTORY DEFAULTS
# ==============================================================================

# 1. Backup Configuration
if ($BackupConfig) {
    if ($PSCmdlet.ShouldProcess("Defender Configuration", "Export preference snapshot to JSON file")) {
        try {
            $currentPrefs = Get-MpPreference -ErrorAction Stop
            $backupObj = [PSCustomObject]@{
                BackupDate               = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                ComputerName             = $env:COMPUTERNAME
                ScanAvgCPULoadFactor     = $currentPrefs.ScanAvgCPULoadFactor
                DisableArchiveScanning   = $currentPrefs.DisableArchiveScanning
                ExclusionProcess         = @($currentPrefs.ExclusionProcess)
                ExclusionPath            = @($currentPrefs.ExclusionPath)
                ExclusionExtension       = @($currentPrefs.ExclusionExtension)
            }
            if (Get-Member -InputObject $currentPrefs -Name 'ScanOnlyIfIdleEnabled') {
                $backupObj | Add-Member -NotePropertyName 'ScanOnlyIfIdleEnabled' -NotePropertyValue $currentPrefs.ScanOnlyIfIdleEnabled
            }
            if (Get-Member -InputObject $currentPrefs -Name 'EnableLowCpuPriority') {
                $backupObj | Add-Member -NotePropertyName 'EnableLowCpuPriority' -NotePropertyValue $currentPrefs.EnableLowCpuPriority
            }

            $backupPath = Join-Path -Path $logDir -ChildPath "$((Get-Date).ToString('yyyyMMdd-HHmmss'))-DefenderConfig-Backup-$env:COMPUTERNAME.json"
            $backupJson = $backupObj | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($backupPath, $backupJson, [System.Text.Encoding]::UTF8)

            Write-ScriptLog -Message "Configuration backup successfully saved to: $backupPath" -Level 'SUCCESS'
        }
        catch {
            Write-ScriptLog -Message "Failed to create configuration backup: $_" -Level 'ERROR'
        }
    }
}

# 2. Restore Configuration
if (-not [string]::IsNullOrWhiteSpace($RestoreConfig)) {
    if (Test-Path -Path $RestoreConfig) {
        if ($PSCmdlet.ShouldProcess($RestoreConfig, "Restore Defender preferences and exclusions from JSON snapshot")) {
            try {
                $restoreContent = Get-Content -Path $RestoreConfig -Raw -Encoding UTF8 | ConvertFrom-Json
                Write-ScriptLog -Message "Restoring configuration from snapshot created on $($restoreContent.BackupDate)..." -Level 'INFO'

                if ($null -ne $restoreContent.ScanAvgCPULoadFactor) {
                    Set-MpPreference -ScanAvgCPULoadFactor $restoreContent.ScanAvgCPULoadFactor -ErrorAction Stop
                    Write-ScriptLog -Message "Restored ScanAvgCPULoadFactor to $($restoreContent.ScanAvgCPULoadFactor)%." -Level 'SUCCESS'
                }
                if ($null -ne $restoreContent.DisableArchiveScanning) {
                    Set-MpPreference -DisableArchiveScanning $restoreContent.DisableArchiveScanning -ErrorAction Stop
                    Write-ScriptLog -Message "Restored DisableArchiveScanning to $($restoreContent.DisableArchiveScanning)." -Level 'SUCCESS'
                }
                if ($restoreContent.ExclusionProcess) {
                    foreach ($proc in $restoreContent.ExclusionProcess) {
                        Add-MpPreference -ExclusionProcess $proc -ErrorAction SilentlyContinue
                    }
                    Write-ScriptLog -Message "Restored $($restoreContent.ExclusionProcess.Count) process exclusions." -Level 'SUCCESS'
                }
                if ($restoreContent.ExclusionPath) {
                    foreach ($p in $restoreContent.ExclusionPath) {
                        Add-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue
                    }
                    Write-ScriptLog -Message "Restored $($restoreContent.ExclusionPath.Count) path exclusions." -Level 'SUCCESS'
                }
                Write-ScriptLog -Message "Configuration restoration completed successfully." -Level 'SUCCESS'
            }
            catch {
                Write-ScriptLog -Message "Failed to restore configuration from JSON: $_" -Level 'ERROR'
            }
        }
    }
    else {
        Write-ScriptLog -Message "Specified restore configuration file does not exist: $RestoreConfig" -Level 'ERROR'
    }
}

# 3. Reset To Defaults
if ($ResetToDefaults) {
    if ($PSCmdlet.ShouldProcess("Microsoft Defender Preferences", "Reset configuration to Microsoft factory defaults (50% CPU, archive scan enabled, etc.)")) {
        Write-ScriptLog -Message "Resetting Microsoft Defender preferences to factory defaults..." -Level 'INFO'
        try {
            Set-MpPreference -ScanAvgCPULoadFactor 50 -ErrorAction Stop
            Set-MpPreference -DisableArchiveScanning $false -ErrorAction Stop
            
            $prefType = Get-Command Set-MpPreference
            if ($prefType.Parameters.ContainsKey('EnableLowCpuPriority')) {
                Set-MpPreference -EnableLowCpuPriority $false -ErrorAction SilentlyContinue
            }
            if ($prefType.Parameters.ContainsKey('ScanOnlyIfIdleEnabled')) {
                Set-MpPreference -ScanOnlyIfIdleEnabled $false -ErrorAction SilentlyContinue
            }
            Write-ScriptLog -Message "Factory defaults applied (ScanAvgCPULoadFactor: 50%, Archive Scanning: Enabled)." -Level 'SUCCESS'
        }
        catch {
            Write-ScriptLog -Message "Failed to reset defaults: $_" -Level 'ERROR'
        }
    }
}

# ==============================================================================
# WORKFLOW D: EXECUTION & PERFORMANCE OPTIMIZATION
# ==============================================================================

# 1. Reset Signatures & Clean Definition Cache
if ($ResetSignatures) {
    if ($PSCmdlet.ShouldProcess("Local Signature Cache & Definition Updates", "Purge definitions (-RemoveDefinitions -All) and download latest definitions (-SignatureUpdate)")) {
        Write-ScriptLog -Message "Purging signature definition cache..." -Level 'INFO'
        try {
            $purgeProcess = Start-Process -FilePath $mpCmdRun -ArgumentList "-RemoveDefinitions -All" -Wait -PassThru -NoNewWindow
            Write-ScriptLog -Message "Signature definition purge finished with exit code: $($purgeProcess.ExitCode)" -Level 'VERBOSE'

            Write-ScriptLog -Message "Downloading fresh signature definitions..." -Level 'INFO'
            $updateProcess = Start-Process -FilePath $mpCmdRun -ArgumentList "-SignatureUpdate" -Wait -PassThru -NoNewWindow
            if ($updateProcess.ExitCode -eq 0) {
                Write-ScriptLog -Message "Signature definitions refreshed successfully." -Level 'SUCCESS'
            }
            else {
                Write-ScriptLog -Message "Signature update finished with code: $($updateProcess.ExitCode)" -Level 'WARN'
            }
        }
        catch {
            Write-ScriptLog -Message "Error updating definitions: $_" -Level 'ERROR'
        }
    }
}

# 2. Safe Engine / Platform Reload (PPL/Tamper-Proof)
if ($RestartEngine) {
    if ($PSCmdlet.ShouldProcess("Microsoft Defender Platform", "Reload protection platform via MpCmdRun CLI (-RestartPlatform)")) {
        Write-ScriptLog -Message "Initiating safe platform reload (-RestartPlatform)..." -Level 'INFO'
        try {
            $reloadProcess = Start-Process -FilePath $mpCmdRun -ArgumentList "-RestartPlatform" -Wait -PassThru -NoNewWindow
            if ($reloadProcess.ExitCode -eq 0) {
                Write-ScriptLog -Message "Defender platform reload signal completed successfully." -Level 'SUCCESS'
            }
            else {
                Write-ScriptLog -Message "Platform reload completed with status code: $($reloadProcess.ExitCode)" -Level 'WARN'
            }
        }
        catch {
            Write-ScriptLog -Message "Failed to reload platform: $_" -Level 'ERROR'
        }
    }
}

# 3. Apply Resource, CPU & Archive Limits
$shouldConfigureCpu = $PSBoundParameters.ContainsKey('CpuLimit') -or $All
$shouldConfigureArchive = $DisableArchiveScanning -or ($PSBoundParameters.ContainsKey('DisableArchiveScanning') -and $DisableArchiveScanning) -or $All

if ($shouldConfigureCpu -or $shouldConfigureArchive) {
    $targetDesc = @()
    if ($shouldConfigureCpu) { $targetDesc += "ScanAvgCPULoadFactor: $CpuLimit%" }
    if ($shouldConfigureArchive) { $targetDesc += "DisableArchiveScanning: True" }
    $description = $targetDesc -join ", "

    if ($PSCmdlet.ShouldProcess("Windows Defender Engine Preferences", "Apply preference changes: $description")) {
        try {
            $currentPref = Get-MpPreference -ErrorAction SilentlyContinue

            if ($shouldConfigureCpu) {
                if ($null -ne $currentPref -and $currentPref.ScanAvgCPULoadFactor -eq $CpuLimit) {
                    Write-ScriptLog -Message "CPU scan load factor is already set to $CpuLimit%. Skipped." -Level 'INFO'
                }
                else {
                    Write-ScriptLog -Message "Configuring CPU scan load factor to $CpuLimit%..." -Level 'INFO'
                    Set-MpPreference -ScanAvgCPULoadFactor $CpuLimit -ErrorAction Stop
                    Write-ScriptLog -Message "CPU scan limit ($CpuLimit%) applied successfully." -Level 'SUCCESS'
                }
            }

            if ($shouldConfigureArchive) {
                if ($null -ne $currentPref -and $currentPref.DisableArchiveScanning -eq $true) {
                    Write-ScriptLog -Message "Archive scanning is already disabled. Skipped." -Level 'INFO'
                }
                else {
                    Write-ScriptLog -Message "Disabling archive scanning to mitigate CPU spikes during scans..." -Level 'INFO'
                    Set-MpPreference -DisableArchiveScanning $true -ErrorAction Stop
                    Write-ScriptLog -Message "Archive scanning disabled successfully." -Level 'SUCCESS'
                }
            }
        }
        catch {
            Write-ScriptLog -Message "Failed to apply Defender engine preferences: $_" -Level 'ERROR'
        }
    }
}

# 4. Schedule & Battery Safeguards (-OptimizeScheduledTasks)
if ($OptimizeScheduledTasks) {
    if ($PSCmdlet.ShouldProcess("Windows Defender Scheduling & Battery Policies", "Set Idle-only scanning, Low CPU priority, and battery safeguards")) {
        Write-ScriptLog -Message "Applying intelligent scan scheduling and battery safeguards..." -Level 'INFO'
        try {
            $prefCmd = Get-Command Set-MpPreference
            if ($prefCmd.Parameters.ContainsKey('ScanOnlyIfIdleEnabled')) {
                Set-MpPreference -ScanOnlyIfIdleEnabled $true -ErrorAction SilentlyContinue
                Write-ScriptLog -Message "ScanOnlyIfIdleEnabled configured: scans will pause when user is active." -Level 'SUCCESS'
            }
            if ($prefCmd.Parameters.ContainsKey('EnableLowCpuPriority')) {
                Set-MpPreference -EnableLowCpuPriority $true -ErrorAction SilentlyContinue
                Write-ScriptLog -Message "EnableLowCpuPriority configured: background scans run with low I/O priority." -Level 'SUCCESS'
            }
            if ($prefCmd.Parameters.ContainsKey('EnableFullScanOnBatteryPower')) {
                Set-MpPreference -EnableFullScanOnBatteryPower $false -ErrorAction SilentlyContinue
                Write-ScriptLog -Message "Disabled full scans on battery power." -Level 'SUCCESS'
            }
            if ($prefCmd.Parameters.ContainsKey('DisableCatchupQuickScan')) {
                Set-MpPreference -DisableCatchupQuickScan $true -ErrorAction SilentlyContinue
                Set-MpPreference -DisableCatchupFullScan $true -ErrorAction SilentlyContinue
                Write-ScriptLog -Message "Disabled catchup scans on boot/resume to eliminate initial startup thrashing." -Level 'SUCCESS'
            }

            # Configure Task Scheduler task settings if possible
            $taskPath = "\Microsoft\Windows\Windows Defender\"
            $taskName = "Windows Defender Scheduled Scan"
            $schedTask = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
            if ($schedTask) {
                $settings = $schedTask.Settings
                $settings.DisallowStartIfOnBatteries = $true
                $settings.StopIfGoingOnBatteries = $true
                Set-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Settings $settings -ErrorAction SilentlyContinue | Out-Null
                Write-ScriptLog -Message "Scheduled Task '$taskName' tuned with battery safeguards." -Level 'SUCCESS'
            }
        }
        catch {
            Write-ScriptLog -Message "Note on task scheduling: $_" -Level 'VERBOSE'
        }
    }
}

# 5. Dev Drive (ReFS) Performance Mode (-OptimizeDevDrive)
if ($OptimizeDevDrive) {
    if ($PSCmdlet.ShouldProcess("Dev Drive Volumes", "Check ReFS volumes and activate Defender Dev Drive Performance Mode")) {
        Write-ScriptLog -Message "Checking for ReFS / Dev Drive volumes on disk..." -Level 'INFO'
        try {
            $devVolumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemType -eq 'ReFS' -or $_.FileSystemLabel -match 'Dev' }
            if ($devVolumes) {
                Write-ScriptLog -Message "Detected ReFS/Dev Drive volume(s): $(($devVolumes | ForEach-Object { "$($_.DriveLetter): [$($_.FileSystemLabel)]" }) -join ', ')" -Level 'INFO'
                $prefCmd = Get-Command Set-MpPreference
                if ($prefCmd.Parameters.ContainsKey('PerformanceModeStatus')) {
                    Set-MpPreference -PerformanceModeStatus 1 -ErrorAction Stop
                    Write-ScriptLog -Message "Defender Dev Drive asynchronous Performance Mode enabled." -Level 'SUCCESS'
                }
            }
            else {
                Write-ScriptLog -Message "No ReFS / Dev Drive volumes detected on this machine. Skipped." -Level 'INFO'
            }
        }
        catch {
            Write-ScriptLog -Message "Dev Drive optimization note: $_" -Level 'VERBOSE'
        }
    }
}

# 6. Exclusions Management (Self, Developer Folders, Custom Paths, Processes)
$hasCustomPaths = ($CustomExclusionPaths -and ($CustomExclusionPaths.Count -gt 0))
$hasCustomProcesses = ($CustomExclusionProcesses -and ($CustomExclusionProcesses.Count -gt 0))

if ($ApplySelfExclusion -or $ApplyDeveloperExclusions -or $ExcludeDevProcesses -or $hasCustomPaths -or $hasCustomProcesses) {
    try {
        # Single query to cache existing exclusions (O(1) memory lookup)
        $initialPrefs = Get-MpPreference -ErrorAction Stop
        $existingProcesses = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        if ($initialPrefs.ExclusionProcess) {
            foreach ($proc in @($initialPrefs.ExclusionProcess)) {
                if (-not [string]::IsNullOrWhiteSpace($proc)) { [void]$existingProcesses.Add($proc.Trim()) }
            }
        }

        $existingPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        if ($initialPrefs.ExclusionPath) {
            foreach ($p in @($initialPrefs.ExclusionPath)) {
                if (-not [string]::IsNullOrWhiteSpace($p)) { [void]$existingPaths.Add($p.Trim().TrimEnd('\')) }
            }
        }

        # 6a. Apply Self-Exclusion
        if ($ApplySelfExclusion) {
            if ($PSCmdlet.ShouldProcess("Microsoft Defender Self-Exclusion", "Add MsMpEng.exe and %ProgramData% directory exclusions")) {
                Write-ScriptLog -Message "Evaluating internal feedback loop exclusions..." -Level 'INFO'

                if (-not $existingProcesses.Contains("MsMpEng.exe")) {
                    Add-MpPreference -ExclusionProcess "MsMpEng.exe" -ErrorAction Stop
                    [void]$existingProcesses.Add("MsMpEng.exe")
                    Write-ScriptLog -Message "Exclusion added for process: MsMpEng.exe" -Level 'SUCCESS'
                }
                else {
                    Write-ScriptLog -Message "Process 'MsMpEng.exe' already present in exclusion list. Skipped." -Level 'INFO'
                }

                $defenderDataPath = "$env:ProgramData\Microsoft\Windows Defender".TrimEnd('\')
                if (-not $existingPaths.Contains($defenderDataPath)) {
                    Add-MpPreference -ExclusionPath $defenderDataPath -ErrorAction Stop
                    [void]$existingPaths.Add($defenderDataPath)
                    Write-ScriptLog -Message "Exclusion added for directory: $defenderDataPath" -Level 'SUCCESS'
                }
                else {
                    Write-ScriptLog -Message "Directory '$defenderDataPath' already present in exclusion list. Skipped." -Level 'INFO'
                }
            }
        }

        # 6b. Apply Developer Path Exclusions
        if ($ApplyDeveloperExclusions) {
            Write-ScriptLog -Message "Evaluating developer tool caches and workspace exclusions (Profiles: $($DevProfiles -join ', '))..." -Level 'INFO'

            $candidateDevPaths = [System.Collections.Generic.List[string]]::new()
            $userProfile = $env:USERPROFILE
            $localAppData = $env:LOCALAPPDATA
            $appData = $env:APPDATA

            $allProfiles = $DevProfiles -contains 'All'

            # Node.js
            if ($allProfiles -or ($DevProfiles -contains 'Node')) {
                $candidateDevPaths.Add((Join-Path -Path $appData -ChildPath "npm-cache"))
                $candidateDevPaths.Add((Join-Path -Path $localAppData -ChildPath "npm-cache"))
                $candidateDevPaths.Add((Join-Path -Path $localAppData -ChildPath "pnpm"))
                $candidateDevPaths.Add((Join-Path -Path $localAppData -ChildPath "Yarn\Cache"))
            }

            # .NET
            if ($allProfiles -or ($DevProfiles -contains 'DotNet')) {
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath ".nuget\packages"))
            }

            # Rust
            if ($allProfiles -or ($DevProfiles -contains 'Rust')) {
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath ".cargo"))
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath ".rustup"))
            }

            # Python
            if ($allProfiles -or ($DevProfiles -contains 'Python')) {
                $candidateDevPaths.Add((Join-Path -Path $localAppData -ChildPath "pip\cache"))
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath ".virtualenvs"))
            }

            # Java
            if ($allProfiles -or ($DevProfiles -contains 'Java')) {
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath ".gradle\caches"))
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath ".gradle\wrapper"))
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath ".m2\repository"))
            }

            # Go
            if ($allProfiles -or ($DevProfiles -contains 'Go')) {
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath "go\pkg"))
            }

            # IDE
            if ($allProfiles -or ($DevProfiles -contains 'IDE')) {
                $candidateDevPaths.Add((Join-Path -Path $localAppData -ChildPath "JetBrains"))
                $candidateDevPaths.Add((Join-Path -Path $userProfile -ChildPath ".vscode\extensions"))
            }

            $addedDevCount = 0
            foreach ($devPath in $candidateDevPaths) {
                if (Test-Path -Path $devPath) {
                    $normDevPath = (Resolve-Path -Path $devPath).Path.TrimEnd('\')
                    if (-not $existingPaths.Contains($normDevPath)) {
                        if ($PSCmdlet.ShouldProcess($normDevPath, "Add developer cache path to Defender exclusions")) {
                            Add-MpPreference -ExclusionPath $normDevPath -ErrorAction SilentlyContinue
                            [void]$existingPaths.Add($normDevPath)
                            $addedDevCount++
                            Write-ScriptLog -Message "Added developer cache exclusion: $normDevPath" -Level 'SUCCESS'
                        }
                    }
                }
            }
            if ($addedDevCount -eq 0) {
                Write-ScriptLog -Message "Developer cache paths were already excluded or not present on disk." -Level 'INFO'
            }
        }

        # 6c. Apply Developer Process Exclusions
        if ($ExcludeDevProcesses) {
            Write-ScriptLog -Message "Evaluating high-frequency developer process exclusions..." -Level 'INFO'
            $standardDevProcesses = @(
                "git.exe", "node.exe", "cargo.exe", "rustc.exe", "dotnet.exe",
                "python.exe", "pythonw.exe", "msbuild.exe", "cl.exe", "tsc.exe",
                "go.exe", "javac.exe", "java.exe", "code.exe"
            )

            $addedProcCount = 0
            foreach ($proc in $standardDevProcesses) {
                if (-not $existingProcesses.Contains($proc)) {
                    if ($PSCmdlet.ShouldProcess($proc, "Add developer binary to Defender process exclusions")) {
                        Add-MpPreference -ExclusionProcess $proc -ErrorAction SilentlyContinue
                        [void]$existingProcesses.Add($proc)
                        $addedProcCount++
                        Write-ScriptLog -Message "Added dev process exclusion: $proc" -Level 'SUCCESS'
                    }
                }
            }
            if ($addedProcCount -eq 0) {
                Write-ScriptLog -Message "Developer processes already present in exclusion list." -Level 'INFO'
            }
        }

        # 6d. Apply Custom Processes
        if ($hasCustomProcesses) {
            foreach ($cProc in $CustomExclusionProcesses) {
                if ([string]::IsNullOrWhiteSpace($cProc)) { continue }
                $cleanProc = $cProc.Trim()
                if (-not $existingProcesses.Contains($cleanProc)) {
                    if ($PSCmdlet.ShouldProcess($cleanProc, "Add custom process to Defender exclusions")) {
                        Add-MpPreference -ExclusionProcess $cleanProc -ErrorAction SilentlyContinue
                        [void]$existingProcesses.Add($cleanProc)
                        Write-ScriptLog -Message "Added custom process exclusion: $cleanProc" -Level 'SUCCESS'
                    }
                }
            }
        }

        # 6e. Apply Custom Path Exclusions
        if ($hasCustomPaths) {
            foreach ($rawPath in $CustomExclusionPaths) {
                if ([string]::IsNullOrWhiteSpace($rawPath)) { continue }
                $trimmedPath = $rawPath.Trim().Trim('"').Trim("'")

                if (Test-Path -Path $trimmedPath) {
                    $resolvedPath = (Resolve-Path -Path $trimmedPath).Path.TrimEnd('\')
                    if ($PSCmdlet.ShouldProcess($resolvedPath, "Add path to Defender exclusion list")) {
                        try {
                            if (-not $existingPaths.Contains($resolvedPath)) {
                                Add-MpPreference -ExclusionPath $resolvedPath -ErrorAction Stop
                                [void]$existingPaths.Add($resolvedPath)
                                Write-ScriptLog -Message "Added custom path exclusion: $resolvedPath" -Level 'SUCCESS'
                            }
                            else {
                                Write-ScriptLog -Message "Path already excluded: $resolvedPath" -Level 'INFO'
                            }
                        }
                        catch {
                            Write-ScriptLog -Message "Error adding exclusion for '$resolvedPath': $_" -Level 'ERROR'
                        }
                    }
                }
                else {
                    Write-ScriptLog -Message "Specified exclusion path does not exist on disk: $trimmedPath" -Level 'WARN'
                }
            }
        }
    }
    catch {
        Write-ScriptLog -Message "Failed to evaluate or configure exclusions: $_" -Level 'ERROR'
    }
}

# 7. Clean Detection History
if ($CleanDetectionHistory) {
    $detectionHistoryPath = "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service\DetectionHistory"
    if ($PSCmdlet.ShouldProcess($detectionHistoryPath, "Purge stale detection history log containers")) {
        Write-ScriptLog -Message "Attempting to clean stale detection history logs..." -Level 'INFO'
        if (Test-Path -Path $detectionHistoryPath) {
            $items = Get-ChildItem -Path $detectionHistoryPath -Force -ErrorAction SilentlyContinue
            if (-not $items -or $items.Count -eq 0) {
                Write-ScriptLog -Message "DetectionHistory folder is already empty." -Level 'INFO'
            }
            else {
                $removedCount = 0
                $lockedCount = 0
                foreach ($item in $items) {
                    try {
                        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                        $removedCount++
                    }
                    catch {
                        $lockedCount++
                        Write-ScriptLog -Message "Item '$($item.Name)' is locked by WinDefend PPL." -Level 'VERBOSE'
                    }
                }

                if ($removedCount -gt 0 -and $lockedCount -eq 0) {
                    Write-ScriptLog -Message "Detection history container cleared successfully ($removedCount item(s) purged)." -Level 'SUCCESS'
                }
                elseif ($removedCount -gt 0 -and $lockedCount -gt 0) {
                    Write-ScriptLog -Message "Partial history cleanup: $removedCount item(s) cleared, $lockedCount locked by active engine." -Level 'WARN'
                }
                else {
                    Write-ScriptLog -Message "DetectionHistory items ($lockedCount) are currently locked by WinDefend / Tamper Protection." -Level 'WARN'
                }
            }
        }
        else {
            Write-ScriptLog -Message "DetectionHistory directory not present on this system. Skipped." -Level 'INFO'
        }
    }
}

# ==============================================================================
# Summary Status
# ==============================================================================

$stopwatch.Stop()
Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-ScriptLog -Message "Optimization sequence completed in $([math]::Round($stopwatch.Elapsed.TotalSeconds, 2))s. Current configuration state:" -Level 'INFO'

$summaryObj = $null
try {
    $finalPrefs = Get-MpPreference -ErrorAction SilentlyContinue
    $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue

    $summaryObj = [PSCustomObject]@{
        ComputerName             = $env:COMPUTERNAME
        ScanAvgCPULoadFactor     = if ($null -ne $finalPrefs) { "$($finalPrefs.ScanAvgCPULoadFactor)%" } else { "N/A" }
        DisableArchiveScanning   = if ($null -ne $finalPrefs) { $finalPrefs.DisableArchiveScanning } else { "N/A" }
        ScanOnlyIfIdle           = if ($null -ne $finalPrefs -and (Get-Member -InputObject $finalPrefs -Name 'ScanOnlyIfIdleEnabled')) { $finalPrefs.ScanOnlyIfIdleEnabled } else { "N/A" }
        LowCpuPriority           = if ($null -ne $finalPrefs -and (Get-Member -InputObject $finalPrefs -Name 'EnableLowCpuPriority')) { $finalPrefs.EnableLowCpuPriority } else { "N/A" }
        AntivirusSignatureVer    = if ($null -ne $mpStatus) { $mpStatus.AntivirusSignatureVersion } else { "N/A" }
        AntivirusSignatureAge    = if ($null -ne $mpStatus) { "$($mpStatus.AntivirusSignatureAge) day(s)" } else { "N/A" }
        AMEngineVersion          = if ($null -ne $mpStatus) { $mpStatus.AMEngineVersion } else { "N/A" }
        ExcludedProcesses        = if ($null -ne $finalPrefs -and $finalPrefs.ExclusionProcess) { ($finalPrefs.ExclusionProcess -join '; ') } else { "(None)" }
        ExcludedPathsCount       = if ($null -ne $finalPrefs -and $null -ne $finalPrefs.ExclusionPath) { @($finalPrefs.ExclusionPath).Count } else { 0 }
        ExecutionTimeSeconds     = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    }

    $summaryObj | Format-List | Out-String | ForEach-Object { Write-Host $_.TrimEnd() -ForegroundColor White }
}
catch {
    Write-ScriptLog -Message "Could not retrieve post-execution preferences: $_" -Level 'WARN'
}

if ($script:LogFilePath) {
    Write-ScriptLog -Message "Log file persisted at: $script:LogFilePath" -Level 'INFO'
}

if ($PassThru -and $null -ne $summaryObj) {
    return $summaryObj
}
