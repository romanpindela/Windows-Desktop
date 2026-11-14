# Audit-WindowsUpdateAndPatchStatus

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)
[![Security](https://img.shields.io/badge/Security-Patch%20Hygiene%20%7C%20EDR-orange.svg)]()

> **Enterprise read-only Windows Update and Patch Hygiene auditing tool for Windows 10 and Windows 11 endpoints, designed for System Administrators, SOC/EDR teams, and RMM automation.**

---

## Business Objective & Audit Scope

`Audit-WindowsUpdateAndPatchStatus.ps1` evaluates endpoint patch hygiene and detects Windows Update configuration anomalies that can leave critical vulnerabilities unpatched or indicate tampering (e.g., malware disabling updates, orphaned WSUS policies, or stalled reboots).

### Audited Areas
1. **Host & OS Baseline:**
   - Hostname, domain/workgroup, OS caption, version, build number, and **UBR (Update Build Revision)** from `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion`.
   - System uptime (`LastBootUpTime`, `UptimeDays`).
   - Service status and startup type for `wuauserv`, `bits`, `cryptsvc`, `TrustedInstaller`, and `UsoSvc`.
2. **Installed Patches & Patch Age:**
   - Dual-source patch history combining `Get-HotFix` (`Win32_QuickFixEngineering`) and COM API `Microsoft.Update.Session` (`QueryHistory`), including failed installations with `HResult` codes.
   - Calculates `DaysSinceLastPatch` and SLA status (`Compliant` <= 30d, `Warning` 31–60d, `Critical` > 60d by default).
3. **Multi-Vector Pending Reboot Detection:**
   - **CBS:** `RebootPending`, `RebootInProgress`, `PackagesPending`.
   - **Windows Update:** `RebootRequired`, `PostRebootReporting`.
   - **Session Manager:** `PendingFileRenameOperations` (filtered for non-empty entries).
   - **Computer Rename / Domain Join:** `ActiveComputerName` vs `ComputerName` mismatch.
   - **SCCM / ConfigMgr Client:** `CCM_ClientUtilities.DetermineIfRebootPending()` (when `root\ccm\ClientSDK` is present).
4. **Update Channel & EDR Policy Red Flags:**
   - Detects `Windows Update (Cloud)`, `WSUS`, or `Windows Update for Business (WUfB)`.
   - Flags `NoAutoUpdate=1`, `DisableWindowsUpdateAccess=1`, `DoNotConnectToWindowsUpdateInternetLocations=1` (without WSUS), and unreachable or loopback `WUServer` targets.
5. **Missing Updates Scan:**
   - Queries `Microsoft.Update.Session` for missing `Software` (and optionally `Driver`) updates, categorized by `MsrcSeverity` (`Critical`, `Important`, `Moderate`, `Low`, `Unspecified`) and classification.

---

## Prerequisites & Privileges

- **OS:** Windows 10 / Windows 11 (Enterprise / Pro)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Privileges:** Local Administrator (SID `S-1-5-32-544`) or `NT AUTHORITY\SYSTEM` (SID `S-1-5-18`). If launched from a standard user account without `-NoElevate`, the script automatically requests UAC elevation while preserving all parameters.

---

## Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Run`, `-r` | `[switch]` | `$false` | Executes the audit. Omitting `-Run` displays the CLI help guide and examples. |
| `-OutputDirectory` | `[string]` | `C:\Logs\PatchAudit` | Target directory for generated HTML, CSV, and JSON reports. |
| `-MaxPatchAgeDays` | `[int]` | `30` | Maximum acceptable age in days since the last security/cumulative patch. |
| `-HistoryLimit` | `[int]` | `25` | Number of recent update history entries included in detailed reports. |
| `-OfflineScanOnly` | `[switch]` | `$false` | Skips online queries to Microsoft Update / WSUS (`UpdateSearcher.Online = $false`). |
| `-IncludeDrivers` | `[switch]` | `$false` | Includes missing driver updates (`Type='Driver'`) in the scan. |
| `-ExportJson` | `[switch]` | `$false` | Generates an additional `.json` report for EDR/SIEM ingestion. |
| `-OpenReport` | `[switch]` | `$false` | Automatically opens the generated HTML dashboard in the default browser. |
| `-NoElevate` | `[switch]` | `$false` | Disables automatic UAC elevation (for RMM/EDR agents or non-interactive runs). |
| `-Help`, `-h` | `[switch]` | `$false` | Displays the interactive CLI help guide and usage examples. |

---

## Usage Examples

```powershell
# Display CLI help guide and usage examples
.\Audit-WindowsUpdateAndPatchStatus.ps1
.\Audit-WindowsUpdateAndPatchStatus.ps1 -h

# Standard interactive audit (prompts UAC if not elevated)
.\Audit-WindowsUpdateAndPatchStatus.ps1 -r -OpenReport

# Strict 14-day SLA with JSON export for SIEM/EDR
.\Audit-WindowsUpdateAndPatchStatus.ps1 -r -MaxPatchAgeDays 14 -ExportJson

# Non-interactive RMM/EDR execution using local update cache only
.\Audit-WindowsUpdateAndPatchStatus.ps1 -r -OfflineScanOnly -NoElevate -OutputDirectory "C:\Logs\PatchAudit"
```

---

## Output Files

- **Session Log:** `C:\Logs\Audit-WindowsUpdateAndPatchStatus_<YYYYMMDD_HHmmss>.log`
- **HTML Dashboard:** `<OutputDirectory>\PatchAudit_<HOST>_<TIMESTAMP>.html` (100% offline, no external CDN dependencies)
- **Summary CSV:** `<OutputDirectory>\PatchAudit_<HOST>_<TIMESTAMP>_Summary.csv` (single-row host summary for fleet aggregation)
- **Details CSV:** `<OutputDirectory>\PatchAudit_<HOST>_<TIMESTAMP>_Details.csv` (missing updates + recent installed/failed history)
- **JSON Report (optional):** `<OutputDirectory>\PatchAudit_<HOST>_<TIMESTAMP>.json`

---

## EDR / Security Interpretation & Exit Codes

### Overall Health Ratings
- **`Healthy` (Exit Code `0`):** Patch age within SLA, no pending reboot, no missing critical/important security updates, all update services enabled, and no policy red flags.
- **`AttentionRequired` (Exit Code `1`):** Pending reboot detected, patch age exceeded (`> MaxPatchAgeDays`), missing important/security updates, high uptime (`> 30` days), or recent failed update installations.
- **`CriticalRisk` (Exit Code `1`):** Missing `Critical` updates, patch age `> 2 * MaxPatchAgeDays`, disabled update service (`wuauserv`, `UsoSvc`, `TrustedInstaller`, etc.), or EDR policy red flags (`NoAutoUpdate=1`, `DisableWindowsUpdateAccess=1`, unreachable/loopback `WUServer`).

### Exit Codes
| Code | Meaning |
| :---: | :--- |
| `0` | Audit completed successfully; endpoint status is `Healthy`. |
| `1` | Audit completed successfully; endpoint status is `AttentionRequired` or `CriticalRisk`. |
| `2` | Critical execution error (e.g., log initialization failure or missing admin rights with `-NoElevate`). |

---

## Screenshots

### Standard Execution & CLI Help
![Standard Run](assets/Standard_run.jpg)

### Scanning Progress
![Scanning Progress](assets/Scanning.jpg)

### Console Audit Report
![Console Report](assets/Console_raport.jpg)

### HTML Audit Dashboard
![HTML Audit Dashboard](assets/Patch-Audit-ROMAN-PC-E590-11-13-2026_07_42_PM.png)

### HTML Audit Dashboard (Updated with Author Footer)
![HTML Audit Dashboard Updated](assets/Patch-Audit-ROMAN-PC-E590-11-14-2026_07_47_AM.png)

---

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
- **Repository:** [Windows-Desktop](https://github.com/romanpindela/Windows-Desktop)
