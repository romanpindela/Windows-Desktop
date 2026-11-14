# Audit-BitLockerAndTpmStatus

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)
[![Compliance](https://img.shields.io/badge/Compliance-EU%20NIS2%20%7C%20Zero--Trust-green.svg)]()
[![Security](https://img.shields.io/badge/Security-TPM%202.0%20%7C%20BitLocker-orange.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Problem Statement

Verifying endpoint compliance with data-at-rest encryption and hardware trust policies (such as EU NIS2 and Zero-Trust baselines) manually across Windows estates is error-prone because TPM readiness, UEFI Secure Boot, BitLocker cipher strength, and Entra ID / Active Directory recovery key escrow records are scattered across separate WMI namespaces, CLI tools, and event logs.

## Overview

`Audit-BitLockerAndTpmStatus.ps1` performs an automated, read-only cryptographic and hardware trust audit on Windows 10, Windows 11, and Windows Server endpoints. It evaluates TPM 2.0 readiness (dTPM vs fTPM), UEFI Secure Boot status, BitLocker volume encryption and cipher compliance, and recovery key escrow events (`EventID 845`/`846`), outputting console summaries, UTF-8 logs, pipeline objects, and a standalone HTML dashboard.

## Environment & Prerequisites

* **Operating System:** Windows 10, Windows 11, or Windows Server 2016+ (x64 / ARM64).
* **PowerShell Version:** Windows PowerShell 5.1 or PowerShell 7+.
* **Required Modules & Tools:** Built-in `TrustedPlatformModule`, `BitLocker`, and `SecureBoot` PowerShell modules, WMI/CIM namespaces (`root\CIMv2\Security\MicrosoftTpm`, `root\CIMv2\Security\MicrosoftVolumeEncryption`), and `dsregcmd.exe`.

## Permissions Required

* **Admin** — Administrator privileges (Well-Known SID `S-1-5-32-544`) are required to query hardware TPM status, UEFI Secure Boot state, and BitLocker volume encryption / protector metadata (`root\CIMv2\Security\MicrosoftVolumeEncryption`). Unless `-SkipAdminCheck` is passed, the script automatically requests UAC elevation (help via `-Help` / `-h` runs without elevation).

## Safety & Impact

* **Risk Level:** `Read-Only / Non-destructive` — performs read-only queries against hardware, WMI/CIM, registry, and event logs; strictly excludes plaintext recovery passwords from logs and reports (recording only KeyProtector GUIDs). Writes audit logs and HTML reports to `C:\Logs\` (or `-PathHtmlReport`).
* **Simulation & Backup:** Declares `[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]` (accepting `-WhatIf` / `-Confirm` common parameters); no system state is modified, so no backup is required.

## Usage Examples

### 1. Standard Workstation Security Audit

```powershell
.\Audit-BitLockerAndTpmStatus.ps1
```

### 2. Audit with Automatic Browser Dashboard Display

```powershell
.\Audit-BitLockerAndTpmStatus.ps1 -OpenReport
```

### 3. Enforce Strict AES-256 Encryption Policy

```powershell
.\Audit-BitLockerAndTpmStatus.ps1 -EnforceAes256 -PathHtmlReport "C:\Reports\Audit-BitLocker-AES256.html" -OpenReport
```

### 4. Pipeline Ingestion and Querying Unprotected Drives

```powershell
$audit = .\Audit-BitLockerAndTpmStatus.ps1 -PassThru
$audit.Volumes | Where-Object { $_.ProtectionStatus -ne 'On' } | Select-Object MountPoint, VolumeStatus, EncryptionPercentage
```

### 5. Display Interactive Command-Line Help

```powershell
.\Audit-BitLockerAndTpmStatus.ps1 -Help
```

---

## Key Capabilities

* **Hardware Root of Trust (TPM Module):** Multi-layered detection (`Get-Tpm`, `Win32_Tpm`, `Win32_PnPEntity`), dTPM vs fTPM classification, firmware version, and UEFI Secure Boot verification.
* **BitLocker Volume Encryption:** Inventory of OS, Fixed, and Removable drives, encryption completeness (`100%`), cipher algorithms (`XtsAes256`, `XtsAes128`, `Aes256`, `Aes128`), and key protector hygiene without exposing plaintext recovery keys.
* **Cloud & Directory Escrow Verification:** Machine join state discovery via `dsregcmd /status` and `Microsoft-Windows-BitLocker/BitLocker Management` event log analysis (`EventID 845` vs `846`).
* **Standalone HTML Dashboard & Telemetry:** Dependency-free dark/light mode HTML report, colorized console status (`[PASS]`, `[WARN]`, `[FAIL]`), UTF-8 audit logs in `C:\Logs\`, and `[PSCustomObject]` pipeline output via `-PassThru`.

---

## Script Parameters

| Parameter | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `-PathHtmlReport` | `[string]` | `C:\Logs\Audit-BitLockerAndTpmStatus_<timestamp>.html` | Custom file destination for the generated HTML audit report. |
| `-OpenReport` | `[switch]` | `$false` | Automatically opens the generated HTML report in the system default web browser upon completion. |
| `-EnforceAes256` | `[switch]` | `$false` | Flags algorithms other than `XtsAes256` or `Aes256` as `[FAIL]` instead of `[PASS]`/`[WARN]`. |
| `-PassThru` | `[switch]` | `$false` | Returns the comprehensive audit dataset as a structured `[PSCustomObject]` to the PowerShell pipeline. |
| `-SkipAdminCheck` | `[switch]` | `$false` | Bypasses the mandatory UAC elevation check (useful for automated testing and non-privileged diagnostics). |
| `-Help`, `-h` | `[switch]` | `$false` | Displays the interactive CLI help guide and syntax examples in the console. |

---

## NIS2 Directive Compliance Assessment Matrix

| Component | Compliant `[PASS]` | Warning `[WARN]` | Critical Deficiency `[FAIL]` |
| :--- | :--- | :--- | :--- |
| **TPM Module** | TPM 2.0 active, enabled, and ready (`Ready: True`). | TPM 1.2 or TPM 2.0 present but not activated in BIOS/UEFI. | TPM chip missing, disabled in firmware, or malfunctioning. |
| **Secure Boot** | UEFI mode active with Secure Boot enabled. | UEFI mode active, but Secure Boot disabled by user. | Legacy BIOS mode (no Secure Boot support). |
| **OS System Drive** | Fully encrypted (100%), Protection On, TPM + recovery protector. | 128-bit encryption method (standard policy) or missing TPM protector. | Decrypted, encryption incomplete (<100%), or protection Off. |
| **Fixed Data Drives** | Fully encrypted (100%), auto-unlock or passphrase protector active. | Drive undergoing encryption or incomplete coverage. | Unencrypted volume hosting operational data. |
| **Escrow Backup** | Confirmed recovery key archival in Entra ID or AD (`EventID 845`). | Device joined to directory/cloud, but escrow events missing. | Explicit escrow backup error (`EventID 846`) on managed machine. |

---

## Screenshots & Visual Verification

### 1. Interactive CLI Help Menu (`.\Audit-BitLockerAndTpmStatus.ps1 -Help`)
![Interactive CLI Help Menu](assets/Help_info.jpg)

### 2. Standard Audit Execution & Console Summary (`.\Audit-BitLockerAndTpmStatus.ps1`)
![Standard Audit Execution & Console Summary](assets/Standard_run.jpg)

### 3. Standalone Responsive HTML Audit Report (`.\Audit-BitLockerAndTpmStatus.ps1 -OpenReport`)
![Standalone Responsive HTML Audit Report](assets/Raport-Audytu-BitLocker-TPM-ROMAN-PC-E590-11-09-2026_12_35_PM.png)

---

## Author

* **Author:** Roman Pindela
* **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
* **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **Repository:** [Windows-Desktop](https://github.com/romanpindela/Windows-Desktop)
* **Version:** 1.0.0
* **Release Date:** 2026-11-09
* **License:** [MIT](https://opensource.org/licenses/MIT)
