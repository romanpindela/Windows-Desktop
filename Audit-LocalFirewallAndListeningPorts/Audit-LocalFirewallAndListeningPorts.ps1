<#
.SYNOPSIS
    Audits Windows Defender Firewall profiles, identifies high-risk inbound rules, enumerates
    listening TCP/UDP endpoints, verifies process Authenticode digital signatures, logs telemetry to C:\Logs,
    and generates a standalone, responsive HTML security audit report.

.DESCRIPTION
    Audit-LocalFirewallAndListeningPorts.ps1 is an enterprise-grade endpoint security auditing tool
    designed for Windows 10, Windows 11, and Windows Server systems. It evaluates the network attack surface
    of a Windows endpoint by inspecting three critical security tiers:

      1. Windows Defender Firewall Profiles:
         Audits Domain, Private, and Public profiles for active operational state, default inbound/outbound
         action posture, and drop/allow logging status.

      2. High-Risk Inbound Rule Baseline Violations:
         Detects active inbound firewall rules permitting unrestricted access (RemoteAddress = Any / * / 0.0.0.0/0)
         to critical administrative and file-sharing ports (RDP 3389, WinRM 5985/5986, SMB 445/139, SSH 22, FTP 21, Telnet 23).

      3. Active Listening Network Sockets & Process Integrity:
         Enumerates all TCP listening sockets (Get-NetTCPConnection -State Listen) and UDP endpoints (Get-NetUDPEndpoint),
         associating each endpoint with its owning process, executable image path, command-line invocation,
         and cryptographic Authenticode digital signature status (Get-AuthenticodeSignature) to detect untrusted,
         unsigned, or phantom listening services.

    The script supports dual compatibility across Windows PowerShell 5.1 and modern PowerShell 7+,
    features language-independent UAC self-elevation via Well-Known SID (S-1-5-32-544), outputs strongly typed
    [PSCustomObject] to the PowerShell pipeline, writes structured microsecond-precision logs to C:\Logs\,
    and generates a 100% self-contained, offline HTML report featuring an Apple-inspired responsive layout.

.PARAMETER LogDirectory
    Target directory for structured audit logs and generated reports.
    Default: C:\Logs. If the directory is unavailable or read-only, falls back to $env:TEMP\Logs.

.PARAMETER ReportPath
    Custom target file path for the generated HTML audit report.
    Default: <LogDirectory>\Firewall-Audit-Report-<yyyyMMdd-HHmmss>.html.

.PARAMETER HighRiskPorts
    Array of integer port numbers classified as high-risk administrative or remote access ports.
    Default: @(21, 22, 23, 139, 445, 3389, 5985, 5986).

.PARAMETER NoHtmlReport
    Suppresses generation of the HTML audit report file.

.PARAMETER ShowReportInBrowser
    Automatically launches the generated HTML audit report in the default web browser upon completion.

.PARAMETER Quiet
    Suppresses standard console output messages. Telemetry remains recorded in the log file.

.PARAMETER SkipAdminCheck
    Bypasses automatic UAC administrator privilege verification (useful for CI/CD runners or SYSTEM contexts).

.PARAMETER ExportCsv
    Exports the listening ports inventory and high-risk rules to structured CSV files.

.PARAMETER CsvPath
    Custom file path for CSV export. Defaults to <LogDirectory>\Firewall-Audit-Report-<yyyyMMdd-HHmmss>.csv.

.PARAMETER PassThru
    Emits the primary structured PSCustomObject audit summary to the standard PowerShell pipeline.

.PARAMETER Help
    Displays the interactive CLI command syntax and parameter documentation. Alias: -h.

.EXAMPLE
    .\Audit-LocalFirewallAndListeningPorts.ps1 -Help
    Displays interactive command syntax, parameter reference, and usage examples.

.EXAMPLE
    .\Audit-LocalFirewallAndListeningPorts.ps1
    Runs full security audit with default settings, logs to C:\Logs\, and creates an HTML report.

.EXAMPLE
    .\Audit-LocalFirewallAndListeningPorts.ps1 -ShowReportInBrowser
    Executes audit, logs details, and opens the generated HTML report in the default browser.

.EXAMPLE
    .\Audit-LocalFirewallAndListeningPorts.ps1 -HighRiskPorts @(22, 80, 443, 3389, 8080) -ExportCsv
    Runs audit with custom high-risk port definitions and exports findings to CSV.

.EXAMPLE
    $audit = .\Audit-LocalFirewallAndListeningPorts.ps1 -PassThru
    $audit.HighRiskRules | Format-Table -AutoSize
    Pipes audit findings directly into downstream PowerShell objects for SIEM or automation scripts.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Date:         2026-11-09
    Requires:     Windows 10/11 / Windows Server 2016-2025, PowerShell 5.1+, Elevated Administrator Token
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(Mandatory = $false)]
    [string]$ReportPath,

    [Parameter(Mandatory = $false)]
    [int[]]$HighRiskPorts = @(21, 22, 23, 139, 445, 3389, 5985, 5986),

    [Parameter(Mandatory = $false)]
    [switch]$NoHtmlReport,

    [Parameter(Mandatory = $false)]
    [switch]$ShowReportInBrowser,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [switch]$ExportCsv,

    [Parameter(Mandatory = $false)]
    [string]$CsvPath,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

begin {
    $ErrorActionPreference = 'Stop'

    # Global execution session state
    $script:TimestampTag = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $script:ResolvedLogDirectory = $LogDirectory
    $script:ResolvedLogPath = $null
    $script:ResolvedReportPath = $null
    $script:ResolvedCsvPath = $null

    # --------------------------------------------------------------------------
    # Helper: Interactive CLI Help Display
    # --------------------------------------------------------------------------
    function Show-ScriptHelp {
        [CmdletBinding()]
        param()

        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host " Audit-LocalFirewallAndListeningPorts.ps1 - Windows Attack Surface Audit Suite" -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Version: 1.0.0 | Author: Roman Pindela | Repository: Windows-Desktop`n" -ForegroundColor DarkGray

        Write-Host "DESCRIPTION:" -ForegroundColor Green
        Write-Host "  Performs deep inspection of the local endpoint attack surface:"
        Write-Host "  - Windows Defender Firewall profile configurations (Domain, Private, Public)"
        Write-Host "  - High-risk inbound firewall rules permitting unrestricted access (Any -> HighRiskPort)"
        Write-Host "  - Active TCP/UDP listening endpoints mapped to processes, command lines, and Authenticode signatures"
        Write-Host "  - Standalone, dependency-free responsive HTML report generation & pipeline output`n"

        Write-Host "PARAMETERS:" -ForegroundColor Green
        Write-Host "  -LogDirectory <string>     Directory for log files & reports (Default: C:\Logs)"
        Write-Host "  -ReportPath <string>       Custom destination path for HTML audit report"
        Write-Host "  -HighRiskPorts <int[]>     Custom port list to evaluate (Default: 21, 22, 23, 139, 445, 3389, 5985, 5986)"
        Write-Host "  -NoHtmlReport              Disable HTML report generation"
        Write-Host "  -ShowReportInBrowser       Open generated HTML report automatically in default browser"
        Write-Host "  -Quiet                     Suppress non-essential console text output"
        Write-Host "  -SkipAdminCheck            Bypass UAC administrator elevation requirement"
        Write-Host "  -ExportCsv                 Export audit findings to structured CSV files"
        Write-Host "  -CsvPath <string>          Custom path for CSV export"
        Write-Host "  -PassThru                  Emit PSCustomObject summary to the pipeline"
        Write-Host "  -Help (-h)                 Display this command syntax reference`n"

        Write-Host "EXAMPLES:" -ForegroundColor Green
        Write-Host "  .\Audit-LocalFirewallAndListeningPorts.ps1"
        Write-Host "  .\Audit-LocalFirewallAndListeningPorts.ps1 -ShowReportInBrowser"
        Write-Host "  .\Audit-LocalFirewallAndListeningPorts.ps1 -HighRiskPorts @(22, 3389, 5985, 5986) -ExportCsv"
        Write-Host "  .\Audit-LocalFirewallAndListeningPorts.ps1 -PassThru | Out-GridView`n"
    }

    # --------------------------------------------------------------------------
    # Helper: Elevation Verification & UAC Auto-Relaunch
    # --------------------------------------------------------------------------
    function Test-IsAdministrator {
        [CmdletBinding()]
        param()
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        $adminSid = [Security.Principal.SecurityIdentifier]::new([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
        return $principal.IsInRole($adminSid)
    }

    function Invoke-SelfElevation {
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
            elseif ($val -is [System.Array]) {
                $arrayJoined = ($val -join ',')
                $argList.Add("-$key @($arrayJoined)")
            }
            else {
                $argList.Add("-$key")
                $argList.Add("`"$val`"")
            }
        }

        try {
            [void](Start-Process -FilePath 'powershell.exe' -ArgumentList ($argList -join ' ') -Verb RunAs -PassThru)
            [System.Environment]::Exit(0)
        }
        catch {
            Write-Error "Failed to request administrative elevation: $($_.Exception.Message). Please execute PowerShell as Administrator."
            [System.Environment]::Exit(1)
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Logging Infrastructure (Write-CustomLog)
    # --------------------------------------------------------------------------
    function Initialize-LogInfrastructure {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Directory
        )

        $targetDir = $Directory
        if (-not (Test-Path -LiteralPath $targetDir)) {
            try {
                [void](New-Item -Path $targetDir -ItemType Directory -Force)
            }
            catch {
                $targetDir = Join-Path -Path $env:TEMP -ChildPath 'Logs'
                if (-not (Test-Path -LiteralPath $targetDir)) {
                    [void](New-Item -Path $targetDir -ItemType Directory -Force)
                }
            }
        }

        $script:ResolvedLogDirectory = $targetDir
        $script:ResolvedLogPath = Join-Path -Path $targetDir -ChildPath 'Audit-LocalFirewallAndListeningPorts.log'

        if ([string]::IsNullOrWhiteSpace($script:ResolvedReportPath)) {
            $script:ResolvedReportPath = Join-Path -Path $targetDir -ChildPath "Firewall-Audit-Report-$($script:TimestampTag).html"
        }

        if ([string]::IsNullOrWhiteSpace($script:ResolvedCsvPath)) {
            $script:ResolvedCsvPath = Join-Path -Path $targetDir -ChildPath "Firewall-Audit-Report-$($script:TimestampTag).csv"
        }
    }

    function Write-CustomLog {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'CRITICAL', 'SUCCESS', 'HEADER')]
            [string]$Severity = 'INFO'
        )

        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
        $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId.ToString('D2')
        $fileSeverity = if ($Severity -in @('HEADER', 'SUCCESS')) { 'INFO' } else { $Severity }
        $logLine = "[$timestamp] [$fileSeverity] [$threadId] $Message"

        if (-not $Quiet) {
            switch ($Severity) {
                'HEADER'   { Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
                'SUCCESS'  { Write-Host $logLine -ForegroundColor Green }
                'WARN'     { Write-Host $logLine -ForegroundColor DarkYellow }
                'ERROR'    { Write-Host $logLine -ForegroundColor Red }
                'CRITICAL' { Write-Host $logLine -ForegroundColor Magenta }
                'DEBUG'    { Write-Debug $Message }
                Default    { Write-Host $logLine -ForegroundColor Gray }
            }
        }
        elseif ($VerbosePreference -eq 'Continue') {
            Write-Verbose $logLine
        }

        if ($script:ResolvedLogPath) {
            try {
                [System.IO.File]::AppendAllText($script:ResolvedLogPath, "$logLine`r`n", [System.Text.Encoding]::UTF8)
            }
            catch {}
        }
    }

    # --------------------------------------------------------------------------
    # Helper: Port & Address Analysis Matcher
    # --------------------------------------------------------------------------
    function Test-IsUnrestrictedRemoteAddress {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false)]
            $RemoteAddresses
        )

        if ($null -eq $RemoteAddresses) {
            return $true
        }

        $list = @($RemoteAddresses)
        if ($list.Length -eq 0) {
            return $true
        }

        foreach ($addr in $list) {
            if ($null -eq $addr -or [string]::IsNullOrWhiteSpace([string]$addr)) {
                return $true
            }
            $cleanAddr = ([string]$addr).Trim().ToUpperInvariant()
            if ($cleanAddr -in @('ANY', '*', 'INTERNET', '0.0.0.0/0', '::/0', '0.0.0.0-255.255.255.255')) {
                return $true
            }
        }
        return $false
    }

    function Test-RuleExposesHighRiskPort {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false)]
            $RuleLocalPorts,

            [Parameter(Mandatory = $true)]
            [int[]]$TargetHighRiskPorts
        )

        if ($null -eq $RuleLocalPorts) {
            return @()
        }

        $ports = @($RuleLocalPorts)
        if ($ports.Length -eq 0) {
            return @()
        }

        $matchedPorts = [System.Collections.Generic.List[string]]::new()

        foreach ($portItem in $ports) {
            if ($null -eq $portItem) {
                continue
            }
            $pStr = ([string]$portItem).Trim()
            if ([string]::IsNullOrWhiteSpace($pStr)) {
                continue
            }

            # Single integer port
            $parsedPort = 0
            if ([int]::TryParse($pStr, [ref]$parsedPort)) {
                if ($TargetHighRiskPorts -contains $parsedPort) {
                    $matchedPorts.Add("$parsedPort")
                }
                continue
            }

            # Range: e.g. 5000-6000
            if ($pStr -match '^\s*(\d+)\s*-\s*(\d+)\s*$') {
                $startPort = [int]$Matches[1]
                $endPort = [int]$Matches[2]
                foreach ($hp in $TargetHighRiskPorts) {
                    if ($hp -ge $startPort -and $hp -le $endPort) {
                        $matchedPorts.Add("$hp (range $pStr)")
                    }
                }
                continue
            }
        }

        return $matchedPorts.ToArray()
    }
}

process {
    # Check for Help switch
    if ($Help) {
        Show-ScriptHelp
        return
    }

    # Verify Administrator privileges unless explicitly bypassed
    if (-not $SkipAdminCheck) {
        if (-not (Test-IsAdministrator)) {
            Invoke-SelfElevation -BoundParameters $PSBoundParameters
            return
        }
    }

    # Resolve paths
    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
        $script:ResolvedReportPath = $ReportPath
    }
    if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
        $script:ResolvedCsvPath = $CsvPath
    }
    Initialize-LogInfrastructure -Directory $LogDirectory

    Write-CustomLog "=== Initializing Windows Defender Firewall & Listening Ports Audit ===" -Severity 'HEADER'
    Write-CustomLog "Hostname: $env:COMPUTERNAME | User: $env:USERNAME | OS: $((Get-CimInstance Win32_OperatingSystem -Property Caption).Caption)" -Severity 'INFO'
    Write-CustomLog "Target Log File: $script:ResolvedLogPath" -Severity 'INFO'

    # ==========================================================================
    # Step 1: Firewall Profiles Audit
    # ==========================================================================
    Write-CustomLog "Auditing Windows Defender Firewall Profiles (Domain, Private, Public)..." -Severity 'INFO'
    $profileResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $profilesOk = $true

    try {
        $rawProfiles = Get-NetFirewallProfile -ErrorAction Stop
        foreach ($p in $rawProfiles) {
            $inboundAction = [string]$p.DefaultInboundAction
            $outboundAction = [string]$p.DefaultOutboundAction

            # Evaluate posture
            $status = 'PASS'
            $statusNotes = 'Profile enabled with restrictive default posture.'
            if (-not $p.Enabled) {
                $status = 'FAIL'
                $statusNotes = 'Profile is completely DISABLED!'
                $profilesOk = $false
            }
            elseif ($inboundAction -eq 'Allow') {
                $status = 'WARN'
                $statusNotes = 'Default inbound traffic is set to ALLOW!'
            }

            $profObj = [PSCustomObject]@{
                Name                  = [string]$p.Name
                Enabled               = [bool]$p.Enabled
                DefaultInboundAction  = $inboundAction
                DefaultOutboundAction = $outboundAction
                LogAllowed            = [bool]$p.LogAllowed
                LogBlocked            = [bool]$p.LogBlocked
                LogFileName           = [string]$p.LogFileName
                LogMaxSizeKilobytes   = [int]$p.LogMaxSizeKilobytes
                ComplianceStatus      = $status
                Notes                 = $statusNotes
            }
            $profileResults.Add($profObj)

            $logSev = switch ($status) {
                'FAIL' { 'ERROR' }
                'WARN' { 'WARN' }
                Default { 'SUCCESS' }
            }
            Write-CustomLog "Profile [$($p.Name)] Enabled: $($p.Enabled) | Inbound: $inboundAction | Status: $status ($statusNotes)" -Severity $logSev
        }
    }
    catch {
        Write-CustomLog "Error reading firewall profiles: $($_.Exception.Message)" -Severity 'ERROR'
        $profilesOk = $false
    }

    # ==========================================================================
    # Step 2: High-Risk Inbound Firewall Rules Detection
    # ==========================================================================
    Write-CustomLog "Scanning active Inbound Allow rules for unrestricted access to high-risk ports..." -Severity 'INFO'
    Write-CustomLog "Monitored High-Risk Ports: $($HighRiskPorts -join ', ')" -Severity 'INFO'

    $criticalRules = [System.Collections.Generic.List[PSCustomObject]]::new()
    $allInboundAllowRules = @()

    try {
        $allInboundAllowRules = @(Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow -ErrorAction Stop)
        Write-CustomLog "Total enabled Inbound Allow rules discovered: $($allInboundAllowRules.Length)" -Severity 'INFO'
    }
    catch {
        Write-CustomLog "Error querying firewall rules: $($_.Exception.Message)" -Severity 'ERROR'
    }

    $ruleIndex = 0
    $totalRules = $allInboundAllowRules.Length

    foreach ($rule in $allInboundAllowRules) {
        $ruleIndex++
        if ($totalRules -gt 0 -and ($ruleIndex % 15 -eq 0 -or $ruleIndex -eq $totalRules)) {
            $pct = [math]::Round(($ruleIndex / $totalRules) * 100)
            Write-Progress -Activity "Auditing Local Firewall & Listening Ports" `
                -Status "Analyzing Inbound Rules ($ruleIndex / $totalRules)..." `
                -PercentComplete $pct
        }

        try {
            $portFilter = $null
            try {
                $portFilter = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
            } catch {}

            $localPorts = if ($null -ne $portFilter -and $null -ne $portFilter.LocalPort) { @($portFilter.LocalPort) } else { @() }
            $matchedHighRisk = Test-RuleExposesHighRiskPort -RuleLocalPorts $localPorts -TargetHighRiskPorts $HighRiskPorts

            # Fast evaluation: only query address filter if a high-risk port was exposed
            if ($matchedHighRisk.Length -gt 0) {
                $addrFilter = $null
                try {
                    $addrFilter = $rule | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue
                } catch {}

                $remoteAddrs = if ($null -ne $addrFilter -and $null -ne $addrFilter.RemoteAddress) { @($addrFilter.RemoteAddress) } else { @() }
                $protocol = if ($null -ne $portFilter -and $null -ne $portFilter.Protocol) { [string]$portFilter.Protocol } else { 'TCP' }

                if (Test-IsUnrestrictedRemoteAddress -RemoteAddresses $remoteAddrs) {
                    $violationObj = [PSCustomObject]@{
                        RuleName            = [string]$rule.Name
                        DisplayName         = if ($rule.DisplayName) { [string]$rule.DisplayName } else { [string]$rule.Name }
                        Profile             = [string]$rule.Profile
                        Direction           = [string]$rule.Direction
                        Action              = [string]$rule.Action
                        Protocol            = $protocol
                        LocalPort           = if ($localPorts.Length -gt 0) { ($localPorts -join ', ') } else { 'Any' }
                        RemoteAddress       = if ($remoteAddrs.Length -gt 0) { ($remoteAddrs -join ', ') } else { 'Any' }
                        ExposedPorts        = ($matchedHighRisk -join ', ')
                        Description         = [string]$rule.Description
                        IsCriticalExposure  = $true
                        Severity            = 'CRITICAL'
                    }
                    $criticalRules.Add($violationObj)
                    Write-CustomLog "CRITICAL EXPOSURE: Rule '$($violationObj.DisplayName)' ($($violationObj.RuleName)) exposes port(s) $($violationObj.ExposedPorts) to RemoteAddress '$($violationObj.RemoteAddress)'" -Severity 'CRITICAL'
                }
            }
        }
        catch {
            Write-CustomLog "Warning inspecting rule '$($rule.Name)': $($_.Exception.Message)" -Severity 'DEBUG'
        }
    }
    Write-Progress -Activity "Auditing Local Firewall & Listening Ports" -Completed

    Write-CustomLog "High-risk inbound rule evaluation completed. Baseline violations detected: $($criticalRules.Count)" -Severity $(if ($criticalRules.Count -gt 0) { 'WARN' } else { 'SUCCESS' })

    # ==========================================================================
    # Step 3: Listening Ports & Active Services Inventory
    # ==========================================================================
    Write-CustomLog "Enumerating active TCP listening sockets and UDP endpoints..." -Severity 'INFO'

    # Pre-fetch process metadata and command lines to accelerate mapping
    $processDict = @{}
    $cimProcessDict = @{}

    try {
        $allProcs = Get-Process -ErrorAction SilentlyContinue
        foreach ($pr in $allProcs) {
            $processDict[$pr.Id] = $pr
        }
    }
    catch {}

    try {
        $cimProcs = Get-CimInstance -ClassName Win32_Process -Property ProcessId, Name, ExecutablePath, CommandLine, CreationDate -ErrorAction SilentlyContinue
        foreach ($cp in $cimProcs) {
            $cimProcessDict[[int]$cp.ProcessId] = $cp
        }
    }
    catch {}

    # Gather TCP listen sockets
    $tcpSockets = @()
    try {
        $tcpSockets = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
    }
    catch {
        Write-CustomLog "Error reading TCP connections: $($_.Exception.Message)" -Severity 'WARN'
    }

    # Gather UDP endpoints
    $udpSockets = @()
    try {
        $udpSockets = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue)
    }
    catch {
        Write-CustomLog "Error reading UDP endpoints: $($_.Exception.Message)" -Severity 'WARN'
    }

    Write-CustomLog "Active Sockets Discovered: TCP Listen = $($tcpSockets.Length), UDP Endpoints = $($udpSockets.Length)" -Severity 'INFO'

    # Unified Socket Inventory List
    $rawSockets = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($t in $tcpSockets) {
        $rawSockets.Add([PSCustomObject]@{
            Protocol      = 'TCP'
            LocalAddress  = [string]$t.LocalAddress
            LocalPort     = [int]$t.LocalPort
            OwningProcess = [int]$t.OwningProcess
        })
    }
    foreach ($u in $udpSockets) {
        $rawSockets.Add([PSCustomObject]@{
            Protocol      = 'UDP'
            LocalAddress  = [string]$u.LocalAddress
            LocalPort     = [int]$u.LocalPort
            OwningProcess = [int]$u.OwningProcess
        })
    }

    # Authenticode Signature Cache to prevent redundant disk I/O
    $signatureCache = @{}
    $listeningInventory = [System.Collections.Generic.List[PSCustomObject]]::new()
    $socketIndex = 0
    $totalSockets = $rawSockets.Count

    foreach ($sock in $rawSockets) {
        $socketIndex++
        if ($totalSockets -gt 0 -and ($socketIndex % 10 -eq 0 -or $socketIndex -eq $totalSockets)) {
            $pct = [math]::Round(($socketIndex / $totalSockets) * 100)
            Write-Progress -Activity "Auditing Local Firewall & Listening Ports" `
                -Status "Resolving sockets and Authenticode signatures ($socketIndex / $totalSockets)..." `
                -PercentComplete $pct
        }

        $pidVal = $sock.OwningProcess
        $procName = 'Unknown'
        $exePath = ''
        $cmdLine = ''
        $isPhantom = $false

        # Resolve Process Information
        if ($pidVal -eq 0) {
            $procName = 'System Idle Process'
            $exePath = 'N/A'
            $authStatus = 'System Idle'
            $isSigned = $true
            $signerSubject = 'Microsoft Windows'
            $signerIssuer = 'N/A'
        }
        elseif ($pidVal -eq 4) {
            $procName = 'System'
            $systemKernelPath = Join-Path -Path $env:windir -ChildPath 'System32\ntoskrnl.exe'
            $exePath = $systemKernelPath
            $authStatus = 'System Kernel'
            $isSigned = $true
            $signerSubject = 'CN=Microsoft Windows, O=Microsoft Corporation'
            $signerIssuer = 'CN=Microsoft Windows Production PCA 2011'
        }
        else {
            # Check CIM dictionary first
            if ($cimProcessDict.ContainsKey($pidVal)) {
                $cp = $cimProcessDict[$pidVal]
                $procName = [string]$cp.Name
                $exePath = [string]$cp.ExecutablePath
                $cmdLine = [string]$cp.CommandLine
            }
            elseif ($processDict.ContainsKey($pidVal)) {
                $pr = $processDict[$pidVal]
                $procName = $pr.ProcessName
                try {
                    $exePath = $pr.Path
                }
                catch {
                    $exePath = 'Access Denied / Protected Process'
                }
            }
            else {
                # Ghost / phantom process - port listening but process vanished
                $procName = '[Ghost / Terminated Process]'
                $isPhantom = $true
            }

            # Authenticode Signature Evaluation
            $authStatus = 'Unknown'
            $isSigned = $false
            $signerSubject = 'N/A'
            $signerIssuer = 'N/A'

            if ($isPhantom) {
                $authStatus = 'Process Terminated / Phantom PID'
            }
            elseif ([string]::IsNullOrWhiteSpace($exePath) -or $exePath -eq 'Access Denied / Protected Process') {
                $authStatus = 'Protected System Process'
            }
            elseif ($signatureCache.ContainsKey($exePath)) {
                $cachedSig = $signatureCache[$exePath]
                $authStatus = $cachedSig.Status
                $isSigned = $cachedSig.IsSigned
                $signerSubject = $cachedSig.Subject
                $signerIssuer = $cachedSig.Issuer
            }
            elseif (Test-Path -LiteralPath $exePath) {
                try {
                    $sig = Get-AuthenticodeSignature -FilePath $exePath -ErrorAction SilentlyContinue
                    $authStatus = [string]$sig.Status
                    $isSigned = ($sig.Status -eq 'Valid')

                    if ($sig.SignerCertificate) {
                        $signerSubject = [string]$sig.SignerCertificate.Subject
                        $signerIssuer = [string]$sig.SignerCertificate.Issuer
                    }
                    else {
                        $signerSubject = 'Unsigned Binary'
                    }

                    $signatureCache[$exePath] = [PSCustomObject]@{
                        Status   = $authStatus
                        IsSigned = $isSigned
                        Subject  = $signerSubject
                        Issuer   = $signerIssuer
                    }
                }
                catch {
                    $authStatus = "Signature Check Failed: $($_.Exception.Message)"
                }
            }
            else {
                $authStatus = 'File Not Found on Disk'
            }
        }

        # Format Clean Signer CN if available
        $cleanSigner = $signerSubject
        if ($signerSubject -match 'CN=([^,]+)') {
            $cleanSigner = $Matches[1]
        }

        $endpointObj = [PSCustomObject]@{
            Protocol            = $sock.Protocol
            LocalAddress        = $sock.LocalAddress
            LocalPort           = $sock.LocalPort
            OwningProcess       = $pidVal
            ProcessName         = $procName
            ExecutablePath      = $exePath
            CommandLine         = $cmdLine
            AuthenticodeStatus  = $authStatus
            IsSigned            = $isSigned
            SignerSubject       = $cleanSigner
            RawSignerSubject    = $signerSubject
            SignerIssuer        = $signerIssuer
            IsPhantom           = $isPhantom
        }
        $listeningInventory.Add($endpointObj)
    }
    Write-Progress -Activity "Auditing Local Firewall & Listening Ports" -Completed

    $signedCount = @($listeningInventory | Where-Object { $_.IsSigned -eq $true }).Count
    $unsignedCount = @($listeningInventory | Where-Object { $_.IsSigned -ne $true -and $_.OwningProcess -notin @(0, 4) }).Count
    Write-CustomLog "Listening endpoint resolution completed. Total: $($listeningInventory.Count) (Signed: $signedCount, Unsigned/Anomalous: $unsignedCount)" -Severity 'INFO'

    # ==========================================================================
    # Step 4: Standalone Responsive HTML Report Generation
    # ==========================================================================
    if (-not $NoHtmlReport) {
        Write-CustomLog "Generating standalone responsive HTML report at: $script:ResolvedReportPath" -Severity 'INFO'

        $reportDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $osCaption = (Get-CimInstance Win32_OperatingSystem -Property Caption).Caption
        $overallStatus = if ($criticalRules.Count -eq 0 -and $profilesOk) { 'PASS' } else { 'FAIL' }
        $overallBadgeClass = if ($overallStatus -eq 'PASS') { 'badge-pass' } else { 'badge-fail' }

        # Firewall Profiles Table Rows
        $profileRowsHtml = [System.Text.StringBuilder]::new()
        foreach ($p in $profileResults) {
            $badgeClass = switch ($p.ComplianceStatus) {
                'PASS' { 'pill pill-enabled' }
                'WARN' { 'pill pill-warn' }
                Default { 'pill pill-disabled' }
            }
            $enabledPill = if ($p.Enabled) { '<span class="pill pill-enabled">Enabled</span>' } else { '<span class="pill pill-disabled">Disabled</span>' }
            [void]$profileRowsHtml.AppendLine(@"
            <tr>
                <td><strong>$([System.Net.WebUtility]::HtmlEncode($p.Name))</strong></td>
                <td>$enabledPill</td>
                <td><code>$([System.Net.WebUtility]::HtmlEncode($p.DefaultInboundAction))</code></td>
                <td><code>$([System.Net.WebUtility]::HtmlEncode($p.DefaultOutboundAction))</code></td>
                <td><small>Drop: $(if($p.LogBlocked){'Yes'}else{'No'}) / Allow: $(if($p.LogAllowed){'Yes'}else{'No'})</small></td>
                <td><small class="text-muted">$([System.Net.WebUtility]::HtmlEncode($p.LogFileName))</small></td>
                <td><span class="$badgeClass">$($p.ComplianceStatus)</span></td>
            </tr>
"@)
        }

        # Critical Rules Table Rows
        $criticalRulesHtml = [System.Text.StringBuilder]::new()
        if ($criticalRules.Count -eq 0) {
            [void]$criticalRulesHtml.AppendLine(@"
            <tr>
                <td colspan="7" class="text-center text-muted" style="padding: 24px;">
                    <em>No high-risk unrestricted inbound rules detected. Local firewall baseline conforms to security policy.</em>
                </td>
            </tr>
"@)
        }
        else {
            foreach ($cr in $criticalRules) {
                [void]$criticalRulesHtml.AppendLine(@"
            <tr class="row-critical">
                <td><strong>$([System.Net.WebUtility]::HtmlEncode($cr.DisplayName))</strong><br><small class="text-muted">$([System.Net.WebUtility]::HtmlEncode($cr.RuleName))</small></td>
                <td><span class="type-pill">$([System.Net.WebUtility]::HtmlEncode($cr.Profile))</span></td>
                <td><code>$($cr.Protocol)</code></td>
                <td><span class="badge badge-port-alert">$([System.Net.WebUtility]::HtmlEncode($cr.LocalPort))</span></td>
                <td><code class="code-danger">$([System.Net.WebUtility]::HtmlEncode($cr.RemoteAddress))</code></td>
                <td><span class="badge badge-critical">ALLOW (Any Source)</span></td>
                <td><span class="badge badge-critical">CRITICAL</span></td>
            </tr>
"@)
            }
        }

        # Listening Endpoints Table Rows
        $endpointsHtml = [System.Text.StringBuilder]::new()
        foreach ($ep in $listeningInventory) {
            $protoPill = if ($ep.Protocol -eq 'TCP') { 'pill-tcp' } else { 'pill-udp' }
            $sigBadge = if ($ep.IsSigned) {
                '<span class="pill pill-enabled">Valid</span>'
            } elseif ($ep.OwningProcess -in @(0, 4)) {
                '<span class="pill pill-neutral">System</span>'
            } else {
                "<span class=`"badge badge-warn`">$([System.Net.WebUtility]::HtmlEncode($ep.AuthenticodeStatus))</span>"
            }

            $rowClass = if (-not $ep.IsSigned -and $ep.OwningProcess -notin @(0, 4)) { 'row-warning' } else { '' }

            [void]$endpointsHtml.AppendLine(@"
            <tr class="$rowClass" data-proto="$($ep.Protocol)" data-signed="$($ep.IsSigned)" data-pid="$($ep.OwningProcess)">
                <td><span class="pill $protoPill">$($ep.Protocol)</span></td>
                <td><strong>$([System.Net.WebUtility]::HtmlEncode($ep.LocalAddress)):$($ep.LocalPort)</strong></td>
                <td><code>$($ep.OwningProcess)</code></td>
                <td><strong>$([System.Net.WebUtility]::HtmlEncode($ep.ProcessName))</strong></td>
                <td><small class="text-muted" title="$([System.Net.WebUtility]::HtmlEncode($ep.ExecutablePath))">$([System.Net.WebUtility]::HtmlEncode($ep.ExecutablePath))</small></td>
                <td>$sigBadge</td>
                <td><small>$([System.Net.WebUtility]::HtmlEncode($ep.SignerSubject))</small></td>
            </tr>
"@)
        }

        $htmlDocument = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Firewall & Listening Ports Security Audit - $env:COMPUTERNAME</title>
    <style>
        :root {
            --bg-body: #0d1117;
            --bg-card: #161b22;
            --bg-card-hover: #1f242c;
            --border-color: #30363d;
            --text-main: #c9d1d9;
            --text-heading: #f0f6fc;
            --text-muted: #8b949e;
            --accent-blue: #58a6ff;
            --accent-green: #3fb950;
            --accent-orange: #d29922;
            --accent-red: #f85149;
            --badge-critical-bg: rgba(248, 81, 73, 0.15);
            --badge-warn-bg: rgba(210, 153, 34, 0.15);
            --badge-pass-bg: rgba(63, 185, 80, 0.15);
        }

        [data-theme="light"] {
            --bg-body: #f6f8fa;
            --bg-card: #ffffff;
            --bg-card-hover: #f3f4f6;
            --border-color: #d0d7de;
            --text-main: #24292f;
            --text-heading: #1f2328;
            --text-muted: #57606a;
            --accent-blue: #0969da;
            --accent-green: #1a7f37;
            --accent-orange: #9a6700;
            --accent-red: #cf222e;
            --badge-critical-bg: rgba(207, 34, 46, 0.12);
            --badge-warn-bg: rgba(154, 103, 0, 0.12);
            --badge-pass-bg: rgba(26, 127, 55, 0.12);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            background-color: var(--bg-body);
            color: var(--text-main);
            line-height: 1.5;
            padding: 24px;
            transition: background-color 0.2s ease, color 0.2s ease;
        }

        .container { max-width: 1440px; margin: 0 auto; }

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
        }

        .header-title p {
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 4px;
        }

        .header-controls {
            display: flex;
            gap: 12px;
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
            font-size: 28px;
            font-weight: 700;
            color: var(--text-heading);
            line-height: 1.2;
        }

        .card-subtext {
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 6px;
        }

        .section-panel {
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
        }

        .section-title {
            font-size: 18px;
            font-weight: 600;
            color: var(--text-heading);
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .search-box {
            display: flex;
            gap: 12px;
            margin-bottom: 16px;
            flex-wrap: wrap;
        }

        .search-input {
            flex: 1;
            min-width: 260px;
            background: var(--bg-body);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 8px 14px;
            color: var(--text-main);
            font-size: 13px;
        }
        .search-input:focus {
            outline: none;
            border-color: var(--accent-blue);
        }

        .filter-btn {
            background: var(--bg-body);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 8px 12px;
            color: var(--text-main);
            font-size: 12px;
            cursor: pointer;
            transition: all 0.2s;
        }
        .filter-btn.active, .filter-btn:hover {
            background: var(--accent-blue);
            color: #ffffff;
            border-color: var(--accent-blue);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            text-align: left;
        }

        th {
            background-color: var(--bg-body);
            color: var(--text-muted);
            font-weight: 600;
            padding: 10px 14px;
            border-bottom: 2px solid var(--border-color);
            text-transform: uppercase;
            font-size: 11px;
            letter-spacing: 0.5px;
        }

        td {
            padding: 12px 14px;
            border-bottom: 1px solid var(--border-color);
            vertical-align: middle;
        }

        tr:hover td {
            background-color: var(--bg-card-hover);
        }

        .row-critical td {
            background-color: var(--badge-critical-bg) !important;
        }

        .row-warning td {
            background-color: var(--badge-warn-bg) !important;
        }

        .pill {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
        }

        .pill-enabled { background: var(--badge-pass-bg); color: var(--accent-green); }
        .pill-disabled { background: var(--badge-critical-bg); color: var(--accent-red); }
        .pill-warn { background: var(--badge-warn-bg); color: var(--accent-orange); }
        .pill-neutral { background: var(--border-color); color: var(--text-muted); }
        .pill-tcp { background: rgba(88, 166, 255, 0.15); color: var(--accent-blue); }
        .pill-udp { background: rgba(210, 153, 34, 0.15); color: var(--accent-orange); }

        .badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
        }

        .badge-pass { background: var(--badge-pass-bg); color: var(--accent-green); border: 1px solid var(--accent-green); }
        .badge-fail { background: var(--badge-critical-bg); color: var(--accent-red); border: 1px solid var(--accent-red); }
        .badge-critical { background: var(--badge-critical-bg); color: var(--accent-red); }
        .badge-warn { background: var(--badge-warn-bg); color: var(--accent-orange); }
        .badge-port-alert { background: rgba(248, 81, 73, 0.2); color: var(--accent-red); border: 1px solid var(--accent-red); font-family: monospace; }

        .code-danger {
            color: var(--accent-red);
            font-weight: bold;
            font-family: monospace;
        }

        .type-pill {
            background: var(--bg-body);
            border: 1px solid var(--border-color);
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 11px;
        }

        .text-center { text-align: center; }
        .text-muted { color: var(--text-muted); }
        code { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace; font-size: 12px; }

        @media (max-width: 900px) {
            header { flex-direction: column; align-items: flex-start; gap: 12px; }
            .header-controls { width: 100%; justify-content: space-between; }
            .table-responsive { overflow-x: auto; }
        }

        @media print {
            body { background: #fff !important; color: #000 !important; }
            .theme-toggle-btn, .search-box { display: none !important; }
            .card, .section-panel { border: 1px solid #ccc !important; box-shadow: none !important; }
        }
    </style>
</head>
<body data-theme="dark">
<div class="container">
    <header>
        <div class="header-title">
            <h1>Firewall & Listening Ports Security Audit</h1>
            <p>Host: <strong>$env:COMPUTERNAME</strong> | User: <strong>$env:USERNAME</strong> | OS: <strong>$osCaption</strong> | Timestamp: <strong>$reportDate</strong></p>
        </div>
        <div class="header-controls">
            <span class="badge $overallBadgeClass">BASELINE: $overallStatus</span>
            <button class="theme-toggle-btn" onclick="toggleTheme()">🌓 Toggle Light / Dark</button>
        </div>
    </header>

    <!-- Executive Metrics Grid -->
    <div class="metrics-grid">
        <div class="card">
            <div class="card-label">Firewall Profiles</div>
            <div class="card-value" style="color: $(if($profilesOk){'var(--accent-green)'}else{'var(--accent-red)'});">
                $(if($profilesOk){'3 / 3 Active'}else{'Degraded'})
            </div>
            <div class="card-subtext">Domain, Private, Public Profiles</div>
        </div>

        <div class="card">
            <div class="card-label">High-Risk Exposure Rules</div>
            <div class="card-value" style="color: $(if($criticalRules.Count -eq 0){'var(--accent-green)'}else{'var(--accent-red)'});">
                $($criticalRules.Count)
            </div>
            <div class="card-subtext">Unrestricted Any -> HighRiskPort Inbound Rules</div>
        </div>

        <div class="card">
            <div class="card-label">Listening Endpoints</div>
            <div class="card-value">
                $($listeningInventory.Count)
            </div>
            <div class="card-subtext">TCP: $($tcpSockets.Length) | UDP: $($udpSockets.Length)</div>
        </div>

        <div class="card">
            <div class="card-label">Authenticode Integrity</div>
            <div class="card-value" style="color: $(if($unsignedCount -eq 0){'var(--accent-green)'}else{'var(--accent-orange)'});">
                $signedCount / $($listeningInventory.Count)
            </div>
            <div class="card-subtext">$unsignedCount unsigned or anomalous binaries</div>
        </div>
    </div>

    <!-- Section 1: Firewall Profiles Status -->
    <div class="section-panel">
        <div class="section-title">
            <span>1. Windows Defender Firewall Profiles</span>
        </div>
        <div class="table-responsive">
            <table>
                <thead>
                    <tr>
                        <th>Profile</th>
                        <th>State</th>
                        <th>Default Inbound</th>
                        <th>Default Outbound</th>
                        <th>Event Logging</th>
                        <th>Log Path</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    $($profileRowsHtml.ToString())
                </tbody>
            </table>
        </div>
    </div>

    <!-- Section 2: High-Risk Inbound Rules -->
    <div class="section-panel">
        <div class="section-title">
            <span>2. High-Risk Inbound Rules (Baseline Violations)</span>
            <span class="badge $(if($criticalRules.Count -eq 0){'badge-pass'}else{'badge-critical'})">$($criticalRules.Count) Violations</span>
        </div>
        <p class="text-muted" style="margin-bottom: 14px; font-size: 12px;">
            Rules permitting unrestricted inbound access (<code>RemoteAddress: Any / * / 0.0.0.0/0</code>) to administrative or lateral movement ports (RDP 3389, WinRM 5985/5986, SMB 445/139, SSH 22, FTP 21, Telnet 23).
        </p>
        <div class="table-responsive">
            <table>
                <thead>
                    <tr>
                        <th>Rule Name / Display Name</th>
                        <th>Profile</th>
                        <th>Protocol</th>
                        <th>Local Port(s)</th>
                        <th>Remote Source</th>
                        <th>Firewall Action</th>
                        <th>Exposure Level</th>
                    </tr>
                </thead>
                <tbody>
                    $($criticalRulesHtml.ToString())
                </tbody>
            </table>
        </div>
    </div>

    <!-- Section 3: Listening Sockets & Services Inventory -->
    <div class="section-panel">
        <div class="section-title">
            <span>3. Active Listening Sockets & Process Inventory</span>
            <span class="badge badge-warn" id="filteredCountBadge">$($listeningInventory.Count) Endpoints</span>
        </div>

        <div class="search-box">
            <input type="text" id="endpointSearch" class="search-input" placeholder="Filter by port, address, process name, PID, or signer..." onkeyup="filterSockets()">
            <button class="filter-btn active" onclick="setSocketFilter('all', this)">All</button>
            <button class="filter-btn" onclick="setSocketFilter('unsigned', this)">Unsigned Only</button>
            <button class="filter-btn" onclick="setSocketFilter('tcp', this)">TCP Only</button>
            <button class="filter-btn" onclick="setSocketFilter('udp', this)">UDP Only</button>
        </div>

        <div class="table-responsive">
            <table id="socketsTable">
                <thead>
                    <tr>
                        <th>Proto</th>
                        <th>Local Address:Port</th>
                        <th>PID</th>
                        <th>Process Name</th>
                        <th>Executable Path</th>
                        <th>Signature</th>
                        <th>Signer Subject</th>
                    </tr>
                </thead>
                <tbody>
                    $($endpointsHtml.ToString())
                </tbody>
            </table>
        </div>
    </div>
</div>

<script>
    function toggleTheme() {
        const body = document.body;
        const currentTheme = body.getAttribute('data-theme');
        body.setAttribute('data-theme', currentTheme === 'dark' ? 'light' : 'dark');
    }

    let activeFilterMode = 'all';

    function setSocketFilter(mode, btn) {
        activeFilterMode = mode;
        document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        filterSockets();
    }

    function filterSockets() {
        const query = document.getElementById('endpointSearch').value.toLowerCase();
        const rows = document.querySelectorAll('#socketsTable tbody tr');
        let visibleCount = 0;

        rows.forEach(row => {
            const proto = (row.getAttribute('data-proto') || '').toLowerCase();
            const signed = row.getAttribute('data-signed') === 'True';
            const text = row.innerText.toLowerCase();

            let matchesQuery = text.includes(query);
            let matchesFilter = true;

            if (activeFilterMode === 'unsigned') {
                matchesFilter = !signed;
            } else if (activeFilterMode === 'tcp') {
                matchesFilter = (proto === 'tcp');
            } else if (activeFilterMode === 'udp') {
                matchesFilter = (proto === 'udp');
            }

            if (matchesQuery && matchesFilter) {
                row.style.display = '';
                visibleCount++;
            } else {
                row.style.display = 'none';
            }
        });

        document.getElementById('filteredCountBadge').innerText = visibleCount + ' Endpoints';
    }
</script>
</body>
</html>
"@

        try {
            [System.IO.File]::WriteAllText($script:ResolvedReportPath, $htmlDocument, [System.Text.Encoding]::UTF8)
            Write-CustomLog "Report successfully generated: $script:ResolvedReportPath" -Severity 'SUCCESS'

            if ($ShowReportInBrowser) {
                Write-CustomLog "Launching report in browser: $script:ResolvedReportPath" -Severity 'INFO'
                [void](Start-Process -FilePath $script:ResolvedReportPath)
            }
        }
        catch {
            Write-CustomLog "Failed to write HTML report: $($_.Exception.Message)" -Severity 'ERROR'
        }
    }

    # ==========================================================================
    # Step 5: CSV Export (Optional)
    # ==========================================================================
    if ($ExportCsv) {
        try {
            Write-CustomLog "Exporting listening endpoints inventory to CSV: $script:ResolvedCsvPath" -Severity 'INFO'
            $listeningInventory | Export-Csv -Path $script:ResolvedCsvPath -NoTypeInformation -Encoding UTF8
            Write-CustomLog "CSV export successfully written." -Severity 'SUCCESS'
        }
        catch {
            Write-CustomLog "Failed to export CSV: $($_.Exception.Message)" -Severity 'ERROR'
        }
    }

    # ==========================================================================
    # Step 6: Structured Pipeline Object
    # ==========================================================================
    $summaryResult = [PSCustomObject]@{
        ComputerName       = $env:COMPUTERNAME
        AuditTimestamp     = (Get-Date)
        FirewallProfiles   = $profileResults.ToArray()
        HighRiskRulesCount = $criticalRules.Count
        HighRiskRules      = $criticalRules.ToArray()
        ListeningEndpoints = $listeningInventory.ToArray()
        SummaryStatus      = if ($criticalRules.Count -eq 0 -and $profilesOk) { 'PASS' } else { 'FAIL' }
    }

    Write-CustomLog "=== Audit Completed. Overall Baseline Posture: $($summaryResult.SummaryStatus) ===" -Severity $(if ($summaryResult.SummaryStatus -eq 'PASS') { 'SUCCESS' } else { 'WARN' })

    # Emit to pipeline
    $summaryResult
}

end {
}
