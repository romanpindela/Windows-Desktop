<#
.SYNOPSIS
    Audits members of the local Administrators security group (S-1-5-32-544), detects orphaned SIDs,
    classifies local/domain/Entra ID accounts, identifies security anomalies, logs to C:\Logs,
    and optionally generates a self-contained, responsive HTML audit report.

.DESCRIPTION
    Audit-LocalAdministrators.ps1 is an enterprise-grade security auditing and compliance tool designed
    for Windows 10, Windows 11, and Windows Server systems. It resolves the built-in Administrators group
    using its language-independent Well-Known SID (S-1-5-32-544), avoiding failures on non-English locales
    (such as Polish 'Administratorzy', German 'Administratoren', etc.).

    The script performs deep inspection of all group members, resolving:
      1. Built-in Local Administrator accounts (RID 500, S-1-5-21-*-500) and LAPS governance status.
      2. Local Standard User accounts elevated to the Administrators group (RID >= 1000).
      3. Active Directory Domain Users and Domain Groups (e.g., Domain Admins, Enterprise Admins).
      4. Microsoft Entra ID (Azure AD) cloud roles and users (S-1-12-1-* SIDs, AzureAD\* identities).
      5. Orphaned and Unresolved SIDs left behind by deleted local or domain accounts.

    Security Anomaly Detection Engine flags:
      - Lingering orphaned SIDs (deleted accounts still retaining administrator rights).
      - Enabled built-in Administrator (RID 500) without verified Windows LAPS / Legacy LAPS management.
      - Excessive local administrator proliferation (privilege sprawl).
      - Stale administrator credentials (> 90/180 days without password rotation).
      - Inactive or dormant administrator accounts (> 90 days without logon).
      - Accounts configured with passwords that never expire.

    Outputs structured PSCustomObject objects to the pipeline, records microsecond-precision logs
    to C:\Logs, supports CSV export, and produces a standalone, dependency-free HTML report
    featuring Apple-inspired responsive dark/light mode styling and interactive client-side filtering.

.PARAMETER Audit
    Executes the security audit workflow. Alias: -Scan, -Enumerate.

.PARAMETER GenerateHtmlReport
    Generates a standalone, dependency-free HTML security audit report with inline CSS and interactive UI.

.PARAMETER ReportPath
    Custom target file path or directory for the HTML report.
    Default: C:\Logs\<yyyyMMdd-HHmmss>-Audit-LocalAdministrators-<COMPUTERNAME>.html.

.PARAMETER ExportCsv
    Exports raw pipeline audit objects to a structured CSV file.

.PARAMETER CsvPath
    Custom target file path for CSV export.
    Default: C:\Logs\<yyyyMMdd-HHmmss>-Audit-LocalAdministrators-<COMPUTERNAME>.csv.

.PARAMETER LogDirectory
    Target directory for execution logs, reports, and CSV exports. Default: C:\Logs.

.PARAMETER IncludeDisabled
    Includes disabled administrator accounts in the audit report and console output. Default: $true.

.PARAMETER SkipAdminCheck
    Bypasses automatic UAC elevation check (useful for automated deployment runners or SYSTEM context).

.PARAMETER PassThru
    Explicitly emits structured PSCustomObject audit records to the PowerShell pipeline.

.PARAMETER Help
    Displays the interactive console help guide and parameter documentation. Alias: -h.

.EXAMPLE
    .\Audit-LocalAdministrators.ps1 -Help
    Displays syntax, description, parameters, and usage examples.

.EXAMPLE
    .\Audit-LocalAdministrators.ps1 -Audit
    Performs standard audit, logs execution to C:\Logs, and displays formatted table in console.

.EXAMPLE
    .\Audit-LocalAdministrators.ps1 -GenerateHtmlReport
    Runs full audit and generates a self-contained responsive HTML report in C:\Logs.

.EXAMPLE
    .\Audit-LocalAdministrators.ps1 -Audit -GenerateHtmlReport -ExportCsv
    Runs comprehensive audit, writes microsecond logs, saves CSV, and generates HTML report.

.EXAMPLE
    .\Audit-LocalAdministrators.ps1 -Audit -PassThru | Where-Object { $_.RiskLevel -in @('High', 'Critical') }
    Pipes audit records for high-risk accounts to downstream PowerShell filtering.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Date:         2026-11-08
    Requires:     Windows 10/11 / Windows Server, PowerShell 5.1+, Elevated Administrator Token
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false)]
    [Alias('Scan', 'Enumerate')]
    [switch]$Audit,

    [Parameter(Mandatory = $false)]
    [switch]$GenerateHtmlReport,

    [Parameter(Mandatory = $false)]
    [string]$ReportPath,

    [Parameter(Mandatory = $false)]
    [switch]$ExportCsv,

    [Parameter(Mandatory = $false)]
    [string]$CsvPath,

    [Parameter(Mandatory = $false)]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(Mandatory = $false)]
    [bool]$IncludeDisabled = $true,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

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

    # Global & Script-Scoped Variables
    $script:LogFilePath = $null
    $script:SessionTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:AdministratorsGroupSid = 'S-1-5-32-544'

    # --------------------------------------------------------------------------
    # Helper Functions
    # --------------------------------------------------------------------------

    function Show-ScriptHelp {
        [CmdletBinding()]
        param()

        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host " Audit-LocalAdministrators.ps1 - Local Administrators Security Audit Suite" -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Version: 1.0.0 | Author: Roman Pindela | Repository: Windows-Desktop`n" -ForegroundColor DarkGray

        Write-Host "DESCRIPTION:" -ForegroundColor Green
        Write-Host "  Audits members of the local Administrators security group (S-1-5-32-544) on Windows 10/11"
        Write-Host "  endpoints. Language-independent SID resolution, Entra ID (Azure AD) classification,"
        Write-Host "  orphaned SID detection, security risk rating, microsecond logging to C:\Logs\, and"
        Write-Host "  standalone Apple-inspired HTML report generation with zero external dependencies.`n"

        Write-Host "PARAMETERS & SWITCHES:" -ForegroundColor Green
        Write-Host "  -Audit (-Scan, -Enumerate)  Executes standard audit and outputs summary to console."
        Write-Host "  -GenerateHtmlReport         Generates a standalone responsive HTML audit report."
        Write-Host "  -ReportPath <string>        Custom file path or directory for HTML report."
        Write-Host "  -ExportCsv                  Exports audit results to CSV in LogDirectory."
        Write-Host "  -CsvPath <string>           Custom file path for CSV export."
        Write-Host "  -LogDirectory <string>      Target directory for logs and default reports (Default: C:\Logs)."
        Write-Host "  -IncludeDisabled <bool>     Include disabled administrator accounts (Default: `$true)."
        Write-Host "  -SkipAdminCheck             Bypasses automatic UAC elevation check."
        Write-Host "  -PassThru                   Emits structured PSCustomObject items to the PowerShell pipeline."
        Write-Host "  -WhatIf / -Confirm          Standard PowerShell impact preview and confirmation switches."
        Write-Host "  -Help (-h)                  Displays this visual CLI guide.`n"

        Write-Host "EXAMPLES:" -ForegroundColor Green
        Write-Host "  .\Audit-LocalAdministrators.ps1 -Audit"
        Write-Host "  .\Audit-LocalAdministrators.ps1 -GenerateHtmlReport"
        Write-Host "  .\Audit-LocalAdministrators.ps1 -Audit -GenerateHtmlReport -ExportCsv"
        Write-Host "  .\Audit-LocalAdministrators.ps1 -Audit -PassThru | Out-GridView`n"
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
            elseif ($val -is [array]) {
                $argList.Add("-$key")
                $itemsJoined = ($val | ForEach-Object { "`"$_`"" }) -join ','
                $argList.Add($itemsJoined)
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
            Write-Error "Failed to elevate process: $($_.Exception.Message). Please execute PowerShell as Administrator."
            [System.Environment]::Exit(1)
        }
    }

    function Initialize-LogDirectory {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$DirectoryPath
        )

        $targetDir = $DirectoryPath
        if (-not (Test-Path -Path $targetDir)) {
            try {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }
            catch {
                $fallback = Join-Path -Path $env:TEMP -ChildPath 'Logs'
                if (-not (Test-Path -Path $fallback)) {
                    New-Item -Path $fallback -ItemType Directory -Force | Out-Null
                }
                $targetDir = $fallback
            }
        }

        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $logFileName = "$($script:SessionTimestamp)-Audit-LocalAdministrators-$computerName-$userName.log"
        $script:LogFilePath = Join-Path -Path $targetDir -ChildPath $logFileName
        return $targetDir
    }

    function Write-ScriptLog {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'VERBOSE', 'DEBUG', 'HEADER')]
            [string]$Level = 'INFO'
        )

        $now = Get-Date
        $timestamp = $now.ToString('yyyy-MM-dd HH:mm:ss.fff')
        $fileLogLevel = if ($Level -eq 'HEADER') { 'INFO' } elseif ($Level -eq 'SUCCESS') { 'INFO' } else { $Level }
        $logLine = "[$timestamp] [$fileLogLevel] $Message"

        switch ($Level) {
            'HEADER'  { Write-Host "`n$Message" -ForegroundColor Yellow }
            'SUCCESS' { Write-Host $logLine -ForegroundColor Green }
            'WARN'    { Write-Host $logLine -ForegroundColor DarkYellow }
            'ERROR'   { Write-Host $logLine -ForegroundColor Red }
            'DEBUG'   { Write-Debug $Message }
            'VERBOSE' { Write-Verbose $Message }
            Default   { Write-Host $logLine -ForegroundColor Cyan }
        }

        if ($script:LogFilePath) {
            try {
                [System.IO.File]::AppendAllText($script:LogFilePath, "$logLine`r`n", [System.Text.Encoding]::UTF8)
            }
            catch {}
        }
    }

    function Get-LocalMachineDomainSid {
        [CmdletBinding()]
        param()

        try {
            $adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::AccountAdministratorSid, $null)
            $adminSidValue = $adminSid.Value
            if ($adminSidValue -match '^(S-1-5-21-\d+-\d+-\d+)-500$') {
                return $Matches[1]
            }
        }
        catch {}

        try {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
            $user = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount = True" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($user -and $user.SID -match '^(S-1-5-21-\d+-\d+-\d+)-\d+$') {
                return $Matches[1]
            }
        }
        catch {}

        return $null
    }

    function Test-IsLapsConfigured {
        [CmdletBinding()]
        param()

        $modernLapsPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\LAPS',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LAPS',
            'HKLM:\SOFTWARE\Microsoft\Policies\LAPS'
        )
        foreach ($path in $modernLapsPaths) {
            if (Test-Path -Path $path) {
                $val = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
                if ($val -and ($val.BackupDirectory -or $val.PasswordComplexity -or $val.PasswordLength)) {
                    return [PSCustomObject]@{ IsConfigured = $true; Flavor = 'Windows LAPS (Modern Policy)'; Path = $path }
                }
            }
        }

        $legacyLapsPath = 'HKLM:\SOFTWARE\Policies\Microsoft Services\AdmPwd'
        if (Test-Path -Path $legacyLapsPath) {
            $val = Get-ItemProperty -Path $legacyLapsPath -ErrorAction SilentlyContinue
            if ($val -and $val.AdmPwdEnabled -eq 1) {
                return [PSCustomObject]@{ IsConfigured = $true; Flavor = 'Legacy Microsoft LAPS (AdmPwd)'; Path = $legacyLapsPath }
            }
        }

        $legacyDll = Join-Path -Path $env:ProgramFiles -ChildPath 'LAPS\CSE\AdmPwd.dll'
        if (Test-Path -Path $legacyDll) {
            return [PSCustomObject]@{ IsConfigured = $true; Flavor = 'Legacy Microsoft LAPS (Binary Present)'; Path = $legacyDll }
        }

        return [PSCustomObject]@{ IsConfigured = $false; Flavor = 'None'; Path = $null }
    }

    function Resolve-GroupMembersLanguageIndependent {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$GroupSid
        )

        $resolvedGroup = $null
        $localizedGroupName = $null

        try {
            $resolvedGroup = Get-LocalGroup -SID $GroupSid -ErrorAction Stop
            $localizedGroupName = $resolvedGroup.Name
            Write-ScriptLog "Resolved group SID $GroupSid to localized name '$localizedGroupName'." -Level 'DEBUG'
        }
        catch {
            Write-ScriptLog "Could not resolve group via Get-LocalGroup: $($_.Exception.Message). Falling back to NTAccount translation." -Level 'WARN'
            try {
                $sidObj = New-Object Security.Principal.SecurityIdentifier($GroupSid)
                $ntAccount = $sidObj.Translate([Security.Principal.NTAccount]).Value
                if ($ntAccount -match '\\') {
                    $localizedGroupName = $ntAccount.Split('\')[-1]
                }
                else {
                    $localizedGroupName = $ntAccount
                }
            }
            catch {
                $localizedGroupName = 'Administrators'
            }
        }

        $collected = [System.Collections.Generic.List[PSCustomObject]]::new()
        $processedSids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        # 1. Primary: Try Get-LocalGroupMember
        try {
            $members = Get-LocalGroupMember -Group $localizedGroupName -ErrorAction Stop
            foreach ($m in $members) {
                $sidVal = $m.SID.Value
                $obj = [PSCustomObject]@{
                    RawName         = $m.Name
                    SID             = $sidVal
                    PrincipalSource = [string]$m.PrincipalSource
                    ObjectClass     = [string]$m.ObjectClass
                    DiscoveryMethod = 'Get-LocalGroupMember'
                }
                $collected.Add($obj)
                [void]$processedSids.Add($sidVal)
            }
            Write-ScriptLog "Enumerated $($collected.Count) member(s) via Get-LocalGroupMember." -Level 'INFO'
        }
        catch {
            Write-ScriptLog "Get-LocalGroupMember failed or encountered orphaned entries: $($_.Exception.Message). Falling back to ADSI enumeration." -Level 'WARN'
        }

        # 2. Secondary & Fallback: ADSI WinNT provider (resilient to orphaned/deleted SIDs)
        try {
            $adsiGroup = [ADSI]"WinNT://./$localizedGroupName,group"
            $adsiMembers = @($adsiGroup.Invoke('Members'))
            foreach ($m in $adsiMembers) {
                $sidBytes = $m.GetType().InvokeMember('objectSID', [System.Reflection.BindingFlags]::GetProperty, $null, $m, $null)
                $sidStr = $null
                if ($sidBytes) {
                    try {
                        $sidObj = New-Object Security.Principal.SecurityIdentifier($sidBytes, 0)
                        $sidStr = $sidObj.Value
                    }
                    catch {}
                }

                $rawAdsPath = [string]$m.GetType().InvokeMember('AdsPath', [System.Reflection.BindingFlags]::GetProperty, $null, $m, $null)
                $rawMemberName = [string]$m.GetType().InvokeMember('Name', [System.Reflection.BindingFlags]::GetProperty, $null, $m, $null)
                $rawMemberClass = [string]$m.GetType().InvokeMember('Class', [System.Reflection.BindingFlags]::GetProperty, $null, $m, $null)

                if (-not $sidStr) {
                    if ($rawAdsPath -match '(S-1-\d+(?:-\d+)+)') {
                        $sidStr = $Matches[1]
                    }
                    elseif ($rawMemberName -match '^(S-1-\d+(?:-\d+)+)$') {
                        $sidStr = $rawMemberName
                    }
                }

                if ($sidStr -and (-not $processedSids.Contains($sidStr))) {
                    $obj = [PSCustomObject]@{
                        RawName         = if ($rawMemberName) { $rawMemberName } else { $rawAdsPath }
                        SID             = $sidStr
                        PrincipalSource = 'ADSI'
                        ObjectClass     = if ($rawMemberClass) { $rawMemberClass } else { 'Unknown' }
                        DiscoveryMethod = 'ADSI'
                    }
                    $collected.Add($obj)
                    [void]$processedSids.Add($sidStr)
                    Write-ScriptLog "Discovered additional/orphaned member '$($obj.RawName)' ($sidStr) via ADSI." -Level 'DEBUG'
                }
            }
        }
        catch {
            Write-ScriptLog "ADSI WinNT group member inspection warning: $($_.Exception.Message)" -Level 'DEBUG'
        }

        return [PSCustomObject]@{
            GroupName = $localizedGroupName
            GroupSid  = $GroupSid
            Members   = $collected.ToArray()
        }
    }

    function Get-MemberAccountDetails {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$RawMember,

            [Parameter(Mandatory = $false)]
            [string]$MachineDomainSid
        )

        $sid = $RawMember.SID
        $rawName = $RawMember.RawName
        $principalSource = $RawMember.PrincipalSource
        $objectClass = $RawMember.ObjectClass

        $accountName = $rawName
        $domainOrSource = 'Local'
        $accountType = 'Local User'
        $enabled = $null
        $passwordLastSet = $null
        $lastLogon = $null
        $passwordExpires = $null
        $passwordNeverExpires = $false
        $description = ''
        $isOrphaned = $false

        $isWellKnownBuiltInAdmin = ($sid -match '^S-1-5-21-\d+-\d+-\d+-500$')
        $isEntraId = ($sid -match '^S-1-12-1-\d+-\d+-\d+-\d+$') -or ($rawName -like 'AzureAD\*') -or ($rawName -like '*\Azure AD*')

        if ($rawName -match '^S-1-\d+' -or [string]::IsNullOrWhiteSpace($rawName)) {
            try {
                $sidObj = New-Object Security.Principal.SecurityIdentifier($sid)
                $accountName = $sidObj.Translate([Security.Principal.NTAccount]).Value
            }
            catch [System.Security.Principal.IdentityNotMappedException] {
                $accountName = "$sid"
                $isOrphaned = $true
            }
            catch {
                $accountName = "$sid"
            }
        }

        if ($isOrphaned) {
            $accountType = 'Orphaned / Unresolved SID'
            $domainOrSource = 'Unresolved'
        }
        elseif ($isEntraId) {
            $accountType = 'Entra ID (Azure AD)'
            $domainOrSource = 'Microsoft Entra ID'
            if ($sid -match '^S-1-12-1-') {
                if ($accountName -like '*Global Administrator*' -or $rawName -like '*Global Administrator*') {
                    $accountType = 'Entra ID Global Administrator'
                }
                elseif ($accountName -like '*Administrator*' -or $rawName -like '*Administrator*') {
                    $accountType = 'Entra ID Device Local Administrator'
                }
                else {
                    $accountType = 'Entra ID Cloud Role/User'
                }
            }
        }
        elseif ($isWellKnownBuiltInAdmin) {
            $accountType = 'Built-in Local Administrator'
            $domainOrSource = 'Local Machine'
        }
        elseif ($MachineDomainSid -and $sid.StartsWith("$MachineDomainSid-")) {
            $accountType = if ($objectClass -eq 'Group') { 'Local Group' } else { 'Local User (Elevated)' }
            $domainOrSource = 'Local Machine'
        }
        elseif ($principalSource -eq 'ActiveDirectory' -or ($sid -match '^S-1-5-21-' -and (-not ($MachineDomainSid -and $sid.StartsWith($MachineDomainSid))))) {
            $accountType = if ($objectClass -eq 'Group') { 'Domain Group' } else { 'Domain User' }
            $domainOrSource = if ($accountName -match '^([^\\]+)\\') { $Matches[1] } else { 'Active Directory' }
        }
        else {
            if ($sid -eq 'S-1-5-18') {
                $accountType = 'Local System'
                $domainOrSource = 'NT AUTHORITY'
            }
            elseif ($sid -eq 'S-1-5-19') {
                $accountType = 'Local Service'
                $domainOrSource = 'NT AUTHORITY'
            }
            elseif ($sid -eq 'S-1-5-20') {
                $accountType = 'Network Service'
                $domainOrSource = 'NT AUTHORITY'
            }
            else {
                $accountType = if ($principalSource) { "$principalSource $objectClass" } else { "Local $objectClass" }
                $domainOrSource = if ($accountName -match '^([^\\]+)\\') { $Matches[1] } else { 'Local' }
            }
        }

        if ($domainOrSource -eq 'Local Machine' -or ($accountType -in @('Built-in Local Administrator', 'Local User (Elevated)'))) {
            try {
                $localUserObj = Get-LocalUser -SID $sid -ErrorAction SilentlyContinue
                if ($localUserObj) {
                    $accountName = "$($env:COMPUTERNAME)\$($localUserObj.Name)"
                    $enabled = [bool]$localUserObj.Enabled
                    $passwordLastSet = $localUserObj.PasswordLastSet
                    $lastLogon = $localUserObj.LastLogon
                    $passwordExpires = $localUserObj.PasswordExpires
                    $passwordNeverExpires = ($localUserObj.PasswordExpires -eq $null -and $localUserObj.PasswordRequired)
                    $description = [string]$localUserObj.Description
                }
            }
            catch {}

            if ($null -eq $enabled) {
                try {
                    $cimUser = Get-CimInstance -ClassName Win32_UserAccount -Filter "SID = '$sid'" -ErrorAction SilentlyContinue
                    if ($cimUser) {
                        $accountName = "$($cimUser.Domain)\$($cimUser.Name)"
                        $enabled = -not [bool]$cimUser.Disabled
                        $passwordNeverExpires = [bool]$cimUser.PasswordNeverExpires
                        $description = [string]$cimUser.Description
                    }
                }
                catch {}
            }
        }

        $passwordAgeDays = $null
        if ($passwordLastSet) {
            $passwordAgeDays = [int][Math]::Floor(((Get-Date) - $passwordLastSet).TotalDays)
        }

        $lastLogonDays = $null
        if ($lastLogon) {
            $lastLogonDays = [int][Math]::Floor(((Get-Date) - $lastLogon).TotalDays)
        }

        return [PSCustomObject]@{
            AccountName           = $accountName
            DomainOrSource        = $domainOrSource
            SID                   = $sid
            AccountType           = $accountType
            ObjectClass           = $objectClass
            Enabled               = $enabled
            PasswordLastSet       = $passwordLastSet
            PasswordAgeDays       = $passwordAgeDays
            LastLogon             = $lastLogon
            LastLogonDays         = $lastLogonDays
            PasswordExpires       = $passwordExpires
            PasswordNeverExpires  = $passwordNeverExpires
            Description           = $description
            IsOrphaned            = $isOrphaned
        }
    }

    function Detect-SecurityAnomalies {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$AccountDetails,

            [Parameter(Mandatory = $false)]
            [PSCustomObject]$LapsStatus,

            [Parameter(Mandatory = $false)]
            [int]$TotalActiveLocalAdmins = 1
        )

        $anomalies = [System.Collections.Generic.List[string]]::new()
        $riskScore = 0

        # 1. Orphaned / Lingering SID
        if ($AccountDetails.IsOrphaned -or $AccountDetails.AccountType -eq 'Orphaned / Unresolved SID') {
            $anomalies.Add('Lingering Orphaned SID: Account was deleted but still holds administrative privileges')
            if ($riskScore -lt 3) { $riskScore = 3 }
        }

        # 2. Built-in RID 500 Administrator Anomaly Checks
        if ($AccountDetails.AccountType -eq 'Built-in Local Administrator') {
            if ($AccountDetails.Enabled -eq $true) {
                if ($LapsStatus -and -not $LapsStatus.IsConfigured) {
                    $anomalies.Add('RID 500 Administrator is ENABLED without Windows LAPS management')
                    if ($riskScore -lt 3) { $riskScore = 3 }
                }
                else {
                    $anomalies.Add('Active built-in Administrator account (RID 500)')
                    if ($riskScore -lt 2) { $riskScore = 2 }
                }
            }
            else {
                $anomalies.Add('Hardened: Built-in Administrator (RID 500) is disabled')
            }
        }

        # 3. Local Standard User Elevated to Administrator
        if ($AccountDetails.AccountType -eq 'Local User (Elevated)') {
            if ($AccountDetails.Enabled -eq $true) {
                $anomalies.Add('Elevated local user account: local credential sprawl')
                if ($riskScore -lt 1) { $riskScore = 1 }
            }
        }

        # 4. Domain Groups in Workstation Local Admins
        if ($AccountDetails.AccountType -eq 'Domain Group') {
            $anomalies.Add('Domain Group in local Administrators (verify tiering & PAW architecture)')
            if ($riskScore -lt 2) { $riskScore = 2 }
        }

        # 5. Password Age & Expiration Policies
        if ($AccountDetails.PasswordAgeDays -ne $null -and $AccountDetails.PasswordAgeDays -gt 180) {
            $anomalies.Add("Password not rotated in over 180 days ($($AccountDetails.PasswordAgeDays) days old)")
            if ($riskScore -lt 2) { $riskScore = 2 }
        }
        elseif ($AccountDetails.PasswordAgeDays -ne $null -and $AccountDetails.PasswordAgeDays -gt 90) {
            $anomalies.Add("Password not rotated in over 90 days ($($AccountDetails.PasswordAgeDays) days old)")
            if ($riskScore -lt 1) { $riskScore = 1 }
        }

        if ($AccountDetails.PasswordNeverExpires -eq $true) {
            $anomalies.Add('Password is set to Never Expire')
            if ($riskScore -lt 1) { $riskScore = 1 }
        }

        # 6. Dormant / Stale Active Account
        if ($AccountDetails.Enabled -eq $true -and $AccountDetails.LastLogonDays -ne $null -and $AccountDetails.LastLogonDays -gt 90) {
            $anomalies.Add("Dormant account: no logon recorded in past $($AccountDetails.LastLogonDays) days")
            if ($riskScore -lt 2) { $riskScore = 2 }
        }

        # 7. Multiple Active Local Admins Sprawl
        if ($TotalActiveLocalAdmins -gt 2 -and $AccountDetails.Enabled -eq $true -and $AccountDetails.DomainOrSource -eq 'Local Machine') {
            $anomalies.Add("Local administrator privilege sprawl ($TotalActiveLocalAdmins active local admins detected)")
            if ($riskScore -lt 1) { $riskScore = 1 }
        }

        $riskLevel = switch ($riskScore) {
            3 { 'Critical' }
            2 { 'High' }
            1 { 'Medium' }
            Default { 'Low' }
        }

        return [PSCustomObject]@{
            RiskLevel      = $riskLevel
            RiskScore      = $riskScore
            AnomaliesList  = $anomalies.ToArray()
            AnomaliesText  = ($anomalies -join '; ')
        }
    }

    function New-StandaloneHtmlReport {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [array]$AuditRecords,

            [Parameter(Mandatory = $true)]
            [string]$OutputPath,

            [Parameter(Mandatory = $true)]
            [string]$GroupName,

            [Parameter(Mandatory = $true)]
            [string]$GroupSid,

            [Parameter(Mandatory = $false)]
            [PSCustomObject]$LapsStatus
        )

        $computerName = $env:COMPUTERNAME
        $generatedTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

        $totalAccounts = @($AuditRecords).Count
        $localCount = @($AuditRecords | Where-Object { $_.DomainOrSource -eq 'Local Machine' }).Count
        $domainCount = @($AuditRecords | Where-Object { $_.DomainOrSource -notin @('Local Machine', 'Microsoft Entra ID', 'Unresolved') }).Count
        $entraCount = @($AuditRecords | Where-Object { $_.DomainOrSource -eq 'Microsoft Entra ID' }).Count
        $orphanedCount = @($AuditRecords | Where-Object { $_.AccountType -eq 'Orphaned / Unresolved SID' }).Count
        $criticalCount = @($AuditRecords | Where-Object { $_.RiskLevel -eq 'Critical' }).Count
        $highCount = @($AuditRecords | Where-Object { $_.RiskLevel -eq 'High' }).Count
        $mediumCount = @($AuditRecords | Where-Object { $_.RiskLevel -eq 'Medium' }).Count
        $lowCount = @($AuditRecords | Where-Object { $_.RiskLevel -eq 'Low' }).Count

        $overallPosture = if ($criticalCount -gt 0) {
            'Critical Risk'
        } elseif ($highCount -gt 0) {
            'High Risk'
        } elseif ($mediumCount -gt 0) {
            'Medium Risk'
        } else {
            'Compliant & Secure'
        }

        $postureBadgeClass = if ($criticalCount -gt 0) { 'badge-critical' }
            elseif ($highCount -gt 0) { 'badge-high' }
            elseif ($mediumCount -gt 0) { 'badge-medium' }
            else { 'badge-low' }

        $rowsHtml = [System.Text.StringBuilder]::new()
        foreach ($r in $AuditRecords) {
            $enabledBadge = if ($r.Enabled -eq $true) {
                '<span class="pill pill-enabled">Enabled</span>'
            } elseif ($r.Enabled -eq $false) {
                '<span class="pill pill-disabled">Disabled</span>'
            } else {
                '<span class="pill pill-neutral">N/A</span>'
            }

            $riskBadge = switch ($r.RiskLevel) {
                'Critical' { '<span class="badge badge-critical">Critical</span>' }
                'High'     { '<span class="badge badge-high">High</span>' }
                'Medium'   { '<span class="badge badge-medium">Medium</span>' }
                Default    { '<span class="badge badge-low">Low</span>' }
            }

            $pwDateStr = if ($r.PasswordLastSet) { ([datetime]$r.PasswordLastSet).ToString('yyyy-MM-dd') } else { 'Never / Unknown' }
            $pwAgeStr = if ($r.PasswordAgeDays -ne $null) { "$($r.PasswordAgeDays) d" } else { '-' }
            $logonDateStr = if ($r.LastLogon) { ([datetime]$r.LastLogon).ToString('yyyy-MM-dd') } else { 'Never / Unknown' }

            $anomaliesFormatted = ''
            if (-not [string]::IsNullOrWhiteSpace($r.Anomalies)) {
                $parts = $r.Anomalies.Split(';')
                $items = ($parts | ForEach-Object { "<li class='anomaly-item'>$([System.Net.WebUtility]::HtmlEncode($_.Trim()))</li>" }) -join ''
                $anomaliesFormatted = "<ul class='anomaly-list'>$items</ul>"
            }
            else {
                $anomaliesFormatted = "<span class='text-muted'>None detected</span>"
            }

            [void]$rowsHtml.AppendLine(@"
        <tr data-risk="$($r.RiskLevel)" data-type="$($r.AccountType)" data-enabled="$($r.Enabled)">
            <td class="col-name"><strong>$([System.Net.WebUtility]::HtmlEncode($r.AccountName))</strong></td>
            <td><span class="type-pill">$([System.Net.WebUtility]::HtmlEncode($r.AccountType))</span></td>
            <td><code class="sid-code">$($r.SID)</code></td>
            <td class="text-center">$enabledBadge</td>
            <td class="text-center">$riskBadge</td>
            <td class="text-center"><small>$pwDateStr ($pwAgeStr)</small></td>
            <td class="text-center"><small>$logonDateStr</small></td>
            <td>$anomaliesFormatted</td>
        </tr>
"@)
        }

        $lapsInfo = if ($LapsStatus -and $LapsStatus.IsConfigured) {
            "<span class='pill pill-enabled'>$($LapsStatus.Flavor) Active</span>"
        } else {
            "<span class='pill pill-critical'>Not Configured / Unmanaged</span>"
        }

        $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audit Report: Local Administrators ($computerName)</title>
    <style>
        :root {
            --bg-body: #0d1117;
            --bg-card: #161b22;
            --bg-card-hover: #1c2128;
            --border-color: #30363d;
            --text-main: #c9d1d9;
            --text-muted: #8b949e;
            --text-heading: #f0f6fc;
            --accent-blue: #58a6ff;
            --accent-green: #3fb950;
            --accent-yellow: #d29922;
            --accent-orange: #f0883e;
            --accent-red: #f85149;
            --badge-critical: rgba(248, 81, 73, 0.2);
            --badge-high: rgba(240, 136, 62, 0.2);
            --badge-medium: rgba(210, 153, 34, 0.2);
            --badge-low: rgba(63, 185, 80, 0.2);
        }

        [data-theme="light"] {
            --bg-body: #f6f8fa;
            --bg-card: #ffffff;
            --bg-card-hover: #f3f4f6;
            --border-color: #d0d7de;
            --text-main: #24292f;
            --text-muted: #57606a;
            --text-heading: #1f2328;
            --accent-blue: #0969da;
            --accent-green: #1a7f37;
            --accent-yellow: #9a6700;
            --accent-orange: #bc4c00;
            --accent-red: #cf222e;
            --badge-critical: rgba(207, 34, 46, 0.15);
            --badge-high: rgba(188, 76, 0, 0.15);
            --badge-medium: rgba(154, 103, 0, 0.15);
            --badge-low: rgba(26, 127, 55, 0.15);
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

        .container { max-width: 1400px; margin: 0 auto; }

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
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
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
            min-width: 260px;
            position: relative;
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

        .filter-buttons {
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
        }

        .filter-btn {
            background: var(--bg-body);
            border: 1px solid var(--border-color);
            color: var(--text-muted);
            padding: 7px 14px;
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
            box-shadow: 0 4px 12px rgba(0,0,0,0.05);
            margin-bottom: 24px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            text-align: left;
        }

        thead {
            background: var(--bg-card-hover);
            border-bottom: 1px solid var(--border-color);
        }

        th {
            padding: 12px 16px;
            font-weight: 600;
            color: var(--text-heading);
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
        tr:hover td { background-color: var(--bg-card-hover); }

        .badge {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .badge-critical { background: var(--badge-critical); color: var(--accent-red); border: 1px solid var(--accent-red); }
        .badge-high { background: var(--badge-high); color: var(--accent-orange); border: 1px solid var(--accent-orange); }
        .badge-medium { background: var(--badge-medium); color: var(--accent-yellow); border: 1px solid var(--accent-yellow); }
        .badge-low { background: var(--badge-low); color: var(--accent-green); border: 1px solid var(--accent-green); }

        .pill {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
        }
        .pill-enabled { background: var(--badge-low); color: var(--accent-green); }
        .pill-disabled { background: var(--badge-critical); color: var(--accent-red); }
        .pill-critical { background: var(--badge-critical); color: var(--accent-red); }
        .pill-neutral { background: var(--bg-card-hover); color: var(--text-muted); }

        .type-pill {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 6px;
            font-size: 11px;
            background: rgba(88, 166, 255, 0.15);
            color: var(--accent-blue);
            font-weight: 500;
        }

        .sid-code {
            font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
            font-size: 11px;
            color: var(--text-muted);
            background: var(--bg-body);
            padding: 2px 6px;
            border-radius: 4px;
            border: 1px solid var(--border-color);
        }

        .anomaly-list {
            list-style: none;
            padding: 0;
            margin: 0;
        }

        .anomaly-item {
            font-size: 12px;
            color: var(--accent-orange);
            margin-bottom: 2px;
            position: relative;
            padding-left: 14px;
        }
        .anomaly-item::before {
            content: "•";
            position: absolute;
            left: 0;
            color: var(--accent-red);
            font-weight: bold;
        }

        .text-center { text-align: center; }
        .text-muted { color: var(--text-muted); }

        footer {
            margin-top: 24px;
            padding-top: 16px;
            border-top: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            font-size: 12px;
            color: var(--text-muted);
            flex-wrap: wrap;
            gap: 8px;
        }

        @media print {
            body { background: white; color: black; padding: 0; }
            .theme-toggle-btn, .controls-panel { display: none; }
            .card { border: 1px solid #ccc; box-shadow: none; }
            .table-wrapper { border: 1px solid #ccc; box-shadow: none; }
            th, td { border-bottom: 1px solid #eee; }
        }
    </style>
</head>
<body data-theme="dark">
    <div class="container">
        <header>
            <div class="header-title">
                <h1>Local Administrators Security Audit</h1>
                <p>Host: <strong>$computerName</strong> | Group: <strong>$GroupName</strong> ($GroupSid) | Generated: $generatedTime</p>
            </div>
            <div>
                <button class="theme-toggle-btn" id="themeBtn" onclick="toggleTheme()">☀️ Toggle Light Mode</button>
            </div>
        </header>

        <section class="metrics-grid">
            <div class="card">
                <div class="card-label">Security Posture</div>
                <div class="card-value"><span class="badge $postureBadgeClass">$overallPosture</span></div>
                <div class="card-subtext">Critical Issues: $criticalCount</div>
            </div>
            <div class="card">
                <div class="card-label">Total Administrators</div>
                <div class="card-value">$totalAccounts</div>
                <div class="card-subtext">Active elevated identities</div>
            </div>
            <div class="card">
                <div class="card-label">Local Accounts</div>
                <div class="card-value">$localCount</div>
                <div class="card-subtext">Local endpoint principals</div>
            </div>
            <div class="card">
                <div class="card-label">Domain / AD Accounts</div>
                <div class="card-value">$domainCount</div>
                <div class="card-subtext">Tiered Domain Users/Groups</div>
            </div>
            <div class="card">
                <div class="card-label">Entra ID (Azure AD)</div>
                <div class="card-value">$entraCount</div>
                <div class="card-subtext">Cloud roles & users</div>
            </div>
            <div class="card">
                <div class="card-label">Orphaned SIDs</div>
                <div class="card-value" style="color: $(if ($orphanedCount -gt 0) { 'var(--accent-red)' } else { 'inherit' });">$orphanedCount</div>
                <div class="card-subtext">Lingering deleted accounts</div>
            </div>
            <div class="card">
                <div class="card-label">Windows LAPS</div>
                <div class="card-value" style="font-size: 16px; margin-top: 6px;">$lapsInfo</div>
                <div class="card-subtext">Local Administrator Governance</div>
            </div>
        </section>

        <section class="controls-panel">
            <div class="search-box">
                <input type="text" id="searchInput" class="search-input" placeholder="Search account name, SID, type, risk, or anomaly..." onkeyup="filterTable()">
            </div>
            <div class="filter-buttons">
                <button class="filter-btn active" onclick="setFilter('all', this)">All ($totalAccounts)</button>
                <button class="filter-btn" onclick="setFilter('Critical', this)">Critical ($criticalCount)</button>
                <button class="filter-btn" onclick="setFilter('High', this)">High ($highCount)</button>
                <button class="filter-btn" onclick="setFilter('Medium', this)">Medium ($mediumCount)</button>
                <button class="filter-btn" onclick="setFilter('Low', this)">Low ($lowCount)</button>
            </div>
        </section>

        <section class="table-wrapper">
            <table id="auditTable">
                <thead>
                    <tr>
                        <th onclick="sortTable(0)">Account Name ↕</th>
                        <th onclick="sortTable(1)">Type ↕</th>
                        <th onclick="sortTable(2)">Security Identifier (SID) ↕</th>
                        <th onclick="sortTable(3)" class="text-center">Status ↕</th>
                        <th onclick="sortTable(4)" class="text-center">Risk ↕</th>
                        <th onclick="sortTable(5)" class="text-center">Password Age ↕</th>
                        <th onclick="sortTable(6)" class="text-center">Last Logon ↕</th>
                        <th>Detected Security Anomalies</th>
                    </tr>
                </thead>
                <tbody>
$($rowsHtml.ToString())
                </tbody>
            </table>
        </section>

        <footer>
            <div>Audit Suite: <strong>Audit-LocalAdministrators.ps1 v1.0.0</strong> | Author: Roman Pindela (roman.pindela@gmail.com)</div>
            <div>Generated with zero external dependencies | Output: $OutputPath</div>
        </footer>
    </div>

    <script>
        function toggleTheme() {
            const body = document.body;
            const btn = document.getElementById('themeBtn');
            const currentTheme = body.getAttribute('data-theme');
            if (currentTheme === 'dark') {
                body.setAttribute('data-theme', 'light');
                btn.textContent = '🌙 Toggle Dark Mode';
            } else {
                body.setAttribute('data-theme', 'dark');
                btn.textContent = '☀️ Toggle Light Mode';
            }
        }

        let currentRiskFilter = 'all';

        function setFilter(risk, btn) {
            currentRiskFilter = risk;
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            filterTable();
        }

        function filterTable() {
            const query = document.getElementById('searchInput').value.toLowerCase();
            const rows = document.querySelectorAll('#auditTable tbody tr');
            rows.forEach(row => {
                const text = row.innerText.toLowerCase();
                const risk = row.getAttribute('data-risk');
                const matchesSearch = text.includes(query);
                const matchesRisk = (currentRiskFilter === 'all') || (risk === currentRiskFilter);
                row.style.display = (matchesSearch && matchesRisk) ? '' : 'none';
            });
        }

        function sortTable(columnIndex) {
            const table = document.getElementById('auditTable');
            const tbody = table.querySelector('tbody');
            const rows = Array.from(tbody.querySelectorAll('tr'));
            const isAsc = table.getAttribute('data-sort-col') == columnIndex && table.getAttribute('data-sort-asc') === 'true';

            rows.sort((a, b) => {
                const aText = a.children[columnIndex].innerText.trim();
                const bText = b.children[columnIndex].innerText.trim();
                return isAsc ? bText.localeCompare(aText, undefined, {numeric: true}) : aText.localeCompare(bText, undefined, {numeric: true});
            });

            table.setAttribute('data-sort-col', columnIndex);
            table.setAttribute('data-sort-asc', (!isAsc).toString());

            rows.forEach(r => tbody.appendChild(r));
        }
    </script>
</body>
</html>
"@

        [System.IO.File]::WriteAllText($OutputPath, $htmlContent, [System.Text.Encoding]::UTF8)
    }

    # --------------------------------------------------------------------------
    # Startup Validations
    # --------------------------------------------------------------------------

    if ($Help -or ($PSBoundParameters.Count -eq 0)) {
        Show-ScriptHelp
        Exit 0
    }

    if (-not $SkipAdminCheck) {
        if (-not (Test-IsElevated)) {
            Invoke-ElevationRelaunch -BoundParameters $PSBoundParameters
        }
    }

    $script:ResolvedLogDirectory = Initialize-LogDirectory -DirectoryPath $LogDirectory
    Write-ScriptLog "================================================================================" -Level 'HEADER'
    Write-ScriptLog "Audit-LocalAdministrators v1.0.0 - Session Started ($($script:SessionTimestamp))" -Level 'HEADER'
    Write-ScriptLog "================================================================================" -Level 'HEADER'
    Write-ScriptLog "Host: $env:COMPUTERNAME | User: $env:USERNAME | OS: $((Get-CimInstance Win32_OperatingSystem).Caption)" -Level 'INFO'
    Write-ScriptLog "Log file initialized at: $script:LogFilePath" -Level 'INFO'
}

# ==============================================================================
# Script Lifecycle: Process Block
# ==============================================================================

process {
    $computerName = $env:COMPUTERNAME

    Write-ScriptLog "Querying local machine security identifiers and LAPS governance status..." -Level 'INFO'
    $localMachineSid = Get-LocalMachineDomainSid
    if ($localMachineSid) {
        Write-ScriptLog "Local machine domain SID identified: $localMachineSid" -Level 'DEBUG'
    }

    $lapsStatus = Test-IsLapsConfigured
    if ($lapsStatus.IsConfigured) {
        Write-ScriptLog "LAPS Governance: $($lapsStatus.Flavor) detected at $($lapsStatus.Path)." -Level 'INFO'
    }
    else {
        Write-ScriptLog "LAPS Governance: No active LAPS policy or provider detected." -Level 'WARN'
    }

    if ($PSCmdlet.ShouldProcess("Local Administrators Group (SID $script:AdministratorsGroupSid)", "Audit members and security anomalies")) {
        Write-ScriptLog "Resolving members of group SID $script:AdministratorsGroupSid via language-independent method..." -Level 'INFO'
        $groupInfo = Resolve-GroupMembersLanguageIndependent -GroupSid $script:AdministratorsGroupSid
        $rawMembers = @($groupInfo.Members)
        $groupName = $groupInfo.GroupName

        Write-ScriptLog "Successfully identified $(@($rawMembers).Count) raw member(s) in local group '$groupName'." -Level 'SUCCESS'

        # Pass 1: Parse and categorize all accounts
        $detailedAccounts = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($rm in $rawMembers) {
            $details = Get-MemberAccountDetails -RawMember $rm -MachineDomainSid $localMachineSid
            $detailedAccounts.Add($details)
        }

        # Calculate active local admin count for privilege sprawl detection
        $totalActiveLocal = @($detailedAccounts | Where-Object { $_.DomainOrSource -eq 'Local Machine' -and $_.Enabled -eq $true }).Count

        # Pass 2: Anomaly detection and pipeline record construction
        $auditRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
        $now = Get-Date

        foreach ($acc in $detailedAccounts) {
            if (-not $IncludeDisabled -and $acc.Enabled -eq $false) {
                Write-ScriptLog "Skipping disabled account '$($acc.AccountName)' due to -IncludeDisabled:`$false." -Level 'DEBUG'
                continue
            }

            $anomalyResult = Detect-SecurityAnomalies -AccountDetails $acc -LapsStatus $lapsStatus -TotalActiveLocalAdmins $totalActiveLocal

            $record = [PSCustomObject]@{
                ComputerName         = $computerName
                AccountName          = $acc.AccountName
                DomainOrSource       = $acc.DomainOrSource
                SID                  = $acc.SID
                AccountType          = $acc.AccountType
                ObjectClass          = $acc.ObjectClass
                Enabled              = $acc.Enabled
                PasswordLastSet      = $acc.PasswordLastSet
                PasswordAgeDays      = $acc.PasswordAgeDays
                LastLogon            = $acc.LastLogon
                LastLogonDays        = $acc.LastLogonDays
                PasswordExpires      = $acc.PasswordExpires
                PasswordNeverExpires = $acc.PasswordNeverExpires
                RiskLevel            = $anomalyResult.RiskLevel
                RiskScore            = $anomalyResult.RiskScore
                Anomalies            = $anomalyResult.AnomaliesText
                AuditTimestamp       = $now
            }

            $auditRecords.Add($record)

            $logLevel = switch ($anomalyResult.RiskLevel) {
                'Critical' { 'ERROR' }
                'High'     { 'WARN' }
                'Medium'   { 'INFO' }
                Default    { 'SUCCESS' }
            }

            $anomalySummary = if ($anomalyResult.AnomaliesText) { " [Anomalies: $($anomalyResult.AnomaliesText)]" } else { '' }
            Write-ScriptLog "Member: $($acc.AccountName) | Type: $($acc.AccountType) | Risk: $($anomalyResult.RiskLevel)$anomalySummary" -Level $logLevel
        }

        # Console Summary Presentation
        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host " LOCAL ADMINISTRATORS AUDIT SUMMARY - $computerName" -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Cyan
        $auditRecords | Format-Table -Property AccountName, AccountType, Enabled, RiskLevel, Anomalies -AutoSize | Out-Host

        # Standalone HTML Report Generation
        if ($GenerateHtmlReport -or $ReportPath) {
            $htmlTarget = $ReportPath
            if ([string]::IsNullOrWhiteSpace($htmlTarget)) {
                $htmlTarget = Join-Path -Path $script:ResolvedLogDirectory -ChildPath "$($script:SessionTimestamp)-Audit-LocalAdministrators-$computerName.html"
            }
            elseif (Test-Path -Path $htmlTarget -PathType Container) {
                $htmlTarget = Join-Path -Path $htmlTarget -ChildPath "$($script:SessionTimestamp)-Audit-LocalAdministrators-$computerName.html"
            }

            Write-ScriptLog "Generating standalone responsive HTML report at '$htmlTarget'..." -Level 'INFO'
            New-StandaloneHtmlReport -AuditRecords $auditRecords.ToArray() -OutputPath $htmlTarget -GroupName $groupName -GroupSid $script:AdministratorsGroupSid -LapsStatus $lapsStatus
            Write-ScriptLog "HTML report successfully generated: $htmlTarget" -Level 'SUCCESS'
        }

        # CSV Export
        if ($ExportCsv -or $CsvPath) {
            $csvTarget = $CsvPath
            if ([string]::IsNullOrWhiteSpace($csvTarget)) {
                $csvTarget = Join-Path -Path $script:ResolvedLogDirectory -ChildPath "$($script:SessionTimestamp)-Audit-LocalAdministrators-$computerName.csv"
            }
            elseif (Test-Path -Path $csvTarget -PathType Container) {
                $csvTarget = Join-Path -Path $csvTarget -ChildPath "$($script:SessionTimestamp)-Audit-LocalAdministrators-$computerName.csv"
            }

            Write-ScriptLog "Exporting raw audit records to CSV at '$csvTarget'..." -Level 'INFO'
            $auditRecords | Export-Csv -Path $csvTarget -NoTypeInformation -Encoding UTF8
            Write-ScriptLog "CSV export successfully created: $csvTarget" -Level 'SUCCESS'
        }

        # Pipeline Output
        if ($PassThru) {
            $auditRecords | ForEach-Object { $_ }
        }
    }
}

# ==============================================================================
# Script Lifecycle: End Block
# ==============================================================================

end {
    Write-ScriptLog "Audit-LocalAdministrators session completed successfully." -Level 'SUCCESS'
    Write-ScriptLog "Execution log saved to: $script:LogFilePath" -Level 'INFO'
}
