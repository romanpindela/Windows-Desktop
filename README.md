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
