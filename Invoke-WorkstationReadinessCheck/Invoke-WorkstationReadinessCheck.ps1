<#
.SYNOPSIS
    Performs a comprehensive workstation handover readiness check (hardware, disks, Windows activation,
    TPM/Secure Boot/BitLocker, AD/Entra ID join, required apps, and 24h Event Log health) with a
    printable HTML acceptance report.

.DESCRIPTION
    Invoke-WorkstationReadinessCheck.ps1 is an enterprise workstation QA and handover verification
    tool ("acceptance checklist") for Windows 10 and Windows 11 endpoints prior to issuing a new,
    reimaged, or post-service device to an employee.

    In a single automated pass, the script evaluates seven readiness pillars:
      1. System Identity & Pending Reboot:
         - Collects Hostname, Manufacturer, Model, BIOS Serial Number, CPU, RAM, OS Edition/Build,
           uptime, and Windows pending-reboot registry flags.
      2. Storage Health & Free Space:
         - Evaluates physical disk health (Get-PhysicalDisk) and fixed volume free capacity against
           configurable thresholds (-MinFreeSpacePercent and -MinFreeSpaceGB).
      3. Windows Activation & Licensing:
         - Queries SoftwareLicensingProduct to verify genuine Licensed status (LicenseStatus = 1).
      4. Hardware Security Posture (TPM / Secure Boot / BitLocker):
         - Verifies TPM 2.0 readiness, UEFI Secure Boot state, and OS drive BitLocker protection
           and encryption completeness.
      5. Directory & Cloud Join Status (dsregcmd /status):
         - Parses AzureAdJoined, DomainJoined, TenantName, DomainName, and AzureAdPrt to classify
           the endpoint (Hybrid Entra ID, Entra ID Joined, On-Premises AD, or Standalone Workgroup).
      6. Required Applications Verification:
         - Scans 64-bit HKLM, 32-bit WOW6432Node HKLM, and HKCU Uninstall registry hives against
           user-supplied -RequiredApps patterns (reporting detected version or MISSING).
      7. Event Log Stability (Last 24h):
         - Scans System and Application Event Logs for Critical (Level 1) and Error (Level 2) events
           within -EventLogHours (default 24h), highlighting unexpected shutdowns (Event ID 41/6008)
           and top recurring error sources.

    Outputs a colorized readiness scorecard in the console, a standalone printable HTML Handover
    Certificate (with Dark/Light theme and sign-off section), optional JSON export, UTF-8 execution
    logs in C:\Logs\, and structured [PSCustomObject] pipeline output via -PassThru.

.PARAMETER Run
    Executes the full workstation readiness checklist.
    Aliases: -Check, -Audit, -All

.PARAMETER RequiredApps
    Optional array of required application name patterns (wildcard/substring match) to verify
    against installed Windows applications (e.g., 'Google Chrome', 'Microsoft 365', '7-Zip').

.PARAMETER MinFreeSpacePercent
    Minimum required free space percentage on the OS drive (C:). Range: 1-95. Default: 15.

.PARAMETER MinFreeSpaceGB
    Minimum required free space in GB on the OS drive (C:). Range: 1-10000. Default: 20.

.PARAMETER EventLogHours
    Lookback window in hours for Critical and Error Event Log inspection. Range: 1-720. Default: 24.

.PARAMETER RequireBitLocker
    Strict compliance switch: flags missing or suspended OS drive BitLocker protection as [FAIL]
    instead of [WARN].

.PARAMETER RequireDomainOrEntra
    Strict compliance switch: flags Standalone Workgroup devices (neither AD nor Entra ID joined)
    as [FAIL] instead of [WARN].

.PARAMETER GenerateHtmlReport
    Generates a standalone printable HTML Workstation Readiness Acceptance Report.
    Aliases: -ExportHtml

.PARAMETER ReportPath
    Custom file path or directory for the HTML report.
    Aliases: -ExportPath

.PARAMETER OpenReport
    Automatically opens the generated HTML report in the system default web browser.

.PARAMETER ExportJson
    Exports the full readiness assessment object to a JSON file.

.PARAMETER JsonPath
    Custom file path or directory for the JSON export.

.PARAMETER PassThru
    Returns the structured readiness [PSCustomObject] to the PowerShell pipeline.

.PARAMETER EnableLogging
    Enables structured execution logging to C:\Logs\ (or -LogDirectory).
    Aliases: -Log

.PARAMETER LogDirectory
    Target directory for logs and default reports. Default: 'C:\Logs'.

.PARAMETER SkipAdminCheck
    Bypasses mandatory SID-based Administrator elevation check (useful for non-elevated preview/testing;
    TPM/Secure Boot/BitLocker details may be limited without elevation).

.PARAMETER Help
    Displays the interactive console help screen and exits cleanly.
    Aliases: -h

.EXAMPLE
    .\Invoke-WorkstationReadinessCheck.ps1 -Help
    Displays interactive help, parameter documentation, and usage examples.

.EXAMPLE
    .\Invoke-WorkstationReadinessCheck.ps1 -Run -GenerateHtmlReport -OpenReport
    Runs the full workstation readiness checklist and opens the printable HTML handover report.

.EXAMPLE
    .\Invoke-WorkstationReadinessCheck.ps1 -Run -RequiredApps "Google Chrome","7-Zip","Microsoft Edge" -RequireBitLocker -RequireDomainOrEntra -GenerateHtmlReport
    Enforces strict corporate baseline (BitLocker, AD/Entra ID join, required apps) and generates HTML report.

.EXAMPLE
    $check = .\Invoke-WorkstationReadinessCheck.ps1 -Run -PassThru
    $check | Select-Object ComputerName, OverallVerdict, PassCount, WarnCount, FailCount
    Runs readiness verification and inspects the verdict object in the PowerShell pipeline.

.EXAMPLE
    .\Invoke-GitHubScript.ps1 -UrlToDownload "https://github.com/romanpindela/Windows-Desktop/blob/main/Invoke-WorkstationReadinessCheck/Invoke-WorkstationReadinessCheck.ps1" -ScriptArgs "-Run -GenerateHtmlReport -OpenReport"
    Downloads and executes Invoke-WorkstationReadinessCheck.ps1 directly from GitHub.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Date:         2026-11-19
    Requires:     Windows 10 / 11 / Windows Server 2016+, PowerShell 5.1+ or PowerShell 7+, Administrator Privileges
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param (
    [Parameter(Mandatory = $false)]
    [Alias('Check', 'Audit', 'All')]
    [switch]$Run,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$RequiredApps,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 95)]
    [int]$MinFreeSpacePercent = 15,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10000)]
    [int]$MinFreeSpaceGB = 20,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 720)]
    [int]$EventLogHours = 24,

    [Parameter(Mandatory = $false)]
    [switch]$RequireBitLocker,

    [Parameter(Mandatory = $false)]
    [switch]$RequireDomainOrEntra,

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

    $script:ScriptName       = 'Invoke-WorkstationReadinessCheck'
    $script:ScriptVersion    = '1.0.0'
    $script:ScriptAuthor     = 'Roman Pindela'
    $script:ScriptEmail      = 'roman.pindela@gmail.com'
    $script:ScriptGitHub     = 'https://github.com/romanpindela'
    $script:LastModified     = '2026-11-19'
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
        Write-Host " $($script:ScriptName).ps1 v$($script:ScriptVersion) - Workstation Handover Checklist" -ForegroundColor White
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host "Author: $($script:ScriptAuthor) | Email: $($script:ScriptEmail) | GitHub: $($script:ScriptGitHub)" -ForegroundColor DarkGray
        Write-Host "Version: $($script:ScriptVersion) | Last Modified: $($script:LastModified)" -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Verifies workstation readiness in a single pass: disk health & free space,' -ForegroundColor Gray
        Write-Host 'Windows activation, TPM/Secure Boot/BitLocker, AD/Entra ID join status,' -ForegroundColor Gray
        Write-Host 'required applications, and 24h Event Log stability - with printable HTML export.' -ForegroundColor Gray
        Write-Host ''
        Write-Host 'PARAMETERS:' -ForegroundColor Yellow
        Write-Host '  -Run, -Check, -Audit          Execute the full workstation readiness checklist.' -ForegroundColor White
        Write-Host '  -RequiredApps <String[]>      Application names/wildcards required on device.' -ForegroundColor White
        Write-Host '  -MinFreeSpacePercent <Int>    Minimum OS drive free % threshold (Default: 15).' -ForegroundColor White
        Write-Host '  -MinFreeSpaceGB <Int>         Minimum OS drive free GB threshold (Default: 20).' -ForegroundColor White
        Write-Host '  -EventLogHours <Int>          Event Log lookback window in hours (Default: 24).' -ForegroundColor White
        Write-Host '  -RequireBitLocker             Treat missing BitLocker as [FAIL] instead of [WARN].' -ForegroundColor White
        Write-Host '  -RequireDomainOrEntra         Treat Workgroup status as [FAIL] instead of [WARN].' -ForegroundColor White
        Write-Host '  -GenerateHtmlReport           Export printable HTML handover report (-ExportHtml).' -ForegroundColor White
        Write-Host '  -ReportPath <Path>            Custom HTML report path (-ExportPath).' -ForegroundColor White
        Write-Host '  -OpenReport                   Open generated HTML report in default browser.' -ForegroundColor White
        Write-Host '  -ExportJson                   Export structured readiness results to JSON.' -ForegroundColor White
        Write-Host '  -JsonPath <Path>              Custom JSON file path.' -ForegroundColor White
        Write-Host '  -PassThru                     Return [PSCustomObject] to the pipeline.' -ForegroundColor White
        Write-Host '  -EnableLogging, -Log          Write UTF-8 execution logs to C:\Logs\.' -ForegroundColor White
        Write-Host '  -LogDirectory <Path>          Override log/report directory (Default: C:\Logs).' -ForegroundColor White
        Write-Host '  -SkipAdminCheck               Bypass UAC elevation check (limited security data).' -ForegroundColor White
        Write-Host '  -Help, -h                     Display this help screen and exit.' -ForegroundColor White
        Write-Host ''
        Write-Host 'EXAMPLES:' -ForegroundColor Yellow
        Write-Host '  .\Invoke-WorkstationReadinessCheck.ps1 -Run -GenerateHtmlReport -OpenReport' -ForegroundColor Gray
        Write-Host '  .\Invoke-WorkstationReadinessCheck.ps1 -Run -RequiredApps "Chrome","7-Zip" -RequireBitLocker' -ForegroundColor Gray
        Write-Host '  .\Invoke-WorkstationReadinessCheck.ps1 -Run -PassThru -EnableLogging' -ForegroundColor Gray
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

        Write-Host '[!] Administrator privileges (SID S-1-5-32-544) are required for full security checks. Requesting UAC elevation...' -ForegroundColor Yellow
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
    # Check 1: System Identity & Pending Reboot
    # --------------------------------------------------------------------------
    function Get-SystemIdentityCheck {
        [CmdletBinding()]
        param ()

        $cs   = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $os   = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cpu  = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

        $ubr = $null
        try {
            $ubr = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'UBR' -ErrorAction SilentlyContinue).UBR
        }
        catch {
            Write-Verbose 'Unable to read OS UBR.'
        }

        $pendingRebootReasons = New-Object System.Collections.Generic.List[string]
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
            $pendingRebootReasons.Add('CBS RebootPending')
        }
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
            $pendingRebootReasons.Add('Windows Update RebootRequired')
        }
        $pfr = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        if ($pfr -and $pfr.PendingFileRenameOperations) {
            $pendingRebootReasons.Add('PendingFileRenameOperations')
        }

        $uptime = if ($os -and $os.LastBootUpTime) {
            $span = (Get-Date) - $os.LastBootUpTime
            "{0}d {1}h {2}m" -f $span.Days, $span.Hours, $span.Minutes
        } else { 'Unknown' }

        $ramGB = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { $null }
        $buildStr = if ($os) {
            if ($null -ne $ubr) { "$($os.Version).$ubr" } else { $os.Version }
        } else { 'Unknown' }

        return [PSCustomObject]@{
            ComputerName         = $env:COMPUTERNAME
            Manufacturer         = if ($cs) { $cs.Manufacturer } else { 'Unknown' }
            Model                = if ($cs) { $cs.Model } else { 'Unknown' }
            SerialNumber         = if ($bios) { $bios.SerialNumber } else { 'Unknown' }
            BiosVersion          = if ($bios) { $bios.SMBIOSBIOSVersion } else { 'Unknown' }
            Processor            = if ($cpu) { $cpu.Name.Trim() } else { 'Unknown' }
            TotalRamGB           = $ramGB
            OsCaption            = if ($os) { $os.Caption } else { 'Unknown' }
            OsBuild              = $buildStr
            Uptime               = $uptime
            PendingReboot        = ($pendingRebootReasons.Count -gt 0)
            PendingRebootReasons = ($pendingRebootReasons -join ', ')
            Status               = if ($pendingRebootReasons.Count -gt 0) { 'WARN' } else { 'PASS' }
        }
    }

    # --------------------------------------------------------------------------
    # Check 2: Disk Health & Free Space
    # --------------------------------------------------------------------------
    function Get-StorageReadinessCheck {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [int]$MinPct,

            [Parameter(Mandatory = $true)]
            [int]$MinGB
        )

        $physicalDisks = @()
        try {
            $disks = @(Get-PhysicalDisk -ErrorAction Stop)
            foreach ($d in $disks) {
                $dStatus = if ($d.HealthStatus -eq 'Healthy' -and $d.OperationalStatus -eq 'OK') { 'PASS' }
                           elseif ($d.HealthStatus -eq 'Warning') { 'WARN' }
                           else { 'FAIL' }

                $physicalDisks += [PSCustomObject]@{
                    FriendlyName      = $d.FriendlyName
                    MediaType         = [string]$d.MediaType
                    BusType           = [string]$d.BusType
                    SizeGB            = [math]::Round($d.Size / 1GB, 1)
                    HealthStatus      = [string]$d.HealthStatus
                    OperationalStatus = [string]$d.OperationalStatus
                    Status            = $dStatus
                }
            }
        }
        catch {
            Write-LogEntry -Message "Get-PhysicalDisk unavailable, falling back to Win32_DiskDrive: $($_.Exception.Message)" -Level 'WARN'
            $wmiDisks = @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue)
            foreach ($wd in $wmiDisks) {
                $dStatus = if ($wd.Status -eq 'OK') { 'PASS' } else { 'WARN' }
                $physicalDisks += [PSCustomObject]@{
                    FriendlyName      = $wd.Model
                    MediaType         = $wd.MediaType
                    BusType           = $wd.InterfaceType
                    SizeGB            = [math]::Round($wd.Size / 1GB, 1)
                    HealthStatus      = $wd.Status
                    OperationalStatus = $wd.Status
                    Status            = $dStatus
                }
            }
        }

        $volumes = @()
        $osDrive = $env:SystemDrive.TrimEnd(':')
        $logicalDisks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)
        foreach ($v in $logicalDisks) {
            $sizeGB = if ($v.Size -gt 0) { [math]::Round($v.Size / 1GB, 1) } else { 0 }
            $freeGB = if ($v.FreeSpace -ge 0) { [math]::Round($v.FreeSpace / 1GB, 1) } else { 0 }
            $freePct = if ($v.Size -gt 0) { [math]::Round(($v.FreeSpace / $v.Size) * 100, 1) } else { 0 }
            $isOs = ($v.DeviceID.TrimEnd(':') -eq $osDrive)

            $vStatus = if ($isOs -and ($freePct -lt $MinPct -or $freeGB -lt $MinGB)) { 'FAIL' }
                       elseif ($freePct -lt $MinPct) { 'WARN' }
                       else { 'PASS' }

            $volumes += [PSCustomObject]@{
                DriveLetter = $v.DeviceID
                Label       = $v.VolumeName
                FileSystem  = $v.FileSystem
                SizeGB      = $sizeGB
                FreeGB      = $freeGB
                FreePercent = $freePct
                IsOsDrive   = $isOs
                Status      = $vStatus
            }
        }

        $allSt = @($physicalDisks | ForEach-Object { $_.Status }) + @($volumes | ForEach-Object { $_.Status })
        $overall = if ($allSt -contains 'FAIL') { 'FAIL' }
                   elseif ($allSt -contains 'WARN') { 'WARN' }
                   else { 'PASS' }

        return [PSCustomObject]@{
            PhysicalDisks = $physicalDisks
            Volumes       = $volumes
            Status        = $overall
            Notes         = "$($physicalDisks.Count) physical disk(s) and $($volumes.Count) fixed volume(s) verified."
        }
    }

    # --------------------------------------------------------------------------
    # Check 3: Windows Activation & Licensing
    # --------------------------------------------------------------------------
    function Get-WindowsActivationCheck {
        [CmdletBinding()]
        param ()

        $statusMap = @{
            0 = 'Unlicensed'
            1 = 'Licensed'
            2 = 'OOB Grace'
            3 = 'OOT Grace'
            4 = 'Non-Genuine Grace'
            5 = 'Notification'
            6 = 'Extended Grace'
        }

        try {
            $lic = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-98e3-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction Stop |
                Select-Object -First 1

            if ($null -eq $lic) {
                return [PSCustomObject]@{
                    Activated         = $false
                    LicenseStatusText = 'No Product Key Found'
                    ProductName       = 'Unknown'
                    PartialProductKey = 'N/A'
                    Status            = 'FAIL'
                    Notes             = 'Windows does not appear to have an active license installed.'
                }
            }

            $code = [int]$lic.LicenseStatus
            $text = if ($statusMap.ContainsKey($code)) { $statusMap[$code] } else { "Unknown ($code)" }
            $activated = ($code -eq 1)

            return [PSCustomObject]@{
                Activated         = $activated
                LicenseStatusText = $text
                ProductName       = $lic.Name
                PartialProductKey = "*****-$($lic.PartialProductKey)"
                Status            = if ($activated) { 'PASS' } else { 'FAIL' }
                Notes             = if ($activated) { 'Windows is permanently/properly activated.' } else { "Windows activation state is '$text'." }
            }
        }
        catch {
            Write-LogEntry -Message "SoftwareLicensingProduct query failed: $($_.Exception.Message)" -Level 'WARN'
            return [PSCustomObject]@{
                Activated         = $false
                LicenseStatusText = 'Query Error'
                ProductName       = 'Unknown'
                PartialProductKey = 'N/A'
                Status            = 'WARN'
                Notes             = "Could not query Windows activation status: $($_.Exception.Message)"
            }
        }
    }

    # --------------------------------------------------------------------------
    # Check 4: TPM, Secure Boot & BitLocker
    # --------------------------------------------------------------------------
    function Get-SecurityPostureCheck {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [switch]$StrictBitLocker
        )

        # TPM
        $tpmPresent = $false
        $tpmReady   = $false
        $tpmVersion = 'Unknown'
        $tpmStatus  = 'WARN'
        try {
            $tpm = Get-Tpm -ErrorAction Stop
            $tpmPresent = [bool]$tpm.TpmPresent
            $tpmReady   = [bool]$tpm.TpmReady
            $wmiTpm = Get-CimInstance -Namespace 'root\CIMv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
            if ($wmiTpm -and $wmiTpm.SpecVersion) {
                $tpmVersion = ($wmiTpm.SpecVersion -split ',')[0].Trim()
            }
            $tpmStatus = if ($tpmPresent -and $tpmReady -and $tpmVersion -like '2.*') { 'PASS' }
                         elseif ($tpmPresent) { 'WARN' }
                         else { 'FAIL' }
        }
        catch {
            $tpmVersion = 'Unavailable (Requires Admin)'
            $tpmStatus  = 'WARN'
        }

        # Secure Boot
        $secureBootText   = 'Unknown'
        $secureBootStatus = 'WARN'
        try {
            $sb = Confirm-SecureBootUEFI -ErrorAction Stop
            if ($sb) {
                $secureBootText   = 'Enabled (UEFI)'
                $secureBootStatus = 'PASS'
            }
            else {
                $secureBootText   = 'Disabled (UEFI)'
                $secureBootStatus = 'WARN'
            }
        }
        catch {
            if ($_.Exception.Message -match 'not supported|Cmdlet not supported') {
                $secureBootText   = 'Unsupported (Legacy BIOS)'
                $secureBootStatus = 'FAIL'
            }
            else {
                $secureBootText   = 'Unavailable (Requires Admin)'
                $secureBootStatus = 'WARN'
            }
        }

        # BitLocker OS Drive
        $blProtection = 'Unknown'
        $blPercent    = $null
        $blStatus     = 'WARN'
        try {
            $blVol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
            $blProtection = "$($blVol.ProtectionStatus) ($($blVol.VolumeStatus))"
            $blPercent    = $blVol.EncryptionPercentage
            if ($blVol.ProtectionStatus -eq 'On' -and $blVol.EncryptionPercentage -eq 100) {
                $blStatus = 'PASS'
            }
            elseif ($StrictBitLocker) {
                $blStatus = 'FAIL'
            }
            else {
                $blStatus = 'WARN'
            }
        }
        catch {
            $blProtection = 'Unavailable / Not Installed (Requires Admin)'
            $blStatus     = if ($StrictBitLocker) { 'FAIL' } else { 'WARN' }
        }

        $statuses = @($tpmStatus, $secureBootStatus, $blStatus)
        $overall = if ($statuses -contains 'FAIL') { 'FAIL' }
                   elseif ($statuses -contains 'WARN') { 'WARN' }
                   else { 'PASS' }

        return [PSCustomObject]@{
            TpmPresent          = $tpmPresent
            TpmReady            = $tpmReady
            TpmSpecVersion      = $tpmVersion
            TpmStatus           = $tpmStatus
            SecureBoot          = $secureBootText
            SecureBootStatus    = $secureBootStatus
            BitLockerOsDrive    = $blProtection
            BitLockerPercentage = $blPercent
            BitLockerStatus     = $blStatus
            Status              = $overall
        }
    }

    # --------------------------------------------------------------------------
    # Check 5: Domain / Entra ID Join Status (dsregcmd /status)
    # --------------------------------------------------------------------------
    function Get-DirectoryJoinCheck {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [switch]$StrictJoin
        )

        $azureAdJoined  = $false
        $domainJoined   = $false
        $workplaceJoin  = $false
        $azureAdPrt     = $false
        $tenantName     = 'N/A'
        $domainName     = 'N/A'

        try {
            $raw = @(& dsregcmd.exe /status 2>&1)
            foreach ($line in $raw) {
                $s = [string]$line
                if ($s -match '^\s*AzureAdJoined\s*:\s*(\S+)')    { $azureAdJoined = ($Matches[1] -eq 'YES') }
                elseif ($s -match '^\s*DomainJoined\s*:\s*(\S+)') { $domainJoined  = ($Matches[1] -eq 'YES') }
                elseif ($s -match '^\s*WorkplaceJoined\s*:\s*(\S+)') { $workplaceJoin = ($Matches[1] -eq 'YES') }
                elseif ($s -match '^\s*AzureAdPrt\s*:\s*(\S+)')   { $azureAdPrt    = ($Matches[1] -eq 'YES') }
                elseif ($s -match '^\s*TenantName\s*:\s*(.+)$')   { $tenantName    = $Matches[1].Trim() }
                elseif ($s -match '^\s*DomainName\s*:\s*(.+)$')   { $domainName    = $Matches[1].Trim() }
            }
        }
        catch {
            Write-LogEntry -Message "dsregcmd /status failed: $($_.Exception.Message)" -Level 'WARN'
        }

        $joinType = if ($azureAdJoined -and $domainJoined) { 'Hybrid Entra ID Joined' }
                    elseif ($azureAdJoined) { 'Entra ID Joined' }
                    elseif ($domainJoined) { 'On-Premises AD Joined' }
                    elseif ($workplaceJoin) { 'Entra ID Registered (Workplace)' }
                    else { 'Standalone Workgroup' }

        $isManaged = ($azureAdJoined -or $domainJoined)
        $status = if ($isManaged) { 'PASS' }
                  elseif ($StrictJoin) { 'FAIL' }
                  else { 'WARN' }

        return [PSCustomObject]@{
            JoinType        = $joinType
            AzureAdJoined   = $azureAdJoined
            DomainJoined    = $domainJoined
            WorkplaceJoined = $workplaceJoin
            AzureAdPrt      = $azureAdPrt
            TenantName      = $tenantName
            DomainName      = $domainName
            Status          = $status
            Notes           = if ($isManaged) { "Device is managed ($joinType)." } else { "Device is not joined to Active Directory or Entra ID ($joinType)." }
        }
    }

    # --------------------------------------------------------------------------
    # Check 6: Required Applications Verification
    # --------------------------------------------------------------------------
    function Get-RequiredAppsCheck {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [string[]]$ExpectedApps
        )

        $regPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )

        $installed = New-Object System.Collections.Generic.List[PSCustomObject]
        foreach ($rp in $regPaths) {
            try {
                $items = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                foreach ($it in $items) {
                    $dn = $null
                    if ($it.PSObject.Properties['DisplayName']) { $dn = [string]$it.DisplayName }
                    if ([string]::IsNullOrWhiteSpace($dn)) { continue }
                    $dv = if ($it.PSObject.Properties['DisplayVersion']) { [string]$it.DisplayVersion } else { '' }
                    $pub = if ($it.PSObject.Properties['Publisher']) { [string]$it.Publisher } else { '' }
                    $installed.Add([PSCustomObject]@{
                        DisplayName    = $dn.Trim()
                        DisplayVersion = $dv.Trim()
                        Publisher      = $pub.Trim()
                    })
                }
            }
            catch {
                Write-Verbose "Skipped uninstall hive ${rp}: $($_.Exception.Message)"
            }
        }

        $appChecks = @()
        if ($ExpectedApps -and $ExpectedApps.Count -gt 0) {
            foreach ($req in $ExpectedApps) {
                $pattern = if ($req -match '\*') { $req } else { "*$req*" }
                $hit = $installed | Where-Object { $_.DisplayName -like $pattern } | Select-Object -First 1
                if ($hit) {
                    $appChecks += [PSCustomObject]@{
                        RequiredPattern = $req
                        Found           = $true
                        MatchedName     = $hit.DisplayName
                        Version         = if ($hit.DisplayVersion) { $hit.DisplayVersion } else { 'Installed' }
                        Status          = 'PASS'
                    }
                }
                else {
                    $appChecks += [PSCustomObject]@{
                        RequiredPattern = $req
                        Found           = $false
                        MatchedName     = 'Not Installed'
                        Version         = 'N/A'
                        Status          = 'FAIL'
                    }
                }
            }

            $overall = if (@($appChecks | ForEach-Object { $_.Status }) -contains 'FAIL') { 'FAIL' } else { 'PASS' }
            $notes   = "$(@($appChecks | Where-Object { $_.Found }).Count) of $($appChecks.Count) required application(s) verified."
        }
        else {
            $overall = 'INFO'
            $notes   = "No -RequiredApps list supplied. Total detected installed software entries: $($installed.Count)."
        }

        return [PSCustomObject]@{
            TotalInstalledCount = $installed.Count
            RequiredAppChecks   = $appChecks
            Status              = $overall
            Notes               = $notes
        }
    }

    # --------------------------------------------------------------------------
    # Check 7: Event Log Stability (Last N Hours)
    # --------------------------------------------------------------------------
    function Get-EventLogStabilityCheck {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [int]$LookbackHours
        )

        $startTime = (Get-Date).AddHours(-$LookbackHours)
        $criticalEvents = New-Object System.Collections.Generic.List[PSCustomObject]
        $errorEvents    = New-Object System.Collections.Generic.List[PSCustomObject]

        foreach ($logName in @('System', 'Application')) {
            try {
                $raw = @(Get-WinEvent -FilterHashtable @{
                    LogName   = $logName
                    Level     = @(1, 2)
                    StartTime = $startTime
                } -MaxEvents 200 -ErrorAction SilentlyContinue)

                foreach ($ev in $raw) {
                    $firstLine = if ($ev.Message) {
                        ($ev.Message -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
                    } else { 'No description.' }
                    if ($firstLine.Length -gt 160) { $firstLine = $firstLine.Substring(0, 157) + '...' }

                    $obj = [PSCustomObject]@{
                        TimeCreated = $ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
                        LogName     = $logName
                        Level       = if ($ev.Level -eq 1) { 'Critical' } else { 'Error' }
                        Provider    = $ev.ProviderName
                        EventId     = $ev.Id
                        Summary     = $firstLine
                    }

                    if ($ev.Level -eq 1) { $criticalEvents.Add($obj) }
                    else { $errorEvents.Add($obj) }
                }
            }
            catch {
                Write-Verbose "Event log '$logName' returned no matching events or could not be read."
            }
        }

        $topErrors = @($errorEvents | Group-Object -Property LogName, Provider, EventId |
            Sort-Object -Property Count -Descending | Select-Object -First 8 | ForEach-Object {
                $sample = $_.Group | Select-Object -First 1
                [PSCustomObject]@{
                    LogName  = $sample.LogName
                    Provider = $sample.Provider
                    EventId  = $sample.EventId
                    Count    = $_.Count
                    Sample   = $sample.Summary
                }
            })

        $status = if ($criticalEvents.Count -gt 0) { 'FAIL' }
                  elseif ($errorEvents.Count -gt 10) { 'WARN' }
                  else { 'PASS' }

        $notes = if ($criticalEvents.Count -gt 0) {
            "$($criticalEvents.Count) Critical event(s) and $($errorEvents.Count) Error event(s) detected in the last ${LookbackHours}h."
        }
        elseif ($errorEvents.Count -gt 10) {
            "0 Critical events, but $($errorEvents.Count) Error events recorded in the last ${LookbackHours}h."
        }
        else {
            "0 Critical events and $($errorEvents.Count) Error event(s) in the last ${LookbackHours}h."
        }

        return [PSCustomObject]@{
            LookbackHours  = $LookbackHours
            CriticalCount  = $criticalEvents.Count
            ErrorCount     = $errorEvents.Count
            CriticalEvents = $criticalEvents.ToArray()
            TopErrorGroups = $topErrors
            Status         = $status
            Notes          = $notes
        }
    }

    # --------------------------------------------------------------------------
    # Reporting: Console Scorecard
    # --------------------------------------------------------------------------
    function Write-ConsoleScorecard {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Report
        )

        $colors = @{
            'PASS'                = 'Green'
            'READY'               = 'Green'
            'WARN'                = 'Yellow'
            'READY WITH WARNINGS' = 'Yellow'
            'FAIL'                = 'Red'
            'NOT READY'           = 'Red'
            'INFO'                = 'Cyan'
        }

        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host " WORKSTATION READINESS CHECKLIST | $($Report.SystemInfo.ComputerName) | $($Report.Timestamp)" -ForegroundColor White
        Write-Host " $($script:ScriptName).ps1 v$($script:ScriptVersion) | Author: $($script:ScriptAuthor) ($($script:ScriptGitHub))" -ForegroundColor DarkGray
        Write-Host '================================================================================' -ForegroundColor Cyan

        Write-Host "`n[1] SYSTEM IDENTITY & REBOOT STATE" -ForegroundColor Yellow
        Write-Host ("    Hardware : {0} {1} | S/N: {2}" -f $Report.SystemInfo.Manufacturer, $Report.SystemInfo.Model, $Report.SystemInfo.SerialNumber) -ForegroundColor White
        Write-Host ("    OS / RAM : {0} (Build {1}) | RAM: {2} GB | Uptime: {3}" -f $Report.SystemInfo.OsCaption, $Report.SystemInfo.OsBuild, $Report.SystemInfo.TotalRamGB, $Report.SystemInfo.Uptime) -ForegroundColor Gray
        $rc = $colors[$Report.SystemInfo.Status]
        Write-Host ("    [{0,-4}] Pending Reboot: {1}" -f $Report.SystemInfo.Status, $(if ($Report.SystemInfo.PendingReboot) { "YES ($($Report.SystemInfo.PendingRebootReasons))" } else { 'None' })) -ForegroundColor $rc

        Write-Host "`n[2] DISK HEALTH & FREE SPACE" -ForegroundColor Yellow
        foreach ($d in $Report.Storage.PhysicalDisks) {
            Write-Host ("    [{0,-4}] Disk: {1} ({2}, {3} GB) - Health: {4} / {5}" -f $d.Status, $d.FriendlyName, $d.MediaType, $d.SizeGB, $d.HealthStatus, $d.OperationalStatus) -ForegroundColor $colors[$d.Status]
        }
        foreach ($v in $Report.Storage.Volumes) {
            Write-Host ("    [{0,-4}] Vol {1} ({2}) - Free: {3} GB / {4} GB ({5}%)" -f $v.Status, $v.DriveLetter, $v.FileSystem, $v.FreeGB, $v.SizeGB, $v.FreePercent) -ForegroundColor $colors[$v.Status]
        }

        Write-Host "`n[3] WINDOWS ACTIVATION" -ForegroundColor Yellow
        Write-Host ("    [{0,-4}] {1} | {2} ({3})" -f $Report.Activation.Status, $Report.Activation.LicenseStatusText, $Report.Activation.ProductName, $Report.Activation.PartialProductKey) -ForegroundColor $colors[$Report.Activation.Status]

        Write-Host "`n[4] HARDWARE SECURITY (TPM / SECURE BOOT / BITLOCKER)" -ForegroundColor Yellow
        Write-Host ("    [{0,-4}] TPM         : Present=$($Report.Security.TpmPresent) | Ready=$($Report.Security.TpmReady) | Spec=$($Report.Security.TpmSpecVersion)" -f $Report.Security.TpmStatus) -ForegroundColor $colors[$Report.Security.TpmStatus]
        Write-Host ("    [{0,-4}] Secure Boot : $($Report.Security.SecureBoot)" -f $Report.Security.SecureBootStatus) -ForegroundColor $colors[$Report.Security.SecureBootStatus]
        Write-Host ("    [{0,-4}] BitLocker   : $($Report.Security.BitLockerOsDrive) ($($Report.Security.BitLockerPercentage)%)" -f $Report.Security.BitLockerStatus) -ForegroundColor $colors[$Report.Security.BitLockerStatus]

        Write-Host "`n[5] DIRECTORY & ENTRA ID JOIN (dsregcmd /status)" -ForegroundColor Yellow
        Write-Host ("    [{0,-4}] Join State  : $($Report.DirectoryJoin.JoinType) | Domain: $($Report.DirectoryJoin.DomainName) | Tenant: $($Report.DirectoryJoin.TenantName) | PRT: $($Report.DirectoryJoin.AzureAdPrt)" -f $Report.DirectoryJoin.Status) -ForegroundColor $colors[$Report.DirectoryJoin.Status]

        Write-Host "`n[6] REQUIRED APPLICATIONS" -ForegroundColor Yellow
        if ($Report.Applications.RequiredAppChecks.Count -eq 0) {
            Write-Host ("    [INFO] $($Report.Applications.Notes)") -ForegroundColor Cyan
        }
        else {
            foreach ($app in $Report.Applications.RequiredAppChecks) {
                Write-Host ("    [{0,-4}] {1,-26} -> {2} ({3})" -f $app.Status, $app.RequiredPattern, $app.MatchedName, $app.Version) -ForegroundColor $colors[$app.Status]
            }
        }

        Write-Host "`n[7] EVENT LOG STABILITY (Last $($Report.EventLogs.LookbackHours)h)" -ForegroundColor Yellow
        Write-Host ("    [{0,-4}] $($Report.EventLogs.Notes)" -f $Report.EventLogs.Status) -ForegroundColor $colors[$Report.EventLogs.Status]
        foreach ($ce in ($Report.EventLogs.CriticalEvents | Select-Object -First 5)) {
            Write-Host ("      - [CRIT] {0} | {1} | ID {2} | {3}" -f $ce.TimeCreated, $ce.Provider, $ce.EventId, $ce.Summary) -ForegroundColor Red
        }

        $vc = $colors[$Report.OverallVerdict]
        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host (" HANDOVER VERDICT: [{0}]  (PASS: {1} | WARN: {2} | FAIL: {3})" -f $Report.OverallVerdict, $Report.PassCount, $Report.WarnCount, $Report.FailCount) -ForegroundColor $vc
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host ''
    }

    # --------------------------------------------------------------------------
    # Reporting: Printable Standalone HTML Handover Acceptance Report
    # --------------------------------------------------------------------------
    function Export-HtmlReadinessReport {
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
                'PASS'                { 'badge-pass' }
                'READY'               { 'badge-pass' }
                'WARN'                { 'badge-warn' }
                'READY WITH WARNINGS' { 'badge-warn' }
                'FAIL'                { 'badge-fail' }
                'NOT READY'           { 'badge-fail' }
                default               { 'badge-info' }
            }
        }

        $diskRows = ($Report.Storage.PhysicalDisks | ForEach-Object {
            "<tr><td><span class=`"badge $(& $badgeClass $_.Status)`">$($_.Status)</span></td><td>$(ConvertTo-SafeHtml $_.FriendlyName)</td><td>$(ConvertTo-SafeHtml $_.MediaType)</td><td>$($_.SizeGB) GB</td><td>$(ConvertTo-SafeHtml $_.HealthStatus) / $(ConvertTo-SafeHtml $_.OperationalStatus)</td></tr>"
        }) -join "`n"

        $volRows = ($Report.Storage.Volumes | ForEach-Object {
            "<tr><td><span class=`"badge $(& $badgeClass $_.Status)`">$($_.Status)</span></td><td>$(ConvertTo-SafeHtml $_.DriveLetter)</td><td>$(ConvertTo-SafeHtml $_.FileSystem)</td><td>$($_.FreeGB) GB / $($_.SizeGB) GB</td><td>$($_.FreePercent)%</td></tr>"
        }) -join "`n"

        $appRows = if ($Report.Applications.RequiredAppChecks.Count -gt 0) {
            ($Report.Applications.RequiredAppChecks | ForEach-Object {
                "<tr><td><span class=`"badge $(& $badgeClass $_.Status)`">$($_.Status)</span></td><td>$(ConvertTo-SafeHtml $_.RequiredPattern)</td><td>$(ConvertTo-SafeHtml $_.MatchedName)</td><td>$(ConvertTo-SafeHtml $_.Version)</td></tr>"
            }) -join "`n"
        } else {
            "<tr><td colspan=`"4`">$(ConvertTo-SafeHtml $Report.Applications.Notes)</td></tr>"
        }

        $critRows = if ($Report.EventLogs.CriticalCount -gt 0) {
            ($Report.EventLogs.CriticalEvents | Select-Object -First 15 | ForEach-Object {
                "<tr><td><span class=`"badge badge-fail`">Critical</span></td><td>$(ConvertTo-SafeHtml $_.TimeCreated)</td><td>$(ConvertTo-SafeHtml $_.LogName)</td><td>$(ConvertTo-SafeHtml $_.Provider) ($($_.EventId))</td><td>$(ConvertTo-SafeHtml $_.Summary)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="5">No Critical events detected in the inspected time window.</td></tr>'
        }

        $errGroupRows = if ($Report.EventLogs.TopErrorGroups.Count -gt 0) {
            ($Report.EventLogs.TopErrorGroups | ForEach-Object {
                "<tr><td>$($_.Count)x</td><td>$(ConvertTo-SafeHtml $_.LogName)</td><td>$(ConvertTo-SafeHtml $_.Provider)</td><td>$($_.EventId)</td><td>$(ConvertTo-SafeHtml $_.Sample)</td></tr>"
            }) -join "`n"
        } else {
            '<tr><td colspan="5">No recurring Error events recorded.</td></tr>'
        }

        $html = @"
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Workstation Readiness Certificate - $(ConvertTo-SafeHtml $Report.SystemInfo.ComputerName)</title>
<style>
  :root { --bg:#f8fafc; --card:#ffffff; --text:#0f172a; --muted:#475569; --border:#e2e8f0; --accent:#0284c7; }
  [data-theme="dark"] { --bg:#0f172a; --card:#1e293b; --text:#e2e8f0; --muted:#94a3b8; --border:#334155; --accent:#38bdf8; }
  body { font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background:var(--bg); color:var(--text); margin:0; padding:24px; line-height:1.5; }
  .container { max-width:1150px; margin:0 auto; }
  header { display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; margin-bottom:20px; border-bottom:2px solid var(--border); padding-bottom:16px; }
  h1 { margin:0; font-size:1.5rem; }
  h2 { margin-top:0; font-size:1.05rem; color:var(--accent); }
  .meta { color:var(--muted); font-size:0.88rem; }
  .btn { background:var(--card); color:var(--text); border:1px solid var(--border); padding:8px 14px; border-radius:6px; cursor:pointer; font-size:0.85rem; }
  .grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(200px, 1fr)); gap:12px; margin-bottom:18px; }
  .kpi { background:var(--card); border:1px solid var(--border); border-radius:10px; padding:14px; }
  .kpi-label { font-size:0.78rem; color:var(--muted); text-transform:uppercase; }
  .kpi-val { font-size:1.15rem; font-weight:700; margin-top:4px; }
  .card { background:var(--card); border:1px solid var(--border); border-radius:10px; padding:16px; margin-bottom:16px; overflow-x:auto; page-break-inside:avoid; }
  table { width:100%; border-collapse:collapse; font-size:0.86rem; }
  th, td { text-align:left; padding:8px 10px; border-bottom:1px solid var(--border); }
  th { color:var(--muted); font-weight:600; }
  .badge { display:inline-block; padding:2px 9px; border-radius:999px; font-size:0.75rem; font-weight:700; }
  .badge-pass { background:#dcfce7; color:#166534; }
  .badge-warn { background:#fef9c3; color:#854d0e; }
  .badge-fail { background:#fee2e2; color:#991b1b; }
  .badge-info { background:#e0f2fe; color:#075985; }
  [data-theme="dark"] .badge-pass { background:#14532d; color:#86efac; }
  [data-theme="dark"] .badge-warn { background:#713f12; color:#fde047; }
  [data-theme="dark"] .badge-fail { background:#7f1d1d; color:#fca5a5; }
  [data-theme="dark"] .badge-info { background:#0c4a6e; color:#7dd3fc; }
  .signoff { display:grid; grid-template-columns:1fr 1fr; gap:24px; margin-top:12px; }
  .sig-box { border-top:1px dashed var(--border); padding-top:8px; color:var(--muted); font-size:0.85rem; margin-top:32px; }
  footer { text-align:center; color:var(--muted); font-size:0.8rem; margin-top:20px; }
  @media print { .no-print { display:none; } body { padding:0; background:#fff; color:#000; } }
</style>
</head>
<body>
<div class="container">
  <header>
    <div>
      <h1>Workstation Readiness Acceptance Report</h1>
      <div class="meta">Host: <strong>$(ConvertTo-SafeHtml $Report.SystemInfo.ComputerName)</strong> | S/N: <strong>$(ConvertTo-SafeHtml $Report.SystemInfo.SerialNumber)</strong> | Checked: $(ConvertTo-SafeHtml $Report.Timestamp)</div>
    </div>
    <div class="no-print">
      <button class="btn" onclick="document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'">Toggle Theme</button>
      <button class="btn" onclick="window.print()">Print / Save PDF</button>
    </div>
  </header>

  <div class="grid">
    <div class="kpi"><div class="kpi-label">Handover Verdict</div><div class="kpi-val"><span class="badge $(& $badgeClass $Report.OverallVerdict)">$($Report.OverallVerdict)</span></div></div>
    <div class="kpi"><div class="kpi-label">Checks Passed / Warn / Fail</div><div class="kpi-val">$($Report.PassCount) / $($Report.WarnCount) / $($Report.FailCount)</div></div>
    <div class="kpi"><div class="kpi-label">Directory Join</div><div class="kpi-val">$(ConvertTo-SafeHtml $Report.DirectoryJoin.JoinType)</div></div>
    <div class="kpi"><div class="kpi-label">Critical Events ($($Report.EventLogs.LookbackHours)h)</div><div class="kpi-val">$($Report.EventLogs.CriticalCount)</div></div>
  </div>

  <section class="card">
    <h2>1. System Identity &amp; Hardware</h2>
    <table>
      <tbody>
        <tr><th>Manufacturer / Model</th><td>$(ConvertTo-SafeHtml $Report.SystemInfo.Manufacturer) $(ConvertTo-SafeHtml $Report.SystemInfo.Model)</td><th>Serial Number</th><td>$(ConvertTo-SafeHtml $Report.SystemInfo.SerialNumber)</td></tr>
        <tr><th>Operating System</th><td>$(ConvertTo-SafeHtml $Report.SystemInfo.OsCaption) (Build $(ConvertTo-SafeHtml $Report.SystemInfo.OsBuild))</td><th>BIOS / Uptime</th><td>$(ConvertTo-SafeHtml $Report.SystemInfo.BiosVersion) | $(ConvertTo-SafeHtml $Report.SystemInfo.Uptime)</td></tr>
        <tr><th>Processor / RAM</th><td>$(ConvertTo-SafeHtml $Report.SystemInfo.Processor) | $($Report.SystemInfo.TotalRamGB) GB</td><th>Pending Reboot</th><td><span class="badge $(& $badgeClass $Report.SystemInfo.Status)">$(if ($Report.SystemInfo.PendingReboot) { "YES ($($Report.SystemInfo.PendingRebootReasons))" } else { 'None' })</span></td></tr>
      </tbody>
    </table>
  </section>

  <section class="card">
    <h2>2. Storage Health &amp; Free Space</h2>
    <table>
      <thead><tr><th>Status</th><th>Physical Disk</th><th>Media</th><th>Capacity</th><th>Health</th></tr></thead>
      <tbody>$diskRows</tbody>
    </table>
    <br />
    <table>
      <thead><tr><th>Status</th><th>Volume</th><th>File System</th><th>Free / Total</th><th>Free %</th></tr></thead>
      <tbody>$volRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>3. Activation, Hardware Security &amp; Identity</h2>
    <table>
      <thead><tr><th>Status</th><th>Control</th><th>Details</th></tr></thead>
      <tbody>
        <tr><td><span class="badge $(& $badgeClass $Report.Activation.Status)">$($Report.Activation.Status)</span></td><td>Windows Activation</td><td>$(ConvertTo-SafeHtml $Report.Activation.LicenseStatusText) - $(ConvertTo-SafeHtml $Report.Activation.ProductName) ($(ConvertTo-SafeHtml $Report.Activation.PartialProductKey))</td></tr>
        <tr><td><span class="badge $(& $badgeClass $Report.Security.TpmStatus)">$($Report.Security.TpmStatus)</span></td><td>TPM Module</td><td>Present: $($Report.Security.TpmPresent) | Ready: $($Report.Security.TpmReady) | Spec: $(ConvertTo-SafeHtml $Report.Security.TpmSpecVersion)</td></tr>
        <tr><td><span class="badge $(& $badgeClass $Report.Security.SecureBootStatus)">$($Report.Security.SecureBootStatus)</span></td><td>UEFI Secure Boot</td><td>$(ConvertTo-SafeHtml $Report.Security.SecureBoot)</td></tr>
        <tr><td><span class="badge $(& $badgeClass $Report.Security.BitLockerStatus)">$($Report.Security.BitLockerStatus)</span></td><td>BitLocker ($($env:SystemDrive))</td><td>$(ConvertTo-SafeHtml $Report.Security.BitLockerOsDrive) ($($Report.Security.BitLockerPercentage)%)</td></tr>
        <tr><td><span class="badge $(& $badgeClass $Report.DirectoryJoin.Status)">$($Report.DirectoryJoin.Status)</span></td><td>AD / Entra ID Join</td><td>$(ConvertTo-SafeHtml $Report.DirectoryJoin.JoinType) | Domain: $(ConvertTo-SafeHtml $Report.DirectoryJoin.DomainName) | Tenant: $(ConvertTo-SafeHtml $Report.DirectoryJoin.TenantName) | PRT: $($Report.DirectoryJoin.AzureAdPrt)</td></tr>
      </tbody>
    </table>
  </section>

  <section class="card">
    <h2>4. Required Applications Verification</h2>
    <table>
      <thead><tr><th>Status</th><th>Required Pattern</th><th>Detected Application</th><th>Version</th></tr></thead>
      <tbody>$appRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>5. Event Log Stability (Last $($Report.EventLogs.LookbackHours) Hours)</h2>
    <p class="meta">$(ConvertTo-SafeHtml $Report.EventLogs.Notes)</p>
    <table>
      <thead><tr><th>Level</th><th>Timestamp</th><th>Log</th><th>Provider (ID)</th><th>Summary</th></tr></thead>
      <tbody>$critRows</tbody>
    </table>
    <br />
    <table>
      <thead><tr><th>Count</th><th>Log</th><th>Top Error Provider</th><th>Event ID</th><th>Sample Message</th></tr></thead>
      <tbody>$errGroupRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>6. Handover Sign-Off</h2>
    <div class="signoff">
      <div class="sig-box">IT Technician Signature &amp; Date (Prepared by: $(ConvertTo-SafeHtml $Report.CheckedBy))</div>
      <div class="sig-box">Employee / Recipient Signature &amp; Date</div>
    </div>
  </section>

  <footer>Generated by Invoke-WorkstationReadinessCheck.ps1 v$($script:ScriptVersion) | Roman Pindela (github.com/romanpindela)</footer>
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

    if (-not $SkipAdminCheck -and -not (Test-IsAdministrator)) {
        Invoke-UacElevation
        $script:ShouldExitEarly = $true
        return
    }

    if ($EnableLogging -or $GenerateHtmlReport -or $ExportJson) {
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
        Write-Progress -Activity 'Workstation Readiness Check' -Status 'Collecting system identity and reboot state...' -PercentComplete 14
        $sysInfo = Get-SystemIdentityCheck

        Write-Progress -Activity 'Workstation Readiness Check' -Status 'Evaluating disk health and volume free space...' -PercentComplete 28
        $storage = Get-StorageReadinessCheck -MinPct $MinFreeSpacePercent -MinGB $MinFreeSpaceGB

        Write-Progress -Activity 'Workstation Readiness Check' -Status 'Verifying Windows activation status...' -PercentComplete 42
        $activation = Get-WindowsActivationCheck

        Write-Progress -Activity 'Workstation Readiness Check' -Status 'Auditing TPM, Secure Boot, and BitLocker...' -PercentComplete 56
        $security = Get-SecurityPostureCheck -StrictBitLocker:$RequireBitLocker

        Write-Progress -Activity 'Workstation Readiness Check' -Status 'Checking AD / Entra ID join state (dsregcmd)...' -PercentComplete 70
        $dirJoin = Get-DirectoryJoinCheck -StrictJoin:$RequireDomainOrEntra

        Write-Progress -Activity 'Workstation Readiness Check' -Status 'Verifying required applications...' -PercentComplete 84
        $apps = Get-RequiredAppsCheck -ExpectedApps $RequiredApps

        Write-Progress -Activity 'Workstation Readiness Check' -Status "Scanning System & Application Event Logs (${EventLogHours}h)..." -PercentComplete 95
        $eventLogs = Get-EventLogStabilityCheck -LookbackHours $EventLogHours

        Write-Progress -Activity 'Workstation Readiness Check' -Completed

        $pillarStatuses = @(
            $sysInfo.Status,
            $storage.Status,
            $activation.Status,
            $security.TpmStatus,
            $security.SecureBootStatus,
            $security.BitLockerStatus,
            $dirJoin.Status,
            $apps.Status,
            $eventLogs.Status
        )

        $passCount = @($pillarStatuses | Where-Object { $_ -eq 'PASS' }).Count
        $warnCount = @($pillarStatuses | Where-Object { $_ -eq 'WARN' }).Count
        $failCount = @($pillarStatuses | Where-Object { $_ -eq 'FAIL' }).Count

        $verdict = if ($failCount -gt 0) { 'NOT READY' }
                   elseif ($warnCount -gt 0) { 'READY WITH WARNINGS' }
                   else { 'READY' }

        $reportObject = [PSCustomObject]@{
            ComputerName   = $env:COMPUTERNAME
            CheckedBy      = $env:USERNAME
            Timestamp      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            OverallVerdict = $verdict
            PassCount      = $passCount
            WarnCount      = $warnCount
            FailCount      = $failCount
            SystemInfo     = $sysInfo
            Storage        = $storage
            Activation     = $activation
            Security       = $security
            DirectoryJoin  = $dirJoin
            Applications   = $apps
            EventLogs      = $eventLogs
        }

        Write-LogEntry -Message "Readiness Verdict: $verdict (PASS=$passCount, WARN=$warnCount, FAIL=$failCount)." -Level 'INFO'
        Write-ConsoleScorecard -Report $reportObject

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

            Export-HtmlReadinessReport -Report $reportObject -DestinationPath $finalHtml
            Write-Host "[+] HTML handover report saved to: $finalHtml" -ForegroundColor Green
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
