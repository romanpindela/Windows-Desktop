<#
.SYNOPSIS
    Optimizes Microsoft Defender Antivirus performance, resets definition caches, and manages operational exclusions.

.DESCRIPTION
    Optimize-WindowsDefender.ps1 resolves excessive CPU utilization and I/O bottlenecks caused by Microsoft Defender
    Antivirus (WinDefend / MsMpEng.exe). The script performs safe definition cache hygiene, regulates CPU scanning thresholds,
    configures idempotent file/process exclusions, and cleans stale detection history without triggering PPL (Protected Process Light)
    or Tamper Protection service termination errors.

.PARAMETER ResetSignatures
    Purges local signature definitions (-RemoveDefinitions -All) and downloads the latest Antimalware/Network Inspection definitions via MpCmdRun.exe.

.PARAMETER RestartEngine
    Performs a safe platform reload using MpCmdRun.exe (-RestartPlatform) without attempting to stop WinDefend directly.

.PARAMETER CpuLimit
    Specifies the maximum average CPU percentage Microsoft Defender can consume during scheduled/on-demand scans (5-100%). Default: 20.

.PARAMETER DisableArchiveScanning
    Disables deep scanning of large archive files (.zip, .cab, .iso, etc.) during scans to prevent severe CPU and disk I/O spikes.

.PARAMETER ApplySelfExclusion
    Adds operational exclusions for the MsMpEng.exe process and the %ProgramData%\Microsoft\Windows Defender directory to prevent scanning feedback loops.

.PARAMETER CustomExclusionPaths
    Specifies an optional array of folder paths to exclude from real-time monitoring (e.g., Git repositories, build artifacts, developer caches).

.PARAMETER CleanDetectionHistory
    Cleans stale and unlocked detection event logs from the DetectionHistory directory to resolve persistent false-positive GUI notifications.

.PARAMETER All
    Executes the complete maintenance and optimization workflow in a single sequence: signature refresh, platform reload, 20% CPU limit, archive scan bypass, self-exclusions, and history cleanup.

.PARAMETER LogPath
    Optional custom path for the execution log file. Default: C:\Logs\<yyyyMMdd_HHmmss>-Optimize-WindowsDefender-<ComputerName>-<UserName>.log.

.PARAMETER SkipAdminCheck
    Bypasses the automatic UAC elevation check (useful in automated or non-interactive deployment pipelines).

.PARAMETER PassThru
    Outputs a structured PSCustomObject containing the final configuration and execution summary to the pipeline.

.PARAMETER Help
    Displays the console help screen and parameter details. Alias: -h.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -Help
    Displays detailed parameter descriptions, syntax, and operational warnings.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -All
    Runs full signature refresh, platform reload, 20% CPU limit, archive bypass, self-exclusions, and history cleanup.

.EXAMPLE
    .\Optimize-WindowsDefender.ps1 -ResetSignatures -CpuLimit 15 -CustomExclusionPaths "C:\Dane\rpindela\GitHub" -WhatIf
    Simulates signature reset, sets CPU scan factor to 15%, and previews adding custom workspace exclusions.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.1.0
    LastModified: 2026-11-07
    Requires:     RunAsAdministrator (Elevated Token), Windows 10/11 / Windows Server, PowerShell 5.1+
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
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
    [string[]]$CustomExclusionPaths,

    [Parameter(Mandatory = $false)]
    [switch]$CleanDetectionHistory,

    [Parameter(Mandatory = $false)]
    [switch]$All,

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
    Write-Host " Optimize-WindowsDefender.ps1 - Architecture & Maintenance Guide" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Version: 1.1.0 | Author: Roman Pindela | Repository: Windows-Desktop`n" -ForegroundColor DarkGray

    Write-Host "DESCRIPTION:" -ForegroundColor Green
    Write-Host "  Maintains and optimizes Microsoft Defender Antivirus (WinDefend / MsMpEng.exe)."
    Write-Host "  Resolves runaway CPU consumption, manages scan limits, and resets corrupted caches"
    Write-Host "  without violating Protected Process Light (PPL) or Tamper Protection barriers.`n"

    Write-Host "PARAMETERS:" -ForegroundColor Green
    Write-Host "  -ResetSignatures         Purges definition cache and downloads fresh threat signatures."
    Write-Host "  -RestartEngine            Safely reloads Defender engine via platform CLI."
    Write-Host "  -CpuLimit <int>           Limits average scan CPU utilization factor (Default: 20%)."
    Write-Host "  -DisableArchiveScanning   Disables deep archive inspection during scans to avoid CPU spikes."
    Write-Host "  -ApplySelfExclusion       Excludes MsMpEng.exe and %ProgramData% Defender directories."
    Write-Host "  -CustomExclusionPaths     Array of high-I/O directories to exclude (e.g. repos, caches)."
    Write-Host "  -CleanDetectionHistory    Removes stale entries from DetectionHistory folder."
    Write-Host "  -All                      Executes all optimization and maintenance tasks."
    Write-Host "  -LogPath <string>         Custom file path for the execution log."
    Write-Host "  -SkipAdminCheck           Bypasses automatic UAC elevation check."
    Write-Host "  -PassThru                 Emits a PSCustomObject summary to the pipeline."
    Write-Host "  -WhatIf / -Confirm        Standard PowerShell impact mitigation switches."
    Write-Host "  -Help (-h)                Displays this console guide.`n"

    Write-Host "EXAMPLES:" -ForegroundColor Green
    Write-Host "  .\Optimize-WindowsDefender.ps1 -All"
    Write-Host "  .\Optimize-WindowsDefender.ps1 -ResetSignatures -RestartEngine"
    Write-Host "  .\Optimize-WindowsDefender.ps1 -CpuLimit 15 -CustomExclusionPaths 'C:\Dane\rpindela\GitHub' -WhatIf`n"
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
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'VERBOSE')]
        [string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logLine = "[$timestamp] [$Level] $Message"

    # Console Output
    switch ($Level) {
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

if (-not (Test-IsElevated) -and -not $SkipAdminCheck) {
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
    $ResetSignatures        = $true
    $RestartEngine          = $true
    $ApplySelfExclusion     = $true
    $CleanDetectionHistory   = $true
    $DisableArchiveScanning = $true
}

# Resolve Defender CLI Tool
try {
    $mpCmdRun = Get-MpCmdRunPath
    Write-ScriptLog -Message "Detected platform utility: $mpCmdRun" -Level 'VERBOSE'
}
catch {
    Write-ScriptLog -Message $_.Exception.Message -Level 'ERROR'
    Exit 1
}

# ==============================================================================
# Execution Logic
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

# 3. Apply Resource & CPU Limits
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

# 4. Exclusions (Self-Exclusion & Custom Paths)
$hasCustomPaths = ($CustomExclusionPaths -and ($CustomExclusionPaths.Count -gt 0))
if ($ApplySelfExclusion -or $hasCustomPaths) {
    try {
        # Single query to cache existing exclusions (avoids slow repetitive CIM queries)
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

        # Apply Self-Exclusions
        if ($ApplySelfExclusion) {
            if ($PSCmdlet.ShouldProcess("Microsoft Defender Exclusions", "Add MsMpEng.exe and %ProgramData% directory exclusions")) {
                Write-ScriptLog -Message "Evaluating internal feedback loop exclusions..." -Level 'INFO'

                # Process Exclusion: MsMpEng.exe
                if (-not $existingProcesses.Contains("MsMpEng.exe")) {
                    Add-MpPreference -ExclusionProcess "MsMpEng.exe" -ErrorAction Stop
                    [void]$existingProcesses.Add("MsMpEng.exe")
                    Write-ScriptLog -Message "Exclusion added for process: MsMpEng.exe" -Level 'SUCCESS'
                }
                else {
                    Write-ScriptLog -Message "Process 'MsMpEng.exe' already present in exclusion list. Skipped." -Level 'INFO'
                }

                # Directory Exclusion: %ProgramData%\Microsoft\Windows Defender
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

        # Apply Custom Path Exclusions
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

# 5. Clean Detection History
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
