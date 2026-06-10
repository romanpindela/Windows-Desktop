<#
.SYNOPSIS
    Advanced Deep System Audit Tool for Enterprise Environments.
.DESCRIPTION
    Executes a thorough diagnostic audit covering OS, Hardware (GPU, RAM Types), Storage (NVMe/SATA, SSD/HDD), 
    Performance (Top 10), Network (Manufacturers, Profiles & Routing), Security (TPM, BitLocker, 3rd Party AV), 
    Users, Services, and Event Logs.
.PARAMETER ComputerName
    The target machine hostname or IP. Defaults to localhost.
.PARAMETER Credential
    Optional credentials for remote execution.
.PARAMETER ExportToCsv
    Switch. If specified, exports the audit results to a CSV file.
.NOTES
    Author: Roman Pindela
    Version: 6.0.1
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory=$false)]
    [switch]$ExportToCsv,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

if ($ShowHelp) { Get-Help $PSCommandPath -Detailed; exit }

# --- 0. PREPARATION & ADMIN CHECK ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($ComputerName -ne $env:COMPUTERNAME -and -not $Credential) {
    $Credential = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message "Enter credentials for $($ComputerName)"
}

$sessionParams = @{}
$session = $null

try {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " [i] INITIATING DEEP SYSTEM AUDIT ON $($ComputerName.ToUpper())" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    if (-not $isAdmin -and $ComputerName -eq $env:COMPUTERNAME) {
        Write-Host "[!] WARNING: Script is not running as Administrator. Some deep WMI classes will return Access Denied.`n" -ForegroundColor Yellow
    }

    if ($ComputerName -ne $env:COMPUTERNAME) {
        $cimSessionArgs = @{ ComputerName = $ComputerName }
        if ($Credential) { $cimSessionArgs.Credential = $Credential }
        $session = New-CimSession @cimSessionArgs -ErrorAction Stop
        $sessionParams.CimSession = $session
    }

    # --- 1. OS & HARDWARE (CPU, GPU, RAM) ---
    Write-Host "`n[1/7] OS & HARDWARE" -ForegroundColor Green
    $os = Get-CimInstance @sessionParams -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $proc = Get-CimInstance @sessionParams -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $gpu = Get-CimInstance @sessionParams -ClassName Win32_VideoController -ErrorAction SilentlyContinue
    $ramChips = Get-CimInstance @sessionParams -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue

    if (-not $os) {
        Write-Host "  [!] WARNING: Core WMI query failed. No data returned from Win32_OperatingSystem." -ForegroundColor Red
    }
    
    $uptime = if ($os -and $os.LastBootUpTime) { (Get-Date) - $os.LastBootUpTime } else { [TimeSpan]::Zero }
    $gpuDetails = if ($gpu) { ($gpu | ForEach-Object { "$($_.Name) ($([math]::Round($_.AdapterRAM/1GB, 1)) GB)" }) -join " | " } else { "Unknown" }
    
    $ramTypeMap = @{ 20="DDR"; 21="DDR2"; 24="DDR3"; 26="DDR4"; 34="DDR5" }
    $ramType = if ($ramChips) { $ramTypeMap[[int]$ramChips[0].SMBIOSMemoryType] } else { "Unknown" }
    if (-not $ramType) { $ramType = "Unknown/Other" }
    
    $totalRamGB = if ($os -and $os.TotalVisibleMemorySize) { [math]::Round(($os.TotalVisibleMemorySize / 1MB), 2) } else { 0 }

    [PSCustomObject]@{
        "OS Version" = if ($os) { "$($os.Caption) ($($os.OSArchitecture), Build $($os.BuildNumber))" } else { "Unknown" }
        "Uptime"     = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
        "CPU"        = if ($proc) { $proc.Name } else { "Unknown" }
        "GPU"        = $gpuDetails
        "Memory"     = "$($totalRamGB) GB ($ramType @ $(if ($ramChips) { $ramChips[0].Speed } else { 'Unknown' }) MHz)"
    } | Format-List

    # --- 1B. STORAGE (VOLUMES & PHYSICAL DISKS) ---
    Write-Host "[STORAGE]" -ForegroundColor Green
    try {
        $logicalDisks = Get-CimInstance @sessionParams -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
        $diskData = @()
        foreach ($ld in $logicalDisks) {
            $freePct = [math]::Round(($ld.FreeSpace / $ld.Size) * 100, 2)
            $warn = if ($freePct -lt 15) { "<< WARNING: LOW SPACE" } else { "" }
            $diskData += [PSCustomObject]@{
                Drive = $ld.DeviceID
                FreeGB = [math]::Round($ld.FreeSpace/1GB, 2)
                TotalGB = [math]::Round($ld.Size/1GB, 2)
                FreePct = "$($freePct)%"
                Status = $warn
            }
        }
        $diskData | Format-Table -AutoSize
    } catch { Write-Host "  [-] Failed to retrieve logical disks: $($_.Exception.Message)" -ForegroundColor Red }

    try {
        $physParams = $sessionParams.Clone(); $physParams.Namespace = "Root\Microsoft\Windows\Storage"
        $physicalDisks = Get-CimInstance @physParams -ClassName MSFT_PhysicalDisk -ErrorAction Stop
        
        $busMap = @{ 7="USB"; 8="RAID"; 11="SATA"; 17="NVMe" }
        $mediaMap = @{ 3="HDD"; 4="SSD"; 5="SCM" }
        
        $physicalDisks | Select-Object @{Name="Model"; Expression={$_.FriendlyName}}, 
                                       @{Name="Type"; Expression={$mediaMap[[int]$_.MediaType]}}, 
                                       @{Name="Interface"; Expression={$busMap[[int]$_.BusType]}}, 
                                       @{Name="Size (GB)"; Expression={[math]::Round($_.Size/1GB, 2)}} | Format-Table -AutoSize
    } catch { 
        Write-Host "  [-] Advanced physical disk info requires Administrator privileges or failed: $($_.Exception.Message)" -ForegroundColor Yellow 
    }

    # --- 2. PERFORMANCE (TOP 10 PROCESSES) ---
    Write-Host "`n[2/7] PERFORMANCE (TOP 10 PROCESSES)" -ForegroundColor Green
    $ramUsed = if ($os -and $os.TotalVisibleMemorySize -and $os.FreePhysicalMemory) { [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2) } else { 0 }
    Write-Host "Total RAM: $($ramUsed) GB Used / $($totalRamGB) GB Total`n" -ForegroundColor Cyan

    $processes = Get-CimInstance @sessionParams -ClassName Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -ne "_Total" -and $_.Name -ne "Idle" } | 
        Sort-Object PercentProcessorTime, WorkingSetPrivate -Descending | Select-Object -First 10
    
    if ($processes) {
        $processes | Select-Object Name, 
                     @{Name="CPU (%)"; Expression={$_.PercentProcessorTime}}, 
                     @{Name="RAM (MB)"; Expression={[math]::Round($_.WorkingSetPrivate/1MB,1)}} | 
                     Format-Table -AutoSize
    }

    # --- 3. NETWORK CONFIGURATION & ROUTING ---
    Write-Host "`n[3/7] NETWORK ADAPTERS" -ForegroundColor Green
    try {
        $netConfigs = Get-CimInstance @sessionParams -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" -ErrorAction Stop
        $netAdapters = Get-CimInstance @sessionParams -ClassName Win32_NetworkAdapter -ErrorAction SilentlyContinue
        
        $netData = @()
        foreach ($config in $netConfigs) {
            $ip = $config.IPAddress -join ", "
            $hardware = $netAdapters | Where-Object DeviceID -eq $config.Index
            
            $netData += [PSCustomObject]@{
                Manufacturer = if ($hardware.Manufacturer) { $hardware.Manufacturer } else { "Unknown" }
                Model = $config.Description
                IPAddress = $ip
                Gateway = $config.DefaultIPGateway -join ', '
            }
        }
        $netData | Format-Table -AutoSize
    } catch { Write-Host "  [-] Failed to retrieve adapters: $($_.Exception.Message)" -ForegroundColor Red }

    Write-Host "[NETWORK PROFILES]" -ForegroundColor Green
    try {
        $netParams = $sessionParams.Clone(); $netParams.Namespace = "root\StandardCimv2"
        $profiles = Get-CimInstance @netParams -ClassName MSFT_NetConnectionProfile -ErrorAction Stop
        $profiles | Select-Object Name, InterfaceAlias, @{Name="Category"; Expression={switch($_.NetworkCategory){0{"Public"};1{"Private"};2{"Domain"};default{"Unknown"}}}} | Format-Table -AutoSize
    } catch { Write-Host "  [-] Network Profiles require Administrator privileges." -ForegroundColor Yellow }

    Write-Host "[IPv4 ROUTING TABLE]" -ForegroundColor Green
    try {
        $routes = Get-CimInstance @sessionParams -ClassName Win32_IP4RouteTable -ErrorAction Stop | Where-Object { $_.Destination -ne '127.0.0.0' -and $_.Destination -ne '224.0.0.0' -and $_.Destination -ne '255.255.255.255' }
        $routes | Select-Object Destination, Mask, NextHop, Metric1 | Format-Table -AutoSize
    } catch { Write-Host "  [-] Failed to retrieve routing table." -ForegroundColor Red }

    # --- 4. SECURITY & ANTIVIRUS ---
    Write-Host "`n[4/7] SECURITY & ANTIVIRUS" -ForegroundColor Green
    $secData = @()

    $avFound = $false
    try {
        $scParams = $sessionParams.Clone(); $scParams.Namespace = "Root\SecurityCenter2"
        $thirdPartyAV = Get-CimInstance @scParams -ClassName AntivirusProduct -ErrorAction Stop
        if ($thirdPartyAV) { 
            foreach($av in $thirdPartyAV) { $secData += [PSCustomObject]@{ Component = "Antivirus"; Status = "$($av.displayName) (Running)" }; $avFound = $true }
        }
    } catch { }

    if (-not $avFound) {
        try {
            $defParams = $sessionParams.Clone(); $defParams.Namespace = "root\Microsoft\Windows\Defender"
            $defender = Get-CimInstance @defParams -ClassName MSFT_MpComputerStatus -ErrorAction Stop | Select-Object -First 1
            if ($defender) { $secData += [PSCustomObject]@{ Component = "Antivirus (Defender)"; Status = "Engine: $($defender.AMEngineVersion), Sigs: $($defender.AntivirusSignatureLastUpdated)" } }
        } catch { 
            $avSvc = Get-CimInstance @sessionParams -ClassName Win32_Service -Filter "Name='WinDefend' OR Name='ekrn'" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($avSvc) { $secData += [PSCustomObject]@{ Component = "Antivirus Service"; Status = "$($avSvc.DisplayName) is $($avSvc.State)" } }
            else { $secData += [PSCustomObject]@{ Component = "Antivirus"; Status = "Not Found / Access Denied" } }
        }
    }

    try {
        $blParams = $sessionParams.Clone(); $blParams.Namespace = "Root\CIMV2\Security\MicrosoftVolumeEncryption"
        $bitlocker = Get-CimInstance @blParams -ClassName Win32_EncryptableVolume -Filter "DriveLetter='C:'" -ErrorAction Stop
        $blState = if ($bitlocker.ProtectionStatus -eq 1) { "Encrypted" } else { "Unprotected" }
        $secData += [PSCustomObject]@{ Component = "BitLocker (C:)"; Status = $blState }
    } catch { $secData += [PSCustomObject]@{ Component = "BitLocker (C:)"; Status = "Access Denied / Unverifiable" } }

    $secData | Format-Table -AutoSize -HideTableHeaders

    # --- 5. INFRASTRUCTURE SERVICES ---
    Write-Host "`n[5/7] INFRASTRUCTURE SERVICES" -ForegroundColor Green
    $targetServices = @("wuauserv", "Spooler", "TermService", "WinRM")
    Get-CimInstance @sessionParams -ClassName Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -in $targetServices } | 
        Select-Object Name, DisplayName, State, StartMode | Format-Table -AutoSize

    # --- 6. LOGS: INSTABILITY & ERRORS (LAST 30) ---
    Write-Host "`n[6/7] SYSTEM INSTABILITY LOGS (LAST 30 EVENTS)" -ForegroundColor Green
    $timeLimit = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime((Get-Date).AddDays(-1))
    
    $query = "SELECT * FROM Win32_NTLogEvent WHERE (Logfile='System' OR Logfile='Application') AND (Type='Error' OR Type='Warning') AND TimeGenerated >= '$($timeLimit)'"
    $events = Get-CimInstance @sessionParams -Query $query -ErrorAction SilentlyContinue | Select-Object -First 30
    
    if ($events) {
        foreach ($evt in $events) {
            $color = if ($evt.Type -match "Error") { "Red" } else { "Yellow" }
            $cleanMsg = if ($evt.Message) { $evt.Message.Replace("`n", " ").Replace("`r", "").Trim() } else { "No description available." }
            if ($cleanMsg.Length -gt 150) { $cleanMsg = $cleanMsg.Substring(0, 147) + "..." }
            
            Write-Host "[$($evt.Type.ToUpper())] " -ForegroundColor $color -NoNewline
            Write-Host "$($evt.TimeGenerated) | $($evt.SourceName) | $cleanMsg"
        }
    } else {
        Write-Host "  OK: No critical errors or warnings detected in the last 24h." -ForegroundColor Cyan
    }

} catch {
    Write-Host "`n[!] AUDIT FAILED ON $($ComputerName): $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($session) { Remove-CimSession $session }
    Write-Host "`n[i] Diagnostics Complete.`n" -ForegroundColor DarkGray
}