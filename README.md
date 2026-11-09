# Windows-Desktop Automation & Management

A collection of professional PowerShell scripts designed to automate routine tasks, optimize system performance, and facilitate efficient remote management across **Windows 10** and **Windows 11** Desktop environments.

These tools are built to help IT Administrators and power users streamline daily operations, maintain system health, and enforce configurations without manual intervention.

## 🚀 Key Features

* **Task Automation:** Automates repetitive administrative and maintenance tasks to save time and reduce human error.
* **Remote Management:** Scripts tailored for seamless execution via WinRM, PSSession, or deployment tools.
* **System Optimization:** Utilities for auditing, tweaking, and maintaining Windows 10/11 desktops.
* **Admin-Friendly:** Clean, commented, and modular PowerShell code ready for integration into corporate environments or helpdesk workflows.

## 🛠️ Prerequisites

* **OS:** Windows 10 / Windows 11
* **PowerShell:** 5.1+ (PowerShell 7+ recommended for modern features)
* **Execution Policy:** Must be set to allow script execution (e.g., `RemoteSigned` or `Bypass` for specific sessions).
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```

## 📦 Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/romanpindela/Windows-Desktop.git
   cd Windows-Desktop
   ```

2. **Unblock downloaded scripts:**
   ```powershell
   Unblock-File -Path .\Add-NetworkPrinter\Add-NetworkPrinter.ps1
   ```

---

## 🖨️ Featured Scripts & Tools

### [Add-NetworkPrinter](Add-NetworkPrinter/README.md)
* **Script:** [`Add-NetworkPrinter.ps1`](Add-NetworkPrinter/Add-NetworkPrinter.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise-grade automation script for deploying network TCP/IP printers in local area networks (LAN).
  * **Network Diagnostics:** Automatically verifies Print Spooler service, performs ICMP Ping and RAW TCP port 9100 availability tests.
  * **Driver Flexibility:** Supports installing via pre-existing system drivers (e.g. `KONICA MINOLTA Universal PCL`), local `.inf` files/directories, or downloading driver archives (.zip / .inf) directly over HTTPS.
  * **Reliable Setup:** Idempotently creates TCP/IP ports and printer queues with optional automated test page printing (`-PrintTestPage`).
  * **Standards Compliant:** Interactive console help on zero parameters (`-h`), language-independent UAC auto-elevation (supports English and Polish Windows), and strict input sanitization.
* **Quick Example:**
  ```powershell
  # Deploy network printer using system driver (e.g., Konica Minolta C224e at 10.10.1.71)
  .\Add-NetworkPrinter\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e"
  ```

---

### [Manage-WindowsOptionalFeatures](Manage-WindowsOptionalFeatures/README.md)
* **Script:** [`Manage-WindowsOptionalFeatures.ps1`](Manage-WindowsOptionalFeatures/Manage-WindowsOptionalFeatures.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise-grade PowerShell tool for inspecting, listing details, enabling, and disabling Windows Optional Features (DISM / `Win32_OptionalFeature`) in Windows 10 and Windows 11.
  * **Complete Feature Details:** Combines DISM (`Get-WindowsOptionalFeature`) and CIM (`Win32_OptionalFeature`) to list `FeatureName`, localized `DisplayName`, `State`, `RestartRequired`, `Description`, and `CustomProperties` for every option.
  * **Enable & Disable Operations:** Supports enabling or disabling single or multiple features via `-Action Enable|Disable` or `-Enable` / `-Disable` switches, with automatic parent dependency resolution (`-All`), `-DryRun` simulation, and CSV/JSON export (`-ExportPath`).
  * **Standards Compliant:** Zero-parameter interactive help (`-h`), language-independent UAC auto-elevation via SID (`S-1-5-32-544`), input sanitization, and detailed logging to `C:\Logs`.
* **Quick Example:**
  ```powershell
  # List all Windows Optional Features with details
  .\Manage-WindowsOptionalFeatures\Manage-WindowsOptionalFeatures.ps1 -List

  # Enable Telnet Client and Windows Sandbox
  .\Manage-WindowsOptionalFeatures\Manage-WindowsOptionalFeatures.ps1 -Action Enable -FeatureName "TelnetClient", "Containers-DisposableClientVM"
  ```

---

### [replace-text-in-files](replace-text-in-files/README.md)
* **Script:** [`replace-text-in-files.ps1`](replace-text-in-files/replace-text-in-files.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Safe, atomic search-and-replace utility across files and directory trees.
  * **Safe & Non-Destructive:** Loads content in memory (`-Raw`), performs changes, writes to temporary files before atomic replacement to prevent data corruption.
  * **Dual Compatibility:** Works seamlessly across Windows PowerShell 5.1 and PowerShell 7+.
  * **Advanced Regex & Evaluators:** Supports literal string matching, full regular expressions (`-UseRegex`), multiline/singleline block modes (`-RegexSingleline`, `-RegexMultiline`), and dynamic PowerShell ScriptBlock evaluators (`-MatchEvaluator`).
  * **Binary Protection & Size Guard:** Auto-detects and skips binary files to prevent corruption, with configurable file size limits (`-MaxFileSizeMB`).
  * **Visual Diff & Auditing:** Colorized line-by-line diff preview (`-ShowDiff`), in-place or isolated backup directory trees (`-BackupDirectory`), and audit exports to JSON/CSV (`-ExportReportPath`).
  * **WhatIf & Backups:** Native `-WhatIf` simulation, `-Confirm` prompts, optional `.bak` file backups (`-CreateBackup`), and structured logging (`-EnableLogging`).
* **Quick Example:**
  ```powershell
  # Search and replace in Markdown files with visual diff preview
  .\replace-text-in-files\replace-text-in-files.ps1 -Path ".\Docs" -Filter "*.md" -FindText "old-domain.com" -ReplaceWith "new-domain.com" -CreateBackup -ShowDiff
  ```

---

### [Optimize-WindowsDefender](Optimize-WindowsDefender/README.md)
* **Script:** [`Optimize-WindowsDefender.ps1`](Optimize-WindowsDefender/Optimize-WindowsDefender.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Comprehensive performance tuning, diagnostics, and maintenance suite for Microsoft Defender Antivirus (`WinDefend` / `MsMpEng.exe`).
  * **Resource Regulation & Scan Limits:** Sets maximum scan CPU load factor (`-CpuLimit`, default: 20%), disables deep archive scanning (`-DisableArchiveScanning`), and enforces low CPU/IO priority.
  * **Developer Acceleration:** Auto-detects and excludes package caches across profiles (`Node`, `DotNet`, `Rust`, `Python`, `Java`, `Go`, `IDE`), excludes dev binaries (`git.exe`, `node.exe`, `cargo.exe`, `dotnet.exe`), and enables Dev Drive (ReFS) Performance Mode.
  * **Live Performance Profiler:** Records ETW traces (`-Analyze` / `-TopOffenders`) to identify the top 10 files, processes, and extensions causing real-time scan latency.
  * **Health Check & Audit:** Non-destructive assessment (`-Audit`) evaluating signature health, exclusion coverage, recent operational event logs, and posture ratings.
  * **Intelligent Scheduling & Battery Guards:** Pauses scans when user is active (`ScanOnlyIfIdleEnabled`), disables battery-draining full scans, and prevents startup catchup scan spikes.
  * **Snapshot Backup & Restore:** Exports configuration state to timestamped JSON (`-BackupConfig`), restores snapshots (`-RestoreConfig`), and supports factory reset (`-ResetToDefaults`).
  * **Safe Platform Operations:** Performs cache hygiene via `MpCmdRun.exe`, signals PPL-compliant platform reloads, and purges stale `DetectionHistory` containers.
  * **Standards Compliant:** Zero-parameter interactive help (`-h`), language-independent UAC auto-elevation via SID (`S-1-5-32-544`), `-WhatIf` / `-Confirm` preview modes, and structured audit logging to `C:\Logs`.
* **Quick Example:**
  ```powershell
  # Full optimization run (backup, signatures, reload, CPU limit 20%, self/dev exclusions, battery guards)
  .\Optimize-WindowsDefender\Optimize-WindowsDefender.ps1 -All

  # Non-destructive health check and audit dashboard
  .\Optimize-WindowsDefender\Optimize-WindowsDefender.ps1 -Audit

  # Profile live Defender scan latency for 20 seconds
  .\Optimize-WindowsDefender\Optimize-WindowsDefender.ps1 -Analyze -AnalyzeDurationSeconds 20
  ```

---

### [Audit-LocalAdministrators](Audit-LocalAdministrators/README.md)
* **Script:** [`Audit-LocalAdministrators.ps1`](Audit-LocalAdministrators/Audit-LocalAdministrators.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise PowerShell security suite for local Administrators group auditing, hybrid/cloud SID classification, orphaned identity detection, and standalone HTML reporting.
  * **Language-Independent Resolution:** Resolves the local Administrators group via Well-Known SID (`S-1-5-32-544`), avoiding failures on non-English locales (e.g., Polish, German, French).
  * **Hybrid & Cloud Classification:** Deep inspection distinguishes built-in Administrator (RID 500), elevated standard local users, Active Directory domain accounts, and Microsoft Entra ID (Azure AD) identities (`S-1-12-1-*`).
  * **Advanced Anomaly Engine:** Flags lingering orphaned SIDs, unmanaged RID 500 accounts lacking Windows LAPS, credential sprawl, dormant accounts, and stale passwords.
  * **Offline Standalone HTML Report:** Emits a dependency-free, Apple-inspired responsive dark/light mode HTML dashboard with real-time text filtering and column sorting.
  * **Standards Compliant:** Zero-parameter interactive help (`-h`), language-independent UAC auto-elevation, structured microsecond logging to `C:\Logs`, and CSV export.
* **Quick Example:**
  ```powershell
  # Perform security audit and generate standalone responsive HTML report
  .\Audit-LocalAdministrators\Audit-LocalAdministrators.ps1 -GenerateHtmlReport

  # Full audit with console summary, CSV export, and HTML report
  .\Audit-LocalAdministrators\Audit-LocalAdministrators.ps1 -Audit -GenerateHtmlReport -ExportCsv
  ```

### [Audit-BitLockerAndTpmStatus](Audit-BitLockerAndTpmStatus/README.md)
* **Script:** [`Audit-BitLockerAndTpmStatus.ps1`](Audit-BitLockerAndTpmStatus/Audit-BitLockerAndTpmStatus.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise cryptographic and hardware trust audit tool for Windows 10/11 and Windows Server, verifying EU NIS2 and Zero-Trust data-at-rest compliance.
  * **Hardware Root of Trust:** Audits TPM 2.0 presence, readiness, physical dTPM vs firmware fTPM, firmware version, and UEFI Secure Boot enablement.
  * **BitLocker Volume Encryption:** Audits complete encryption (100%), cipher algorithms (XTS-AES 128/256), and key protector hygiene (TPM, Recovery Passwords).
  * **Cloud / AD Escrow Verification:** Inspects Event Log `845`/`846` events and directory join status (`dsregcmd /status`) to verify recovery key backup in Microsoft Entra ID or Active Directory.
  * **Modern HTML Dashboard:** Emits a standalone, dependency-free responsive dark/light mode HTML compliance report with zero external CDN dependencies.
* **Quick Example:**
  ```powershell
  # Full cryptographic audit with console summary and HTML report
  .\Audit-BitLockerAndTpmStatus\Audit-BitLockerAndTpmStatus.ps1 -OpenReport
  ```

### [Audit-EndpointPersistence](Audit-EndpointPersistence/README.md)
* **Script:** [`Audit-EndpointPersistence.ps1`](Audit-EndpointPersistence/Audit-EndpointPersistence.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise-grade security auditing and threat detection suite for Windows Auto-Start Execution Points (ASEP) and persistence mechanisms.
  * **Exhaustive ASEP Vectors:** Audits Scheduled Tasks (elevated SYSTEM/admin contexts, user-writable folders), Registry Run/RunOnce (64-bit and WOW6432Node), Explorer Shell Folders, Active Setup StubPath, Startup Folders (with deep shortcut `.lnk` resolution), and Windows Services.
  * **Unquoted Service Paths (CWE-428):** Flags unquoted service binaries containing spaces vulnerable to privilege escalation via binary planting.
  * **Authenticode Signature Verification:** Inspects digital signatures (`Get-AuthenticodeSignature`) and extracts publisher identities to distinguish legitimate software from rogue drops.
  * **Heuristic Risk Engine:** Automatically qualifies findings into `Critical`, `High`, `Medium`, and `Low` risk levels.
  * **Standalone HTML Dashboard:** Self-contained, responsive Apple-inspired dark/light theme report with instant search, category/risk filter pills, column sorting, and actionable remediation commands.
  * **Enterprise Integration:** Timestamped telemetry logging to `C:\Logs\Audit-EndpointPersistence.log`, CSV export, and pipeline-friendly `PSCustomObject` emission.
* **Quick Example:**
  ```powershell
  # Full persistence audit and launch interactive HTML report in browser
  .\Audit-EndpointPersistence\Audit-EndpointPersistence.ps1 -OpenReport

  # Filter console and pipeline output to high and critical threats
  .\Audit-EndpointPersistence\Audit-EndpointPersistence.ps1 -MinimumRiskLevel High -ExportCsv
  ```

### [Audit-LocalFirewallAndListeningPorts](Audit-LocalFirewallAndListeningPorts/README.md)
* **Script:** [`Audit-LocalFirewallAndListeningPorts.ps1`](Audit-LocalFirewallAndListeningPorts/Audit-LocalFirewallAndListeningPorts.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise PowerShell security suite for Windows Defender Firewall posture auditing, critical inbound exposure detection, active network socket inventory, process Authenticode signature verification, and standalone responsive HTML reporting.
  * **Firewall Profile Posture:** Inspects `Domain`, `Private`, and `Public` profiles for active state, default inbound/outbound actions, and security drop/allow event logging.
  * **Critical Inbound Rule Detection:** Flags unrestricted inbound access (`RemoteAddress: Any / * / 0.0.0.0/0`) targeting critical ports: RDP (3389), WinRM (5985/5986), SMB (445/139), SSH (22), FTP (21), and Telnet (23).
  * **Listening Sockets & Process Integrity:** Enumerates all active TCP listening sockets and UDP endpoints, correlates owning PIDs, executable paths, command lines, and verifies cryptographic Authenticode signatures to identify untrusted, unsigned, or ghost processes.
  * **Standalone HTML Dashboard:** 100% self-contained, offline HTML audit report featuring an Apple-inspired responsive layout with dark/light theme, live instant search, and protocol/signature filter pills.
  * **Enterprise Integration:** Structured microsecond logging to `C:\Logs`, CSV export, and native pipeline `[PSCustomObject]` output.
* **Quick Example:**
  ```powershell
  # Full security audit with console summary and HTML report
  .\Audit-LocalFirewallAndListeningPorts\Audit-LocalFirewallAndListeningPorts.ps1 -ShowReportInBrowser

  # Custom high-risk ports audit and CSV export
  .\Audit-LocalFirewallAndListeningPorts\Audit-LocalFirewallAndListeningPorts.ps1 -HighRiskPorts @(22, 3389, 5985, 5986) -ExportCsv
  ```

---

## 🛡️ Desktop Auditing & Security

| Tool | Description | Compatibility |
| :--- | :--- | :--- |
| [Audit-BitLockerAndTpmStatus](./Audit-BitLockerAndTpmStatus) | Cryptographic audit of TPM 2.0, UEFI Secure Boot, BitLocker encryption, and Cloud/AD Escrow for NIS2 compliance. | PowerShell 5.1 / 7+ |
| [Audit-EndpointPersistence](./Audit-EndpointPersistence) | Audits Auto-Start Execution Points (ASEP), unquoted service paths (CWE-428), startup items, and persistence mechanisms with HTML reporting. | PowerShell 5.1 / 7+ |
| [Audit-LocalAdministrators](./Audit-LocalAdministrators) | Audits members of the local Administrators group (SID S-1-5-32-544), detects orphaned SIDs, logs to C:\Logs, and generates standalone HTML reports. | PowerShell 5.1 / 7+ |
| [Audit-LocalFirewallAndListeningPorts](./Audit-LocalFirewallAndListeningPorts) | Audits Windows Defender Firewall profiles, high-risk unrestricted inbound rules, listening TCP/UDP endpoints, and Authenticode signatures. | PowerShell 5.1 / 7+ |
| [Optimize-WindowsDefender](./Optimize-WindowsDefender) | Performance tuning, diagnostics, and maintenance suite for Microsoft Defender Antivirus (`WinDefend` / `MsMpEng.exe`). | PowerShell 5.1 / 7+ |

