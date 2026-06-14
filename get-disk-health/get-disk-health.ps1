<#
.SYNOPSIS
    Advanced SSD/HDD Health and SMART Diagnostics Tool.
.DESCRIPTION
    This script audits all locally connected physical disks, maps them to their 
    respective partitions and mount points, and performs a deep SMART health 
    diagnostic using native Windows Storage Reliable Counters.
.PARAMETER Help
    Displays help information.
.EXAMPLE
    .\get-disk-health.ps1
.NOTES
    Version : 1.0.0
    Author  : Roman Pindela
    Email   : roman.pindela@gmail.com
    GitHub  : https://github.com/romanpindela
#>

param(
    [switch]$Help,
    [switch]$H,
    [switch]$ExportHtml,
    [string]$ExportPath
)

$ScriptVersion = "1.0.0"

function Show-Help {
    Write-Host ""
    Write-Host "GET-DISK-HEALTH v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Advanced SSD/HDD Diagnostics Tool"
    Write-Host ""
    Write-Host "DESCRIPTION"
    Write-Host "    Audits physical disks, displays partition and volume mapping,"
    Write-Host "    and runs native SMART queries (Storage Reliability Counters)"
    Write-Host "    to assess the health, wear, and error rates of connected drives."
    Write-Host ""
    Write-Host "REQUIREMENTS"
    Write-Host "    - Administrator privileges (auto-prompts for UAC elevation)"
    Write-Host ""
    Write-Host "OPTIONS"
    Write-Host "    -ExportHtml"
    Write-Host "        Generates an HTML report in C:\temp\ with a default name."
    Write-Host "    -ExportPath <Path>"
    Write-Host "        Optional. Specifies a custom directory or file path for the HTML report."
    Write-Host ""
    Write-Host "EXAMPLES"
    Write-Host "    .\get-disk-health.ps1"
    Write-Host "        Runs the standard diagnostics and displays results in the console."
    Write-Host "    .\get-disk-health.ps1 -ExportHtml"
    Write-Host "        Runs diagnostics and automatically exports to C:\temp\."
    Write-Host "    .\get-disk-health.ps1 -ExportPath 'D:\Reports\MyServer.html'"
    Write-Host "        Runs diagnostics and exports to the explicitly specified file."
    Write-Host ""
    Write-Host "AUTHOR"
    Write-Host "    Roman Pindela | roman.pindela@gmail.com"
    Write-Host ""
}

if ($Help -or $H) {
    Show-Help
    exit
}

# ------------------------------------------------------------------------------
# ADMINISTRATOR PRIVILEGES CHECK
# ------------------------------------------------------------------------------
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)

if (-not $principal.IsInRole($adminSid)) {
    Write-Host "[!] Administrator privileges required. Requesting elevation..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " [i] INITIATING STORAGE HEALTH & SMART AUDIT" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# HTML EXPORT PATH & SYSTEM INFO PREPARATION
# ------------------------------------------------------------------------------
$ipObj = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue | Select-Object -First 1
$ipAddr = if ($ipObj) { ($ipObj.IPAddress | Where-Object { $_ -match '\.' } | Select-Object -First 1) } else { "UnknownIP" }
$osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$osName = if ($osInfo) { "$($osInfo.Caption) ($($osInfo.OSArchitecture))" } else { "Unknown OS" }
$computerName = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyyMMddHHmmss"

$FinalExportPath = $null
if ($ExportHtml -or (-not [string]::IsNullOrWhiteSpace($ExportPath))) {
    $DefaultFileName = "disk_health_raport-${computerName}_${ipAddr}_${timestamp}.html"
    $DefaultDir = "C:\temp"

    if ([string]::IsNullOrWhiteSpace($ExportPath)) {
        $FinalExportPath = Join-Path -Path $DefaultDir -ChildPath $DefaultFileName
    } else {
        if (Test-Path -Path $ExportPath -PathType Container) {
            $FinalExportPath = Join-Path -Path $ExportPath -ChildPath $DefaultFileName
        } else {
            $FinalExportPath = $ExportPath
        }
    }
}

$HtmlReport = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Storage Health & SMART Audit Report</title>
<style>
    body { background-color: #1e1e1e; color: #d4d4d4; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 20px; }
    h1, h2, h3, h4 { color: #569cd6; }
    .success { color: #4CAF50; font-weight: bold; }
    .warning { color: #FFEB3B; font-weight: bold; }
    .danger { color: #F44336; font-weight: bold; }
    .white { color: #FFFFFF; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; font-size: 14px; }
    th, td { border: 1px solid #444; padding: 8px; text-align: left; }
    th { background-color: #2d2d30; color: #4CAF50; }
    tr:nth-child(even) { background-color: #252526; }
    .prop-key { color: #808080; display: inline-block; width: 220px; font-family: Consolas, monospace; }
    .prop-val { font-family: Consolas, monospace; }
    .container { background-color: #252526; padding: 15px; border-radius: 5px; margin-bottom: 20px; border: 1px solid #333; }
    .header-info { background-color: #2d2d30; padding: 15px; border-radius: 5px; margin-bottom: 20px; border-left: 4px solid #569cd6; font-size: 15px; }
</style>
</head>
<body>
<h2>STORAGE HEALTH & SMART AUDIT REPORT</h2>
<div class="header-info">
    <strong>Computer Name:</strong> $computerName<br>
    <strong>IP Address:</strong> $ipAddr<br>
    <strong>Operating System:</strong> $osName<br>
    <strong>Report Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
</div>
<hr style="border-color: #333;">
"@

# ------------------------------------------------------------------------------
# SECTION 1: DISK AND PARTITION TOPOLOGY MAP
# ------------------------------------------------------------------------------
Write-Host "[1/2] DISK & PARTITION TOPOLOGY" -ForegroundColor Green
Write-Host "Mapping connected physical disks to logical partitions and mount points...`n" -ForegroundColor DarkGray

try {
    $diskMap = @()
    $disks = Get-Disk -ErrorAction Stop | Sort-Object Number
    
    foreach ($disk in $disks) {
        $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object Type -ne "Reserved"
        
        foreach ($part in $partitions) {
            $vol = $null
            if ($part.DriveLetter) {
                $vol = Get-Volume -DriveLetter $part.DriveLetter -ErrorAction SilentlyContinue
            }
            
            $diskMap += [PSCustomObject]@{
                "Disk #"      = $disk.Number
                "Model"       = $disk.FriendlyName
                "Bus/Type"    = $disk.BusType
                "Part #"      = $part.PartitionNumber
                "Letter"      = if ($part.DriveLetter) { "$($part.DriveLetter):" } else { "-" }
                "Label"       = if ($vol -and $vol.FileSystemLabel) { $vol.FileSystemLabel } else { "<No Label>" }
                "Part Type"   = $part.Type
                "FileSystem"  = if ($vol) { $vol.FileSystem } else { "-" }
                "Size (GB)"   = [math]::Round($part.Size / 1GB, 2)
            }
        }
    }
    $diskMap | Format-Table -AutoSize
    
    $HtmlReport += "<h3>[1/3] DISK & PARTITION TOPOLOGY</h3>"
    if ($diskMap) { $HtmlReport += ($diskMap | ConvertTo-Html -Fragment | Out-String) }
}
catch {
    Write-Host "  [-] Failed to retrieve disk topology: $($_.Exception.Message)" -ForegroundColor Red
    $HtmlReport += "<p class='danger'>[-] Failed to retrieve disk topology: $($_.Exception.Message)</p>"
}

# ------------------------------------------------------------------------------
# SMARTMONTOOLS (SMARTCTL) INTEGRATION
# ------------------------------------------------------------------------------
Write-Host "`n[2/3] INITIALIZING DEEP DIAGNOSTICS ENGINE (SMARTCTL)" -ForegroundColor Green
$smartctlAvailable = $false
if (Get-Command "smartctl" -ErrorAction SilentlyContinue) {
    $smartctlAvailable = $true
    Write-Host "  [+] smartctl is installed and available." -ForegroundColor DarkGray
    $HtmlReport += "<h3>[2/3] SMARTCTL DIAGNOSTICS ENGINE</h3><p class='success'>[+] smartctl is installed and available.</p>"
} elseif (Test-Path "C:\Program Files\smartmontools\bin\smartctl.exe") {
    $env:Path += ";C:\Program Files\smartmontools\bin"
    $smartctlAvailable = $true
    Write-Host "  [+] smartctl found in Program Files." -ForegroundColor DarkGray
    $HtmlReport += "<h3>[2/3] SMARTCTL DIAGNOSTICS ENGINE</h3><p class='success'>[+] smartctl found in Program Files.</p>"
} else {
    Write-Host "  [*] smartctl not found on this system. Attempting automatic download and installation via winget..." -ForegroundColor Yellow
    try {
        if (Get-Command "winget" -ErrorAction SilentlyContinue) {
            $installProc = Start-Process -FilePath "winget" -ArgumentList "install Smartmontools.smartmontools --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
            if ($installProc.ExitCode -eq 0 -or (Test-Path "C:\Program Files\smartmontools\bin\smartctl.exe")) {
                $env:Path += ";C:\Program Files\smartmontools\bin"
                $smartctlAvailable = $true
                Write-Host "  [+] smartmontools installed successfully! Using it for deep analysis." -ForegroundColor Green
                $HtmlReport += "<h3>[2/3] SMARTCTL DIAGNOSTICS ENGINE</h3><p class='success'>[+] smartmontools installed automatically via winget.</p>"
            } else {
                Write-Host "  [-] Installation failed. Script will fall back to native Windows WMI diagnostics." -ForegroundColor Red
                $HtmlReport += "<h3>[2/3] SMARTCTL DIAGNOSTICS ENGINE</h3><p class='danger'>[-] smartmontools installation failed. Falling back to native WMI.</p>"
            }
        } else {
            Write-Host "  [-] winget package manager is not available. Falling back to native Windows WMI diagnostics." -ForegroundColor Red
            $HtmlReport += "<h3>[2/3] SMARTCTL DIAGNOSTICS ENGINE</h3><p class='warning'>[-] winget not available. Falling back to native WMI.</p>"
        }
    } catch {
        Write-Host "  [-] Error during smartmontools installation: $($_.Exception.Message)" -ForegroundColor Red
        $HtmlReport += "<h3>[2/3] SMARTCTL DIAGNOSTICS ENGINE</h3><p class='danger'>[-] Error during smartmontools installation: $($_.Exception.Message)</p>"
    }
}

# ------------------------------------------------------------------------------
# SECTION 2: DETAILED SMART & PHYSICAL DISK DIAGNOSTICS
# ------------------------------------------------------------------------------
Write-Host "`n[3/3] DETAILED PHYSICAL DISK DIAGNOSTICS" -ForegroundColor Green
Write-Host "Querying physical storage devices...`n" -ForegroundColor DarkGray

try {
    $physicalDisks = Get-PhysicalDisk -ErrorAction Stop | Sort-Object DeviceId
    
    $HtmlReport += "<h3>[3/3] DETAILED PHYSICAL DISK DIAGNOSTICS</h3>"

    foreach ($pDisk in $physicalDisks) {
        Write-Host ">> Disk $($pDisk.DeviceId): $($pDisk.FriendlyName) " -ForegroundColor Yellow -NoNewline
        $HtmlReport += "<h4>Disk $($pDisk.DeviceId): $($pDisk.FriendlyName) "
        
        if ($pDisk.HealthStatus -eq "Healthy") {
            Write-Host "[HEALTHY]" -ForegroundColor Green
            $HtmlReport += "<span class='success'>[HEALTHY]</span></h4>"
        } else {
            Write-Host "[$($pDisk.HealthStatus.ToUpper())]" -ForegroundColor Red
            $HtmlReport += "<span class='danger'>[$($pDisk.HealthStatus.ToUpper())]</span></h4>"
        }
        $HtmlReport += "<div class='container'>"
        
        $details = [ordered]@{
            "Manufacturer"       = if ($pDisk.Manufacturer) { $pDisk.Manufacturer } else { "Unknown" }
            "Model"              = if ($pDisk.Model) { $pDisk.Model } else { "Unknown" }
            "Serial Number"      = $pDisk.SerialNumber
            "Firmware Version"   = $pDisk.FirmwareVersion
            "Bus & Media Type"   = "$($pDisk.BusType) / $($pDisk.MediaType)"
            "Capacity (GB)"      = [math]::Round($pDisk.Size / 1GB, 2)
            "Sector Size"        = "$($pDisk.LogicalSectorSize) B (Log) / $($pDisk.PhysicalSectorSize) B (Phys)"
            "Spindle Speed"      = if ($pDisk.SpindleSpeed -and $pDisk.SpindleSpeed -ne 0) { "$($pDisk.SpindleSpeed) RPM" } else { "Solid State (No RPM)" }
            "Operational Status" = ($pDisk.OperationalStatus -join ", ")
        }

        $smartctlUsed = $false
        if ($smartctlAvailable) {
            try {
                $smartJsonStr = & smartctl -j -x /dev/pd$($pDisk.DeviceId) 2>$null
                $smartJson = $smartJsonStr | ConvertFrom-Json -ErrorAction Stop

                if ($smartJson) {
                    $smartctlUsed = $true
                    $details["---"] = "--- SMARTCTL DEEP DIAGNOSTICS ---"
                    if ($smartJson.model_name) { $details["Model"] = $smartJson.model_name }
                    if ($smartJson.firmware_version) { $details["Firmware Version"] = $smartJson.firmware_version }
                    if ($smartJson.smart_status) { $details["SMART Health Status"] = if ($smartJson.smart_status.passed) { "PASSED" } else { "FAILED" } }
                    if ($smartJson.temperature -and $smartJson.temperature.current) { $details["Temperature"] = "$($smartJson.temperature.current) °C" }
                    if ($smartJson.power_cycle_count) { $details["Power Cycles"] = $smartJson.power_cycle_count }
                    if ($smartJson.power_on_time -and $smartJson.power_on_time.hours -ne $null) { $details["Power-On Hours"] = "$($smartJson.power_on_time.hours) hours" }

                    if ($smartJson.nvme_smart_health_information_log) {
                        $nvme = $smartJson.nvme_smart_health_information_log
                        $details["Data Written (GB)"] = [math]::Round(($nvme.data_units_written * 512000) / 1GB, 2)
                        $details["Data Read (GB)"]    = [math]::Round(($nvme.data_units_read * 512000) / 1GB, 2)
                        $details["Wear (%)"]          = "$($nvme.percentage_used) %"
                        $details["Available Spare"]   = "$($nvme.available_spare) %"
                        $details["Critical Warning"]  = $nvme.critical_warning
                        $details["Unsafe Shutdowns"]  = $nvme.unsafe_shutdowns
                    }
                    if ($smartJson.ata_smart_attributes.table) {
                        $tbw = $smartJson.ata_smart_attributes.table | Where-Object { $_.name -match "Total_LBAs_Written" }
                        if ($tbw) { $details["Total LBAs Written"] = $tbw.raw.value }
                    }
                }
            } catch {
                Write-Host "  [-] Failed to parse smartctl for disk $($pDisk.DeviceId)." -ForegroundColor DarkGray
            }
        }

        if (-not $smartctlUsed) {
            $counters = $pDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
            $details["---"] = "--- WINDOWS NATIVE COUNTERS ---"
            if ($counters) {
                $details["Temperature (C)"]   = if ($counters.Temperature) { "$($counters.Temperature) °C (Max recorded: $($counters.TemperatureMax) °C)" } else { "N/A" }
                $details["Power-On Hours"]    = if ($counters.PowerOnHours) { "$($counters.PowerOnHours) hours" } else { "N/A (Driver restricts this data natively)" }
                $details["Wear (%)"]          = if ($counters.Wear -ne $null) { "$($counters.Wear) %" } else { "N/A" }
                $details["Read Latency Max"]  = if ($counters.ReadLatencyMax) { "$($counters.ReadLatencyMax) ms" } else { "N/A" }
                $details["Write Latency Max"] = if ($counters.WriteLatencyMax) { "$($counters.WriteLatencyMax) ms" } else { "N/A" }
                $details["Read Errors"]       = if ($counters.ReadErrorsTotal -ne $null) { "$($counters.ReadErrorsTotal) (Max: $($counters.ReadErrorsMax))" } else { 0 }
                $details["Write Errors"]      = if ($counters.WriteErrorsTotal -ne $null) { "$($counters.WriteErrorsTotal) (Max: $($counters.WriteErrorsMax))" } else { 0 }
            } else {
                $details["SMART Status"] = "Counters unavailable (Could be a Virtual Disk or unsupported interface)"
            }
        }

        # Dynamiczne wyświetlanie z oznaczaniem kolorami progów ostrzegawczych
        Write-Host ""
        foreach ($key in $details.Keys) {
            $val = $details[$key]
            
            # Nagłówki separatora
            if ($key -eq "---") {
                Write-Host $val -ForegroundColor DarkCyan
                $HtmlReport += "<div style='margin-top: 10px; margin-bottom: 5px; color: #008B8B; font-weight: bold;'>$val</div>"
                continue
            }

            Write-Host "$($key.PadRight(22)) : " -NoNewline -ForegroundColor DarkGray

            $HtmlColorClass = "white"

            # Kolorowanie progu "Wear (%)"
            if ($key -eq "Wear (%)" -and $val -match "(\d+)") {
                $wear = [int]$matches[1]
                if ($wear -ge 90) { Write-Host $val -ForegroundColor Red; $HtmlColorClass = "danger" }
                elseif ($wear -ge 75) { Write-Host $val -ForegroundColor Yellow; $HtmlColorClass = "warning" }
                else { Write-Host $val -ForegroundColor Green; $HtmlColorClass = "success" }
            }
            # Kolorowanie zapasu sektorów (odwrotnie, mało = źle)
            elseif ($key -eq "Available Spare" -and $val -match "(\d+)") {
                $spare = [int]$matches[1]
                if ($spare -le 10) { Write-Host $val -ForegroundColor Red; $HtmlColorClass = "danger" }
                elseif ($spare -le 30) { Write-Host $val -ForegroundColor Yellow; $HtmlColorClass = "warning" }
                else { Write-Host $val -ForegroundColor Green; $HtmlColorClass = "success" }
            }
            # Kolorowanie temperatury
            elseif ($key -match "Temperature" -and $val -match "(\d+)") {
                $temp = [int]$matches[1]
                if ($temp -ge 70) { Write-Host $val -ForegroundColor Red; $HtmlColorClass = "danger" }
                elseif ($temp -ge 55) { Write-Host $val -ForegroundColor Yellow; $HtmlColorClass = "warning" }
                else { Write-Host $val -ForegroundColor Green; $HtmlColorClass = "success" }
            }
            # Kolorowanie statusów, błędów i flag krytycznych
            elseif ($key -match "Status") {
                if ($val -match "FAILED|Error|Degraded|Pred Fail") { Write-Host $val -ForegroundColor Red; $HtmlColorClass = "danger" }
                elseif ($val -match "Warning") { Write-Host $val -ForegroundColor Yellow; $HtmlColorClass = "warning" }
                else { Write-Host $val -ForegroundColor Green; $HtmlColorClass = "success" }
            }
            elseif ($key -match "Critical Warning") {
                if ($val -ne "0") { Write-Host $val -ForegroundColor Red; $HtmlColorClass = "danger" }
                else { Write-Host $val -ForegroundColor Green; $HtmlColorClass = "success" }
            }
            elseif ($key -match "Errors") {
                if ($val -match "^0" -or $val -eq 0) { Write-Host $val -ForegroundColor Green; $HtmlColorClass = "success" }
                else { Write-Host $val -ForegroundColor Red; $HtmlColorClass = "danger" }
            }
            # Domyślny kolor dla reszty atrybutów
            else {
                Write-Host $val -ForegroundColor White
                $HtmlColorClass = "white"
            }
            
            $HtmlReport += "<div style='margin: 2px 0;'><span class='prop-key'>$($key.PadRight(22).Replace(' ', '&nbsp;')) : </span><span class='prop-val $HtmlColorClass'>$val</span></div>"
        }
        Write-Host "`n------------------------------------------------------------" -ForegroundColor DarkGray
        $HtmlReport += "</div>"
    }
}
catch {
    Write-Host "  [-] Failed to retrieve physical disk details: $($_.Exception.Message)" -ForegroundColor Red
    $HtmlReport += "<p class='danger'>[-] Failed to retrieve physical disk details: $($_.Exception.Message)</p>"
}

$HtmlReport += "</body></html>"

if ($FinalExportPath) {
    try {
        $exportDirToCreate = Split-Path -Path $FinalExportPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($exportDirToCreate) -and -not (Test-Path -Path $exportDirToCreate)) {
            New-Item -ItemType Directory -Force -Path $exportDirToCreate | Out-Null
        }

        $HtmlReport | Out-File -FilePath $FinalExportPath -Encoding UTF8 -Force
        Write-Host "`n[+] HTML report successfully saved to: $FinalExportPath" -ForegroundColor Green
    } catch {
        Write-Host "`n[-] Failed to save HTML report: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n[i] Diagnostics Complete.`n" -ForegroundColor DarkGray