<#
.SYNOPSIS
    Audits TPM 2.0 hardware trust, UEFI Secure Boot, BitLocker volume encryption, and Active Directory /
    Microsoft Entra ID recovery key escrow for NIS2 and zero-trust data-at-rest compliance.

.DESCRIPTION
    Audit-BitLockerAndTpmStatus.ps1 is an enterprise-grade security auditing and compliance tool designed
    for Windows 10, Windows 11, and Windows Server systems. It delivers deep cryptographic inspection
    and zero-trust posture verification aligned with the EU NIS2 Directive, CIS benchmarks, and modern
    enterprise data-at-rest policies.

    The audit evaluates three core architectural layers:
      1. Hardware Root of Trust:
         - TPM module presence, activation, readiness, ownership, and specification version (TPM 2.0 required).
         - Detection of physical discrete TPM (dTPM) vs firmware TPM (fTPM) and vendor firmware versions.
         - Firmware mode (UEFI vs Legacy BIOS) and UEFI Secure Boot validation.
      2. BitLocker Volume Encryption:
         - Complete inventory of logical volumes (OS Drive, Fixed Data Drives, Removable Drives).
         - Volume status, 100% encryption completeness verification, and algorithm validation (XTS-AES 128/256).
         - Protection status and comprehensive key protector inspection (TPM, TPM+PIN, RecoveryPassword).
         - Exclusion of secret plaintext keys to safeguard credential confidentiality.
      3. Escrow Verification (Cloud / AD Backup):
         - Machine identity and directory join state classification (Entra ID, Hybrid, on-prem AD, Standalone).
         - Deep event inspection of 'Microsoft-Windows-BitLocker/BitLocker Management' log.
         - Verification of Event ID 845 (successful backup) vs Event ID 846 (backup failure).
         - Resolution of escrow status: SUCCESS_ENTRA, SUCCESS_AD, FAILED_NO_ESCROW, STANDALONE_NOT_APPLICABLE.

    The tool outputs colorized status tags ([PASS], [WARN], [FAIL]) in the console, writes microsecond-precision
    audit logs to C:\Logs\, creates a standalone responsive HTML compliance dashboard with Dark/Light theme,
    and supports structured PSCustomObject pipeline output.

.PARAMETER PathHtmlReport
    Target path for the standalone HTML compliance report.
    Default: C:\Logs\Audit-BitLockerAndTpmStatus_<yyyyMMdd_HHmmss>.html

.PARAMETER OpenReport
    Automatically opens the generated HTML report in the system default browser upon completion.

.PARAMETER EnforceAes256
    Enforces strict cryptographic policy. When specified, encryption algorithms other than XTS-AES 256
    or AES 256 (such as XTS-AES 128) are classified as [FAIL] rather than [WARN].

.PARAMETER PassThru
    Returns the comprehensive structured PSCustomObject audit record to the PowerShell pipeline.

.PARAMETER SkipAdminCheck
    Bypasses the mandatory UAC elevation check (useful for automated testing or non-privileged inspection).

.PARAMETER Help
    Displays the interactive console help guide and parameter documentation. Alias: -h.

.EXAMPLE
    .\Audit-BitLockerAndTpmStatus.ps1
    Performs standard cryptographic and TPM compliance audit, outputs colorized summary to console,
    writes execution logs to C:\Logs\, and generates default HTML report.

.EXAMPLE
    .\Audit-BitLockerAndTpmStatus.ps1 -OpenReport
    Executes full audit and immediately launches the generated HTML compliance report in the default browser.

.EXAMPLE
    .\Audit-BitLockerAndTpmStatus.ps1 -EnforceAes256 -PathHtmlReport "C:\Reports\Audit-NIS2.html"
    Executes audit enforcing strict AES-256 encryption requirement and writes HTML dashboard to custom path.

.EXAMPLE
    $audit = .\Audit-BitLockerAndTpmStatus.ps1 -PassThru
    $audit.Volumes | Where-Object { $_.ProtectionStatus -ne 'On' }
    Retrieves full audit data as PSCustomObject and queries unprotected volumes.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Date:         2026-11-09
    Requires:     Windows 10 / 11 / Windows Server 2016+, PowerShell 5.1+, Elevated Administrator Token
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param (
    [Parameter(Mandatory = $false)]
    [string]$PathHtmlReport,

    [Parameter(Mandatory = $false)]
    [switch]$OpenReport,

    [Parameter(Mandatory = $false)]
    [switch]$EnforceAes256,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

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

    # Global script variables
    $script:IsHelpRequested = [bool]$Help
    $script:SessionTimestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $script:LogDirectory = 'C:\Logs'
    $script:LogFilePath = Join-Path -Path $script:LogDirectory -ChildPath "Audit-BitLockerAndTpmStatus_$($script:SessionTimestamp).log"

    # --------------------------------------------------------------------------
    # Logging Module
    # --------------------------------------------------------------------------
    function Write-LogEntry {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
            [string]$Level = 'INFO'
        )

        $dateStr = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
        $logLine = "$dateStr [$Level] $Message"

        try {
            if (-not (Test-Path -Path $script:LogDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null
            }
            [System.IO.File]::AppendAllLines($script:LogFilePath, [string[]]@($logLine), [System.Text.Encoding]::UTF8)
        }
        catch {
            Write-Verbose "Could not append to log file '$($script:LogFilePath)': $_"
        }
    }

    # --------------------------------------------------------------------------
    # Interactive Help Display
    # --------------------------------------------------------------------------
    if ($script:IsHelpRequested) {
        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host " Audit-BitLockerAndTpmStatus - Enterprise Cryptographic & TPM Security Audit" -ForegroundColor White
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Audits TPM 2.0, UEFI Secure Boot, BitLocker encryption, and Cloud/AD Escrow.`n" -ForegroundColor Gray
        Write-Host "PARAMETERS:" -ForegroundColor Yellow
        Write-Host "  -PathHtmlReport <Path>  Target HTML report path (Default: C:\Logs\Audit-BitLockerAndTpmStatus_<timestamp>.html)" -ForegroundColor White
        Write-Host "  -OpenReport             Opens the generated HTML report in the default browser." -ForegroundColor White
        Write-Host "  -EnforceAes256          Treats encryption methods other than XTS-AES 256 as FAIL." -ForegroundColor White
        Write-Host "  -PassThru               Outputs structured PSCustomObject audit record to the pipeline." -ForegroundColor White
        Write-Host "  -SkipAdminCheck         Bypasses strict administrator elevation verification." -ForegroundColor White
        Write-Host "  -Help, -h               Displays this interactive help guide.`n" -ForegroundColor White
        Write-Host "EXAMPLES:" -ForegroundColor Yellow
        Write-Host "  .\Audit-BitLockerAndTpmStatus.ps1" -ForegroundColor Gray
        Write-Host "  .\Audit-BitLockerAndTpmStatus.ps1 -OpenReport" -ForegroundColor Gray
        Write-Host "  .\Audit-BitLockerAndTpmStatus.ps1 -EnforceAes256 -PassThru" -ForegroundColor Gray
        Write-Host "================================================================================`n" -ForegroundColor Cyan
        return
    }

    # --------------------------------------------------------------------------
    # Administrative Privileges Verification (SID: S-1-5-32-544)
    # --------------------------------------------------------------------------
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin -and -not $SkipAdminCheck) {
        throw "Skrypt wymaga uprawnien administratora (UAC Elevation). Uruchom konsole PowerShell jako Administrator lub uzyj parametru -SkipAdminCheck do testow."
    }

    if ([string]::IsNullOrWhiteSpace($PathHtmlReport)) {
        $PathHtmlReport = Join-Path -Path $script:LogDirectory -ChildPath "Audit-BitLockerAndTpmStatus_$($script:SessionTimestamp).html"
    }

    Write-LogEntry "================================================================================" -Level 'INFO'
    Write-LogEntry "Audit-BitLockerAndTpmStatus session started on $($env:COMPUTERNAME)" -Level 'INFO'
    Write-LogEntry "PowerShell Version: $($PSVersionTable.PSVersion.ToString())" -Level 'INFO'
    Write-LogEntry "Elevation Status: $(if ($isAdmin) { 'Elevated (Administrator)' } else { 'Unelevated (-SkipAdminCheck)' })" -Level 'INFO'
    Write-LogEntry "Enforce AES-256 Policy: $EnforceAes256" -Level 'INFO'
    Write-LogEntry "Target HTML Report Path: $PathHtmlReport" -Level 'INFO'
    Write-LogEntry "================================================================================" -Level 'INFO'

    # --------------------------------------------------------------------------
    # Console Helper Formatting
    # --------------------------------------------------------------------------
    function Write-StatusRow {
        param (
            [string]$Category,
            [string]$Item,
            [string]$Status,
            [string]$Details
        )

        $tagColor = switch ($Status) {
            'PASS'    { 'Green' }
            'WARN'    { 'Yellow' }
            'FAIL'    { 'Red' }
            default   { 'White' }
        }

        Write-Host "  " -NoNewline
        Write-Host "[$Status]".PadRight(8) -ForegroundColor $tagColor -NoNewline
        Write-Host "$Category".PadRight(22) -ForegroundColor Cyan -NoNewline
        Write-Host "$Item".PadRight(28) -ForegroundColor White -NoNewline
        Write-Host "$Details" -ForegroundColor Gray
    }
}

# ==============================================================================
# Script Lifecycle: Process Block
# ==============================================================================

process {
    if ($script:IsHelpRequested) { return }

    # --------------------------------------------------------------------------
    # Step 1: Hardware Root of Trust (TPM & UEFI Secure Boot)
    # --------------------------------------------------------------------------
    Write-Progress -Activity "Audyt bezpieczenstwa stacji roboczej" -Status "Krok 1/4: Sprawdzanie stanu TPM i UEFI..." -PercentComplete 25
    Write-LogEntry "Checking Hardware Root of Trust: TPM module and UEFI Secure Boot..." -Level 'INFO'

    $tpmInfo = [PSCustomObject]@{
        Present             = $false
        Ready               = $false
        Enabled             = $false
        Activated           = $false
        Owned               = $false
        SpecVersion         = 'Not Detected'
        ManufacturerId      = $null
        ManufacturerIdTxt   = 'Unknown'
        ManufacturerVersion = 'Unknown'
        TpmType             = 'Unknown'
        Status              = 'FAIL'
        StatusDetails       = ''
    }

    # 1. Query via Get-Tpm cmdlet
    try {
        $getTpmResult = Get-Tpm -ErrorAction Stop
        if ($getTpmResult) {
            $tpmInfo.Present   = [bool]$getTpmResult.TpmPresent
            $tpmInfo.Ready     = [bool]$getTpmResult.TpmReady
            $tpmInfo.Enabled   = [bool]$getTpmResult.TpmEnabled
            $tpmInfo.Activated = [bool]$getTpmResult.TpmActivated
            $tpmInfo.Owned     = [bool]$getTpmResult.TpmOwned
            if ($getTpmResult.ManufacturerIdTxt) { $tpmInfo.ManufacturerIdTxt = $getTpmResult.ManufacturerIdTxt.Trim() }
            if ($getTpmResult.ManufacturerVersion) { $tpmInfo.ManufacturerVersion = $getTpmResult.ManufacturerVersion.Trim() }
        }
    }
    catch {
        Write-LogEntry "Get-Tpm cmdlet call failed: $($_.Exception.Message). Continuing to fallbacks..." -Level 'WARN'
    }

    # 2. Query via WMI/CIM Win32_Tpm
    try {
        $cimTpm = Get-CimInstance -Namespace 'root\CIMv2\Security\MicrosoftTpm' -ClassName 'Win32_Tpm' -ErrorAction Stop
        if ($cimTpm) {
            $tpmInfo.Present = $true
            if ($cimTpm.SpecVersion) {
                $tpmInfo.SpecVersion = $cimTpm.SpecVersion.Trim()
            }
            if ($cimTpm.ManufacturerIdTxt -and ($tpmInfo.ManufacturerIdTxt -eq 'Unknown' -or [string]::IsNullOrWhiteSpace($tpmInfo.ManufacturerIdTxt))) {
                $tpmInfo.ManufacturerIdTxt = $cimTpm.ManufacturerIdTxt.Trim()
            }
            if ($cimTpm.ManufacturerVersion -and ($tpmInfo.ManufacturerVersion -eq 'Unknown' -or [string]::IsNullOrWhiteSpace($tpmInfo.ManufacturerVersion))) {
                $tpmInfo.ManufacturerVersion = $cimTpm.ManufacturerVersion.Trim()
            }
        }
    }
    catch {
        Write-LogEntry "WMI Win32_Tpm query notice: $($_.Exception.Message)" -Level 'INFO'
    }

    # 3. Query via PnP Entity (Reliable hardware fallback)
    if ($tpmInfo.SpecVersion -eq 'Not Detected' -or -not $tpmInfo.Present) {
        try {
            $pnpTpm = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue |
                Where-Object { $_.DeviceID -match 'TPM' -or $_.Name -match 'Trusted Platform Module' } |
                Select-Object -First 1

            if ($pnpTpm) {
                $tpmInfo.Present = $true
                if ($pnpTpm.Status -eq 'OK') {
                    $tpmInfo.Ready = $true
                    $tpmInfo.Enabled = $true
                    $tpmInfo.Activated = $true
                }
                if ($pnpTpm.Name -match '2\.0') { $tpmInfo.SpecVersion = '2.0' }
                elseif ($pnpTpm.Name -match '1\.2') { $tpmInfo.SpecVersion = '1.2' }
                else { $tpmInfo.SpecVersion = $pnpTpm.Name }

                if ($tpmInfo.ManufacturerIdTxt -eq 'Unknown' -and $pnpTpm.DeviceID -match 'ACPI\\([A-Za-z0-9]{3,4})') {
                    $tpmInfo.ManufacturerIdTxt = $matches[1]
                }
            }
        }
        catch {
            Write-LogEntry "PnP TPM query notice: $($_.Exception.Message)" -Level 'INFO'
        }
    }

    # Classify TPM Type (Discrete dTPM vs Firmware fTPM)
    $mfgUpper = $tpmInfo.ManufacturerIdTxt.ToUpper()
    if ($mfgUpper -in @('AMD', 'INTC', 'QCOM')) {
        $tpmInfo.TpmType = "fTPM (Firmware TPM / $($tpmInfo.ManufacturerIdTxt))"
    }
    elseif ($mfgUpper -in @('IFX', 'NTC', 'STM', 'NTZ', 'ATML', 'SMSC', 'MSFT')) {
        $tpmInfo.TpmType = "dTPM (Discrete Hardware TPM / $($tpmInfo.ManufacturerIdTxt))"
    }
    elseif ($tpmInfo.Present) {
        $tpmInfo.TpmType = "Hardware TPM ($($tpmInfo.ManufacturerIdTxt))"
    }
    else {
        $tpmInfo.TpmType = 'Brak modulu TPM'
    }

    # Evaluate TPM Status
    $specVerNum = 0.0
    if ($tpmInfo.SpecVersion -match '(\d+(\.\d+)?)') {
        $specVerNum = [double]$matches[1]
    }

    if (-not $tpmInfo.Present) {
        $tpmInfo.Status = 'FAIL'
        $tpmInfo.StatusDetails = 'Brak fizycznego lub programowego modulu TPM.'
    }
    elseif (-not $tpmInfo.Ready) {
        $tpmInfo.Status = 'FAIL'
        $tpmInfo.StatusDetails = 'Modul TPM jest obecny, lecz nie jest w stanie gotowosci (Not Ready).'
    }
    elseif ($specVerNum -lt 2.0) {
        $tpmInfo.Status = 'WARN'
        $tpmInfo.StatusDetails = "Wersja specyfikacji TPM ($($tpmInfo.SpecVersion)) jest ponizej standardu TPM 2.0 wymaganego przez NIS2."
    }
    elseif (-not $tpmInfo.Enabled -or -not $tpmInfo.Activated) {
        $tpmInfo.Status = 'WARN'
        $tpmInfo.StatusDetails = 'TPM 2.0 jest gotowy, lecz nie jest w pelni wlaczony lub aktywowany w BIOS/UEFI.'
    }
    else {
        $tpmInfo.Status = 'PASS'
        $tpmInfo.StatusDetails = "TPM 2.0 aktywny i gotowy ($($tpmInfo.TpmType), Firmware: $($tpmInfo.ManufacturerVersion))."
    }

    Write-LogEntry "TPM Assessment: [$($tpmInfo.Status)] - $($tpmInfo.StatusDetails)" -Level $(if ($tpmInfo.Status -eq 'PASS') { 'SUCCESS' } elseif ($tpmInfo.Status -eq 'WARN') { 'WARN' } else { 'ERROR' })

    # Firmware and Secure Boot Verification
    $secureBootInfo = [PSCustomObject]@{
        FirmwareType     = 'Unknown'
        SecureBootStatus = 'Unknown'
        SecureBootBool   = $false
        Status           = 'FAIL'
        StatusDetails    = ''
    }

    try {
        # 1. Firmware Type (UEFI vs BIOS)
        $fw = $env:firmware_type
        if ([string]::IsNullOrWhiteSpace($fw)) {
            try {
                $regFw = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Control" -Name "PEFirmwareType" -ErrorAction SilentlyContinue
                if ($regFw -eq 1) { $fw = 'BIOS' }
                elseif ($regFw -eq 2) { $fw = 'UEFI' }
            } catch { }
        }
        if ([string]::IsNullOrWhiteSpace($fw)) { $fw = 'Unknown' }
        $secureBootInfo.FirmwareType = $fw

        # 2. Secure Boot Status
        $sbTested = $false
        try {
            $sbResult = Confirm-SecureBootUEFI -ErrorAction Stop
            $secureBootInfo.SecureBootBool = [bool]$sbResult
            $secureBootInfo.SecureBootStatus = if ($sbResult) { 'Enabled' } else { 'Disabled' }
            $sbTested = $true
        }
        catch [System.PlatformNotSupportedException] {
            $secureBootInfo.SecureBootStatus = 'NotSupported'
            $secureBootInfo.SecureBootBool = $false
            $sbTested = $true
        }
        catch {
            Write-LogEntry "Confirm-SecureBootUEFI notice: $($_.Exception.Message). Checking registry fallback..." -Level 'INFO'
        }

        if (-not $sbTested) {
            # Registry Fallback for Secure Boot State
            try {
                $regSb = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State" -Name "UEFISecureBootEnabled" -ErrorAction Stop
                if ($regSb -eq 1) {
                    $secureBootInfo.SecureBootStatus = 'Enabled'
                    $secureBootInfo.SecureBootBool = $true
                } else {
                    $secureBootInfo.SecureBootStatus = 'Disabled'
                    $secureBootInfo.SecureBootBool = $false
                }
            }
            catch {
                $secureBootInfo.SecureBootStatus = 'Undetermined'
            }
        }

        # Evaluate Secure Boot Posture
        if ($secureBootInfo.FirmwareType -eq 'BIOS' -or $secureBootInfo.SecureBootStatus -eq 'NotSupported') {
            $secureBootInfo.Status = 'FAIL'
            $secureBootInfo.StatusDetails = 'System uruchomiony w trybie Legacy BIOS. Secure Boot nie jest obslugiwany (niezgodnosc z NIS2).'
        }
        elseif ($secureBootInfo.SecureBootStatus -eq 'Disabled') {
            $secureBootInfo.Status = 'WARN'
            $secureBootInfo.StatusDetails = 'Tryb UEFI aktywny, lecz Bezpieczny Rozruch (Secure Boot) jest wylaczony.'
        }
        elseif ($secureBootInfo.SecureBootStatus -eq 'Enabled') {
            $secureBootInfo.Status = 'PASS'
            $secureBootInfo.StatusDetails = 'Bezpieczny Rozruch (Secure Boot) jest wlaczony i aktywny w trybie UEFI.'
        }
        else {
            $secureBootInfo.Status = 'WARN'
            $secureBootInfo.StatusDetails = "Nie mozna jednoznacznie zweryfikowac Secure Boot ($($secureBootInfo.SecureBootStatus))."
        }

        Write-LogEntry "Secure Boot Assessment: [$($secureBootInfo.Status)] - $($secureBootInfo.StatusDetails)" -Level $(if ($secureBootInfo.Status -eq 'PASS') { 'SUCCESS' } elseif ($secureBootInfo.Status -eq 'WARN') { 'WARN' } else { 'ERROR' })
    }
    catch {
        $secureBootInfo.Status = 'FAIL'
        $secureBootInfo.StatusDetails = "Blad audytu Secure Boot: $($_.Exception.Message)"
        Write-LogEntry "Secure Boot audit error: $($_.Exception.ToString())" -Level 'ERROR'
    }

    # --------------------------------------------------------------------------
    # Step 2: Station Identity & Directory Join Classification
    # --------------------------------------------------------------------------
    Write-Progress -Activity "Audyt bezpieczenstwa stacji roboczej" -Status "Krok 2/4: Weryfikacja typu dolaczenia stacji..." -PercentComplete 45
    Write-LogEntry "Checking device directory join state (dsregcmd /status)..." -Level 'INFO'

    $joinInfo = [PSCustomObject]@{
        AzureAdJoined    = 'NO'
        EnterpriseJoined = 'NO'
        DomainJoined     = 'NO'
        WorkplaceJoined  = 'NO'
        TenantName       = ''
        DomainName       = ''
        JoinType         = 'Workgroup / Standalone'
    }

    try {
        $dsreg = dsregcmd /status 2>&1 | Out-String
        if ($dsreg -match 'AzureAdJoined\s*:\s*(\w+)') { $joinInfo.AzureAdJoined = $matches[1].ToUpper() }
        if ($dsreg -match 'EnterpriseJoined\s*:\s*(\w+)') { $joinInfo.EnterpriseJoined = $matches[1].ToUpper() }
        if ($dsreg -match 'DomainJoined\s*:\s*(\w+)') { $joinInfo.DomainJoined = $matches[1].ToUpper() }
        if ($dsreg -match 'WorkplaceJoined\s*:\s*(\w+)') { $joinInfo.WorkplaceJoined = $matches[1].ToUpper() }
        if ($dsreg -match 'TenantName\s*:\s*([^\r\n]+)') { $joinInfo.TenantName = $matches[1].Trim() }
        if ($dsreg -match 'DomainName\s*:\s*([^\r\n]+)') { $joinInfo.DomainName = $matches[1].Trim() }

        if ($joinInfo.AzureAdJoined -eq 'YES' -and $joinInfo.DomainJoined -eq 'YES') {
            $joinInfo.JoinType = 'Hybrid Microsoft Entra ID Joined'
        }
        elseif ($joinInfo.AzureAdJoined -eq 'YES') {
            $joinInfo.JoinType = 'Microsoft Entra ID Joined'
        }
        elseif ($joinInfo.DomainJoined -eq 'YES') {
            $joinInfo.JoinType = 'Active Directory Domain Joined'
        }
        elseif ($joinInfo.WorkplaceJoined -eq 'YES') {
            $joinInfo.JoinType = 'Workplace Joined (BYOD)'
        }
        else {
            $joinInfo.JoinType = 'Workgroup / Standalone'
        }

        Write-LogEntry "Device Join Classification: $($joinInfo.JoinType) (AzureAdJoined=$($joinInfo.AzureAdJoined), DomainJoined=$($joinInfo.DomainJoined))" -Level 'INFO'
    }
    catch {
        Write-LogEntry "Error querying dsregcmd status: $($_.Exception.Message)" -Level 'WARN'
    }

    # --------------------------------------------------------------------------
    # Step 3: Event Log Escrow Verification (Cloud / AD Backup)
    # --------------------------------------------------------------------------
    Write-Progress -Activity "Audyt bezpieczenstwa stacji roboczej" -Status "Krok 3/4: Weryfikacja historii zdarzen escrow kluczy..." -PercentComplete 65
    Write-LogEntry "Inspecting Event Log 'Microsoft-Windows-BitLocker/BitLocker Management' for Escrow events (845 / 846)..." -Level 'INFO'

    $escrowEventRecords = @()
    try {
        $escrowEventRecords = @(Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-BitLocker/BitLocker Management'
            Id      = 845, 846
        } -MaxEvents 50 -ErrorAction SilentlyContinue)
        Write-LogEntry "Retrieved $($escrowEventRecords.Count) BitLocker escrow event records from Management log." -Level 'INFO'
    }
    catch {
        Write-LogEntry "Notice: Could not query BitLocker Management event log: $($_.Exception.Message)" -Level 'INFO'
    }

    # Function to determine escrow status for a specific volume
    function Get-VolumeEscrowStatus {
        param (
            [string]$MountPoint,
            [string]$VolumeGuid,
            [PSCustomObject]$JoinData,
            [array]$Events
        )

        # Standalone machines do not participate in enterprise key escrow
        if ($JoinData.JoinType -eq 'Workgroup / Standalone') {
            return [PSCustomObject]@{
                EscrowStatus  = 'STANDALONE_NOT_APPLICABLE'
                LastTimestamp = $null
                Details       = 'Stacja autonomiczna (Workgroup) - brak podlaczenia do AD / Entra ID.'
                BadgeClass    = 'badge-info'
                ConsoleTag    = 'PASS'
            }
        }

        $cleanMount = $MountPoint.TrimEnd('\')
        $matchingEvents = @($Events | Where-Object {
            $msg = $_.Message
            if ([string]::IsNullOrWhiteSpace($msg)) { $false }
            else {
                ($cleanMount -and $msg -match [regex]::Escape($cleanMount)) -or
                ($VolumeGuid -and $msg -match [regex]::Escape($VolumeGuid))
            }
        })

        if ($matchingEvents.Count -eq 0 -and $Events.Count -gt 0) {
            $matchingEvents = $Events
        }

        if ($matchingEvents.Count -gt 0) {
            $latestEvent = $matchingEvents[0]
            if ($latestEvent.Id -eq 845) {
                $statusName = if ($JoinData.AzureAdJoined -eq 'YES') { 'SUCCESS_ENTRA' } else { 'SUCCESS_AD' }
                return [PSCustomObject]@{
                    EscrowStatus  = $statusName
                    LastTimestamp = $latestEvent.TimeCreated
                    Details       = "Klucz odzyskiwania pomyslnie zarchiwizowany w katalogu ($statusName) dnia $($latestEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm'))."
                    BadgeClass    = 'badge-pass'
                    ConsoleTag    = 'PASS'
                }
            }
            elseif ($latestEvent.Id -eq 846) {
                return [PSCustomObject]@{
                    EscrowStatus  = 'FAILED_NO_ESCROW'
                    LastTimestamp = $latestEvent.TimeCreated
                    Details       = "Blad wysylania klucza do katalogu (EventID 846) dnia $($latestEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm'))."
                    BadgeClass    = 'badge-fail'
                    ConsoleTag    = 'FAIL'
                }
            }
        }

        return [PSCustomObject]@{
            EscrowStatus  = 'FAILED_NO_ESCROW'
            LastTimestamp = $null
            Details       = 'Stacja dolaczona do AD/Entra, lecz w dzienniku zdarzen brak potwierdzenia escrow (EventID 845).'
            BadgeClass    = 'badge-fail'
            ConsoleTag    = 'FAIL'
        }
    }

    # --------------------------------------------------------------------------
    # Step 4: BitLocker Volumes & Key Protectors Analysis
    # --------------------------------------------------------------------------
    Write-Progress -Activity "Audyt bezpieczenstwa stacji roboczej" -Status "Krok 4/4: Audyt wolumenow BitLocker i generowanie raportu..." -PercentComplete 85
    Write-LogEntry "Auditing BitLocker Volumes and Key Protectors..." -Level 'INFO'

    $volumeResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $rawVolumes = @()

    try {
        $rawVolumes = @(Get-BitLockerVolume -ErrorAction Stop)
        Write-LogEntry "Get-BitLockerVolume identified $($rawVolumes.Count) logical volume(s)." -Level 'INFO'
    }
    catch {
        Write-LogEntry "Get-BitLockerVolume threw: $($_.Exception.Message). Falling back to Get-Volume enumeration..." -Level 'WARN'
        try {
            $sysVolumes = Get-Volume | Where-Object { $_.DriveLetter -or $_.FileSystemLabel }
            foreach ($sv in $sysVolumes) {
                $mount = if ($sv.DriveLetter) { "$($sv.DriveLetter):" } else { $sv.FileSystemLabel }
                $rawVolumes += [PSCustomObject]@{
                    MountPoint           = $mount
                    VolumeType           = if ($mount -match '^C') { 'OperatingSystem' } else { 'Data' }
                    CapacityGB           = [math]::Round(($sv.Size / 1GB), 2)
                    VolumeStatus         = 'Unknown (Access Denied)'
                    EncryptionPercentage = 0
                    EncryptionMethod     = 'Unknown'
                    ProtectionStatus     = 'Unknown'
                    LockStatus           = 'Unlocked'
                    KeyProtector         = @()
                }
            }
        }
        catch {
            Write-LogEntry "Fallback volume enumeration error: $($_.Exception.Message)" -Level 'ERROR'
        }
    }

    $allVolumesCompliant = $true
    $osVolumeFound = $false

    foreach ($vol in $rawVolumes) {
        $mountPoint   = $vol.MountPoint
        $volType      = if ($vol.VolumeType) { [string]$vol.VolumeType } else { 'OperatingSystem' }
        $capGb        = if ($vol.CapacityGB) { [math]::Round([double]$vol.CapacityGB, 2) } else { 0.0 }
        $volStatus    = if ($vol.VolumeStatus) { [string]$vol.VolumeStatus } else { 'FullyDecrypted' }
        $encPercent   = if ($null -ne $vol.EncryptionPercentage) { [int]$vol.EncryptionPercentage } else { 0 }
        $encMethod    = if ($vol.EncryptionMethod) { [string]$vol.EncryptionMethod } else { 'None' }
        $protStatus   = if ($vol.ProtectionStatus) { [string]$vol.ProtectionStatus } else { 'Off' }
        $lockStatus   = if ($vol.LockStatus) { [string]$vol.LockStatus } else { 'Unlocked' }

        if ($volType -eq 'OperatingSystem' -or $mountPoint -eq 'C:') {
            $osVolumeFound = $true
        }

        # Extract Key Protectors (Strictly omitting plaintext secrets)
        $protectorList = @()
        $hasTpmProtector = $false
        $hasRecoveryPassword = $false

        if ($vol.KeyProtector) {
            foreach ($kp in $vol.KeyProtector) {
                $kpType = [string]$kp.KeyProtectorType
                $kpId   = [string]$kp.KeyProtectorId

                if ($kpType -in @('Tpm', 'TpmPin', 'TpmNetworkKey', 'TpmStartupKey')) {
                    $hasTpmProtector = $true
                }
                if ($kpType -in @('RecoveryPassword', 'NumericalPassword')) {
                    $hasRecoveryPassword = $true
                }

                $protectorList += [PSCustomObject]@{
                    Type = $kpType
                    Id   = $kpId
                }
            }
        }

        # Escrow verification for volume
        $escrowResult = Get-VolumeEscrowStatus -MountPoint $mountPoint -VolumeGuid $mountPoint -JoinData $joinInfo -Events $escrowEventRecords

        # Evaluate Volume Posture & NIS2 Compliance
        $volComplianceStatus = 'PASS'
        $complianceReasons = [System.Collections.Generic.List[string]]::new()

        # Check 1: Protection Status & Encryption Percentage
        if ($protStatus -ne 'On' -or $volStatus -ne 'FullyEncrypted' -or $encPercent -lt 100) {
            if ($volType -eq 'OperatingSystem' -or $mountPoint -eq 'C:') {
                $volComplianceStatus = 'FAIL'
                $complianceReasons.Add("Dysk systemowy nie jest w pelni zaszyfrowany ($encPercent%, Status: $volStatus, Ochrona: $protStatus).")
            } else {
                if ($volComplianceStatus -ne 'FAIL') { $volComplianceStatus = 'WARN' }
                $complianceReasons.Add("Wolumen danych nie jest w pelni zaszyfrowany ($encPercent%, Status: $volStatus).")
            }
        }

        # Check 2: Encryption Algorithm (AES-128 vs AES-256)
        if ($encMethod -eq 'None') {
            # Handled above
        }
        elseif ($EnforceAes256) {
            if ($encMethod -notin @('XtsAes256', 'Aes256')) {
                $volComplianceStatus = 'FAIL'
                $complianceReasons.Add("Wymuszona polityka AES-256: Wykryto metode $encMethod (wymagane XTS-AES 256).")
            }
        }
        else {
            if ($encMethod -notin @('XtsAes256', 'XtsAes128', 'Aes256', 'Aes128')) {
                if ($volComplianceStatus -ne 'FAIL') { $volComplianceStatus = 'WARN' }
                $complianceReasons.Add("Wykryto niestandardowy algorytm szyfrowania: $encMethod.")
            }
            elseif ($encMethod -in @('XtsAes128', 'Aes128')) {
                $complianceReasons.Add("Standardowa metoda szyfrowania ($encMethod). Rekomendacja: XTS-AES 256.")
            }
        }

        # Check 3: Key Protectors
        if ($protStatus -eq 'On') {
            if ($volType -eq 'OperatingSystem' -or $mountPoint -eq 'C:') {
                if (-not $hasTpmProtector) {
                    if ($volComplianceStatus -ne 'FAIL') { $volComplianceStatus = 'WARN' }
                    $complianceReasons.Add('Brak sprzetowego protektora TPM na wolumenie systemowym.')
                }
                if (-not $hasRecoveryPassword) {
                    if ($volComplianceStatus -ne 'FAIL') { $volComplianceStatus = 'WARN' }
                    $complianceReasons.Add('Brak klucza odzyskiwania (Recovery Password / Numerical Password).')
                }
            }
        }

        # Check 4: Escrow status
        if ($escrowResult.EscrowStatus -eq 'FAILED_NO_ESCROW') {
            if ($volComplianceStatus -ne 'FAIL') { $volComplianceStatus = 'WARN' }
            $complianceReasons.Add('Brak potwierdzenia kopii zapasowej klucza odzyskiwania w chmurze Entra ID / AD.')
        }

        if ($volComplianceStatus -eq 'PASS' -and $complianceReasons.Count -eq 0) {
            $complianceReasons.Add('Wolumen w pelni zaszyfrowany (100%), protektory aktywne, pelna zgodnosc.')
        }

        if ($volComplianceStatus -eq 'FAIL') {
            $allVolumesCompliant = $false
        }

        $protectorSummary = if ($protectorList.Count -gt 0) { ($protectorList | ForEach-Object { $_.Type }) -join ', ' } else { 'Brak' }

        $volObj = [PSCustomObject]@{
            MountPoint           = $mountPoint
            VolumeType           = $volType
            CapacityGB           = $capGb
            VolumeStatus         = $volStatus
            EncryptionPercentage = $encPercent
            EncryptionMethod     = $encMethod
            ProtectionStatus     = $protStatus
            LockStatus           = $lockStatus
            KeyProtectors        = $protectorList
            ProtectorSummary     = $protectorSummary
            HasTpmProtector      = $hasTpmProtector
            HasRecoveryPassword  = $hasRecoveryPassword
            EscrowStatus         = $escrowResult.EscrowStatus
            EscrowDetails        = $escrowResult.Details
            EscrowTimestamp      = $escrowResult.LastTimestamp
            ComplianceStatus     = $volComplianceStatus
            ComplianceDetails    = ($complianceReasons -join ' ')
        }

        $volumeResults.Add($volObj)

        Write-LogEntry "Volume $mountPoint ($volType): Status=$volStatus, Enc=$encPercent%, Method=$encMethod, Prot=$protStatus, Escrow=$($escrowResult.EscrowStatus), Compliance=[$volComplianceStatus]" -Level $(if ($volComplianceStatus -eq 'PASS') { 'SUCCESS' } elseif ($volComplianceStatus -eq 'WARN') { 'WARN' } else { 'ERROR' })
    }

    # --------------------------------------------------------------------------
    # Overall NIS2 & Zero-Trust Compliance Evaluation
    # --------------------------------------------------------------------------
    $globalCompliant = $true
    $criticalFindings = [System.Collections.Generic.List[string]]::new()
    $warningFindings = [System.Collections.Generic.List[string]]::new()
    $passFindings = [System.Collections.Generic.List[string]]::new()

    # Hardware Root of Trust Checks
    if ($tpmInfo.Status -eq 'PASS') {
        $passFindings.Add("Sprzetowy modul zaufania TPM 2.0 aktywny i gotowy ($($tpmInfo.TpmType)).")
    } elseif ($tpmInfo.Status -eq 'WARN') {
        $warningFindings.Add("Modul TPM wymaga uwagi: $($tpmInfo.StatusDetails)")
    } else {
        $globalCompliant = $false
        $criticalFindings.Add("Krytyczny brak modulu TPM 2.0: $($tpmInfo.StatusDetails)")
    }

    if ($secureBootInfo.Status -eq 'PASS') {
        $passFindings.Add('Bezpieczny Rozruch UEFI (Secure Boot) jest wlaczony.')
    } elseif ($secureBootInfo.Status -eq 'WARN') {
        $warningFindings.Add("Secure Boot wylaczony lub ograniczony: $($secureBootInfo.StatusDetails)")
    } else {
        $globalCompliant = $false
        $criticalFindings.Add("Krytyczny brak Secure Boot: $($secureBootInfo.StatusDetails)")
    }

    # Volumes & Encryption Checks
    $osVolume = $volumeResults | Where-Object { $_.VolumeType -eq 'OperatingSystem' -or $_.MountPoint -eq 'C:' } | Select-Object -First 1
    if ($osVolume) {
        if ($osVolume.ComplianceStatus -eq 'PASS') {
            $passFindings.Add("Dysk systemowy ($($osVolume.MountPoint)) jest w pelni zaszyfrowany ($($osVolume.EncryptionMethod), 100%).")
        } elseif ($osVolume.ComplianceStatus -eq 'WARN') {
            $warningFindings.Add("Dysk systemowy ($($osVolume.MountPoint)): $($osVolume.ComplianceDetails)")
        } else {
            $globalCompliant = $false
            $criticalFindings.Add("Krytyczny stan dysku systemowego ($($osVolume.MountPoint)): $($osVolume.ComplianceDetails)")
        }

        if ($osVolume.EscrowStatus -in @('SUCCESS_ENTRA', 'SUCCESS_AD')) {
            $passFindings.Add("Klucz odzyskiwania BitLocker zostal pomyslnie zarchiwizowany w chmurze/AD ($($osVolume.EscrowStatus)).")
        } elseif ($osVolume.EscrowStatus -eq 'STANDALONE_NOT_APPLICABLE') {
            $passFindings.Add('Stacja autonomiczna (Workgroup) - escrow w AD/Entra ID nie dotyczy.')
        } else {
            $warningFindings.Add("Brak potwierdzenia escrow klucza odzyskiwania w chmurze/AD dla dysku systemowego ($($osVolume.EscrowStatus)).")
        }
    } else {
        $globalCompliant = $false
        $criticalFindings.Add('Nie wykryto wolumenu systemowego (C:).')
    }

    # Data volumes check
    $dataVolumes = @($volumeResults | Where-Object { $_ -ne $osVolume })
    foreach ($dv in $dataVolumes) {
        if ($dv.ComplianceStatus -eq 'FAIL') {
            $criticalFindings.Add("Wolumen danych $($dv.MountPoint) nie jest zabezpieczony: $($dv.ComplianceDetails)")
        } elseif ($dv.ComplianceStatus -eq 'WARN') {
            $warningFindings.Add("Wolumen danych $($dv.MountPoint): $($dv.ComplianceDetails)")
        } else {
            $passFindings.Add("Wolumen danych $($dv.MountPoint) w pelni zaszyfrowany ($($dv.EncryptionMethod)).")
        }
    }

    $overallStatus = if ($globalCompliant -and $warningFindings.Count -eq 0) {
        'NIS2 Ready (Pelna Zgodnosc)'
    } elseif ($globalCompliant) {
        'NIS2 Provisionally Compliant (Zastrzezenia)'
    } else {
        'Non-Compliant (Niezgodny z NIS2)'
    }

    $overallTag = if (-not $globalCompliant) { 'FAIL' } elseif ($warningFindings.Count -gt 0) { 'WARN' } else { 'PASS' }

    Write-LogEntry "Overall Compliance Evaluation: $overallStatus (StatusTag: $overallTag, Critical: $($criticalFindings.Count), Warnings: $($warningFindings.Count))" -Level $(if ($overallTag -eq 'PASS') { 'SUCCESS' } elseif ($overallTag -eq 'WARN') { 'WARN' } else { 'ERROR' })

    # --------------------------------------------------------------------------
    # Console Summary Rendering
    # --------------------------------------------------------------------------
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host " WYNIKI AUDYTU KRYPTOGRAFICZNEGO I SPRZETOWEGO (NIS2 / ZERO-TRUST)" -ForegroundColor White
    Write-Host " Hostname: $($env:COMPUTERNAME) | Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "================================================================================" -ForegroundColor Cyan

    Write-Host "`n[1] SPRZETOWA WARSTWA ZAUFANIA (HARDWARE ROOT OF TRUST)" -ForegroundColor Yellow
    Write-StatusRow -Category "Modul TPM" -Item "Obecnosc i Wersja" -Status $tpmInfo.Status -Details "$($tpmInfo.SpecVersion) ($($tpmInfo.TpmType))"
    Write-StatusRow -Category "Modul TPM" -Item "Stan Gotowosci" -Status $(if ($tpmInfo.Ready) { 'PASS' } else { 'FAIL' }) -Details "Ready: $($tpmInfo.Ready), Enabled: $($tpmInfo.Enabled), Activated: $($tpmInfo.Activated)"
    Write-StatusRow -Category "Bezpieczny Rozruch" -Item "Tryb Firmware" -Status $(if ($secureBootInfo.FirmwareType -eq 'UEFI') { 'PASS' } else { 'FAIL' }) -Details "$($secureBootInfo.FirmwareType)"
    Write-StatusRow -Category "Bezpieczny Rozruch" -Item "Secure Boot UEFI" -Status $secureBootInfo.Status -Details "$($secureBootInfo.SecureBootStatus)"

    Write-Host "`n[2] TOZSAMOSC STACJI I ARCHIWIZACJA KLUCZY (ESCROW)" -ForegroundColor Yellow
    Write-StatusRow -Category "Tozsamosc Maszyny" -Item "Typ Dolaczenia" -Status "PASS" -Details "$($joinInfo.JoinType)"
    if ($joinInfo.TenantName) {
        Write-StatusRow -Category "Microsoft Entra ID" -Item "Tenant Name" -Status "PASS" -Details "$($joinInfo.TenantName)"
    }
    if ($joinInfo.DomainName) {
        Write-StatusRow -Category "Active Directory" -Item "Domain Name" -Status "PASS" -Details "$($joinInfo.DomainName)"
    }

    Write-Host "`n[3] SZYFROWANIE WOLUMENOW BITLOCKER" -ForegroundColor Yellow
    foreach ($vr in $volumeResults) {
        Write-StatusRow -Category "Dysk $($vr.MountPoint)" -Item "Stan Szyfrowania" -Status $vr.ComplianceStatus -Details "$($vr.VolumeStatus) ($($vr.EncryptionPercentage)%, $($vr.EncryptionMethod))"
        Write-StatusRow -Category "Dysk $($vr.MountPoint)" -Item "Protektory Kluczy" -Status $(if ($vr.HasRecoveryPassword) { 'PASS' } else { 'WARN' }) -Details "$($vr.ProtectorSummary)"
        Write-StatusRow -Category "Dysk $($vr.MountPoint)" -Item "Status Escrow" -Status $(if ($vr.EscrowStatus -match 'SUCCESS|STANDALONE') { 'PASS' } else { 'FAIL' }) -Details "$($vr.EscrowStatus)"
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    $statusColor = switch ($overallTag) { 'PASS' { 'Green' } 'WARN' { 'Yellow' } default { 'Red' } }
    Write-Host " PODSUMOWANIE ZGODNOSCI NIS2: " -NoNewline -ForegroundColor White
    Write-Host "[$overallTag] $overallStatus" -ForegroundColor $statusColor
    Write-Host "================================================================================`n" -ForegroundColor Cyan

    # --------------------------------------------------------------------------
    # Step 5: Standalone HTML Report Generation
    # --------------------------------------------------------------------------
    Write-LogEntry "Generating modern standalone HTML report at '$PathHtmlReport'..." -Level 'INFO'

    $osDetails = $null
    try {
        $osDetails = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    } catch { }

    $osCaption = if ($osDetails) { $osDetails.Caption } else { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName }
    $osVersion = if ($osDetails) { $osDetails.Version } else { [System.Environment]::OSVersion.Version.ToString() }
    $osArch    = if ($osDetails) { $osDetails.OSArchitecture } else { $env:PROCESSOR_ARCHITECTURE }

    $htmlTpmBadge = switch ($tpmInfo.Status) { 'PASS' { 'badge-pass' } 'WARN' { 'badge-warn' } default { 'badge-fail' } }
    $htmlSbBadge  = switch ($secureBootInfo.Status) { 'PASS' { 'badge-pass' } 'WARN' { 'badge-warn' } default { 'badge-fail' } }
    $htmlGlobalBadge = switch ($overallTag) { 'PASS' { 'badge-pass' } 'WARN' { 'badge-warn' } default { 'badge-fail' } }

    # Build Volume HTML Rows using [System.Net.WebUtility]::HtmlEncode
    $volTableRowsHtml = [System.Text.StringBuilder]::new()
    foreach ($v in $volumeResults) {
        $badgeClass = switch ($v.ComplianceStatus) { 'PASS' { 'badge-pass' } 'WARN' { 'badge-warn' } default { 'badge-fail' } }
        $escrowBadge = switch ($v.EscrowStatus) {
            'SUCCESS_ENTRA'             { 'badge-pass' }
            'SUCCESS_AD'                { 'badge-pass' }
            'STANDALONE_NOT_APPLICABLE' { 'badge-info' }
            default                     { 'badge-fail' }
        }

        [void]$volTableRowsHtml.AppendLine(@"
        <tr>
            <td><strong>$([System.Net.WebUtility]::HtmlEncode($v.MountPoint))</strong></td>
            <td>$([System.Net.WebUtility]::HtmlEncode($v.VolumeType))</td>
            <td>$($v.CapacityGB) GB</td>
            <td>
                <span class="badge $badgeClass">$($v.VolumeStatus)</span>
                <span style="font-size:0.85em; color:var(--text-secondary); margin-left:6px;">$($v.EncryptionPercentage)%</span>
            </td>
            <td><code>$([System.Net.WebUtility]::HtmlEncode($v.EncryptionMethod))</code></td>
            <td>$([System.Net.WebUtility]::HtmlEncode($v.ProtectionStatus))</td>
            <td>
                <div>$([System.Net.WebUtility]::HtmlEncode($v.ProtectorSummary))</div>
            </td>
            <td><span class="badge $escrowBadge">$([System.Net.WebUtility]::HtmlEncode($v.EscrowStatus))</span></td>
            <td>$([System.Net.WebUtility]::HtmlEncode($v.ComplianceDetails))</td>
        </tr>
"@)
    }

    # Build Findings HTML
    $findingsHtml = [System.Text.StringBuilder]::new()
    if ($criticalFindings.Count -gt 0) {
        [void]$findingsHtml.AppendLine("<h4 style='color:var(--color-fail); margin-top:16px;'>Niezgodnosci Krytyczne (Wymagane Dzialanie)</h4><ul class='findings-list fail-list'>")
        foreach ($cf in $criticalFindings) {
            [void]$findingsHtml.AppendLine("<li><strong>[FAIL]</strong> $([System.Net.WebUtility]::HtmlEncode($cf))</li>")
        }
        [void]$findingsHtml.AppendLine("</ul>")
    }

    if ($warningFindings.Count -gt 0) {
        [void]$findingsHtml.AppendLine("<h4 style='color:var(--color-warn); margin-top:16px;'>Ostrzezenia i Zalecenia Optymalizacyjne</h4><ul class='findings-list warn-list'>")
        foreach ($wf in $warningFindings) {
            [void]$findingsHtml.AppendLine("<li><strong>[WARN]</strong> $([System.Net.WebUtility]::HtmlEncode($wf))</li>")
        }
        [void]$findingsHtml.AppendLine("</ul>")
    }

    if ($passFindings.Count -gt 0) {
        [void]$findingsHtml.AppendLine("<h4 style='color:var(--color-pass); margin-top:16px;'>Pozytywnie Zweryfikowane Mechanizmy Ochrony</h4><ul class='findings-list pass-list'>")
        foreach ($pf in $passFindings) {
            [void]$findingsHtml.AppendLine("<li><strong>[PASS]</strong> $([System.Net.WebUtility]::HtmlEncode($pf))</li>")
        }
        [void]$findingsHtml.AppendLine("</ul>")
    }

    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Raport Audytu BitLocker & TPM - $($env:COMPUTERNAME)</title>
    <style>
        :root {
            --bg-body: #0d1117;
            --bg-card: #161b22;
            --bg-card-subtle: #21262d;
            --text-primary: #f0f6fc;
            --text-secondary: #8b949e;
            --border-color: #30363d;
            --color-pass: #238636;
            --color-pass-text: #3fb950;
            --color-warn: #9e6a03;
            --color-warn-text: #d29922;
            --color-fail: #da3633;
            --color-fail-text: #f85149;
            --color-info: #1f6feb;
            --color-info-text: #58a6ff;
            --accent-cyan: #39c5cf;
        }

        [data-theme="light"] {
            --bg-body: #f6f8fa;
            --bg-card: #ffffff;
            --bg-card-subtle: #eaeef2;
            --text-primary: #1f2328;
            --text-secondary: #656d76;
            --border-color: #d0d7de;
            --color-pass: #1a7f37;
            --color-pass-text: #1a7f37;
            --color-warn: #9a6700;
            --color-warn-text: #9a6700;
            --color-fail: #cf222e;
            --color-fail-text: #cf222e;
            --color-info: #0969da;
            --color-info-text: #0969da;
            --accent-cyan: #057a85;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }

        body {
            background-color: var(--bg-body);
            color: var(--text-primary);
            padding: 28px 20px;
            line-height: 1.5;
            transition: background-color 0.2s, color 0.2s;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 20px;
            margin-bottom: 24px;
        }

        .header-title h1 {
            font-size: 1.8rem;
            font-weight: 700;
            letter-spacing: -0.5px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .header-title p {
            color: var(--text-secondary);
            font-size: 0.95rem;
            margin-top: 4px;
        }

        .theme-toggle-btn {
            background: var(--bg-card-subtle);
            color: var(--text-primary);
            border: 1px solid var(--border-color);
            padding: 8px 14px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.85rem;
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .theme-toggle-btn:hover {
            border-color: var(--text-secondary);
        }

        /* Metrics Grid */
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }

        .metric-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.12);
        }

        .metric-label {
            color: var(--text-secondary);
            font-size: 0.8rem;
            text-transform: uppercase;
            font-weight: 600;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }

        .metric-value {
            font-size: 1.25rem;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        /* Status Badges */
        .badge {
            display: inline-flex;
            align-items: center;
            padding: 3px 10px;
            border-radius: 12px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.3px;
        }

        .badge-pass {
            background-color: rgba(63, 185, 80, 0.15);
            color: var(--color-pass-text);
            border: 1px solid rgba(63, 185, 80, 0.4);
        }

        .badge-warn {
            background-color: rgba(210, 153, 34, 0.15);
            color: var(--color-warn-text);
            border: 1px solid rgba(210, 153, 34, 0.4);
        }

        .badge-fail {
            background-color: rgba(248, 81, 73, 0.15);
            color: var(--color-fail-text);
            border: 1px solid rgba(248, 81, 73, 0.4);
        }

        .badge-info {
            background-color: rgba(88, 166, 255, 0.15);
            color: var(--color-info-text);
            border: 1px solid rgba(88, 166, 255, 0.4);
        }

        /* Section Cards */
        .section-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 22px;
            margin-bottom: 24px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.12);
        }

        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 10px;
        }

        .section-header h2 {
            font-size: 1.2rem;
            font-weight: 600;
        }

        /* Key-Value Table */
        .details-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 14px;
        }

        .detail-item {
            background: var(--bg-card-subtle);
            padding: 10px 14px;
            border-radius: 6px;
            border: 1px solid var(--border-color);
        }

        .detail-item .key {
            font-size: 0.8rem;
            color: var(--text-secondary);
            text-transform: uppercase;
            font-weight: 600;
        }

        .detail-item .val {
            font-size: 0.95rem;
            font-weight: 600;
            margin-top: 4px;
        }

        /* Responsive Tables */
        .table-responsive {
            overflow-x: auto;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9rem;
            text-align: left;
        }

        th {
            background: var(--bg-card-subtle);
            color: var(--text-secondary);
            font-weight: 600;
            padding: 10px 12px;
            border-bottom: 1px solid var(--border-color);
            text-transform: uppercase;
            font-size: 0.75rem;
            letter-spacing: 0.5px;
        }

        td {
            padding: 12px 12px;
            border-bottom: 1px solid var(--border-color);
            vertical-align: middle;
        }

        tr:hover {
            background-color: var(--bg-card-subtle);
        }

        code {
            font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
            background: var(--bg-card-subtle);
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.85em;
        }

        /* Findings Lists */
        .findings-list {
            list-style: none;
            margin-top: 8px;
        }

        .findings-list li {
            padding: 8px 12px;
            margin-bottom: 6px;
            border-radius: 6px;
            font-size: 0.9rem;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .fail-list li {
            background: rgba(248, 81, 73, 0.1);
            border-left: 4px solid var(--color-fail-text);
        }

        .warn-list li {
            background: rgba(210, 153, 34, 0.1);
            border-left: 4px solid var(--color-warn-text);
        }

        .pass-list li {
            background: rgba(63, 185, 80, 0.1);
            border-left: 4px solid var(--color-pass-text);
        }

        footer {
            margin-top: 32px;
            text-align: center;
            color: var(--text-secondary);
            font-size: 0.85rem;
            border-top: 1px solid var(--border-color);
            padding-top: 16px;
        }

        @media print {
            body { background: #fff !important; color: #000 !important; }
            .theme-toggle-btn { display: none !important; }
            .section-card { border: 1px solid #ccc !important; box-shadow: none !important; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-title">
                <h1>🛡️ Audyt BitLocker & TPM</h1>
                <p>Zgodnosc z Dyrektywa NIS2 i Architektura Zero-Trust &bull; <strong>$([System.Net.WebUtility]::HtmlEncode($env:COMPUTERNAME))</strong> &bull; $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            </div>
            <div>
                <button class="theme-toggle-btn" onclick="toggleTheme()" id="themeBtn">🌓 Przelacz Motyw</button>
            </div>
        </header>

        <!-- KPI Metrics Grid -->
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">Status Zgodnosci NIS2</div>
                <div class="metric-value">
                    <span class="badge $htmlGlobalBadge">$overallTag</span>
                    <span style="font-size:0.9rem; font-weight:600;">$overallStatus</span>
                </div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Sprzetowy TPM 2.0</div>
                <div class="metric-value">
                    <span class="badge $htmlTpmBadge">$($tpmInfo.Status)</span>
                    <span style="font-size:0.9rem; font-weight:600;">$($tpmInfo.SpecVersion)</span>
                </div>
            </div>
            <div class="metric-card">
                <div class="metric-label">UEFI Secure Boot</div>
                <div class="metric-value">
                    <span class="badge $htmlSbBadge">$($secureBootInfo.Status)</span>
                    <span style="font-size:0.9rem; font-weight:600;">$($secureBootInfo.SecureBootStatus)</span>
                </div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Typ Dolaczenia Stacji</div>
                <div class="metric-value">
                    <span class="badge badge-info">$($joinInfo.AzureAdJoined.Trim()) / $($joinInfo.DomainJoined.Trim())</span>
                    <span style="font-size:0.85rem; font-weight:500;">$([System.Net.WebUtility]::HtmlEncode($joinInfo.JoinType))</span>
                </div>
            </div>
        </div>

        <!-- Section 1: System & Machine Profile -->
        <div class="section-card">
            <div class="section-header">
                <h2>1. Metadane Stacji Roboczej</h2>
            </div>
            <div class="details-grid">
                <div class="detail-item">
                    <div class="key">Nazwa Komputera</div>
                    <div class="val">$([System.Net.WebUtility]::HtmlEncode($env:COMPUTERNAME))</div>
                </div>
                <div class="detail-item">
                    <div class="key">System Operacyjny</div>
                    <div class="val">$([System.Net.WebUtility]::HtmlEncode($osCaption)) ($osVersion)</div>
                </div>
                <div class="detail-item">
                    <div class="key">Architektura</div>
                    <div class="val">$osArch</div>
                </div>
                <div class="detail-item">
                    <div class="key">Tozsamosc / Katalog</div>
                    <div class="val">$([System.Net.WebUtility]::HtmlEncode($joinInfo.JoinType))</div>
                </div>
                <div class="detail-item">
                    <div class="key">Polityka AES-256</div>
                    <div class="val">$(if ($EnforceAes256) { 'Wymuszona (Enforced)' } else { 'Standardowa (XTS-AES 128/256)' })</div>
                </div>
                <div class="detail-item">
                    <div class="key">Data i Czas Skanowania</div>
                    <div class="val">$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
                </div>
            </div>
        </div>

        <!-- Section 2: Hardware Root of Trust -->
        <div class="section-card">
            <div class="section-header">
                <h2>2. Sprzetowa Warstwa Zaufania (Hardware Root of Trust)</h2>
                <span class="badge $htmlTpmBadge">TPM: $($tpmInfo.Status)</span>
            </div>
            <div class="details-grid">
                <div class="detail-item">
                    <div class="key">Obecnosc Modulu TPM</div>
                    <div class="val">$(if ($tpmInfo.Present) { 'Obecny (True)' } else { 'Brak (False)' })</div>
                </div>
                <div class="detail-item">
                    <div class="key">Stan Gotowosci (Ready)</div>
                    <div class="val">$(if ($tpmInfo.Ready) { 'Gotowy (Ready)' } else { 'Niegotowy (Not Ready)' })</div>
                </div>
                <div class="detail-item">
                    <div class="key">Specyfikacja TPM</div>
                    <div class="val">$([System.Net.WebUtility]::HtmlEncode($tpmInfo.SpecVersion))</div>
                </div>
                <div class="detail-item">
                    <div class="key">Typ / Implementacja</div>
                    <div class="val">$([System.Net.WebUtility]::HtmlEncode($tpmInfo.TpmType))</div>
                </div>
                <div class="detail-item">
                    <div class="key">Producent & Wersja Firmware</div>
                    <div class="val">$([System.Net.WebUtility]::HtmlEncode($tpmInfo.ManufacturerIdTxt)) (v$([System.Net.WebUtility]::HtmlEncode($tpmInfo.ManufacturerVersion)))</div>
                </div>
                <div class="detail-item">
                    <div class="key">Tryb Firmware Plyty</div>
                    <div class="val">$([System.Net.WebUtility]::HtmlEncode($secureBootInfo.FirmwareType))</div>
                </div>
                <div class="detail-item">
                    <div class="key">Bezpieczny Rozruch (Secure Boot)</div>
                    <div class="val"><span class="badge $htmlSbBadge">$($secureBootInfo.SecureBootStatus)</span></div>
                </div>
                <div class="detail-item">
                    <div class="key">Ocena Warstwy Sprzetowej</div>
                    <div class="val">$([System.Net.WebUtility]::HtmlEncode($tpmInfo.StatusDetails))</div>
                </div>
            </div>
        </div>

        <!-- Section 3: BitLocker Volumes & Protectors -->
        <div class="section-card">
            <div class="section-header">
                <h2>3. Szyfrowanie Wolumenow BitLocker</h2>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Punkt Montowania</th>
                            <th>Typ</th>
                            <th>Pojemnosc</th>
                            <th>Stan Szyfrowania</th>
                            <th>Algorytm</th>
                            <th>Ochrona</th>
                            <th>Protektory Klucza</th>
                            <th>Status Escrow</th>
                            <th>Ocena Zgodnosci</th>
                        </tr>
                    </thead>
                    <tbody>
$($volTableRowsHtml.ToString())
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Section 4: Security Findings & NIS2 Recommendations -->
        <div class="section-card">
            <div class="section-header">
                <h2>4. Analiza Zgodnosci i Zalecenia Audytora (NIS2 / Zero-Trust)</h2>
            </div>
$($findingsHtml.ToString())
        </div>

        <footer>
            <p>Wygenerowano automatycznie przez <strong>Audit-BitLockerAndTpmStatus</strong> v1.0.0 &bull; Autor: Roman Pindela (roman.pindela@gmail.com)</p>
            <p>Plik dziennika wykonawczego: <code>$([System.Net.WebUtility]::HtmlEncode($script:LogFilePath))</code></p>
        </footer>
    </div>

    <script>
        function toggleTheme() {
            var currentTheme = document.documentElement.getAttribute('data-theme');
            var newTheme = currentTheme === 'light' ? 'dark' : 'light';
            document.documentElement.setAttribute('data-theme', newTheme);
            localStorage.setItem('bitlocker_audit_theme', newTheme);
        }

        var savedTheme = localStorage.getItem('bitlocker_audit_theme');
        if (savedTheme) {
            document.documentElement.setAttribute('data-theme', savedTheme);
        } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
            document.documentElement.setAttribute('data-theme', 'light');
        }
    </script>
</body>
</html>
"@

    # Ensure parent directory exists for PathHtmlReport
    $reportDir = Split-Path -Path $PathHtmlReport -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDir) -and -not (Test-Path -Path $reportDir -PathType Container)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($PathHtmlReport, $htmlTemplate, [System.Text.Encoding]::UTF8)
    Write-LogEntry "HTML report successfully saved to: $PathHtmlReport" -Level 'SUCCESS'
    Write-Host "  Raport HTML wygenerowany: " -NoNewline -ForegroundColor Gray
    Write-Host "$PathHtmlReport" -ForegroundColor White
    Write-Host "  Dziennik wykonawczy:       $script:LogFilePath`n" -ForegroundColor Gray

    # Open HTML report if requested
    if ($OpenReport) {
        Write-LogEntry "Opening generated HTML report in default browser..." -Level 'INFO'
        Start-Process $PathHtmlReport
    }

    # --------------------------------------------------------------------------
    # Pipeline Output (PassThru)
    # --------------------------------------------------------------------------
    $auditResultObject = [PSCustomObject]@{
        ComputerName        = $env:COMPUTERNAME
        Timestamp           = (Get-Date)
        OverallCompliance   = $overallStatus
        ComplianceTag       = $overallTag
        TpmInfo             = $tpmInfo
        SecureBootInfo      = $secureBootInfo
        JoinInfo            = $joinInfo
        Volumes             = $volumeResults.ToArray()
        CriticalFindings    = $criticalFindings.ToArray()
        WarningFindings     = $warningFindings.ToArray()
        PassFindings        = $passFindings.ToArray()
        HtmlReportPath      = $PathHtmlReport
        LogFilePath         = $script:LogFilePath
    }

    if ($PassThru) {
        Write-Output $auditResultObject
    }
}

# ==============================================================================
# Script Lifecycle: End Block
# ==============================================================================

end {
    if (-not $script:IsHelpRequested) {
        Write-LogEntry "Audit-BitLockerAndTpmStatus execution session ended." -Level 'INFO'
    }
}
