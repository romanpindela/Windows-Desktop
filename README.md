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
  * **Regex & Literal:** Supports case-sensitive/insensitive string replacements and regular expressions (`-UseRegex`).
  * **WhatIf & Backups:** Native `-WhatIf` preview, optional `.bak` file backups (`-CreateBackup`), and audit logging (`-EnableLogging`).
* **Quick Example:**
  ```powershell
  # Safe search and replace in Markdown files
  .\replace-text-in-files\replace-text-in-files.ps1 -Path ".\Docs" -Filter "*.md" -FindText "old-domain.com" -ReplaceWith "new-domain.com" -CreateBackup
  ```

---

### [Optimize-WindowsDefender](Optimize-WindowsDefender/README.md)
* **Script:** [`Optimize-WindowsDefender.ps1`](Optimize-WindowsDefender/Optimize-WindowsDefender.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** High-performance optimization and maintenance utility for Microsoft Defender Antivirus (`WinDefend` / `MsMpEng.exe`).
  * **Resource Regulation & Scan Limits:** Sets maximum scan CPU load factor (`-CpuLimit`, default: 20%) and disables deep archive scanning (`-DisableArchiveScanning`) to prevent system lockups.
  * **Definition Cache Hygiene:** Flushes stale or corrupted signature definition databases and pulls clean updates directly using official `MpCmdRun.exe` CLI.
  * **Safe Platform Reload:** Safely signals platform reload (`-RestartPlatform`) in compliance with Protected Process Light (PPL) and Tamper Protection.
  * **Idempotent Exclusions:** Manages self-exclusions (`MsMpEng.exe` and `%ProgramData%\Microsoft\Windows Defender`) to eliminate recursive scanning feedback loops, and adds high-I/O developer workspace folders with $O(1)$ cached lookups.
  * **Detection History Purge:** Clears stale and unlocked detection logs to resolve persistent false-positive GUI notification loops.
  * **Standards Compliant:** Zero-parameter interactive help (`-h`), language-independent UAC auto-elevation via SID (`S-1-5-32-544`), `-WhatIf` / `-Confirm` preview modes, and structured audit logging to `C:\Logs`.
* **Quick Example:**
  ```powershell
  # Full optimization run (signatures, reload, CPU limit 20%, self-exclusions, and history cleanup)
  .\Optimize-WindowsDefender\Optimize-WindowsDefender.ps1 -All

  # Throttle scan CPU to 15% and exclude high-I/O developer directories
  .\Optimize-WindowsDefender\Optimize-WindowsDefender.ps1 -CpuLimit 15 -CustomExclusionPaths "C:\GitHub", "D:\BuildCaches" -WhatIf
  ```
