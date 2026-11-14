# Audit-EndpointPersistence

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Code Quality](https://img.shields.io/badge/Code%20Quality-Production%20Hardened-brightgreen.svg)]()
[![Encoding](https://img.shields.io/badge/Encoding-UTF--8%20with%20BOM-orange.svg)]()

## Problem Statement

Adversaries, malware, and misconfigured installers frequently establish persistence across reboots using Windows Auto-Start Execution Points (ASEP) such as Scheduled Tasks, Run/RunOnce registry keys, Startup folders, and unquoted Windows service paths (CWE-428), which are tedious and error-prone to inspect manually across 64-bit/32-bit hives and user profiles.

## Overview

`Audit-EndpointPersistence.ps1` systematically audits Windows Scheduled Tasks, autostart registry keys, Startup folders (including `.lnk` resolution), and Windows Services for persistence risks and unquoted service paths. It verifies Authenticode digital signatures, scores each entry (`Critical`, `High`, `Medium`, `Low`), logs telemetry to `C:\Logs\`, and generates a standalone responsive HTML dashboard with optional CSV export and pipeline output.

## Environment & Prerequisites

* **Operating System:** Windows 10, Windows 11, or Windows Server 2016 / 2019 / 2022 / 2025.
* **PowerShell Version:** Windows PowerShell 5.1 or PowerShell 7+.
* **Required Modules & APIs:** Native Windows PowerShell modules (`ScheduledTasks`, `Microsoft.PowerShell.Security`), CIM/WMI (`Win32_Service`), and `WScript.Shell` COM for `.lnk` resolution (no external dependencies).

## Permissions Required

* **Admin** — Administrator privileges (Well-Known SID `S-1-5-32-544`) are required to enumerate privileged Scheduled Tasks, inspect all user profiles (`-IncludeAllProfiles`), and read protected service and HKLM registry paths. The script automatically requests UAC elevation unless `-SkipAdminCheck` is specified (help via `-Help` / `-h` runs without elevation).

## Safety & Impact

* **Risk Level:** `Read-Only / Non-destructive` — performs read-only inspection of Scheduled Tasks, registry keys, Startup folders, service configurations, and binary signatures; writes only report/log output files (`C:\Logs\Audit-EndpointPersistence.log`, HTML report, and optional CSV).
* **Simulation & Backup:** Declares `[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]` (accepting `-WhatIf` / `-Confirm` common parameters); no system configuration is altered, so no backup is required.

## Usage Examples

### 1. Default Comprehensive Audit

```powershell
.\Audit-EndpointPersistence.ps1
```

### 2. High & Critical Threat Hunting with Browser Report

```powershell
.\Audit-EndpointPersistence.ps1 -MinimumRiskLevel High -OpenReport
```

### 3. Multi-Profile Audit with CSV Export

```powershell
.\Audit-EndpointPersistence.ps1 -IncludeAllProfiles -ExportCsv
```

### 4. Automated / Headless Execution (Intune / SCCM / CI-CD)

```powershell
.\Audit-EndpointPersistence.ps1 -SkipAdminCheck -ReportPath "C:\Reports\Persistence.html" -ExportCsv -CsvPath "C:\Reports\Persistence.csv"
```

### 5. Pipeline Analysis & SIEM Forwarding

```powershell
.\Audit-EndpointPersistence.ps1 -PassThru | Where-Object { $_.RiskLevel -eq 'Critical' } | Format-Table -AutoSize
```

### 6. Interactive Command Help

```powershell
.\Audit-EndpointPersistence.ps1 -Help
```

---

## Audited Persistence Vectors & Capabilities

* **Scheduled Tasks:** Identifies tasks running as `NT AUTHORITY\SYSTEM` or `Administrators`, scripts in user-writable folders (`%TEMP%`, `%APPDATA%`, `%LOCALAPPDATA%`, `C:\Users\Public\`), and orphaned task references.
* **Registry Autostart Keys (ASEP):** Inspects 64-bit and WOW6432Node `HKLM`/`HKCU` `Run` and `RunOnce`, `Explorer\User Shell Folders`, Active Setup `StubPath`, and encoded/stealthy LOLBin executions (`powershell.exe -enc`, `mshta.exe`, `wscript.exe`).
* **Startup Folders:** Scans `ProgramData` and user Startup directories (all profiles with `-IncludeAllProfiles`) and resolves `.lnk` shortcut targets and arguments.
* **Windows Services:** Flags Unquoted Service Paths (**CWE-428**) and services pointing outside `%SystemRoot%` and `%ProgramFiles%`.
* **Authenticode & Heuristic Risk Engine:** Verifies signatures via `Get-AuthenticodeSignature` and classifies findings into `Critical`, `High`, `Medium`, and `Low` risk levels.

---

## CLI Parameters Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-ReportPath` | `string` | `C:\Logs\Audit-EndpointPersistence_Report.html` | Destination file path for the standalone HTML audit report. |
| `-LogPath` | `string` | `C:\Logs\Audit-EndpointPersistence.log` | Destination file path for execution log telemetry. |
| `-MinimumRiskLevel` | `string` | `Low` | Filters console table and pipeline objects (`Low`, `Medium`, `High`, `Critical`). |
| `-IncludeAllProfiles` | `switch` | `False` | Audits startup folders across all existing user profiles (`C:\Users\*\AppData\...`). |
| `-OpenReport` | `switch` | `False` | Automatically launches the HTML report in the default browser upon completion. |
| `-SkipAdminCheck` | `switch` | `False` | Bypasses UAC administrator check (for CI/CD pipelines, SCCM/Intune, or SYSTEM context). |
| `-ExportCsv` | `switch` | `False` | Exports evaluated findings to a structured CSV file. |
| `-CsvPath` | `string` | `C:\Logs\Audit-EndpointPersistence.csv` | Custom destination file path for CSV export. |
| `-PassThru` | `switch` | `False` | Emits structured `PSCustomObject` items to the PowerShell pipeline. |
| `-Help` (`-h`) | `switch` | `False` | Displays the interactive CLI help guide. |

---

## Screenshots & Visual Verification

### 1. Console Execution & Live ASEP Audit (`.\Audit-EndpointPersistence.ps1`)
![Console Execution and Live ASEP Audit](assets/Running.jpg)

### 2. Standalone Responsive HTML Audit Dashboard (`.\Audit-EndpointPersistence.ps1 -OpenReport`)
![Standalone Responsive HTML Audit Dashboard](assets/Endpoint-Persistence-Audit-ROMAN-PC-E590-11-09-2026_12_38_PM.png)

---

## Directory Structure

```text
Audit-EndpointPersistence/
├── assets/
│   ├── Endpoint-Persistence-Audit-ROMAN-PC-E590-11-09-2026_12_38_PM.png
│   └── Running.jpg
├── Audit-EndpointPersistence.ps1              # Production persistence auditing tool
└── README.md                                  # Technical documentation & operational guide
```

---

## Author

* **Author:** Roman Pindela
* **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
* **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **Repository:** [Windows-Desktop](https://github.com/romanpindela/Windows-Desktop)
* **Version:** 1.0.0
* **Release Date:** 2026-11-09
* **License:** MIT
