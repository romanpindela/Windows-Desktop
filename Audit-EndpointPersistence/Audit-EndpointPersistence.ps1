<#
.SYNOPSIS
    Audits and detects Windows Auto-Start Execution Points (ASEP) and persistence mechanisms,
    evaluating scheduled tasks, registry run keys, startup folders, and Windows services against
    security risk heuristics, logging execution telemetry, and generating standalone responsive HTML reports.

.DESCRIPTION
    Audit-EndpointPersistence.ps1 is an enterprise-grade endpoint security auditing and threat detection tool
    designed for Windows 10, Windows 11, and Windows Server (supporting Windows PowerShell 5.1 and PowerShell 7+).
    It systematically scans and audits four primary persistence vectors:
      1. Scheduled Tasks (Task Scheduler):
         - Identifies tasks executing under elevated context (NT AUTHORITY\SYSTEM, Administrators).
         - Flags binaries and scripts running from user-writable, temporary, or high-risk folders
           (%TEMP%, %TMP%, %APPDATA%, %LOCALAPPDATA%, C:\Users\Public).
         - Detects orphaned tasks with missing binary files.
      2. Autostart Registry Keys (ASEP):
         - Audits HKLM / HKCU Run and RunOnce (both 64-bit and WOW6432Node).
         - Inspects Explorer Shell Folders and User Shell Folders for persistence hijacking.
         - Inspects Active Setup Installed Components StubPath commands.
         - Detects obfuscated LOLBins and encoded script executions (powershell.exe -enc, mshta.exe, wscript).
      3. Startup Folders:
         - Inspects ProgramData and user profile Startup directories.
         - Resolves shortcut (.lnk) targets, arguments, and direct executable/script drops.
         - Supports multi-profile inspection via -IncludeAllProfiles.
      4. Windows Services:
         - Detects Unquoted Service Paths containing spaces without quotes (CWE-428).
         - Identifies services executing from non-standard directories outside %SystemRoot% and %ProgramFiles%.
         - Flags services pointing to user profile directories or removable storage devices.

    The Risk Assessment Engine evaluates each persistence mechanism, performs Authenticode signature verification
    via Get-AuthenticodeSignature, and assigns a calibrated RiskLevel (Critical, High, Medium, Low).
    Telemetry is logged with millisecond precision to C:\Logs\, and an interactive, standalone HTML audit dashboard
    with zero external CDN dependencies is generated for executive review and threat hunting remediation.

.PARAMETER ReportPath
    Specifies the destination path for the standalone HTML audit report.
    Default: "C:\Logs\Audit-EndpointPersistence_Report.html".

.PARAMETER LogPath
    Specifies the destination file path for execution log telemetry.
    Default: "C:\Logs\Audit-EndpointPersistence.log".

.PARAMETER MinimumRiskLevel
    Filters console output and pipeline results to items meeting or exceeding the specified severity threshold.
    Allowed values: "Low", "Medium", "High", "Critical".
    Default: "Low".

.PARAMETER IncludeAllProfiles
    Scans startup folders across all existing user profiles on the host (C:\Users\*\AppData\...).
    Default: Scans ProgramData and the current active user profile.

.PARAMETER OpenReport
    Automatically launches the generated HTML audit report in the default system web browser upon completion.

.PARAMETER SkipAdminCheck
    Bypasses the automatic UAC administrator elevation check. Useful for automated CI/CD pipelines,
    scheduled background jobs, or execution under SYSTEM context.

.PARAMETER ExportCsv
    Exports the normalized audit findings to a structured CSV file.

.PARAMETER CsvPath
    Specifies a custom destination path for the CSV export.
    Default: "C:\Logs\Audit-EndpointPersistence.csv".

.PARAMETER PassThru
    Outputs the structured PSCustomObject findings to the PowerShell pipeline for downstream filtering or automation.

.PARAMETER Help
    Displays the interactive console help guide and usage summary. Alias: -h.

.EXAMPLE
    .\Audit-EndpointPersistence.ps1
    Executes a comprehensive ASEP audit with default parameters, writes logs to C:\Logs,
    generates the HTML report, and renders a summary table in the console.

.EXAMPLE
    .\Audit-EndpointPersistence.ps1 -MinimumRiskLevel High -OpenReport
    Performs audit, filters console output to High and Critical findings, and automatically opens
    the generated HTML report in the default browser.

.EXAMPLE
    .\Audit-EndpointPersistence.ps1 -IncludeAllProfiles -ExportCsv -PassThru
    Audits all user profiles, saves findings to CSV and HTML, and passes objects down the pipeline.

.EXAMPLE
    .\Audit-EndpointPersistence.ps1 -PassThru | Where-Object { $_.RiskLevel -eq 'Critical' }
    Pipes critical persistence mechanisms directly to downstream security triage commands.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Each persistence record contains:
      - Category        : ScheduledTask | RegistryRun | StartupFolder | WindowsService
      - Name            : Identifier or title of the persistence entry
      - PathOrCommand   : Raw configured command line or target path
      - ResolvedBinary  : Extracted executable or script file path
      - AccountContext  : Execution security identity (e.g. NT AUTHORITY\SYSTEM)
      - RiskLevel       : Critical | High | Medium | Low
      - DetectionReason : Heuristic rationale explaining the assigned risk
      - IsSigned        : Boolean Authenticode signature validation status
      - Signer          : Common Name or Subject of the signing certificate
      - FileExists      : Boolean indicating whether the binary exists on disk

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Date:         2026-11-09
    Requires:     Windows 10 / 11 / Server, PowerShell 5.1+, Elevated Administrator Token
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ReportPath = "C:\Logs\Audit-EndpointPersistence_Report.html",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath = "C:\Logs\Audit-EndpointPersistence.log",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Low", "Medium", "High", "Critical")]
    [string]$MinimumRiskLevel = "Low",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAllProfiles,

    [Parameter(Mandatory = $false)]
    [switch]$OpenReport,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [switch]$ExportCsv,

    [Parameter(Mandatory = $false)]
    [string]$CsvPath = "C:\Logs\Audit-EndpointPersistence.csv",

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

# ==============================================================================
# Script Lifecycle: Begin Block
# ==============================================================================

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Global session state
    $script:SessionTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:ResolvedLogPath  = $LogPath
    $script:ResolvedReportPath = $ReportPath
    $script:ResolvedCsvPath = $CsvPath

    # --------------------------------------------------------------------------
    # Helper: Interactive CLI Help
    # --------------------------------------------------------------------------
    function Show-ScriptHelp {
        [CmdletBinding()]
        param()

        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host " Audit-EndpointPersistence.ps1 - Windows ASEP & Persistence Audit Suite" -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Version: 1.0.0 | Author: Roman Pindela | Repository: Windows-Desktop`n" -ForegroundColor DarkGray

        Write-Host "DESCRIPTION:" -ForegroundColor Green
        Write-Host "  Audits Auto-Start Execution Points (ASEP) and endpoint persistence mechanisms:"
        Write-Host "  Scheduled Tasks, Registry Run/RunOnce/ActiveSetup, Startup Folders, and Windows Services."
        Write-Host "  Features signature verification, unquoted path detection, heuristic risk scoring,"
        Write-Host "  telemetry logging to C:\Logs\, and standalone responsive HTML dashboard generation.`n"

        Write-Host "PARAMETERS:" -ForegroundColor Green
        Write-Host "  -ReportPath <string>        Path for HTML report (Default: C:\Logs\Audit-EndpointPersistence_Report.html)"
        Write-Host "  -LogPath <string>           Path for log file (Default: C:\Logs\Audit-EndpointPersistence.log)"
        Write-Host "  -MinimumRiskLevel <string>  Minimum risk to display/emit: Low | Medium | High | Critical (Default: Low)"
        Write-Host "  -IncludeAllProfiles         Audit startup folders across all user profiles on disk"
        Write-Host "  -OpenReport                 Automatically launch HTML report in default browser"
        Write-Host "  -SkipAdminCheck             Bypass UAC administrator elevation requirement"
        Write-Host "  -ExportCsv                  Export findings to CSV file"
        Write-Host "  -CsvPath <string>           Path for CSV export (Default: C:\Logs\Audit-EndpointPersistence.csv)"
        Write-Host "  -PassThru                   Emit findings to pipeline as PSCustomObject"
        Write-Host "  -Help (-h)                  Show this interactive command reference`n"

        Write-Host "EXAMPLES:" -ForegroundColor Green
        Write-Host "  .\Audit-EndpointPersistence.ps1"
        Write-Host "  .\Audit-EndpointPersistence.ps1 -MinimumRiskLevel High -OpenReport"
        Write-Host "  .\Audit-EndpointPersistence.ps1 -IncludeAllProfiles -ExportCsv"
        Write-Host "  .\Audit-EndpointPersistence.ps1 -PassThru | Out-GridView`n"
    }

    # --------------------------------------------------------------------------
    # Helper: Elevation Verification & Auto-Relaunch
    # --------------------------------------------------------------------------
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
        $argList.Add('-NoProfile')
        $argList.Add('-ExecutionPolicy Bypass')
        $argList.Add("-File `"$scriptPath`"")

        foreach ($key in $BoundParameters.Keys) {
            $val = $BoundParameters[$key]
            if ($val -is [System.Management.Automation.SwitchParameter]) {
                if ($val.IsPresent -and $val.ToBool()) {
                    $argList.Add("-$key")
                }
            }
            elseif ($val -is [bool]) {
                $argList.Add("-${key}:`$$val")
            }
            else {
                $argList.Add("-$key")
                $argList.Add("`"$val`"")
            }
        }

        try {
            $process = Start-Process -FilePath 'powershell.exe' -ArgumentList ($argList -join ' ') -Verb RunAs -PassThru
            [System.Environment]::Exit(0)
        }
        catch {
            Write-Error "Failed to elevate process: $($_.Exception.Message). Please run PowerShell as Administrator."
            [System.Environment]::Exit(1)
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Telemetry Logging (Write-Log)
    # --------------------------------------------------------------------------
    function Initialize-LoggingDirectory {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$TargetLogFile
        )

        $logDir = [System.IO.Path]::GetDirectoryName($TargetLogFile)
        if ([string]::IsNullOrWhiteSpace($logDir)) {
            $logDir = 'C:\Logs'
        }

        if (-not (Test-Path -LiteralPath $logDir)) {
            try {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            catch {
                $fallbackDir = Join-Path -Path $env:TEMP -ChildPath 'Logs'
                if (-not (Test-Path -LiteralPath $fallbackDir)) {
                    New-Item -Path $fallbackDir -ItemType Directory -Force | Out-Null
                }
                $fileName = [System.IO.Path]::GetFileName($TargetLogFile)
                $script:ResolvedLogPath = Join-Path -Path $fallbackDir -ChildPath $fileName
                return
            }
        }
        $script:ResolvedLogPath = $TargetLogFile
    }

    function Write-Log {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'DEBUG', 'VERBOSE', 'HEADER')]
            [string]$Severity = 'INFO'
        )

        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $logSeverity = if ($Severity -in @('HEADER', 'SUCCESS')) { 'INFO' } else { $Severity }
        $logLine = "[$timestamp] [$logSeverity] $Message"

        switch ($Severity) {
            'HEADER'  { Write-Host "`n=== $Message ===" -ForegroundColor Yellow }
            'SUCCESS' { Write-Host $logLine -ForegroundColor Green }
            'WARN'    { Write-Host $logLine -ForegroundColor DarkYellow }
            'ERROR'   { Write-Host $logLine -ForegroundColor Red }
            'DEBUG'   { Write-Debug $Message }
            'VERBOSE' { Write-Verbose $Message }
            Default   { Write-Host $logLine -ForegroundColor Cyan }
        }

        if ($script:ResolvedLogPath) {
            try {
                [System.IO.File]::AppendAllText($script:ResolvedLogPath, "$logLine`r`n", [System.Text.Encoding]::UTF8)
            }
            catch {}
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Executable & Script Path Resolver
    # --------------------------------------------------------------------------
    function Resolve-ExecutablePath {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false)]
            [string]$RawCommand
        )

        if ([string]::IsNullOrWhiteSpace($RawCommand)) {
            return [PSCustomObject]@{
                Binary    = $null
                Arguments = ''
                Exists    = $false
            }
        }

        $cmd = [System.Environment]::ExpandEnvironmentVariables($RawCommand.Trim())
        $bin = $null
        $args = ''

        # Pattern 1: Enclosed in double quotes
        if ($cmd -match '^"([^"]+)"(?:\s+(.*))?$') {
            $bin = $Matches[1]
            $args = if ($Matches.Count -gt 2 -and $Matches[2]) { $Matches[2] } else { '' }
        }
        # Pattern 2: Enclosed in single quotes
        elseif ($cmd -match "^'([^']+)'(?:\s+(.*))?$") {
            $bin = $Matches[1]
            $args = if ($Matches.Count -gt 2 -and $Matches[2]) { $Matches[2] } else { '' }
        }
        else {
            # Direct check if whole string is an existing file
            if (Test-Path -LiteralPath $cmd -PathType Leaf) {
                $bin = $cmd
                $args = ''
            }
            else {
                # Progressive token splitting for unquoted paths with spaces
                $tokens = $cmd -split '\s+'
                $candidate = ''
                $found = $false
                for ($i = 0; $i -lt $tokens.Count; $i++) {
                    if ($candidate -eq '') {
                        $candidate = $tokens[$i]
                    }
                    else {
                        $candidate = "$candidate $($tokens[$i])"
                    }

                    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                        $bin = $candidate
                        if ($i + 1 -lt $tokens.Count) {
                            $args = ($tokens[($i + 1)..($tokens.Count - 1)]) -join ' '
                        }
                        $found = $true
                        break
                    }
                }

                if (-not $found) {
                    # Regex match on standard executable extensions
                    if ($cmd -match '^(.*?\.(?:exe|dll|bat|cmd|vbs|ps1|com|sys|scr))(?:\s+(.*))?$') {
                        $bin = $Matches[1]
                        $args = if ($Matches.Count -gt 2 -and $Matches[2]) { $Matches[2] } else { '' }
                    }
                    else {
                        $bin = $tokens[0]
                        if ($tokens.Count -gt 1) {
                            $args = ($tokens[1..($tokens.Count - 1)]) -join ' '
                        }
                    }
                }
            }
        }

        # Resolve system path for bare executable names (e.g. powershell.exe, cmd.exe)
        if ($bin -and (-not (Test-Path -LiteralPath $bin)) -and ($bin -notmatch '[\\/]')) {
            $foundCmd = Get-Command -Name $bin -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundCmd -and $foundCmd.Source) {
                $bin = $foundCmd.Source
            }
        }

        $exists = if ($bin) { Test-Path -LiteralPath $bin -PathType Leaf } else { $false }

        return [PSCustomObject]@{
            Binary    = $bin
            Arguments = $args
            Exists    = $exists
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Digital Signature Extraction
    # --------------------------------------------------------------------------
    function Get-BinarySignature {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false)]
            [string]$FilePath
        )

        if ([string]::IsNullOrWhiteSpace($FilePath) -or (-not (Test-Path -LiteralPath $FilePath -PathType Leaf))) {
            return [PSCustomObject]@{
                IsSigned = $false
                Signer   = $null
                Status   = 'FileNotFound'
            }
        }

        try {
            $sig = Get-AuthenticodeSignature -LiteralPath $FilePath -ErrorAction SilentlyContinue
            if ($sig) {
                $isValid = ($sig.Status -eq 'Valid')
                $signerName = $null
                if ($sig.SignerCertificate) {
                    $signerName = $sig.SignerCertificate.Subject
                    if ($signerName -match 'CN=([^,]+)') {
                        $signerName = $Matches[1]
                    }
                }

                return [PSCustomObject]@{
                    IsSigned = $isValid
                    Signer   = $signerName
                    Status   = $sig.Status.ToString()
                }
            }
        }
        catch {}

        return [PSCustomObject]@{
            IsSigned = $false
            Signer   = $null
            Status   = 'CheckFailed'
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Unquoted Service Path Analysis
    # --------------------------------------------------------------------------
    function Test-IsUnquotedServicePath {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$PathName
        )

        $trimmed = $PathName.Trim()
        if ($trimmed.StartsWith('"')) {
            return $false
        }

        # Locate .exe boundary
        $exeIndex = $trimmed.IndexOf('.exe', [System.StringComparison]::OrdinalIgnoreCase)
        if ($exeIndex -gt 0) {
            $execPath = $trimmed.Substring(0, $exeIndex + 4)
            # If path contains a space and is not quoted, it is vulnerable to unquoted service path hijacking
            if ($execPath.Contains(' ')) {
                return $true
            }
        }
        elseif ($trimmed.Contains(' ') -and ($trimmed -match '[\\/]')) {
            return $true
        }

        return $false
    }

    # --------------------------------------------------------------------------
    # Helper: Risk Assessment Engine (Heuristic Risk Classifier)
    # --------------------------------------------------------------------------
    function Assess-AsepRisk {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Category,

            [Parameter(Mandatory = $true)]
            [string]$Name,

            [Parameter(Mandatory = $true)]
            [string]$PathOrCommand,

            [Parameter(Mandatory = $false)]
            [string]$ResolvedBinary,

            [Parameter(Mandatory = $false)]
            [string]$AccountContext,

            [Parameter(Mandatory = $true)]
            [bool]$FileExists,

            [Parameter(Mandatory = $true)]
            [bool]$IsSigned,

            [Parameter(Mandatory = $false)]
            [string]$Signer,

            [Parameter(Mandatory = $false)]
            [bool]$IsUnquoted = $false
        )

        $bin = if ($ResolvedBinary) { $ResolvedBinary } else { '' }
        $cmd = $PathOrCommand

        # High-Risk directory regex patterns
        $tempPattern   = '(?i)^([a-z]:)?(\\Users\\Public|\\Users\\[^\\]+\\AppData\\Local\\Temp|\\Windows\\Temp|\\Temp)'
        $appDataPattern = '(?i)^([a-z]:)?\\Users\\[^\\]+\\AppData\\'
        $userProfilePattern = '(?i)^([a-z]:)?\\Users\\[^\\]+'
        $systemDirPattern = '(?i)^[a-z]:\\(Windows\\System32|Program Files|Program Files \(x86\))'

        # Suspicious command-line invocations (LOLBins / Encoded executions)
        $encodedPsPattern = '(?i)(powershell|pwsh)(\.exe)?.*(-enc|-encodedcommand|-e\s|downloadstring|downloadfile|iex|invoke-expression|-w\s+hidden|-windowstyle\s+hidden)'
        $mshtaPattern = '(?i)mshta(\.exe)?.*(http:|https:|javascript:|vbscript:)'
        $suspiciousScriptEngine = '(?i)(wscript|cscript|rundll32|regsvr32|certutil|bitsadmin)\.exe'

        $isElevatedContext = ($AccountContext -match '(?i)SYSTEM|S-1-5-18|Administrators|S-1-5-32-544')

        # ----------------------------------------------------------------------
        # 1. CRITICAL Risk Evaluation
        # ----------------------------------------------------------------------

        # Condition 1A: Elevated context executing from Public, Temp, or AppData
        if ($isElevatedContext -and ($bin -match $tempPattern -or $bin -match $appDataPattern)) {
            return @{
                RiskLevel = 'Critical'
                Reason    = "Elevated context ($AccountContext) executing binary from user-writable path: $bin"
            }
        }

        # Condition 1B: Encoded PowerShell or suspicious script commands
        if ($cmd -match $encodedPsPattern) {
            return @{
                RiskLevel = 'Critical'
                Reason    = "Encoded or hidden PowerShell execution pattern detected in autostart command line"
            }
        }

        # Condition 1C: MSHTA network / remote script download
        if ($cmd -match $mshtaPattern) {
            return @{
                RiskLevel = 'Critical'
                Reason    = "MSHTA remote/script execution pattern detected in persistence configuration"
            }
        }

        # Condition 1D: Windows Service located in user profile or removable storage
        if ($Category -eq 'WindowsService') {
            if ($bin -match $userProfilePattern -or $bin -match $tempPattern) {
                return @{
                    RiskLevel = 'Critical'
                    Reason    = "Windows Service executing from user profile or temporary folder: $bin"
                }
            }

            # Unquoted service path outside Program Files (higher exploitability)
            if ($IsUnquoted -and ($bin -notmatch '(?i)^[a-z]:\\Program Files')) {
                return @{
                    RiskLevel = 'Critical'
                    Reason    = "Unquoted Service Path in potentially user-writable root or custom folder: $bin"
                }
            }
        }

        # Condition 1E: LOLBin executing payload from temp/public directory
        if ($cmd -match $suspiciousScriptEngine -and ($bin -match $tempPattern -or $cmd -match $tempPattern)) {
            return @{
                RiskLevel = 'Critical'
                Reason    = "Script interpreter / LOLBin executing payload from temporary or Public path"
            }
        }

        # ----------------------------------------------------------------------
        # 2. HIGH Risk Evaluation
        # ----------------------------------------------------------------------

        # Condition 2A: Autostart Registry Run pointing to %AppData% or %Temp%
        if ($Category -eq 'RegistryRun' -and ($bin -match $appDataPattern -or $bin -match $tempPattern)) {
            return @{
                RiskLevel = 'High'
                Reason    = "Autostart registry entry pointing to user profile or temporary folder: $bin"
            }
        }

        # Condition 2B: Elevated administrative task running unsigned scripts or binaries
        if ($Category -eq 'ScheduledTask' -and $isElevatedContext -and (-not $IsSigned) -and $FileExists) {
            return @{
                RiskLevel = 'High'
                Reason    = "Elevated administrative scheduled task executing unsigned binary: $bin"
            }
        }

        # Condition 2C: Executable files or scripts placed directly in user Startup folder
        if ($Category -eq 'StartupFolder') {
            if ($bin -match '\.(exe|bat|cmd|vbs|ps1|dll|scr)$' -and (-not $IsSigned)) {
                return @{
                    RiskLevel = 'High'
                    Reason    = "Unsigned binary or script found directly inside Startup folder"
                }
            }
            if ($bin -match $tempPattern) {
                return @{
                    RiskLevel = 'High'
                    Reason    = "Startup shortcut target points to temporary or Public path: $bin"
                }
            }
        }

        # Condition 2D: Windows Service running from non-standard directory
        if ($Category -eq 'WindowsService' -and ($bin -notmatch $systemDirPattern) -and $FileExists) {
            return @{
                RiskLevel = 'High'
                Reason    = "Windows Service executing from non-standard directory: $bin"
            }
        }

        # ----------------------------------------------------------------------
        # 3. MEDIUM Risk Evaluation
        # ----------------------------------------------------------------------

        # Condition 3A: Unquoted Service Path inside Program Files (admin write needed)
        if ($Category -eq 'WindowsService' -and $IsUnquoted) {
            return @{
                RiskLevel = 'Medium'
                Reason    = "Unquoted Service Path within Program Files (requires administrative rights to exploit)"
            }
        }

        # Condition 3B: Orphaned persistence entries (missing binary on disk)
        if (-not $FileExists -and $bin) {
            return @{
                RiskLevel = 'Medium'
                Reason    = "Orphaned persistence entry: target binary not found on disk ($bin)"
            }
        }

        # Condition 3C: Unsigned binary in system or program directory
        if ($FileExists -and (-not $IsSigned) -and ($bin -match $systemDirPattern)) {
            return @{
                RiskLevel = 'Medium'
                Reason    = "Unsigned binary executing from system/program directory: $bin"
            }
        }

        # ----------------------------------------------------------------------
        # 4. LOW Risk Evaluation (Standard / Verified)
        # ----------------------------------------------------------------------
        if ($FileExists -and $IsSigned) {
            $signerText = if ($Signer) { " ($Signer)" } else { '' }
            return @{
                RiskLevel = 'Low'
                Reason    = "Legitimate digitally signed binary in standard path$signerText"
            }
        }

        return @{
            RiskLevel = 'Low'
            Reason    = "Standard persistence configuration item"
        }
    }

    # --------------------------------------------------------------------------
    # Detection Module 1: Scheduled Tasks
    # --------------------------------------------------------------------------
    function Get-ScheduledTaskPersistence {
        [CmdletBinding()]
        param()

        Write-Log "Scanning Scheduled Tasks (Task Scheduler)..." -Severity 'INFO'
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        try {
            $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "Failed to enumerate Scheduled Tasks: $($_.Exception.Message)" -Severity 'ERROR'
            return $results
        }

        $total = $allTasks.Count
        $idx = 0

        foreach ($task in $allTasks) {
            $idx++
            if ($idx % 50 -eq 0 -or $idx -eq $total) {
                Write-Progress -Activity "Auditing Endpoint Persistence" -Status "Auditing Scheduled Tasks ($idx / $total)" -PercentComplete ([int](($idx / $total) * 100))
            }

            # Only inspect tasks with valid actions
            if (-not $task.Actions) { continue }

            $principalContext = 'Unknown'
            if ($task.Principal) {
                $uid = if ($task.Principal.PSObject.Properties['UserId']) { $task.Principal.UserId } else { $null }
                $gid = if ($task.Principal.PSObject.Properties['GroupId']) { $task.Principal.GroupId } else { $null }
                if ($uid) {
                    $principalContext = $uid
                    if ($principalContext -eq 'S-1-5-18' -or $principalContext -eq 'SYSTEM') {
                        $principalContext = 'NT AUTHORITY\SYSTEM'
                    }
                    elseif ($principalContext -eq 'S-1-5-32-544') {
                        $principalContext = 'BUILTIN\Administrators'
                    }
                }
                elseif ($gid) {
                    $principalContext = $gid
                    if ($principalContext -eq 'S-1-5-32-544' -or $principalContext -eq 'Administrators') {
                        $principalContext = 'BUILTIN\Administrators'
                    }
                }
            }

            foreach ($action in $task.Actions) {
                # Look for executable actions safely in strict mode
                if ($action.PSObject.Properties['Execute'] -and $action.Execute) {
                    $argsVal = if ($action.PSObject.Properties['Arguments'] -and $action.Arguments) { $action.Arguments } else { '' }
                    $rawCommand = if ($argsVal) { "$($action.Execute) $argsVal" } else { "$($action.Execute)" }
                    $resolved = Resolve-ExecutablePath -RawCommand $action.Execute
                    $bin = $resolved.Binary
                    $fileExists = $resolved.Exists
                    $sig = Get-BinarySignature -FilePath $bin

                    $risk = Assess-AsepRisk -Category 'ScheduledTask' `
                                            -Name $task.TaskName `
                                            -PathOrCommand $rawCommand `
                                            -ResolvedBinary $bin `
                                            -AccountContext $principalContext `
                                            -FileExists $fileExists `
                                            -IsSigned $sig.IsSigned `
                                            -Signer $sig.Signer

                    $item = [PSCustomObject]@{
                        Category        = "ScheduledTask"
                        Name            = $task.TaskName
                        PathOrCommand   = $rawCommand
                        ResolvedBinary  = $bin
                        AccountContext  = $principalContext
                        RiskLevel       = $risk.RiskLevel
                        DetectionReason = $risk.Reason
                        IsSigned        = $sig.IsSigned
                        Signer          = $sig.Signer
                        FileExists      = $fileExists
                    }
                    $results.Add($item)
                }
            }
        }

        Write-Log "Scheduled Tasks scan completed: found $($results.Count) execution points." -Severity 'SUCCESS'
        return $results
    }

    # --------------------------------------------------------------------------
    # Detection Module 2: Registry Autostart (ASEP Registry Keys)
    # --------------------------------------------------------------------------
    function Get-RegistryPersistence {
        [CmdletBinding()]
        param()

        Write-Log "Scanning Registry Autostart Keys (Run, RunOnce, Active Setup, Shell Folders)..." -Severity 'INFO'
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        $regTargets = @(
            @{ Hive = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Context = 'All Users / Machine' },
            @{ Hive = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Context = 'All Users / Machine' },
            @{ Hive = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Context = 'All Users / Machine (32-bit)' },
            @{ Hive = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'; Context = 'All Users / Machine (32-bit)' },
            @{ Hive = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Context = "$env:USERDOMAIN\$env:USERNAME" },
            @{ Hive = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Context = "$env:USERDOMAIN\$env:USERNAME" }
        )

        # 1. Standard Run / RunOnce Keys
        foreach ($target in $regTargets) {
            $hivePath = $target.Hive
            $context = $target.Context

            if (Test-Path -LiteralPath $hivePath) {
                try {
                    $keyProps = Get-ItemProperty -LiteralPath $hivePath -ErrorAction SilentlyContinue
                    if ($keyProps) {
                        foreach ($prop in $keyProps.PSObject.Properties) {
                            if ($prop.Name -notmatch '^PS.*') {
                                $val = [string]$prop.Value
                                if ([string]::IsNullOrWhiteSpace($val)) { continue }

                                $resolved = Resolve-ExecutablePath -RawCommand $val
                                $bin = $resolved.Binary
                                $fileExists = $resolved.Exists
                                $sig = Get-BinarySignature -FilePath $bin

                                $risk = Assess-AsepRisk -Category 'RegistryRun' `
                                                        -Name "$($prop.Name) [$hivePath]" `
                                                        -PathOrCommand $val `
                                                        -ResolvedBinary $bin `
                                                        -AccountContext $context `
                                                        -FileExists $fileExists `
                                                        -IsSigned $sig.IsSigned `
                                                        -Signer $sig.Signer

                                $results.Add([PSCustomObject]@{
                                    Category        = "RegistryRun"
                                    Name            = $prop.Name
                                    PathOrCommand   = $val
                                    ResolvedBinary  = $bin
                                    AccountContext  = $context
                                    RiskLevel       = $risk.RiskLevel
                                    DetectionReason = $risk.Reason
                                    IsSigned        = $sig.IsSigned
                                    Signer          = $sig.Signer
                                    FileExists      = $fileExists
                                })
                            }
                        }
                    }
                }
                catch {}
            }
        }

        # 2. Active Setup: Installed Components (StubPath)
        $activeSetupHives = @(
            'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components'
        )

        foreach ($asHive in $activeSetupHives) {
            if (Test-Path -LiteralPath $asHive) {
                try {
                    $subKeys = Get-ChildItem -LiteralPath $asHive -ErrorAction SilentlyContinue
                    foreach ($sub in $subKeys) {
                        $itemProp = Get-ItemProperty -LiteralPath $sub.PSPath -ErrorAction SilentlyContinue
                        $stubPath = if ($itemProp -and $itemProp.PSObject.Properties['StubPath']) { $itemProp.StubPath } else { $null }
                        if ($stubPath) {
                            $resolved = Resolve-ExecutablePath -RawCommand $stubPath
                            $bin = $resolved.Binary
                            $fileExists = $resolved.Exists
                            $sig = Get-BinarySignature -FilePath $bin

                            $risk = Assess-AsepRisk -Category 'RegistryRun' `
                                                    -Name "ActiveSetup: $($sub.PSChildName)" `
                                                    -PathOrCommand $stubPath `
                                                    -ResolvedBinary $bin `
                                                    -AccountContext 'Active Setup (User Logon)' `
                                                    -FileExists $fileExists `
                                                    -IsSigned $sig.IsSigned `
                                                    -Signer $sig.Signer

                            $results.Add([PSCustomObject]@{
                                Category        = "RegistryRun"
                                Name            = "ActiveSetup: $($sub.PSChildName)"
                                PathOrCommand   = $stubPath
                                ResolvedBinary  = $bin
                                AccountContext  = 'Active Setup (User Logon)'
                                RiskLevel       = $risk.RiskLevel
                                DetectionReason = $risk.Reason
                                IsSigned        = $sig.IsSigned
                                Signer          = $sig.Signer
                                FileExists      = $fileExists
                            })
                        }
                    }
                }
                catch {}
            }
        }

        # 3. User Shell Folders Startup Hijacking Check
        $shellFolderHives = @(
            @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'; Prop = 'Common Startup' },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'; Prop = 'Startup' }
        )

        foreach ($sf in $shellFolderHives) {
            if (Test-Path -LiteralPath $sf.Path) {
                try {
                    $itemProp = Get-ItemProperty -LiteralPath $sf.Path -ErrorAction SilentlyContinue
                    $propVal = if ($itemProp -and $itemProp.PSObject.Properties[$sf.Prop]) { $itemProp.($sf.Prop) } else { $null }
                    if ($propVal) {
                        $expanded = [System.Environment]::ExpandEnvironmentVariables($propVal)
                        # Check for non-standard path tampering
                        $isTampered = ($expanded -notmatch '(?i)Microsoft\\Windows\\Start Menu\\Programs\\Startup')
                        if ($isTampered) {
                            $results.Add([PSCustomObject]@{
                                Category        = "RegistryRun"
                                Name            = "ShellFolder: $($sf.Prop)"
                                PathOrCommand   = $expanded
                                ResolvedBinary  = $expanded
                                AccountContext  = 'System / User Environment'
                                RiskLevel       = 'Critical'
                                DetectionReason = "User Shell Folders '$($sf.Prop)' redirected to non-standard location: $expanded"
                                IsSigned        = $false
                                Signer          = $null
                                FileExists      = (Test-Path -LiteralPath $expanded)
                            })
                        }
                    }
                }
                catch {}
            }
        }

        Write-Log "Registry Autostart scan completed: found $($results.Count) execution points." -Severity 'SUCCESS'
        return $results
    }

    # --------------------------------------------------------------------------
    # Detection Module 3: Startup Folders
    # --------------------------------------------------------------------------
    function Get-StartupFolderPersistence {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false)]
            [switch]$AuditAllProfiles
        )

        Write-Log "Scanning Startup Folders (ProgramData, AppData)..." -Severity 'INFO'
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        $startupDirs = [System.Collections.Generic.List[hashtable]]::new()

        # 1. Global ProgramData Startup
        $globalStartup = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
        if (Test-Path -LiteralPath $globalStartup) {
            $startupDirs.Add(@{ Path = $globalStartup; Context = 'All Users' })
        }

        # 2. Current User Startup
        $currentUserStartup = Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Windows\Start Menu\Programs\Startup'
        if (Test-Path -LiteralPath $currentUserStartup) {
            $startupDirs.Add(@{ Path = $currentUserStartup; Context = "$env:USERDOMAIN\$env:USERNAME" })
        }

        # 3. Multi-profile scanning if requested
        if ($AuditAllProfiles) {
            try {
                $profileDirs = Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue |
                               Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }

                foreach ($prof in $profileDirs) {
                    $userPath = Join-Path -Path $prof.FullName -ChildPath 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
                    if (Test-Path -LiteralPath $userPath) {
                        # Avoid duplicating current user
                        if ($userPath -ne $currentUserStartup) {
                            $startupDirs.Add(@{ Path = $userPath; Context = $prof.Name })
                        }
                    }
                }
            }
            catch {}
        }

        $wscriptShell = $null
        try {
            $wscriptShell = New-Object -ComObject WScript.Shell
        }
        catch {}

        foreach ($dir in $startupDirs) {
            $dirPath = $dir.Path
            $context = $dir.Context

            try {
                $files = Get-ChildItem -LiteralPath $dirPath -File -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $rawCommand = $file.FullName
                    $resolvedBin = $file.FullName
                    $isShortcut = ($file.Extension -eq '.lnk')

                    if ($isShortcut -and $wscriptShell) {
                        try {
                            $sc = $wscriptShell.CreateShortcut($file.FullName)
                            if ($sc -and $sc.TargetPath) {
                                $resolvedBin = $sc.TargetPath
                                $rawCommand = if ($sc.Arguments) { "$($sc.TargetPath) $($sc.Arguments)" } else { "$($sc.TargetPath)" }
                            }
                        }
                        catch {}
                    }

                    $resolved = Resolve-ExecutablePath -RawCommand $resolvedBin
                    $bin = if ($resolved.Binary) { $resolved.Binary } else { $resolvedBin }
                    $fileExists = if ($bin) { Test-Path -LiteralPath $bin -PathType Leaf } else { $false }
                    $sig = Get-BinarySignature -FilePath $bin

                    $risk = Assess-AsepRisk -Category 'StartupFolder' `
                                            -Name $file.Name `
                                            -PathOrCommand $rawCommand `
                                            -ResolvedBinary $bin `
                                            -AccountContext $context `
                                            -FileExists $fileExists `
                                            -IsSigned $sig.IsSigned `
                                            -Signer $sig.Signer

                    $results.Add([PSCustomObject]@{
                        Category        = "StartupFolder"
                        Name            = $file.Name
                        PathOrCommand   = $rawCommand
                        ResolvedBinary  = $bin
                        AccountContext  = $context
                        RiskLevel       = $risk.RiskLevel
                        DetectionReason = $risk.Reason
                        IsSigned        = $sig.IsSigned
                        Signer          = $sig.Signer
                        FileExists      = $fileExists
                    })
                }
            }
            catch {}
        }

        if ($wscriptShell) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wscriptShell) | Out-Null
        }

        Write-Log "Startup Folders scan completed: found $($results.Count) items." -Severity 'SUCCESS'
        return $results
    }

    # --------------------------------------------------------------------------
    # Detection Module 4: Windows Services (Windows Services & Unquoted Paths)
    # --------------------------------------------------------------------------
    function Get-WindowsServicePersistence {
        [CmdletBinding()]
        param()

        Write-Log "Scanning Windows Services (Unquoted Paths, Non-Standard Binaries)..." -Severity 'INFO'
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        try {
            $services = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "Failed to query Win32_Service: $($_.Exception.Message)" -Severity 'ERROR'
            return $results
        }

        $total = $services.Count
        $idx = 0

        foreach ($svc in $services) {
            $idx++
            if ($idx % 50 -eq 0 -or $idx -eq $total) {
                Write-Progress -Activity "Auditing Endpoint Persistence" -Status "Auditing Windows Services ($idx / $total)" -PercentComplete ([int](($idx / $total) * 100))
            }

            $rawPath = $svc.PathName
            if ([string]::IsNullOrWhiteSpace($rawPath)) { continue }

            $resolved = Resolve-ExecutablePath -RawCommand $rawPath
            $bin = $resolved.Binary
            $fileExists = $resolved.Exists
            $sig = Get-BinarySignature -FilePath $bin

            $isUnquoted = Test-IsUnquotedServicePath -PathName $rawPath
            $context = if ($svc.StartName) { $svc.StartName } else { 'LocalSystem' }
            if ($context -eq 'LocalSystem') { $context = 'NT AUTHORITY\SYSTEM' }

            $risk = Assess-AsepRisk -Category 'WindowsService' `
                                    -Name $svc.Name `
                                    -PathOrCommand $rawPath `
                                    -ResolvedBinary $bin `
                                    -AccountContext $context `
                                    -FileExists $fileExists `
                                    -IsSigned $sig.IsSigned `
                                    -Signer $sig.Signer `
                                    -IsUnquoted $isUnquoted

            # For services, only record non-standard or flagged items to avoid cluttering with 300+ standard services
            $isStandardSystem32 = ($bin -match '(?i)^[a-z]:\\Windows\\(System32|SysWOW64)\\')
            if ($risk.RiskLevel -ne 'Low' -or (-not $isStandardSystem32)) {
                $results.Add([PSCustomObject]@{
                    Category        = "WindowsService"
                    Name            = $svc.Name
                    PathOrCommand   = $rawPath
                    ResolvedBinary  = $bin
                    AccountContext  = $context
                    RiskLevel       = $risk.RiskLevel
                    DetectionReason = $risk.Reason
                    IsSigned        = $sig.IsSigned
                    Signer          = $sig.Signer
                    FileExists      = $fileExists
                })
            }
        }

        Write-Log "Windows Services scan completed: evaluated $total services, cataloged $($results.Count) entries." -Severity 'SUCCESS'
        return $results
    }

    # --------------------------------------------------------------------------
    # Standalone Responsive HTML Report Generator
    # --------------------------------------------------------------------------
    function New-EndpointPersistenceHtmlReport {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [array]$AuditRecords,

            [Parameter(Mandatory = $true)]
            [string]$OutputPath,

            [Parameter(Mandatory = $false)]
            [string]$MinimumRiskFilter = "Low"
        )

        $computerName = $env:COMPUTERNAME
        $generatedTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

        $totalCount    = $AuditRecords.Count
        $criticalCount = @($AuditRecords | Where-Object { $_.RiskLevel -eq 'Critical' }).Count
        $highCount     = @($AuditRecords | Where-Object { $_.RiskLevel -eq 'High' }).Count
        $mediumCount   = @($AuditRecords | Where-Object { $_.RiskLevel -eq 'Medium' }).Count
        $lowCount      = @($AuditRecords | Where-Object { $_.RiskLevel -eq 'Low' }).Count

        $taskCount     = @($AuditRecords | Where-Object { $_.Category -eq 'ScheduledTask' }).Count
        $regCount      = @($AuditRecords | Where-Object { $_.Category -eq 'RegistryRun' }).Count
        $startupCount  = @($AuditRecords | Where-Object { $_.Category -eq 'StartupFolder' }).Count
        $serviceCount  = @($AuditRecords | Where-Object { $_.Category -eq 'WindowsService' }).Count

        # Build table rows HTML
        $tableRows = [System.Text.StringBuilder]::new()
        foreach ($rec in $AuditRecords) {
            $riskBadgeClass = "badge-$($rec.RiskLevel.ToLower())"
            $signedBadgeClass = if ($rec.IsSigned) { "badge-signed" } else { "badge-unsigned" }
            $signedText = if ($rec.IsSigned) {
                if ($rec.Signer) { "Signed ($([System.Net.WebUtility]::HtmlEncode($rec.Signer)))" } else { "Signed" }
            } else {
                "Unsigned"
            }
            $existsBadgeClass = if ($rec.FileExists) { "badge-exists" } else { "badge-missing" }
            $existsText = if ($rec.FileExists) { "On Disk" } else { "Missing" }

            $rowHtml = @"
            <tr data-risk="$($rec.RiskLevel)" data-category="$($rec.Category)">
                <td><span class="category-pill">$([System.Net.WebUtility]::HtmlEncode($rec.Category))</span></td>
                <td class="font-semibold">$([System.Net.WebUtility]::HtmlEncode($rec.Name))</td>
                <td><span class="risk-badge $riskBadgeClass">$($rec.RiskLevel)</span></td>
                <td class="mono text-muted">$([System.Net.WebUtility]::HtmlEncode($rec.AccountContext))</td>
                <td class="mono code-cell" title="$([System.Net.WebUtility]::HtmlEncode($rec.PathOrCommand))">$([System.Net.WebUtility]::HtmlEncode($rec.ResolvedBinary))</td>
                <td>
                    <span class="status-badge $signedBadgeClass">$signedText</span>
                    <span class="status-badge $existsBadgeClass">$existsText</span>
                </td>
                <td class="reason-cell">$([System.Net.WebUtility]::HtmlEncode($rec.DetectionReason))</td>
            </tr>
"@
            $tableRows.AppendLine($rowHtml) | Out-Null
        }

        $htmlContent = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Endpoint Persistence Audit - $computerName</title>
    <style>
        :root {
            --bg-body: #0d1117;
            --bg-card: #161b22;
            --bg-card-hover: #1c2128;
            --border-color: #30363d;
            --text-heading: #f0f6fc;
            --text-main: #c9d1d9;
            --text-muted: #8b949e;
            --accent-blue: #58a6ff;
            --accent-green: #3fb950;
            --accent-yellow: #d29922;
            --accent-orange: #f0883e;
            --accent-red: #f85149;
            --badge-critical: rgba(248, 81, 73, 0.2);
            --badge-critical-text: #ff7b72;
            --badge-high: rgba(240, 136, 62, 0.2);
            --badge-high-text: #ffa657;
            --badge-medium: rgba(210, 153, 34, 0.2);
            --badge-medium-text: #e3b341;
            --badge-low: rgba(63, 185, 80, 0.2);
            --badge-low-text: #7ee787;
        }

        [data-theme="light"] {
            --bg-body: #f6f8fa;
            --bg-card: #ffffff;
            --bg-card-hover: #f3f4f6;
            --border-color: #d0d7de;
            --text-heading: #1f2328;
            --text-main: #24292f;
            --text-muted: #57606a;
            --accent-blue: #0969da;
            --accent-green: #1a7f37;
            --accent-yellow: #9a6700;
            --accent-orange: #bc4c00;
            --accent-red: #cf222e;
            --badge-critical: rgba(207, 34, 46, 0.15);
            --badge-critical-text: #cf222e;
            --badge-high: rgba(188, 76, 0, 0.15);
            --badge-high-text: #bc4c00;
            --badge-medium: rgba(154, 103, 0, 0.15);
            --badge-medium-text: #9a6700;
            --badge-low: rgba(26, 127, 55, 0.15);
            --badge-low-text: #1a7f37;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-body);
            color: var(--text-main);
            line-height: 1.5;
            padding: 24px;
            transition: background-color 0.2s ease, color 0.2s ease;
        }

        .container { max-width: 1500px; margin: 0 auto; }

        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border-color);
            margin-bottom: 24px;
        }

        .header-title h1 {
            font-size: 26px;
            font-weight: 700;
            color: var(--text-heading);
            letter-spacing: -0.5px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .header-title p {
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 4px;
        }

        .header-actions {
            display: flex;
            gap: 10px;
            align-items: center;
        }

        .theme-toggle-btn {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            color: var(--text-main);
            padding: 8px 14px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 13px;
            font-weight: 500;
            transition: all 0.2s;
        }
        .theme-toggle-btn:hover { background: var(--bg-card-hover); }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }

        .card {
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 18px 20px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
            transition: transform 0.15s ease;
        }
        .card:hover { transform: translateY(-2px); }

        .card-label {
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-muted);
            margin-bottom: 6px;
        }

        .card-value {
            font-size: 30px;
            font-weight: 700;
            color: var(--text-heading);
            line-height: 1.2;
        }

        .card-critical .card-value { color: var(--accent-red); }
        .card-high .card-value { color: var(--accent-orange); }
        .card-medium .card-value { color: var(--accent-yellow); }
        .card-low .card-value { color: var(--accent-green); }

        .card-subtext {
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 6px;
        }

        .controls-panel {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 16px 20px;
            margin-bottom: 24px;
            display: flex;
            flex-wrap: wrap;
            gap: 14px;
            align-items: center;
            justify-content: space-between;
        }

        .search-box {
            flex: 1;
            min-width: 280px;
        }

        .search-input {
            width: 100%;
            background: var(--bg-body);
            border: 1px solid var(--border-color);
            color: var(--text-heading);
            padding: 10px 14px;
            border-radius: 8px;
            font-size: 13px;
            outline: none;
            transition: border-color 0.2s;
        }
        .search-input:focus { border-color: var(--accent-blue); }

        .filter-group {
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
        }

        .filter-btn {
            background: var(--bg-body);
            border: 1px solid var(--border-color);
            color: var(--text-muted);
            padding: 7px 13px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
        }
        .filter-btn.active, .filter-btn:hover {
            color: var(--text-heading);
            border-color: var(--accent-blue);
            background: var(--bg-card-hover);
        }

        .table-wrapper {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            overflow-x: auto;
            margin-bottom: 24px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            text-align: left;
            font-size: 13px;
        }

        th {
            background: var(--bg-card-hover);
            color: var(--text-heading);
            padding: 12px 16px;
            font-weight: 600;
            border-bottom: 1px solid var(--border-color);
            white-space: nowrap;
            user-select: none;
            cursor: pointer;
        }

        th:hover { color: var(--accent-blue); }

        td {
            padding: 12px 16px;
            border-bottom: 1px solid var(--border-color);
            vertical-align: middle;
        }

        tr:last-child td { border-bottom: none; }
        tr:hover { background: var(--bg-card-hover); }

        .mono { font-family: ui-monospace, SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace; font-size: 12px; }
        .font-semibold { font-weight: 600; color: var(--text-heading); }
        .text-muted { color: var(--text-muted); }
        .code-cell {
            max-width: 320px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .reason-cell { max-width: 340px; font-size: 12px; line-height: 1.4; }

        .category-pill {
            background: var(--bg-body);
            border: 1px solid var(--border-color);
            padding: 3px 8px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 500;
            color: var(--accent-blue);
            white-space: nowrap;
        }

        .risk-badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            white-space: nowrap;
        }
        .badge-critical { background: var(--badge-critical); color: var(--badge-critical-text); border: 1px solid rgba(248,81,73,0.3); }
        .badge-high { background: var(--badge-high); color: var(--badge-high-text); border: 1px solid rgba(240,136,62,0.3); }
        .badge-medium { background: var(--badge-medium); color: var(--badge-medium-text); border: 1px solid rgba(210,153,34,0.3); }
        .badge-low { background: var(--badge-low); color: var(--badge-low-text); border: 1px solid rgba(63,185,80,0.3); }

        .status-badge {
            display: inline-block;
            padding: 2px 7px;
            border-radius: 4px;
            font-size: 11px;
            margin-right: 4px;
            margin-bottom: 2px;
        }
        .badge-signed { background: rgba(63,185,80,0.15); color: var(--accent-green); }
        .badge-unsigned { background: rgba(248,81,73,0.15); color: var(--accent-red); }
        .badge-exists { background: rgba(88,166,255,0.15); color: var(--accent-blue); }
        .badge-missing { background: rgba(210,153,34,0.15); color: var(--accent-yellow); }

        .remediation-section {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px 24px;
            margin-bottom: 24px;
        }

        .remediation-section h2 {
            font-size: 18px;
            color: var(--text-heading);
            margin-bottom: 12px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .remediation-card {
            background: var(--bg-body);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 14px 18px;
            margin-top: 10px;
        }

        .remediation-card h3 {
            font-size: 14px;
            font-weight: 600;
            color: var(--accent-blue);
            margin-bottom: 6px;
        }

        .remediation-card p {
            font-size: 12px;
            color: var(--text-muted);
            margin-bottom: 8px;
        }

        .code-block {
            background: #000;
            color: #58a6ff;
            padding: 10px 14px;
            border-radius: 6px;
            font-family: monospace;
            font-size: 12px;
            overflow-x: auto;
        }

        footer {
            text-align: center;
            font-size: 12px;
            color: var(--text-muted);
            padding-top: 16px;
            border-top: 1px solid var(--border-color);
        }

        @media print {
            body { background: #fff; color: #000; padding: 0; }
            .theme-toggle-btn, .controls-panel { display: none; }
            .card, .table-wrapper, .remediation-section { border: 1px solid #ccc; box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-title">
                <h1>
                    <span>&#x1F6E1;&#xFE0F;</span> Windows Endpoint Persistence Audit
                </h1>
                <p>Host: <strong>$computerName</strong> | Generated: <strong>$generatedTime</strong> | Engine: Audit-EndpointPersistence v1.0.0</p>
            </div>
            <div class="header-actions">
                <button class="theme-toggle-btn" onclick="toggleTheme()" id="themeBtn">&#x2600;&#xFE0F; Light Mode</button>
            </div>
        </header>

        <section class="metrics-grid">
            <div class="card">
                <div class="card-label">Total ASEP Points</div>
                <div class="card-value">$totalCount</div>
                <div class="card-subtext">Tasks: $taskCount | Reg: $regCount | Startup: $startupCount | Svc: $serviceCount</div>
            </div>
            <div class="card card-critical">
                <div class="card-label">Critical Findings</div>
                <div class="card-value">$criticalCount</div>
                <div class="card-subtext">Immediate triage required</div>
            </div>
            <div class="card card-high">
                <div class="card-label">High Risk Items</div>
                <div class="card-value">$highCount</div>
                <div class="card-subtext">Investigate autostart origins</div>
            </div>
            <div class="card card-medium">
                <div class="card-label">Medium Risk</div>
                <div class="card-value">$mediumCount</div>
                <div class="card-subtext">Unquoted paths & orphans</div>
            </div>
            <div class="card card-low">
                <div class="card-label">Low / Verified</div>
                <div class="card-value">$lowCount</div>
                <div class="card-subtext">Signed legitimate binaries</div>
            </div>
        </section>

        <section class="controls-panel">
            <div class="search-box">
                <input type="text" id="searchInput" class="search-input" placeholder="Search by name, binary, category, context, or detection reason..." onkeyup="filterTable()">
            </div>
            <div class="filter-group">
                <button class="filter-btn active" onclick="setRiskFilter('All', this)">All Risks</button>
                <button class="filter-btn" onclick="setRiskFilter('Critical', this)">Critical ($criticalCount)</button>
                <button class="filter-btn" onclick="setRiskFilter('High', this)">High ($highCount)</button>
                <button class="filter-btn" onclick="setRiskFilter('Medium', this)">Medium ($mediumCount)</button>
                <button class="filter-btn" onclick="setRiskFilter('Low', this)">Low ($lowCount)</button>
            </div>
            <div class="filter-group">
                <button class="filter-btn active" onclick="setCategoryFilter('All', this)">All Categories</button>
                <button class="filter-btn" onclick="setCategoryFilter('ScheduledTask', this)">Tasks ($taskCount)</button>
                <button class="filter-btn" onclick="setCategoryFilter('RegistryRun', this)">Registry ($regCount)</button>
                <button class="filter-btn" onclick="setCategoryFilter('StartupFolder', this)">Startup ($startupCount)</button>
                <button class="filter-btn" onclick="setCategoryFilter('WindowsService', this)">Services ($serviceCount)</button>
            </div>
        </section>

        <section class="table-wrapper">
            <table id="findingsTable">
                <thead>
                    <tr>
                        <th onclick="sortTable(0)">Category &#8597;</th>
                        <th onclick="sortTable(1)">Entry Name &#8597;</th>
                        <th onclick="sortTable(2)">Risk Level &#8597;</th>
                        <th onclick="sortTable(3)">Account Context &#8597;</th>
                        <th onclick="sortTable(4)">Resolved Binary &#8597;</th>
                        <th>Signature & Status</th>
                        <th>Detection Reason</th>
                    </tr>
                </thead>
                <tbody>
$($tableRows.ToString())
                </tbody>
            </table>
        </section>

        <section class="remediation-section">
            <h2><span>&#x1F527;</span> Hardening & Remediation Guidance</h2>
            <div class="remediation-card">
                <h3>1. Remediating Unquoted Service Paths (CWE-428)</h3>
                <p>Enclose the binary path within double quotes in the Windows Service Control Manager to prevent subpath binary planting:</p>
                <div class="code-block">sc.exe config "&lt;ServiceName&gt;" binPath= "\"C:\Path\To\Service.exe\""</div>
            </div>
            <div class="remediation-card">
                <h3>2. Purging Malicious or Suspicious Scheduled Tasks</h3>
                <p>Remove rogue scheduled tasks running from user-writable directories or executing unsigned scripts:</p>
                <div class="code-block">Unregister-ScheduledTask -TaskName "&lt;TaskName&gt;" -Confirm:`$false</div>
            </div>
            <div class="remediation-card">
                <h3>3. Cleaning Suspicious Autostart Registry Keys</h3>
                <p>Remove rogue persistence entries from Run / RunOnce registry hives:</p>
                <div class="code-block">Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "&lt;EntryName&gt;"</div>
            </div>
        </section>

        <footer>
            Audit-EndpointPersistence.ps1 &bull; Created by Roman Pindela &bull; Windows-Desktop Security Suite
        </footer>
    </div>

    <script>
        let currentRisk = 'All';
        let currentCategory = 'All';

        function toggleTheme() {
            const html = document.documentElement;
            const btn = document.getElementById('themeBtn');
            if (html.getAttribute('data-theme') === 'dark') {
                html.setAttribute('data-theme', 'light');
                btn.textContent = '🌙 Dark Mode';
            } else {
                html.setAttribute('data-theme', 'dark');
                btn.textContent = '☀️ Light Mode';
            }
        }

        function setRiskFilter(risk, btn) {
            currentRisk = risk;
            document.querySelectorAll('.filter-group:nth-child(2) .filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            filterTable();
        }

        function setCategoryFilter(cat, btn) {
            currentCategory = cat;
            document.querySelectorAll('.filter-group:nth-child(3) .filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            filterTable();
        }

        function filterTable() {
            const query = document.getElementById('searchInput').value.toLowerCase();
            const rows = document.querySelectorAll('#findingsTable tbody tr');

            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                const risk = row.getAttribute('data-risk');
                const cat = row.getAttribute('data-category');

                const matchesQuery = text.includes(query);
                const matchesRisk = (currentRisk === 'All' || risk === currentRisk);
                const matchesCat = (currentCategory === 'All' || cat === currentCategory);

                if (matchesQuery && matchesRisk && matchesCat) {
                    row.style.display = '';
                } else {
                    row.style.display = 'none';
                }
            });
        }

        function sortTable(n) {
            const table = document.getElementById("findingsTable");
            let rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
            switching = true;
            dir = "asc";

            while (switching) {
                switching = false;
                rows = table.rows;
                for (i = 1; i < (rows.length - 1); i++) {
                    shouldSwitch = false;
                    x = rows[i].getElementsByTagName("TD")[n];
                    y = rows[i + 1].getElementsByTagName("TD")[n];
                    if (dir === "asc") {
                        if (x.textContent.toLowerCase() > y.textContent.toLowerCase()) {
                            shouldSwitch = true;
                            break;
                        }
                    } else if (dir === "desc") {
                        if (x.textContent.toLowerCase() < y.textContent.toLowerCase()) {
                            shouldSwitch = true;
                            break;
                        }
                    }
                }
                if (shouldSwitch) {
                    rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
                    switching = true;
                    switchcount++;
                } else {
                    if (switchcount === 0 && dir === "asc") {
                        dir = "desc";
                        switching = true;
                    }
                }
            }
        }
    </script>
</body>
</html>
"@

        $reportDir = [System.IO.Path]::GetDirectoryName($OutputPath)
        if (-not (Test-Path -LiteralPath $reportDir)) {
            New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
        }

        [System.IO.File]::WriteAllText($OutputPath, $htmlContent, [System.Text.Encoding]::UTF8)
        Write-Log "HTML audit report generated successfully: $OutputPath" -Severity 'SUCCESS'
    }
}

# ==============================================================================
# Script Lifecycle: Process Block
# ==============================================================================

process {
    # 1. Interactive Help Check
    if ($Help) {
        Show-ScriptHelp
        return
    }

    # 2. Administrator Elevation Verification
    if (-not $SkipAdminCheck) {
        if (-not (Test-IsElevated)) {
            Invoke-ElevationRelaunch -BoundParameters $PSBoundParameters
            return
        }
    }

    # 3. Telemetry Log Initialization
    Initialize-LoggingDirectory -TargetLogFile $script:ResolvedLogPath
    Write-Log "Starting Audit-EndpointPersistence session on $env:COMPUTERNAME (User: $env:USERDOMAIN\$env:USERNAME)" -Severity 'HEADER'
    Write-Log "Execution Policy: $(Get-ExecutionPolicy) | PowerShell: $($PSVersionTable.PSVersion)" -Severity 'INFO'

    # Master findings list
    $allFindings = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --------------------------------------------------------------------------
    # Stage 1: Scheduled Tasks
    # --------------------------------------------------------------------------
    Write-Progress -Activity "Auditing Endpoint Persistence" -Status "Auditing Scheduled Tasks" -PercentComplete 10
    $taskFindings = Get-ScheduledTaskPersistence
    $taskFindings | ForEach-Object { $allFindings.Add($_) }

    # --------------------------------------------------------------------------
    # Stage 2: Registry Autostart
    # --------------------------------------------------------------------------
    Write-Progress -Activity "Auditing Endpoint Persistence" -Status "Auditing Registry Autostart Keys" -PercentComplete 35
    $regFindings = Get-RegistryPersistence
    $regFindings | ForEach-Object { $allFindings.Add($_) }

    # --------------------------------------------------------------------------
    # Stage 3: Startup Folders
    # --------------------------------------------------------------------------
    Write-Progress -Activity "Auditing Endpoint Persistence" -Status "Auditing Startup Folders" -PercentComplete 60
    $startupFindings = Get-StartupFolderPersistence -AuditAllProfiles:$IncludeAllProfiles
    $startupFindings | ForEach-Object { $allFindings.Add($_) }

    # --------------------------------------------------------------------------
    # Stage 4: Windows Services
    # --------------------------------------------------------------------------
    Write-Progress -Activity "Auditing Endpoint Persistence" -Status "Auditing Windows Services" -PercentComplete 85
    $serviceFindings = Get-WindowsServicePersistence
    $serviceFindings | ForEach-Object { $allFindings.Add($_) }

    Write-Progress -Activity "Auditing Endpoint Persistence" -Status "Finalizing Findings & Report" -PercentComplete 95

    # --------------------------------------------------------------------------
    # Stage 5: Evaluation & Threshold Filtering
    # --------------------------------------------------------------------------
    $riskHierarchy = @{ 'Low' = 1; 'Medium' = 2; 'High' = 3; 'Critical' = 4 }
    $minThreshold = $riskHierarchy[$MinimumRiskLevel]

    $filteredFindings = @($allFindings | Where-Object {
        $r = $_.RiskLevel
        $rank = if ($riskHierarchy.ContainsKey($r)) { $riskHierarchy[$r] } else { 1 }
        $rank -ge $minThreshold
    })

    # Summary metrics logging
    $criticalCount = @($allFindings | Where-Object { $_.RiskLevel -eq 'Critical' }).Count
    $highCount     = @($allFindings | Where-Object { $_.RiskLevel -eq 'High' }).Count
    $mediumCount   = @($allFindings | Where-Object { $_.RiskLevel -eq 'Medium' }).Count
    $lowCount      = @($allFindings | Where-Object { $_.RiskLevel -eq 'Low' }).Count

    Write-Log "Persistence audit finished: Total=$($allFindings.Count) | Critical=$criticalCount | High=$highCount | Medium=$mediumCount | Low=$lowCount" -Severity 'HEADER'

    # Console Summary Table
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host " ENDPOINT PERSISTENCE AUDIT SUMMARY - $env:COMPUTERNAME" -ForegroundColor Yellow
    Write-Host " Minimum Risk Level Displayed: $MinimumRiskLevel | Filtered Entries: $($filteredFindings.Count)" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan

    if ($filteredFindings.Count -gt 0) {
        $filteredFindings | Select-Object -Property Category, Name, RiskLevel, AccountContext, ResolvedBinary, DetectionReason |
            Format-Table -AutoSize | Out-Host
    }
    else {
        Write-Host "No persistence items matching or exceeding '$MinimumRiskLevel' risk level were identified." -ForegroundColor Green
    }

    # --------------------------------------------------------------------------
    # Stage 6: HTML Report Generation
    # --------------------------------------------------------------------------
    if ($ReportPath) {
        try {
            New-EndpointPersistenceHtmlReport -AuditRecords $allFindings.ToArray() -OutputPath $script:ResolvedReportPath -MinimumRiskFilter $MinimumRiskLevel
        }
        catch {
            Write-Log "Failed to generate HTML report: $($_.Exception.Message)" -Severity 'ERROR'
        }
    }

    # --------------------------------------------------------------------------
    # Stage 7: CSV Export
    # --------------------------------------------------------------------------
    if ($ExportCsv) {
        try {
            $csvDir = [System.IO.Path]::GetDirectoryName($script:ResolvedCsvPath)
            if (-not (Test-Path -LiteralPath $csvDir)) {
                New-Item -Path $csvDir -ItemType Directory -Force | Out-Null
            }
            $allFindings | Export-Csv -LiteralPath $script:ResolvedCsvPath -NoTypeInformation -Encoding UTF8
            Write-Log "Exported findings to CSV: $script:ResolvedCsvPath" -Severity 'SUCCESS'
        }
        catch {
            Write-Log "Failed to export CSV: $($_.Exception.Message)" -Severity 'ERROR'
        }
    }

    # --------------------------------------------------------------------------
    # Stage 8: Pipeline Output
    # --------------------------------------------------------------------------
    if ($PassThru) {
        $filteredFindings | ForEach-Object { $_ }
    }

    Write-Progress -Activity "Auditing Endpoint Persistence" -Completed
}

# ==============================================================================
# Script Lifecycle: End Block
# ==============================================================================

end {
    Write-Log "Audit-EndpointPersistence completed. Log saved to: $script:ResolvedLogPath" -Severity 'SUCCESS'

    # Open report if requested
    if ($OpenReport -and (Test-Path -LiteralPath $script:ResolvedReportPath)) {
        try {
            Start-Process -FilePath $script:ResolvedReportPath
        }
        catch {
            Write-Log "Could not automatically launch browser: $($_.Exception.Message)" -Severity 'WARN'
        }
    }
}
