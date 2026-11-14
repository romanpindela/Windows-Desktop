#Requires -Version 5.1
<#
.SYNOPSIS
    Audits Windows Update configuration, patch hygiene, pending reboots, and EDR/security red flags.

.DESCRIPTION
    Audit-WindowsUpdateAndPatchStatus.ps1 is an enterprise-grade, read-only endpoint auditing tool
    for Windows 10 and Windows 11 workstations (Enterprise/Pro). It evaluates patch compliance,
    detects configuration tampering or orphaned WSUS policies, identifies multi-vector pending
    reboots, and scans for missing security updates.

    Core audit modules:
      1. Host & OS Baseline:
         - Computer name, domain/workgroup membership, OS caption, version, build, and UBR
           (Update Build Revision) from the registry.
         - System uptime (LastBootUpTime, UptimeDays).
         - Status and StartType of core update services: wuauserv, bits, cryptsvc,
           TrustedInstaller, and UsoSvc.
      2. Installed Patches & Patch Age:
         - Dual-source history from Get-HotFix (Win32_QuickFixEngineering) and COM API
           Microsoft.Update.Session (QueryHistory), including failed installations with HResult.
         - Calculates DaysSinceLastPatch and SLA status against -MaxPatchAgeDays.
      3. Multi-Vector Pending Reboot Detection:
         - Component-Based Servicing (CBS), Windows Update Auto Update, PendingFileRenameOperations,
           Computer Rename / Domain Join mismatch, and SCCM/ConfigMgr client (root\ccm\ClientSDK).
      4. Update Channel & Policy Tampering Audit (WSUS / WUfB / Red Flags):
         - Inspects HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate and ...\AU.
         - Identifies Windows Update (Cloud), WSUS, or Windows Update for Business (WUfB).
         - Flags suspicious configurations (NoAutoUpdate=1, DisableWindowsUpdateAccess=1,
           DoNotConnectToWindowsUpdateInternetLocations=1 without WSUS, unreachable/suspicious WUServer).
      5. Missing Updates Scan (Online / Offline Cache):
         - Queries Microsoft.Update.Session for missing Software (and optionally Driver) updates.
         - Categorizes by MsrcSeverity and update classification with proper COM object release.
      6. Reporting & EDR/RMM Integration:
         - Writes session logs to C:\Logs\.
         - Generates standalone offline-ready HTML dashboard, Summary & Details CSV files,
           and optional JSON output in -OutputDirectory.

    Exit Codes:
      0 - Audit completed successfully; overall status is Healthy.
      1 - Audit completed successfully; AttentionRequired or CriticalRisk detected.
      2 - Critical script execution error (e.g., log initialization failure or missing
          administrative privileges when -NoElevate is specified).

.PARAMETER Run
    Executes the Windows Update and Patch Status audit. If omitted (or when -Help / -h is
    specified), the script displays usage instructions and examples instead of running the audit.
    Alias: -r.

.PARAMETER OutputDirectory
    Target directory for generated reports (HTML, CSV, and optional JSON).
    Default: C:\Logs\PatchAudit

.PARAMETER MaxPatchAgeDays
    Maximum acceptable age in days since the last installed security/cumulative update.
    Exceeding this threshold triggers Warning (31-60 days by default) or Critical (>60 days).
    Default: 30

.PARAMETER HistoryLimit
    Maximum number of recent update history entries included in detailed reports.
    Default: 25

.PARAMETER OfflineScanOnly
    Skips online network queries to Microsoft Update / WSUS servers by setting
    UpdateSearcher.Online = $false (uses local update cache only).

.PARAMETER IncludeDrivers
    Includes missing driver updates (Type='Driver') during the Windows Update scan.

.PARAMETER ExportJson
    Generates an additional structured JSON report for EDR, SIEM, or automation ingestion.

.PARAMETER OpenReport
    Automatically opens the generated HTML dashboard in the default web browser upon completion.

.PARAMETER NoElevate
    Disables automatic UAC elevation prompt. Useful for non-interactive RMM/EDR execution
    as NT AUTHORITY\SYSTEM or automated testing.

.PARAMETER Help
    Displays the interactive CLI help guide, parameter descriptions, and usage examples.
    Alias: -h.

.EXAMPLE
    .\Audit-WindowsUpdateAndPatchStatus.ps1
    Displays the CLI help guide with parameter descriptions and usage examples.

.EXAMPLE
    .\Audit-WindowsUpdateAndPatchStatus.ps1 -r
    Runs the full audit with default settings, writes logs to C:\Logs\, and saves HTML/CSV
    reports to C:\Logs\PatchAudit.

.EXAMPLE
    .\Audit-WindowsUpdateAndPatchStatus.ps1 -r -MaxPatchAgeDays 14 -ExportJson -OpenReport
    Runs the audit with a strict 14-day patch SLA, exports JSON for SIEM ingestion, and opens
    the HTML dashboard.

.EXAMPLE
    .\Audit-WindowsUpdateAndPatchStatus.ps1 -r -OfflineScanOnly -NoElevate -OutputDirectory "C:\Temp\Audit"
    Runs an offline-cache-only audit without attempting UAC elevation, saving reports to C:\Temp\Audit.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Requires:     Windows 10 / 11, PowerShell 5.1 or PowerShell 7.x+, Administrator or SYSTEM context
#>

[CmdletBinding(SupportsShouldProcess = $false)]
param (
    [Parameter(Mandatory = $false)]
    [Alias('r')]
    [switch]$Run,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = 'C:\Logs\PatchAudit',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 3650)]
    [int]$MaxPatchAgeDays = 30,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 500)]
    [int]$HistoryLimit = 25,

    [Parameter(Mandatory = $false)]
    [switch]$OfflineScanOnly,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDrivers,

    [Parameter(Mandatory = $false)]
    [switch]$ExportJson,

    [Parameter(Mandatory = $false)]
    [switch]$OpenReport,

    [Parameter(Mandatory = $false)]
    [switch]$NoElevate,

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest

# ==============================================================================
# Script-Scope Configuration
# ==============================================================================
$script:SessionTimestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$script:LogDirectory = 'C:\Logs'
$script:LogFilePath = Join-Path -Path $script:LogDirectory -ChildPath ("Audit-WindowsUpdateAndPatchStatus_{0}.log" -f $script:SessionTimestamp)
$script:CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$script:HostUserLabel = $script:CurrentIdentity.Name
$script:ProcessId = $PID
$script:ProgressActivity = 'Windows Update & Patch Status Audit'

# ==============================================================================
# Helper Functions
# ==============================================================================

function Test-IsElevatedOrSystem {
    <#
    .SYNOPSIS
        Checks whether the current process has local Administrator (SID S-1-5-32-544) or SYSTEM (SID S-1-5-18) privileges.
    #>
    [CmdletBinding()]
    param ()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList $identity
    $adminSid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-32-544'
    $systemSid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-18'

    $isAdmin = $principal.IsInRole($adminSid)
    $isSystem = $principal.IsInRole($systemSid) -or ($identity.User -eq $systemSid)

    return [PSCustomObject]@{
        IsAdmin  = $isAdmin
        IsSystem = $isSystem
        Elevated = ($isAdmin -or $isSystem)
    }
}

function Invoke-SelfElevation {
    <#
    .SYNOPSIS
        Re-launches the script with UAC elevation (RunAs) preserving all bound parameters.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$BoundParameters
    )

    $psExePath = (Get-Process -Id $PID).Path
    if ([string]::IsNullOrWhiteSpace($psExePath)) {
        $psExePath = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh.exe' } else { 'powershell.exe' }
    }

    $argList = New-Object -TypeName System.Collections.Generic.List[string]
    $argList.Add('-NoProfile')
    $argList.Add('-ExecutionPolicy')
    $argList.Add('Bypass')
    $argList.Add('-File')
    $argList.Add(('"{0}"' -f $ScriptPath))

    foreach ($key in $BoundParameters.Keys) {
        $value = $BoundParameters[$key]
        if ($value -is [System.Management.Automation.SwitchParameter]) {
            if ($value.IsPresent) {
                $argList.Add(('-{0}' -f $key))
            }
        }
        else {
            $escaped = [string]$value -replace '"', '\"'
            $argList.Add(('-{0}' -f $key))
            $argList.Add(('"{0}"' -f $escaped))
        }
    }

    Write-Host '[INFO] Administrative privileges required. Requesting UAC elevation...' -ForegroundColor Yellow
    Start-Process -FilePath $psExePath -ArgumentList ($argList -join ' ') -Verb RunAs | Out-Null
}

function Write-AuditLog {
    <#
    .SYNOPSIS
        Writes a structured log entry to C:\Logs\ and displays formatted console output.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'SECURITY')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [switch]$ConsoleSummary
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logLine = '[{0}] [{1}] [{2}] [PID:{3}] {4}' -f $timestamp, $Level, $script:HostUserLabel, $script:ProcessId, $Message

    [System.IO.File]::AppendAllLines($script:LogFilePath, [string[]]@($logLine), [System.Text.Encoding]::UTF8)

    switch ($Level) {
        'WARNING'  { Write-Warning $Message }
        'ERROR'    { Write-Error -Message $Message -ErrorAction Continue }
        'SECURITY' { Write-Host ('[SECURITY] {0}' -f $Message) -ForegroundColor Magenta }
        'SUCCESS'  {
            if ($ConsoleSummary) {
                Write-Host ('[SUCCESS]  {0}' -f $Message) -ForegroundColor Green
            }
            else {
                Write-Verbose ('[SUCCESS] {0}' -f $Message)
            }
        }
        default {
            if ($ConsoleSummary) {
                Write-Host ('[INFO]     {0}' -f $Message) -ForegroundColor Cyan
            }
            else {
                Write-Verbose ('[INFO] {0}' -f $Message)
            }
        }
    }
}

function Initialize-AuditEnvironment {
    <#
    .SYNOPSIS
        Creates log and output directories and records execution context in the log file.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TargetOutputDirectory,

        [Parameter(Mandatory = $true)]
        [hashtable]$BoundParameters
    )

    if (-not (Test-Path -Path $script:LogDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null
    }
    if (-not (Test-Path -Path $TargetOutputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $TargetOutputDirectory -Force | Out-Null
    }

    $paramSummary = if ($BoundParameters.Count -gt 0) {
        ($BoundParameters.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join '; '
    }
    else {
        'None (defaults)'
    }

    $arch = if ([System.Environment]::Is64BitProcess) { '64-bit' } else { '32-bit' }
    Write-AuditLog -Message ('=== Audit Session Started ===') -Level 'INFO'
    Write-AuditLog -Message ('Host: {0} | User: {1} | PSVersion: {2} | ProcessArch: {3}' -f $env:COMPUTERNAME, $script:HostUserLabel, $PSVersionTable.PSVersion.ToString(), $arch) -Level 'INFO'
    Write-AuditLog -Message ('Parameters: {0}' -f $paramSummary) -Level 'INFO'
}

function Release-ComObjectSafely {
    <#
    .SYNOPSIS
        Safely releases a COM object reference if non-null and a valid COM object.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [object]$ComObject
    )

    if ($null -ne $ComObject -and [System.Runtime.InteropServices.Marshal]::IsComObject($ComObject)) {
        try {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ComObject)
        }
        catch {
            Write-Verbose ('Failed to release COM object: {0}' -f $_.Exception.Message)
        }
    }
}

function Get-OsAndServiceBaseline {
    <#
    .SYNOPSIS
        Collects OS version, UBR, system uptime, domain/workgroup context, and update service statuses.
    #>
    [CmdletBinding()]
    param ()

    $ErrorActionPreference = 'Stop'
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem

    $ubr = $null
    $displayVersion = $null
    try {
        $cvKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        if ($cvKey.PSObject.Properties.Name -contains 'UBR') {
            $ubr = $cvKey.UBR
        }
        if ($cvKey.PSObject.Properties.Name -contains 'DisplayVersion') {
            $displayVersion = $cvKey.DisplayVersion
        }
        elseif ($cvKey.PSObject.Properties.Name -contains 'ReleaseId') {
            $displayVersion = $cvKey.ReleaseId
        }
    }
    catch {
        $warnings.Add(('Failed to read UBR from registry: {0}' -f $_.Exception.Message))
    }

    $lastBoot = $operatingSystem.LastBootUpTime
    $uptimeDays = [math]::Round(((Get-Date) - $lastBoot).TotalDays, 1)

    $serviceNames = @('wuauserv', 'bits', 'cryptsvc', 'TrustedInstaller', 'UsoSvc')
    $serviceResults = New-Object -TypeName System.Collections.Generic.List[object]
    $disabledCriticalServices = New-Object -TypeName System.Collections.Generic.List[string]

    foreach ($svcName in $serviceNames) {
        try {
            $cimSvc = Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f $svcName)
            if ($null -ne $cimSvc) {
                $statusText = [string]$cimSvc.State
                $startModeText = [string]$cimSvc.StartMode
                if ($startModeText -eq 'Disabled') {
                    $disabledCriticalServices.Add($svcName)
                }
                $serviceResults.Add([PSCustomObject]@{
                        Name        = $cimSvc.Name
                        DisplayName = $cimSvc.DisplayName
                        Status      = $statusText
                        StartType   = $startModeText
                        IsHealthy   = ($startModeText -ne 'Disabled')
                    })
            }
            else {
                $warnings.Add(("Service '{0}' was not found." -f $svcName))
                $serviceResults.Add([PSCustomObject]@{
                        Name        = $svcName
                        DisplayName = $svcName
                        Status      = 'NotFound'
                        StartType   = 'Unknown'
                        IsHealthy   = $false
                    })
                $disabledCriticalServices.Add($svcName)
            }
        }
        catch {
            $warnings.Add(("Failed to query service '{0}': {1}" -f $svcName, $_.Exception.Message))
        }
    }

    return [PSCustomObject]@{
        ComputerName             = $env:COMPUTERNAME
        Domain                   = $computerSystem.Domain
        PartOfDomain             = [bool]$computerSystem.PartOfDomain
        OSCaption                = $operatingSystem.Caption
        OSVersion                = $operatingSystem.Version
        OSBuild                  = $operatingSystem.BuildNumber
        UBR                      = $ubr
        DisplayVersion           = $displayVersion
        FullBuildString          = if ($null -ne $ubr) { '{0}.{1}' -f $operatingSystem.BuildNumber, $ubr } else { [string]$operatingSystem.BuildNumber }
        LastBootUpTime           = $lastBoot
        UptimeDays               = $uptimeDays
        Services                 = $serviceResults.ToArray()
        DisabledCriticalServices = $disabledCriticalServices.ToArray()
        Warnings                 = $warnings.ToArray()
    }
}

function Convert-UpdateResultCode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$ResultCode
    )

    switch ($ResultCode) {
        0 { return 'NotStarted' }
        1 { return 'InProgress' }
        2 { return 'Succeeded' }
        3 { return 'SucceededWithErrors' }
        4 { return 'Failed' }
        5 { return 'Aborted' }
        default { return ('Unknown({0})' -f $ResultCode) }
    }
}

function Get-InstalledPatchHistory {
    <#
    .SYNOPSIS
        Retrieves installed patches and update history from Get-HotFix and Microsoft.Update.Session.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$MaxPatchAgeDays,

        [Parameter(Mandatory = $true)]
        [int]$HistoryLimit
    )

    $ErrorActionPreference = 'Stop'
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    $combinedRecords = New-Object -TypeName System.Collections.Generic.List[object]
    $seenKeys = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    # 1. Query Get-HotFix (Win32_QuickFixEngineering)
    $hotFixDates = New-Object -TypeName System.Collections.Generic.List[object]
    try {
        $hotFixes = @(Get-HotFix | Sort-Object -Property InstalledOn -Descending)
        foreach ($hf in $hotFixes) {
            $parsedDate = $null
            if ($hf.InstalledOn -is [datetime]) {
                $parsedDate = $hf.InstalledOn
            }
            elseif (-not [string]::IsNullOrWhiteSpace([string]$hf.InstalledOn)) {
                $tmpDate = [datetime]::MinValue
                if ([datetime]::TryParse([string]$hf.InstalledOn, [ref]$tmpDate)) {
                    $parsedDate = $tmpDate
                }
            }

            $kbId = [string]$hf.HotFixID
            $desc = if ([string]::IsNullOrWhiteSpace([string]$hf.Description)) { 'HotFix' } else { [string]$hf.Description }
            $recordKey = '{0}|{1}' -f $kbId, $(if ($parsedDate) { $parsedDate.ToString('yyyy-MM-dd') } else { 'nodate' })

            if ($seenKeys.Add($recordKey)) {
                $record = [PSCustomObject]@{
                    Source       = 'Get-HotFix'
                    RecordType   = 'Installed'
                    KBArticleID  = $kbId
                    Title        = ('{0} ({1})' -f $kbId, $desc)
                    Category     = $desc
                    MsrcSeverity = 'N/A'
                    Date         = $parsedDate
                    SizeMB       = $null
                    ResultStatus = 'Installed'
                    HResultHex   = ''
                }
                $combinedRecords.Add($record)
                if ($null -ne $parsedDate -and ($desc -match 'Security|Update|Hotfix')) {
                    $hotFixDates.Add($record)
                }
            }
        }
    }
    catch {
        $warnings.Add(('Get-HotFix query failed: {0}' -f $_.Exception.Message))
    }

    # 2. Query COM Microsoft.Update.Session History
    $session = $null
    $searcher = $null
    $historyCollection = $null
    $failedCountRecent = 0
    $wuaSucceededDates = New-Object -TypeName System.Collections.Generic.List[object]

    try {
        $session = New-Object -ComObject 'Microsoft.Update.Session'
        $searcher = $session.CreateUpdateSearcher()
        $totalCount = $searcher.GetTotalHistoryCount()

        if ($totalCount -gt 0) {
            $fetchCount = [math]::Min($totalCount, [math]::Max($HistoryLimit * 3, 75))
            $historyCollection = $searcher.QueryHistory(0, $fetchCount)

            foreach ($entry in $historyCollection) {
                $title = [string]$entry.Title
                $kbMatch = [regex]::Match($title, 'KB\d{6,8}', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                $kbId = if ($kbMatch.Success) { $kbMatch.Value.ToUpperInvariant() } else { 'N/A' }
                $resultText = Convert-UpdateResultCode -ResultCode ([int]$entry.ResultCode)
                $hresultHex = '0x{0:X8}' -f ([int]$entry.HResult)
                $entryDate = [datetime]$entry.Date

                if ([int]$entry.ResultCode -in @(4, 5)) {
                    $failedCountRecent++
                }

                $category = 'Windows Update'
                if ($title -match 'Security|Cumulative|Malicious Software|Rollup') {
                    $category = 'Security / Cumulative'
                }
                elseif ($title -match 'Defender|Intelligence|Definition') {
                    $category = 'Definition Update'
                }
                elseif ($title -match 'Driver') {
                    $category = 'Driver'
                }

                $statusDisplay = if ([int]$entry.ResultCode -in @(4, 5)) {
                    '{0} ({1})' -f $resultText, $hresultHex
                }
                else {
                    $resultText
                }

                $record = [PSCustomObject]@{
                    Source       = 'UpdateSession'
                    RecordType   = if ([int]$entry.ResultCode -in @(2, 3)) { 'Installed' } else { 'Failed' }
                    KBArticleID  = $kbId
                    Title        = $title
                    Category     = $category
                    MsrcSeverity = 'N/A'
                    Date         = $entryDate
                    SizeMB       = $null
                    ResultStatus = $statusDisplay
                    HResultHex   = $hresultHex
                }
                $combinedRecords.Add($record)

                if ([int]$entry.ResultCode -in @(2, 3) -and $category -eq 'Security / Cumulative') {
                    $wuaSucceededDates.Add($record)
                }
            }
        }
    }
    catch {
        $warnings.Add(('Microsoft.Update.Session QueryHistory failed: {0}' -f $_.Exception.Message))
    }
    finally {
        Release-ComObjectSafely -ComObject $historyCollection
        Release-ComObjectSafely -ComObject $searcher
        Release-ComObjectSafely -ComObject $session
    }

    # Determine most recent security/cumulative patch
    $candidatePatches = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($item in $hotFixDates) { $candidatePatches.Add($item) }
    foreach ($item in $wuaSucceededDates) { $candidatePatches.Add($item) }

    $latestSecurityPatch = $candidatePatches |
        Where-Object { $null -ne $_.Date } |
        Sort-Object -Property Date -Descending |
        Select-Object -First 1

    $lastPatchDate = if ($null -ne $latestSecurityPatch) { $latestSecurityPatch.Date } else { $null }
    $lastPatchKB = if ($null -ne $latestSecurityPatch) { $latestSecurityPatch.KBArticleID } else { 'None' }
    $lastPatchTitle = if ($null -ne $latestSecurityPatch) { $latestSecurityPatch.Title } else { 'No security/cumulative patch detected' }
    $daysSinceLastPatch = if ($null -ne $lastPatchDate) {
        [math]::Max(0, [math]::Floor(((Get-Date) - $lastPatchDate).TotalDays))
    }
    else {
        $null
    }

    $patchSlaStatus = if ($null -eq $daysSinceLastPatch) {
        'Unknown'
    }
    elseif ($daysSinceLastPatch -le $MaxPatchAgeDays) {
        'Compliant'
    }
    elseif ($daysSinceLastPatch -le ($MaxPatchAgeDays * 2)) {
        'Warning'
    }
    else {
        'Critical'
    }

    $sortedHistory = @($combinedRecords | Sort-Object -Property Date -Descending | Select-Object -First $HistoryLimit)

    return [PSCustomObject]@{
        LastPatchKB        = $lastPatchKB
        LastPatchTitle     = $lastPatchTitle
        LastPatchDate      = $lastPatchDate
        DaysSinceLastPatch = $daysSinceLastPatch
        PatchSlaStatus     = $patchSlaStatus
        RecentFailedCount  = $failedCountRecent
        HistoryEntries     = $sortedHistory
        Warnings           = $warnings.ToArray()
    }
}

function Test-PendingRebootStatus {
    <#
    .SYNOPSIS
        Performs multi-vector pending reboot detection across CBS, Windows Update, Session Manager, Computer Rename, and SCCM.
    #>
    [CmdletBinding()]
    param ()

    $ErrorActionPreference = 'Stop'
    $sources = New-Object -TypeName System.Collections.Generic.List[string]
    $pendingFiles = New-Object -TypeName System.Collections.Generic.List[string]
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]

    # 1. Component-Based Servicing (CBS)
    $cbsKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending'
    )
    foreach ($key in $cbsKeys) {
        if (Test-Path -Path $key) {
            $leaf = Split-Path -Path $key -Leaf
            $sources.Add(('CBS:{0}' -f $leaf))
        }
    }

    # 2. Windows Update Auto Update
    $wuKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting'
    )
    foreach ($key in $wuKeys) {
        if (Test-Path -Path $key) {
            $leaf = Split-Path -Path $key -Leaf
            $sources.Add(('WindowsUpdate:{0}' -f $leaf))
        }
    }

    # 3. Pending File Rename Operations
    try {
        $smPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        $smProps = Get-ItemProperty -Path $smPath -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        if ($null -ne $smProps -and ($smProps.PSObject.Properties.Name -contains 'PendingFileRenameOperations')) {
            $rawFiles = @($smProps.PendingFileRenameOperations | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($rawFiles.Count -gt 0) {
                $sources.Add(('PendingFileRenameOperations({0})' -f $rawFiles.Count))
                foreach ($f in ($rawFiles | Select-Object -First 20)) {
                    $pendingFiles.Add([string]$f)
                }
            }
        }
    }
    catch {
        $warnings.Add(('Failed to inspect PendingFileRenameOperations: {0}' -f $_.Exception.Message))
    }

    # 4. Computer Rename / Domain Join
    try {
        $activeName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name 'ComputerName').ComputerName
        $pendingName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name 'ComputerName').ComputerName
        if ($activeName -ne $pendingName) {
            $sources.Add(('ComputerRename({0}->{1})' -f $activeName, $pendingName))
        }
    }
    catch {
        $warnings.Add(('Failed to compare ActiveComputerName vs ComputerName: {0}' -f $_.Exception.Message))
    }

    # 5. SCCM / Configuration Manager Client
    try {
        $ccmNamespace = Get-CimInstance -Namespace 'root\ccm' -ClassName '__NAMESPACE' -Filter "Name='ClientSDK'" -ErrorAction SilentlyContinue
        if ($null -ne $ccmNamespace) {
            $ccmResult = Invoke-CimMethod -Namespace 'root\ccm\ClientSDK' -ClassName 'CCM_ClientUtilities' -MethodName 'DetermineIfRebootPending' -ErrorAction SilentlyContinue
            if ($null -ne $ccmResult -and ($ccmResult.RebootPending -or $ccmResult.IsHardRebootPending)) {
                $sources.Add('SCCM:ClientUtilities')
            }
        }
    }
    catch {
        Write-Verbose ('SCCM ClientSDK check skipped or unavailable: {0}' -f $_.Exception.Message)
    }

    $isPending = ($sources.Count -gt 0)

    return [PSCustomObject]@{
        PendingReboot        = $isPending
        PendingRebootSources = $sources.ToArray()
        PendingFileRenames   = $pendingFiles.ToArray()
        Warnings             = $warnings.ToArray()
    }
}

function Test-WsusServerReachability {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$WsusUrl,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutMs = 2500
    )

    try {
        $uri = [System.Uri]$WsusUrl
        $targetHost = $uri.Host
        $targetPort = if ($uri.Port -gt 0) { $uri.Port } elseif ($uri.Scheme -eq 'https') { 443 } else { 80 }

        if ($targetHost -in @('127.0.0.1', 'localhost', '::1', '0.0.0.0')) {
            return [PSCustomObject]@{
                Reachable    = $false
                IsSuspicious = $true
                Reason       = ('Loopback/local WSUS host configured ({0})' -f $targetHost)
            }
        }

        $tcpClient = New-Object -TypeName System.Net.Sockets.TcpClient
        try {
            $async = $tcpClient.BeginConnect($targetHost, $targetPort, $null, $null)
            $connected = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
            if ($connected -and $tcpClient.Connected) {
                $tcpClient.EndConnect($async)
                return [PSCustomObject]@{
                    Reachable    = $true
                    IsSuspicious = $false
                    Reason       = ('TCP {0}:{1} reachable' -f $targetHost, $targetPort)
                }
            }
            return [PSCustomObject]@{
                Reachable    = $false
                IsSuspicious = $true
                Reason       = ('WSUS server {0}:{1} unreachable (timeout {2}ms)' -f $targetHost, $targetPort, $TimeoutMs)
            }
        }
        finally {
            $tcpClient.Dispose()
        }
    }
    catch {
        return [PSCustomObject]@{
            Reachable    = $false
            IsSuspicious = $true
            Reason       = ('Invalid or unreachable WSUS URL ({0}): {1}' -f $WsusUrl, $_.Exception.Message)
        }
    }
}

function Get-WindowsUpdatePolicyAudit {
    <#
    .SYNOPSIS
        Audits Windows Update registry policies (WSUS, WUfB) and detects EDR/security red flags.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$SkipNetworkCheck
    )

    $ErrorActionPreference = 'Stop'
    $wuPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $auPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

    $wuProps = if (Test-Path -Path $wuPolicyPath) { Get-ItemProperty -Path $wuPolicyPath } else { $null }
    $auProps = if (Test-Path -Path $auPolicyPath) { Get-ItemProperty -Path $auPolicyPath } else { $null }

    $getProp = {
        param ($Obj, [string]$Name)
        if ($null -ne $Obj -and ($Obj.PSObject.Properties.Name -contains $Name)) {
            return $Obj.$Name
        }
        return $null
    }

    $useWUServer = & $getProp $auProps 'UseWUServer'
    $noAutoUpdate = & $getProp $auProps 'NoAutoUpdate'
    $auOptions = & $getProp $auProps 'AUOptions'
    $wuServer = & $getProp $wuProps 'WUServer'
    $wuStatusServer = & $getProp $wuProps 'WUStatusServer'
    $doNotConnectInternet = & $getProp $wuProps 'DoNotConnectToWindowsUpdateInternetLocations'
    $disableWuAccess = & $getProp $wuProps 'DisableWindowsUpdateAccess'
    $deferFeatureDays = & $getProp $wuProps 'DeferFeatureUpdatesPeriodInDays'
    $deferQualityDays = & $getProp $wuProps 'DeferQualityUpdatesPeriodInDays'
    $targetRelease = & $getProp $wuProps 'TargetReleaseVersionInfo'

    $redFlags = New-Object -TypeName System.Collections.Generic.List[string]
    $policyDetails = New-Object -TypeName System.Collections.Generic.List[object]

    if ($noAutoUpdate -eq 1) {
        $redFlags.Add('NoAutoUpdate=1 (Automatic updates disabled by policy)')
    }
    if ($disableWuAccess -eq 1) {
        $redFlags.Add('DisableWindowsUpdateAccess=1 (Windows Update access blocked)')
    }
    if ($doNotConnectInternet -eq 1 -and $useWUServer -ne 1) {
        $redFlags.Add('DoNotConnectToWindowsUpdateInternetLocations=1 without active WSUS')
    }

    $wsusStatusNote = 'N/A'
    if ($useWUServer -eq 1) {
        if ([string]::IsNullOrWhiteSpace([string]$wuServer)) {
            $redFlags.Add('UseWUServer=1 but WUServer URL is empty')
            $wsusStatusNote = 'Missing WUServer URL'
        }
        elseif (-not $SkipNetworkCheck) {
            $reach = Test-WsusServerReachability -WsusUrl ([string]$wuServer)
            $wsusStatusNote = $reach.Reason
            if ($reach.IsSuspicious) {
                $redFlags.Add(('Suspicious/Unreachable WSUS: {0}' -f $reach.Reason))
            }
        }
        else {
            $wsusStatusNote = 'Network reachability check skipped (-OfflineScanOnly)'
        }
    }

    $hasWufb = ($null -ne $deferFeatureDays) -or ($null -ne $deferQualityDays) -or (-not [string]::IsNullOrWhiteSpace([string]$targetRelease))
    $updateChannel = if ($useWUServer -eq 1) {
        'WSUS'
    }
    elseif ($hasWufb) {
        'Windows Update for Business (WUfB)'
    }
    else {
        'Windows Update (Cloud)'
    }

    $policyRows = @(
        [PSCustomObject]@{ Setting = 'UseWUServer'; Value = $(if ($null -ne $useWUServer) { $useWUServer } else { 'Not Set' }); RiskLevel = 'Info' },
        [PSCustomObject]@{ Setting = 'WUServer'; Value = $(if ($wuServer) { $wuServer } else { 'Not Set' }); RiskLevel = $(if ($useWUServer -eq 1 -and $wsusStatusNote -match 'unreachable|Loopback|Missing') { 'Critical' } else { 'Info' }) },
        [PSCustomObject]@{ Setting = 'WUStatusServer'; Value = $(if ($wuStatusServer) { $wuStatusServer } else { 'Not Set' }); RiskLevel = 'Info' },
        [PSCustomObject]@{ Setting = 'NoAutoUpdate'; Value = $(if ($null -ne $noAutoUpdate) { $noAutoUpdate } else { 'Not Set' }); RiskLevel = $(if ($noAutoUpdate -eq 1) { 'Critical' } else { 'OK' }) },
        [PSCustomObject]@{ Setting = 'AUOptions'; Value = $(if ($null -ne $auOptions) { $auOptions } else { 'Not Set' }); RiskLevel = 'Info' },
        [PSCustomObject]@{ Setting = 'DoNotConnectToWindowsUpdateInternetLocations'; Value = $(if ($null -ne $doNotConnectInternet) { $doNotConnectInternet } else { 'Not Set' }); RiskLevel = $(if ($doNotConnectInternet -eq 1 -and $useWUServer -ne 1) { 'Critical' } else { 'OK' }) },
        [PSCustomObject]@{ Setting = 'DisableWindowsUpdateAccess'; Value = $(if ($null -ne $disableWuAccess) { $disableWuAccess } else { 'Not Set' }); RiskLevel = $(if ($disableWuAccess -eq 1) { 'Critical' } else { 'OK' }) },
        [PSCustomObject]@{ Setting = 'DeferFeatureUpdatesPeriodInDays'; Value = $(if ($null -ne $deferFeatureDays) { $deferFeatureDays } else { 'Not Set' }); RiskLevel = 'Info' },
        [PSCustomObject]@{ Setting = 'DeferQualityUpdatesPeriodInDays'; Value = $(if ($null -ne $deferQualityDays) { $deferQualityDays } else { 'Not Set' }); RiskLevel = 'Info' },
        [PSCustomObject]@{ Setting = 'TargetReleaseVersionInfo'; Value = $(if ($targetRelease) { $targetRelease } else { 'Not Set' }); RiskLevel = 'Info' }
    )
    foreach ($r in $policyRows) { $policyDetails.Add($r) }

    return [PSCustomObject]@{
        UpdateChannel      = $updateChannel
        WSUSServer         = if ($wuServer) { [string]$wuServer } else { 'None' }
        WSUSStatusServer   = if ($wuStatusServer) { [string]$wuStatusServer } else { 'None' }
        WSUSReachability   = $wsusStatusNote
        PolicyRedFlags     = $redFlags.ToArray()
        PolicyEntries      = $policyDetails.ToArray()
    }
}

function Get-MissingWindowsUpdates {
    <#
    .SYNOPSIS
        Scans for missing Windows updates using Microsoft.Update.Session COM API.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$OfflineScanOnly,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDrivers
    )

    $ErrorActionPreference = 'Stop'
    $missingList = New-Object -TypeName System.Collections.Generic.List[object]
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    $scanStatus = if ($OfflineScanOnly) { 'OfflineCache' } else { 'Online' }

    $session = $null
    $searcher = $null
    $searchResult = $null
    $updates = $null

    try {
        $session = New-Object -ComObject 'Microsoft.Update.Session'
        $searcher = $session.CreateUpdateSearcher()
        $searcher.Online = (-not $OfflineScanOnly)

        $criteria = if ($IncludeDrivers) {
            "IsInstalled=0 and IsHidden=0 and (Type='Software' or Type='Driver')"
        }
        else {
            "IsInstalled=0 and Type='Software' and IsHidden=0"
        }

        $searchResult = $searcher.Search($criteria)
        $updates = $searchResult.Updates

        foreach ($upd in $updates) {
            $kbList = New-Object -TypeName System.Collections.Generic.List[string]
            foreach ($kb in $upd.KBArticleIDs) {
                $kbList.Add(('KB{0}' -f $kb))
            }
            $kbString = if ($kbList.Count -gt 0) { $kbList -join ', ' } else { 'N/A' }

            $catNames = New-Object -TypeName System.Collections.Generic.List[string]
            foreach ($cat in $upd.Categories) {
                $catNames.Add([string]$cat.Name)
            }
            $categoryString = if ($catNames.Count -gt 0) { $catNames -join '; ' } else { 'Uncategorized' }

            $severity = if ([string]::IsNullOrWhiteSpace([string]$upd.MsrcSeverity)) {
                'Unspecified'
            }
            else {
                [string]$upd.MsrcSeverity
            }

            $sizeMB = [math]::Round(($upd.MaxDownloadSize / 1MB), 2)
            $pubDate = $null
            try {
                if ($null -ne $upd.LastDeploymentChangeTime) {
                    $pubDate = [datetime]$upd.LastDeploymentChangeTime
                }
            }
            catch {
                $pubDate = $null
            }

            $missingList.Add([PSCustomObject]@{
                    RecordType    = 'Missing'
                    KBArticleID   = $kbString
                    Title         = [string]$upd.Title
                    Category      = $categoryString
                    MsrcSeverity  = $severity
                    Date          = $pubDate
                    SizeMB        = $sizeMB
                    ResultStatus  = 'PendingInstall'
                    IsSecurity    = ($categoryString -match 'Security|Critical')
                })
        }
    }
    catch {
        $scanStatus = 'Failed'
        $warnings.Add(('Windows Update scan failed ({0}): {1}' -f $(if ($OfflineScanOnly) { 'Offline' } else { 'Online' }), $_.Exception.Message))
    }
    finally {
        Release-ComObjectSafely -ComObject $updates
        Release-ComObjectSafely -ComObject $searchResult
        Release-ComObjectSafely -ComObject $searcher
        Release-ComObjectSafely -ComObject $session
    }

    $severityOrder = @{
        'Critical'    = 1
        'Important'   = 2
        'Moderate'    = 3
        'Low'         = 4
        'Unspecified' = 5
    }

    $sortedMissing = @($missingList | Sort-Object -Property @{
            Expression = {
                if ($severityOrder.ContainsKey($_.MsrcSeverity)) { $severityOrder[$_.MsrcSeverity] } else { 99 }
            }
        }, @{
            Expression = { $_.Date }
            Descending = $true
        })

    $criticalCount = @($sortedMissing | Where-Object { $_.MsrcSeverity -eq 'Critical' }).Count
    $importantCount = @($sortedMissing | Where-Object { $_.MsrcSeverity -eq 'Important' }).Count
    $securityCount = @($sortedMissing | Where-Object { $_.IsSecurity }).Count

    return [PSCustomObject]@{
        ScanMode              = $scanStatus
        MissingTotalCount     = $sortedMissing.Count
        MissingCriticalCount  = $criticalCount
        MissingImportantCount = $importantCount
        MissingSecurityCount  = $securityCount
        MissingUpdates        = $sortedMissing
        Warnings              = $warnings.ToArray()
    }
}

function Get-OverallPatchHealth {
    <#
    .SYNOPSIS
        Computes overall patch health rating (Healthy / AttentionRequired / CriticalRisk) and risk reasons.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Baseline,

        [Parameter(Mandatory = $true)]
        [object]$PatchHistory,

        [Parameter(Mandatory = $true)]
        [object]$PendingReboot,

        [Parameter(Mandatory = $true)]
        [object]$PolicyAudit,

        [Parameter(Mandatory = $true)]
        [object]$MissingUpdates,

        [Parameter(Mandatory = $true)]
        [int]$MaxPatchAgeDays
    )

    $criticalReasons = New-Object -TypeName System.Collections.Generic.List[string]
    $attentionReasons = New-Object -TypeName System.Collections.Generic.List[string]

    if ($MissingUpdates.MissingCriticalCount -gt 0) {
        $criticalReasons.Add(('MissingCriticalSecurityUpdates={0}' -f $MissingUpdates.MissingCriticalCount))
    }
    if ($null -ne $PatchHistory.DaysSinceLastPatch -and $PatchHistory.DaysSinceLastPatch -gt ($MaxPatchAgeDays * 2)) {
        $criticalReasons.Add(('PatchAgeCritical={0}d' -f $PatchHistory.DaysSinceLastPatch))
    }
    elseif ($null -ne $PatchHistory.DaysSinceLastPatch -and $PatchHistory.DaysSinceLastPatch -gt $MaxPatchAgeDays) {
        $attentionReasons.Add(('PatchAgeExceeded={0}d' -f $PatchHistory.DaysSinceLastPatch))
    }
    elseif ($null -eq $PatchHistory.DaysSinceLastPatch) {
        $attentionReasons.Add('LastSecurityPatchDate=Unknown')
    }

    if ($PolicyAudit.PolicyRedFlags.Count -gt 0) {
        foreach ($flag in $PolicyAudit.PolicyRedFlags) {
            $criticalReasons.Add(('PolicyRedFlag={0}' -f $flag))
        }
    }

    if ($Baseline.DisabledCriticalServices.Count -gt 0) {
        $criticalReasons.Add(('UpdateServiceDisabled={0}' -f ($Baseline.DisabledCriticalServices -join ',')))
    }

    if ($PendingReboot.PendingReboot) {
        $attentionReasons.Add(('PendingReboot=True({0})' -f ($PendingReboot.PendingRebootSources -join ';')))
    }

    if ($MissingUpdates.MissingImportantCount -gt 0 -or $MissingUpdates.MissingSecurityCount -gt 0) {
        if ($MissingUpdates.MissingCriticalCount -eq 0) {
            $attentionReasons.Add(('MissingSecurityOrImportantUpdates={0}' -f [math]::Max($MissingUpdates.MissingImportantCount, $MissingUpdates.MissingSecurityCount)))
        }
    }

    if ($Baseline.UptimeDays -gt 30) {
        $attentionReasons.Add(('HighUptime={0}d' -f $Baseline.UptimeDays))
    }

    if ($PatchHistory.RecentFailedCount -gt 0) {
        $attentionReasons.Add(('RecentFailedUpdates={0}' -f $PatchHistory.RecentFailedCount))
    }

    if ($MissingUpdates.ScanMode -eq 'Failed') {
        $attentionReasons.Add('UpdateScanFailed')
    }

    $allReasons = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($r in $criticalReasons) { $allReasons.Add($r) }
    foreach ($r in $attentionReasons) { $allReasons.Add($r) }

    $overallStatus = if ($criticalReasons.Count -gt 0) {
        'CriticalRisk'
    }
    elseif ($attentionReasons.Count -gt 0) {
        'AttentionRequired'
    }
    else {
        'Healthy'
    }

    $exitCode = if ($overallStatus -eq 'Healthy') { 0 } else { 1 }

    return [PSCustomObject]@{
        OverallHealthStatus = $overallStatus
        RiskReasons         = $allReasons.ToArray()
        ExitCode            = $exitCode
    }
}

function Export-PatchAuditCsvReports {
    <#
    .SYNOPSIS
        Exports the single-row Summary CSV and detailed Missing/Installed History CSV.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$AuditData,

        [Parameter(Mandatory = $true)]
        [string]$SummaryPath,

        [Parameter(Mandatory = $true)]
        [string]$DetailsPath
    )

    $wuauserv = $AuditData.Baseline.Services | Where-Object { $_.Name -eq 'wuauserv' } | Select-Object -First 1
    $wuauservStatus = if ($null -ne $wuauserv) { '{0} ({1})' -f $wuauserv.Status, $wuauserv.StartType } else { 'Unknown' }

    $summaryRow = [PSCustomObject]@{
        ComputerName          = $AuditData.Baseline.ComputerName
        ScanTimestamp         = $AuditData.ScanTimestamp.ToString('yyyy-MM-dd HH:mm:ss')
        OSCaption             = $AuditData.Baseline.OSCaption
        OSVersion             = $AuditData.Baseline.OSVersion
        OSBuild               = $AuditData.Baseline.OSBuild
        UBR                   = $AuditData.Baseline.UBR
        LastBootUpTime        = $AuditData.Baseline.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
        UptimeDays            = $AuditData.Baseline.UptimeDays
        OverallHealthStatus   = $AuditData.Health.OverallHealthStatus
        RiskReasons           = ($AuditData.Health.RiskReasons -join '; ')
        PendingReboot         = $AuditData.PendingReboot.PendingReboot
        PendingRebootSources  = ($AuditData.PendingReboot.PendingRebootSources -join '; ')
        LastPatchKB           = $AuditData.PatchHistory.LastPatchKB
        LastPatchTitle        = $AuditData.PatchHistory.LastPatchTitle
        LastPatchDate         = if ($null -ne $AuditData.PatchHistory.LastPatchDate) { $AuditData.PatchHistory.LastPatchDate.ToString('yyyy-MM-dd') } else { 'Unknown' }
        DaysSinceLastPatch    = $AuditData.PatchHistory.DaysSinceLastPatch
        UpdateChannel         = $AuditData.PolicyAudit.UpdateChannel
        WSUSServer            = $AuditData.PolicyAudit.WSUSServer
        PolicyRedFlags        = ($AuditData.PolicyAudit.PolicyRedFlags -join '; ')
        WuauservStatus        = $wuauservStatus
        MissingTotalCount     = $AuditData.MissingUpdates.MissingTotalCount
        MissingCriticalCount  = $AuditData.MissingUpdates.MissingCriticalCount
        MissingImportantCount = $AuditData.MissingUpdates.MissingImportantCount
        MissingSecurityCount  = $AuditData.MissingUpdates.MissingSecurityCount
    }

    $summaryRow | Export-Csv -Path $SummaryPath -NoTypeInformation -Encoding UTF8

    $detailRows = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($m in $AuditData.MissingUpdates.MissingUpdates) {
        $detailRows.Add([PSCustomObject]@{
                RecordType   = $m.RecordType
                KBArticleID  = $m.KBArticleID
                Title        = $m.Title
                Category     = $m.Category
                MsrcSeverity = $m.MsrcSeverity
                Date         = if ($null -ne $m.Date) { $m.Date.ToString('yyyy-MM-dd') } else { '' }
                SizeMB       = $m.SizeMB
                ResultStatus = $m.ResultStatus
            })
    }
    foreach ($h in $AuditData.PatchHistory.HistoryEntries) {
        $detailRows.Add([PSCustomObject]@{
                RecordType   = $h.RecordType
                KBArticleID  = $h.KBArticleID
                Title        = $h.Title
                Category     = $h.Category
                MsrcSeverity = $h.MsrcSeverity
                Date         = if ($null -ne $h.Date) { $h.Date.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                SizeMB       = $h.SizeMB
                ResultStatus = $h.ResultStatus
            })
    }

    if ($detailRows.Count -gt 0) {
        $detailRows | Export-Csv -Path $DetailsPath -NoTypeInformation -Encoding UTF8
    }
    else {
        [PSCustomObject]@{
            RecordType   = 'None'
            KBArticleID  = ''
            Title        = 'No missing updates or history records found'
            Category     = ''
            MsrcSeverity = ''
            Date         = ''
            SizeMB       = ''
            ResultStatus = ''
        } | Export-Csv -Path $DetailsPath -NoTypeInformation -Encoding UTF8
    }
}

function Export-PatchAuditHtmlReport {
    <#
    .SYNOPSIS
        Generates a standalone, offline-ready HTML dashboard report.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$AuditData,

        [Parameter(Mandatory = $true)]
        [string]$HtmlPath
    )

    $enc = {
        param ([object]$Value)
        return [System.Net.WebUtility]::HtmlEncode([string]$Value)
    }

    $health = $AuditData.Health.OverallHealthStatus
    $bannerClass = switch ($health) {
        'Healthy'           { 'status-healthy' }
        'AttentionRequired' { 'status-warning' }
        default             { 'status-critical' }
    }
    $healthLabel = switch ($health) {
        'Healthy'           { 'HEALTHY' }
        'AttentionRequired' { 'ATTENTION REQUIRED' }
        default             { 'CRITICAL RISK' }
    }

    $riskHtml = if ($AuditData.Health.RiskReasons.Count -gt 0) {
        $items = ($AuditData.Health.RiskReasons | ForEach-Object { '<li>{0}</li>' -f (& $enc $_) }) -join "`n"
        '<ul class="risk-list">{0}</ul>' -f $items
    }
    else {
        '<p class="muted">No patch compliance or EDR security anomalies detected.</p>'
    }

    $patchAgeText = if ($null -ne $AuditData.PatchHistory.DaysSinceLastPatch) {
        '{0} days' -f $AuditData.PatchHistory.DaysSinceLastPatch
    }
    else { 'Unknown' }
    $patchDateText = if ($null -ne $AuditData.PatchHistory.LastPatchDate) {
        $AuditData.PatchHistory.LastPatchDate.ToString('yyyy-MM-dd')
    }
    else { 'N/A' }

    $rebootBadge = if ($AuditData.PendingReboot.PendingReboot) { '<span class="badge badge-warn">YES</span>' } else { '<span class="badge badge-ok">NO</span>' }
    $rebootSourcesText = if ($AuditData.PendingReboot.PendingRebootSources.Count -gt 0) {
        & $enc ($AuditData.PendingReboot.PendingRebootSources -join ', ')
    }
    else { 'No pending reboot vectors' }

    $servicesRows = ($AuditData.Baseline.Services | ForEach-Object {
            $badge = if ($_.StartType -eq 'Disabled' -or $_.Status -eq 'NotFound') {
                '<span class="badge badge-crit">Disabled / Missing</span>'
            }
            elseif ($_.Status -eq 'Running') {
                '<span class="badge badge-ok">Running</span>'
            }
            else {
                '<span class="badge badge-info">{0}</span>' -f (& $enc $_.Status)
            }
            '<tr><td><code>{0}</code></td><td>{1}</td><td>{2}</td><td>{3}</td></tr>' -f (& $enc $_.Name), (& $enc $_.DisplayName), $badge, (& $enc $_.StartType)
        }) -join "`n"

    $policyRows = ($AuditData.PolicyAudit.PolicyEntries | ForEach-Object {
            $badge = switch ($_.RiskLevel) {
                'Critical' { '<span class="badge badge-crit">RED FLAG</span>' }
                'OK'       { '<span class="badge badge-ok">OK</span>' }
                default    { '<span class="badge badge-info">Info</span>' }
            }
            '<tr><td><code>{0}</code></td><td>{1}</td><td>{2}</td></tr>' -f (& $enc $_.Setting), (& $enc $_.Value), $badge
        }) -join "`n"

    $missingRows = if ($AuditData.MissingUpdates.MissingUpdates.Count -gt 0) {
        ($AuditData.MissingUpdates.MissingUpdates | ForEach-Object {
                $item = $_
                $sevText = [string]$item.MsrcSeverity
                $sevBadge = switch ($sevText) {
                    'Critical'  { '<span class="badge badge-crit">Critical</span>' }
                    'Important' { '<span class="badge badge-warn">Important</span>' }
                    'Moderate'  { '<span class="badge badge-info">Moderate</span>' }
                    default     { '<span class="badge badge-muted">{0}</span>' -f (& $enc $sevText) }
                }
                $pubDate = if ($null -ne $item.Date) { $item.Date.ToString('yyyy-MM-dd') } else { 'N/A' }
                '<tr><td><code>{0}</code></td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4} MB</td><td>{5}</td></tr>' -f (& $enc $item.KBArticleID), (& $enc $item.Title), (& $enc $item.Category), $sevBadge, $item.SizeMB, $pubDate
            }) -join "`n"
    }
    else {
        '<tr><td colspan="6" class="muted">No missing updates reported (Scan mode: {0}).</td></tr>' -f (& $enc $AuditData.MissingUpdates.ScanMode)
    }

    $historyRows = if ($AuditData.PatchHistory.HistoryEntries.Count -gt 0) {
        ($AuditData.PatchHistory.HistoryEntries | ForEach-Object {
                $resBadge = if ($_.RecordType -eq 'Failed') {
                    '<span class="badge badge-crit">{0}</span>' -f (& $enc $_.ResultStatus)
                }
                else {
                    '<span class="badge badge-ok">{0}</span>' -f (& $enc $_.ResultStatus)
                }
                $d = if ($null -ne $_.Date) { $_.Date.ToString('yyyy-MM-dd HH:mm') } else { 'N/A' }
                '<tr><td>{0}</td><td><code>{1}</code></td><td>{2}</td><td>{3}</td><td>{4}</td><td>{5}</td></tr>' -f $d, (& $enc $_.KBArticleID), (& $enc $_.Title), (& $enc $_.Source), (& $enc $_.Category), $resBadge
            }) -join "`n"
    }
    else {
        '<tr><td colspan="6" class="muted">No update history entries found.</td></tr>'
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Patch Audit - $(& $enc $AuditData.Baseline.ComputerName)</title>
<style>
  :root {
    --bg: #0f172a; --surface: #1e293b; --border: #334155; --text: #f1f5f9; --muted: #94a3b8;
    --ok: #10b981; --warn: #f59e0b; --crit: #ef4444; --info: #38bdf8;
  }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); line-height: 1.5; padding: 24px; }
  .container { max-width: 1320px; margin: 0 auto; }
  .banner { padding: 20px 24px; border-radius: 12px; background: var(--surface); border: 1px solid var(--border); border-left-width: 6px; margin-bottom: 20px; }
  .status-healthy { border-left-color: var(--ok); }
  .status-warning { border-left-color: var(--warn); }
  .status-critical { border-left-color: var(--crit); }
  .banner-top { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; }
  h1 { margin: 0; font-size: 1.5rem; }
  h2 { margin: 24px 0 12px; font-size: 1.15rem; color: #e2e8f0; border-bottom: 1px solid var(--border); padding-bottom: 6px; }
  .meta { color: var(--muted); font-size: 0.9rem; margin-top: 4px; }
  .pill { padding: 6px 14px; border-radius: 999px; font-weight: 700; font-size: 0.85rem; letter-spacing: 0.04em; }
  .status-healthy .pill { background: rgba(16,185,129,0.18); color: var(--ok); }
  .status-warning .pill { background: rgba(245,158,11,0.18); color: var(--warn); }
  .status-critical .pill { background: rgba(239,68,68,0.18); color: var(--crit); }
  .kpi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; margin-bottom: 24px; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 16px 18px; }
  .kpi-label { font-size: 0.8rem; text-transform: uppercase; color: var(--muted); letter-spacing: 0.05em; }
  .kpi-value { font-size: 1.6rem; font-weight: 700; margin: 6px 0; }
  .kpi-sub { font-size: 0.85rem; color: var(--muted); }
  .grid-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(460px, 1fr)); gap: 16px; }
  .table-wrap { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 0.88rem; }
  th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--border); vertical-align: top; }
  th { background: rgba(15,23,42,0.55); color: var(--muted); font-weight: 600; font-size: 0.78rem; text-transform: uppercase; }
  tr:last-child td { border-bottom: none; }
  code { background: rgba(15,23,42,0.7); padding: 2px 6px; border-radius: 4px; font-family: Consolas, monospace; font-size: 0.84rem; color: #cbd5e1; }
  .badge { display: inline-block; padding: 2px 8px; border-radius: 6px; font-size: 0.76rem; font-weight: 600; white-space: nowrap; }
  .badge-ok { background: rgba(16,185,129,0.18); color: var(--ok); }
  .badge-warn { background: rgba(245,158,11,0.18); color: var(--warn); }
  .badge-crit { background: rgba(239,68,68,0.2); color: var(--crit); }
  .badge-info { background: rgba(56,189,248,0.18); color: var(--info); }
  .badge-muted { background: rgba(148,163,184,0.18); color: var(--muted); }
  .risk-list { margin: 10px 0 0; padding-left: 20px; color: #fca5a5; }
  .muted { color: var(--muted); }
  @media print { body { background: #fff; color: #000; } .card, .banner, .table-wrap { border-color: #cbd5e1; background: #fff; } }
</style>
</head>
<body>
<div class="container">
  <div class="banner $bannerClass">
    <div class="banner-top">
      <div>
        <h1>Windows Update &amp; Patch Audit: $(& $enc $AuditData.Baseline.ComputerName)</h1>
        <div class="meta">$(& $enc $AuditData.Baseline.OSCaption) | Version $(& $enc $AuditData.Baseline.OSVersion) | Build $(& $enc $AuditData.Baseline.FullBuildString) | Domain: $(& $enc $AuditData.Baseline.Domain) | Scanned: $($AuditData.ScanTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))</div>
      </div>
      <div class="pill">$healthLabel</div>
    </div>
    $riskHtml
  </div>

  <div class="kpi-grid">
    <div class="card">
      <div class="kpi-label">Last Security Patch Age</div>
      <div class="kpi-value">$(& $enc $patchAgeText)</div>
      <div class="kpi-sub">KB: $(& $enc $AuditData.PatchHistory.LastPatchKB) | Date: $(& $enc $patchDateText) | SLA: $(& $enc $AuditData.PatchHistory.PatchSlaStatus)</div>
    </div>
    <div class="card">
      <div class="kpi-label">Pending Reboot</div>
      <div class="kpi-value">$rebootBadge</div>
      <div class="kpi-sub">$rebootSourcesText</div>
    </div>
    <div class="card">
      <div class="kpi-label">Missing Updates ($(& $enc $AuditData.MissingUpdates.ScanMode))</div>
      <div class="kpi-value">$($AuditData.MissingUpdates.MissingTotalCount) Total</div>
      <div class="kpi-sub">Critical: $($AuditData.MissingUpdates.MissingCriticalCount) | Important: $($AuditData.MissingUpdates.MissingImportantCount) | Security: $($AuditData.MissingUpdates.MissingSecurityCount)</div>
    </div>
    <div class="card">
      <div class="kpi-label">System Uptime &amp; Channel</div>
      <div class="kpi-value">$($AuditData.Baseline.UptimeDays) days</div>
      <div class="kpi-sub">Channel: $(& $enc $AuditData.PolicyAudit.UpdateChannel) | WSUS: $(& $enc $AuditData.PolicyAudit.WSUSServer)</div>
    </div>
  </div>

  <h2>Services &amp; Update Policy Audit (EDR &amp; Policy Red Flags)</h2>
  <div class="grid-2">
    <div class="table-wrap">
      <table>
        <thead><tr><th>Service</th><th>Display Name</th><th>Status</th><th>Start Type</th></tr></thead>
        <tbody>$servicesRows</tbody>
      </table>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Policy Key / Value</th><th>Configured Value</th><th>Assessment</th></tr></thead>
        <tbody>$policyRows</tbody>
      </table>
    </div>
  </div>

  <h2>Missing Updates ($($AuditData.MissingUpdates.MissingTotalCount))</h2>
  <div class="table-wrap">
    <table>
      <thead><tr><th>KB</th><th>Title</th><th>Category</th><th>Severity</th><th>Size</th><th>Published</th></tr></thead>
      <tbody>$missingRows</tbody>
    </table>
  </div>

  <h2>Installed &amp; Failed Update History (Top $($AuditData.PatchHistory.HistoryEntries.Count))</h2>
  <div class="table-wrap">
    <table>
      <thead><tr><th>Date</th><th>KB</th><th>Title</th><th>Source</th><th>Category</th><th>Result / HResult</th></tr></thead>
      <tbody>$historyRows</tbody>
    </table>
  </div>

  <footer style="margin-top: 28px; padding-top: 14px; border-top: 1px solid var(--border); color: var(--muted); font-size: 0.82rem; display: flex; justify-content: space-between; flex-wrap: wrap; gap: 8px;">
    <span>Generated by <strong>Audit-WindowsUpdateAndPatchStatus.ps1</strong> (v1.0.0)</span>
    <span>Author: Roman Pindela (<a href="mailto:roman.pindela@gmail.com" style="color: var(--info); text-decoration: none;">roman.pindela@gmail.com</a>) | <a href="https://github.com/romanpindela" style="color: var(--info); text-decoration: none;">github.com/romanpindela</a></span>
  </footer>
</div>
</body>
</html>
"@

    [System.IO.File]::WriteAllText($HtmlPath, $html, [System.Text.Encoding]::UTF8)
}

function Show-PatchAuditConsoleSummary {
    <#
    .SYNOPSIS
        Displays a colorized audit report and summary directly in the PowerShell console.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$AuditData,

        [Parameter(Mandatory = $true)]
        [string]$HtmlPath,

        [Parameter(Mandatory = $true)]
        [string]$SummaryCsvPath,

        [Parameter(Mandatory = $true)]
        [string]$DetailsCsvPath,

        [Parameter(Mandatory = $false)]
        [string]$JsonPath = '',

        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    $b = $AuditData.Baseline
    $ph = $AuditData.PatchHistory
    $pr = $AuditData.PendingReboot
    $pol = $AuditData.PolicyAudit
    $mu = $AuditData.MissingUpdates
    $h = $AuditData.Health

    $healthColor = switch ($h.OverallHealthStatus) {
        'Healthy'           { 'Green' }
        'AttentionRequired' { 'Yellow' }
        default             { 'Red' }
    }

    Write-Host ''
    Write-Host '================================================================================' -ForegroundColor DarkCyan
    Write-Host ('  WINDOWS UPDATE & PATCH STATUS AUDIT REPORT - {0}' -f $b.ComputerName) -ForegroundColor Cyan
    Write-Host '================================================================================' -ForegroundColor DarkCyan
    Write-Host ('  OS / Build       : {0} (Version {1}, Build {2})' -f $b.OSCaption, $b.OSVersion, $b.FullBuildString)
    Write-Host ('  Domain           : {0} | Uptime: {1} days (Last Boot: {2})' -f $b.Domain, $b.UptimeDays, $b.LastBootUpTime.ToString('yyyy-MM-dd HH:mm'))
    Write-Host ('  Scan Timestamp   : {0}' -f $AuditData.ScanTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Host -NoNewline '  Overall Health   : '
    Write-Host $h.OverallHealthStatus.ToUpperInvariant() -ForegroundColor $healthColor

    if ($h.RiskReasons.Count -gt 0) {
        Write-Host '  Risk Reasons     :' -ForegroundColor Yellow
        foreach ($reason in $h.RiskReasons) {
            Write-Host ('    - {0}' -f $reason) -ForegroundColor Yellow
        }
    }
    else {
        Write-Host '  Risk Reasons     : None (All checks compliant)' -ForegroundColor Green
    }

    Write-Host '--------------------------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  KEY METRICS' -ForegroundColor Cyan
    $lastPatchDateStr = if ($null -ne $ph.LastPatchDate) { $ph.LastPatchDate.ToString('yyyy-MM-dd') } else { 'N/A' }
    $patchAgeStr = if ($null -ne $ph.DaysSinceLastPatch) { '{0} days' -f $ph.DaysSinceLastPatch } else { 'Unknown' }
    $slaColor = switch ($ph.PatchSlaStatus) {
        'Compliant' { 'Green' }
        'Warning'   { 'Yellow' }
        default     { 'Red' }
    }
    Write-Host -NoNewline ('  Last Patch       : {0} ({1}, {2} ago) - SLA: ' -f $ph.LastPatchKB, $lastPatchDateStr, $patchAgeStr)
    Write-Host $ph.PatchSlaStatus -ForegroundColor $slaColor

    $rebootColor = if ($pr.PendingReboot) { 'Yellow' } else { 'Green' }
    $rebootText = if ($pr.PendingReboot) { 'YES ({0})' -f ($pr.PendingRebootSources -join ', ') } else { 'NO' }
    Write-Host -NoNewline '  Pending Reboot   : '
    Write-Host $rebootText -ForegroundColor $rebootColor

    Write-Host ('  Update Channel   : {0} (WSUS: {1})' -f $pol.UpdateChannel, $pol.WSUSServer)

    $missingColor = if ($mu.MissingCriticalCount -gt 0) { 'Red' } elseif ($mu.MissingTotalCount -gt 0) { 'Yellow' } else { 'Green' }
    Write-Host -NoNewline '  Missing Updates  : '
    Write-Host ('{0} Total (Critical: {1}, Important: {2}, Security: {3}) [Mode: {4}]' -f $mu.MissingTotalCount, $mu.MissingCriticalCount, $mu.MissingImportantCount, $mu.MissingSecurityCount, $mu.ScanMode) -ForegroundColor $missingColor

    Write-Host '--------------------------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  UPDATE SERVICES' -ForegroundColor Cyan
    foreach ($svc in $b.Services) {
        $svcColor = if ($svc.StartType -eq 'Disabled' -or $svc.Status -eq 'NotFound') { 'Red' } elseif ($svc.Status -eq 'Running') { 'Green' } else { 'Gray' }
        Write-Host ('    {0,-18} Status: {1,-10} StartType: {2}' -f $svc.Name, $svc.Status, $svc.StartType) -ForegroundColor $svcColor
    }

    Write-Host '--------------------------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  EDR / POLICY RED FLAGS' -ForegroundColor Cyan
    if ($pol.PolicyRedFlags.Count -gt 0) {
        foreach ($flag in $pol.PolicyRedFlags) {
            Write-Host ('    [RED FLAG] {0}' -f $flag) -ForegroundColor Red
        }
    }
    else {
        Write-Host '    [OK] No suspicious Windows Update policy tampering detected.' -ForegroundColor Green
    }

    if ($mu.MissingUpdates.Count -gt 0) {
        Write-Host '--------------------------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ('  MISSING UPDATES ({0})' -f $mu.MissingUpdates.Count) -ForegroundColor Cyan
        foreach ($upd in $mu.MissingUpdates) {
            $uColor = switch ($upd.MsrcSeverity) {
                'Critical'  { 'Red' }
                'Important' { 'Yellow' }
                default     { 'White' }
            }
            Write-Host ('    [{0,-11}] {1,-10} ({2,6} MB) {3}' -f $upd.MsrcSeverity, $upd.KBArticleID, $upd.SizeMB, $upd.Title) -ForegroundColor $uColor
        }
    }

    if ($ph.HistoryEntries.Count -gt 0) {
        $consoleHistoryLimit = [math]::Min(10, $ph.HistoryEntries.Count)
        Write-Host '--------------------------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ('  RECENT UPDATE HISTORY (Top {0} of {1})' -f $consoleHistoryLimit, $ph.HistoryEntries.Count) -ForegroundColor Cyan
        foreach ($entry in ($ph.HistoryEntries | Select-Object -First $consoleHistoryLimit)) {
            $dStr = if ($null -ne $entry.Date) { $entry.Date.ToString('yyyy-MM-dd') } else { 'N/A       ' }
            $eColor = if ($entry.RecordType -eq 'Failed') { 'Red' } else { 'Gray' }
            $shortTitle = if ($entry.Title.Length -gt 55) { $entry.Title.Substring(0, 52) + '...' } else { $entry.Title }
            Write-Host ('    {0} | {1,-10} | {2,-12} | {3}' -f $dStr, $entry.KBArticleID, $entry.ResultStatus, $shortTitle) -ForegroundColor $eColor
        }
    }

    Write-Host '--------------------------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  GENERATED FILES' -ForegroundColor Cyan
    Write-Host ('    Log File    : {0}' -f $LogPath)
    Write-Host ('    HTML Report : {0}' -f $HtmlPath)
    Write-Host ('    Summary CSV : {0}' -f $SummaryCsvPath)
    Write-Host ('    Details CSV : {0}' -f $DetailsCsvPath)
    if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
        Write-Host ('    JSON Report : {0}' -f $JsonPath)
    }
    Write-Host '================================================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Show-AuditHelp {
    <#
    .SYNOPSIS
        Displays CLI usage guide, parameter descriptions, examples, and exit codes in English.
    #>
    [CmdletBinding()]
    param ()

    $helpText = @"

================================================================================
  Audit-WindowsUpdateAndPatchStatus.ps1  (v1.0.0)
================================================================================
DESCRIPTION:
  Read-only enterprise audit tool for Windows 10/11 endpoints. Evaluates patch
  hygiene, OS build/UBR baseline, update services, multi-vector pending reboots,
  WSUS/WUfB policy tampering (EDR red flags), and missing security updates.

USAGE:
  .\Audit-WindowsUpdateAndPatchStatus.ps1 -r [options]
  .\Audit-WindowsUpdateAndPatchStatus.ps1 -Run [options]

PARAMETERS:
  -Run, -r                   Execute the audit (required to run; omitting shows help).
  -OutputDirectory <string>  Report output folder (Default: C:\Logs\PatchAudit).
  -MaxPatchAgeDays <int>     Patch age SLA threshold in days (Default: 30).
  -HistoryLimit <int>        Max history entries in reports (Default: 25).
  -OfflineScanOnly           Skip online Microsoft Update / WSUS scan (cache only).
  -IncludeDrivers            Include missing driver updates in scan.
  -ExportJson                Export structured JSON report for EDR/SIEM ingestion.
  -OpenReport                Open the generated HTML dashboard in default browser.
  -NoElevate                 Disable automatic UAC elevation prompt (RMM/SYSTEM).
  -Help, -h                  Display this help screen and exit.

EXAMPLES:
  1. Run standard audit and open HTML dashboard:
     .\Audit-WindowsUpdateAndPatchStatus.ps1 -r -OpenReport

  2. Strict 14-day SLA with JSON export:
     .\Audit-WindowsUpdateAndPatchStatus.ps1 -r -MaxPatchAgeDays 14 -ExportJson

  3. Offline cache audit without UAC prompt (RMM/EDR / automated run):
     .\Audit-WindowsUpdateAndPatchStatus.ps1 -r -OfflineScanOnly -NoElevate

  4. Custom output directory:
     .\Audit-WindowsUpdateAndPatchStatus.ps1 -r -OutputDirectory "C:\Temp\PatchAudit"

EXIT CODES:
  0  Audit completed; endpoint status is Healthy.
  1  Audit completed; AttentionRequired or CriticalRisk detected.
  2  Critical execution error (log init failure or missing admin with -NoElevate).

LOGS & REPORTS:
  Session Logs : C:\Logs\Audit-WindowsUpdateAndPatchStatus_<timestamp>.log
  Reports      : <OutputDirectory>\PatchAudit_<HOST>_<timestamp>.(html|csv|json)

AUTHOR:
  Roman Pindela | Email: roman.pindela@gmail.com | GitHub: https://github.com/romanpindela
================================================================================

"@
    Write-Host $helpText -ForegroundColor Cyan
}

# ==============================================================================
# Main Execution Flow
# ==============================================================================
if ($Help -or (-not $Run)) {
    Show-AuditHelp
    exit 0
}

$privCheck = Test-IsElevatedOrSystem
if (-not $privCheck.Elevated) {
    if ($NoElevate) {
        try {
            if (-not (Test-Path -Path $script:LogDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null
            }
            Write-AuditLog -Message 'Administrative privileges (SID S-1-5-32-544) are required and -NoElevate was specified. Exiting with code 2.' -Level 'ERROR'
        }
        catch {
            Write-Error -Message ('Administrative privileges required and log initialization failed: {0}' -f $_.Exception.Message)
        }
        exit 2
    }

    try {
        Invoke-SelfElevation -ScriptPath $PSCommandPath -BoundParameters $PSBoundParameters
        exit 0
    }
    catch {
        Write-Error -Message ('Failed to elevate script via UAC: {0}' -f $_.Exception.Message)
        exit 2
    }
}

try {
    $ErrorActionPreference = 'Stop'
    Initialize-AuditEnvironment -TargetOutputDirectory $OutputDirectory -BoundParameters $PSBoundParameters
}
catch {
    Write-Error -Message ('Critical initialization failure: {0}' -f $_.Exception.Message)
    exit 2
}

$exitCode = 2
try {
    $scanTimestamp = Get-Date

    # Step 1: Baseline OS & Services
    Write-Progress -Activity $script:ProgressActivity -Status 'Step 1/6: Collecting OS baseline and service status...' -PercentComplete 15
    Write-AuditLog -Message 'Step 1/6: Collecting OS baseline and update services.' -Level 'INFO'
    $baseline = Get-OsAndServiceBaseline
    foreach ($w in $baseline.Warnings) { Write-AuditLog -Message $w -Level 'WARNING' }
    if ($baseline.DisabledCriticalServices.Count -gt 0) {
        Write-AuditLog -Message ('Disabled update services detected: {0}' -f ($baseline.DisabledCriticalServices -join ', ')) -Level 'SECURITY'
    }

    # Step 2: Installed Patches & Patch Age
    Write-Progress -Activity $script:ProgressActivity -Status 'Step 2/6: Querying patch history and calculating patch age...' -PercentComplete 32
    Write-AuditLog -Message 'Step 2/6: Querying Get-HotFix and Microsoft.Update.Session history.' -Level 'INFO'
    $patchHistory = Get-InstalledPatchHistory -MaxPatchAgeDays $MaxPatchAgeDays -HistoryLimit $HistoryLimit
    foreach ($w in $patchHistory.Warnings) { Write-AuditLog -Message $w -Level 'WARNING' }

    # Step 3: Pending Reboot Detection
    Write-Progress -Activity $script:ProgressActivity -Status 'Step 3/6: Checking multi-vector pending reboot status...' -PercentComplete 50
    Write-AuditLog -Message 'Step 3/6: Checking pending reboot vectors.' -Level 'INFO'
    $pendingReboot = Test-PendingRebootStatus
    foreach ($w in $pendingReboot.Warnings) { Write-AuditLog -Message $w -Level 'WARNING' }

    # Step 4: WSUS / WUfB Policies & Red Flags
    Write-Progress -Activity $script:ProgressActivity -Status 'Step 4/6: Auditing WSUS/WUfB policies and EDR red flags...' -PercentComplete 65
    Write-AuditLog -Message 'Step 4/6: Auditing Windows Update registry policies.' -Level 'INFO'
    $policyAudit = Get-WindowsUpdatePolicyAudit -SkipNetworkCheck:$OfflineScanOnly
    foreach ($flag in $policyAudit.PolicyRedFlags) {
        Write-AuditLog -Message ('Policy Red Flag detected: {0}' -f $flag) -Level 'SECURITY'
    }

    # Step 5: Missing Updates Scan
    Write-Progress -Activity $script:ProgressActivity -Status 'Step 5/6: Scanning for missing Windows updates...' -PercentComplete 82
    Write-AuditLog -Message ('Step 5/6: Scanning missing updates (OfflineScanOnly={0}, IncludeDrivers={1}).' -f $OfflineScanOnly, $IncludeDrivers) -Level 'INFO'
    $missingUpdates = Get-MissingWindowsUpdates -OfflineScanOnly:$OfflineScanOnly -IncludeDrivers:$IncludeDrivers
    foreach ($w in $missingUpdates.Warnings) { Write-AuditLog -Message $w -Level 'WARNING' }

    # Calculate Overall Health
    $health = Get-OverallPatchHealth -Baseline $baseline -PatchHistory $patchHistory -PendingReboot $pendingReboot -PolicyAudit $policyAudit -MissingUpdates $missingUpdates -MaxPatchAgeDays $MaxPatchAgeDays
    $exitCode = $health.ExitCode

    $auditData = [PSCustomObject]@{
        ScanTimestamp  = $scanTimestamp
        Baseline       = $baseline
        PatchHistory   = $patchHistory
        PendingReboot  = $pendingReboot
        PolicyAudit    = $policyAudit
        MissingUpdates = $missingUpdates
        Health         = $health
    }

    # Step 6: Generate Reports
    Write-Progress -Activity $script:ProgressActivity -Status 'Step 6/6: Generating HTML, CSV, and optional JSON reports...' -PercentComplete 95
    $filePrefix = 'PatchAudit_{0}_{1}' -f $baseline.ComputerName, $script:SessionTimestamp
    $summaryCsvPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}_Summary.csv' -f $filePrefix)
    $detailsCsvPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}_Details.csv' -f $filePrefix)
    $htmlReportPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}.html' -f $filePrefix)
    $jsonReportPath = Join-Path -Path $OutputDirectory -ChildPath ('{0}.json' -f $filePrefix)

    Export-PatchAuditCsvReports -AuditData $auditData -SummaryPath $summaryCsvPath -DetailsPath $detailsCsvPath
    Export-PatchAuditHtmlReport -AuditData $auditData -HtmlPath $htmlReportPath

    if ($ExportJson) {
        $auditData | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonReportPath -Encoding UTF8
        Write-AuditLog -Message ('JSON report saved: {0}' -f $jsonReportPath) -Level 'INFO'
    }

    Write-AuditLog -Message ('HTML report saved: {0}' -f $htmlReportPath) -Level 'INFO'
    Write-AuditLog -Message ('CSV reports saved: {0} | {1}' -f $summaryCsvPath, $detailsCsvPath) -Level 'INFO'
    Write-AuditLog -Message ('Overall Health: {0} | Reasons: {1}' -f $health.OverallHealthStatus, $(if ($health.RiskReasons.Count -gt 0) { $health.RiskReasons -join '; ' } else { 'None' })) -Level $(if ($health.OverallHealthStatus -eq 'Healthy') { 'SUCCESS' } else { 'WARNING' })

    Show-PatchAuditConsoleSummary -AuditData $auditData -HtmlPath $htmlReportPath -SummaryCsvPath $summaryCsvPath -DetailsCsvPath $detailsCsvPath -JsonPath $(if ($ExportJson) { $jsonReportPath } else { '' }) -LogPath $script:LogFilePath

    if ($OpenReport -and (Test-Path -Path $htmlReportPath)) {
        Start-Process -FilePath $htmlReportPath | Out-Null
    }
}
catch {
    $exitCode = 2
    Write-AuditLog -Message ('Unhandled critical error during audit: {0}' -f $_.Exception.Message) -Level 'ERROR'
}
finally {
    Write-Progress -Activity $script:ProgressActivity -Completed
    Write-AuditLog -Message ('=== Audit Session Completed (ExitCode: {0}) ===' -f $exitCode) -Level 'INFO'
}

exit $exitCode
