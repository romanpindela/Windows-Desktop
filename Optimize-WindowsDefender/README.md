# Optimize Windows Defender (`Optimize-WindowsDefender`)

**Version:** 2.0.0  
**Release Date:** 2026-11-07  
**Author:** Roman Pindela  
**License:** MIT  

An enterprise-grade performance tuning, diagnostics, and maintenance suite for **Microsoft Defender Antivirus** (`WinDefend` / `MsMpEng.exe`) across **Windows 10**, **Windows 11**, and **Windows Server** (x64 / ARM64).

---

## 📋 Project Information

| Parameter | Value |
| :--- | :--- |
| **Project Name** | Optimize Windows Defender |
| **Script Name** | `Optimize-WindowsDefender.ps1` |
| **Author** | Roman Pindela |
| **Email** | [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com) |
| **GitHub** | [https://github.com/romanpindela](https://github.com/romanpindela) |
| **Repository** | [Windows-Desktop](https://github.com/romanpindela/Windows-Desktop) |
| **Version** | 2.0.0 |
| **Release Date** | 2026-11-07 |
| **License** | MIT |

---

## 🚀 Overview

Workstations, developer systems, and server nodes frequently experience runaway CPU spikes, prolonged disk I/O latency, and background thread contention caused by Microsoft Defender Antivirus (`MsMpEng.exe`). Common bottlenecks include:
* **Scanning Feedback Loops:** Defender scanning its own temporary engine caches, definition catalogs, and transaction logs in `%ProgramData%\Microsoft\Windows Defender`.
* **Developer Tool I/O Thrashing:** Real-time mini-filter interception (`WdFilter.sys`) on thousands of file operations during `npm install`, `nuget restore`, `cargo build`, `pip install`, or large `git` commits.
* **Compiler & Binary Interception:** Process creation latency overhead on developer tools (`git.exe`, `node.exe`, `dotnet.exe`, `cargo.exe`, `cl.exe`, `msbuild.exe`).
* **Archive Decompression Spikes:** Deep inspection of multi-gigabyte `.zip`, `.cab`, and `.iso` files locking CPU cores.
* **Corrupted Definition Caches:** Incomplete or fragmented antimalware signature updates causing the engine to repeatedly recompile databases in the background.
* **Intrusive Scheduled Scans:** Background scans kicking in during active interactive work, high-load rendering, or while running on laptop battery power.
* **Ghost GUI Notifications:** Locked or stale detection logs in `DetectionHistory` triggering recurrent false-positive notifications even after threats are cleaned.

`Optimize-WindowsDefender.ps1` resolves these issues cleanly while respecting Windows Security architecture (**Protected Process Light - PPL** and **Tamper Protection**). It interacts strictly through Microsoft's sanctioned platform CLI interfaces (`MpCmdRun.exe`), CIM/WMI cmdlets (`Set-MpPreference`), and kernel ETW tracing.

---

## 🌟 Key Features

* **Complete Optimization Workflow (`-All`):** One-shot execution of automatic configuration backup, signature refresh, platform reload, 20% CPU limit, archive scan bypass, idle-only scanning, battery guards, self-exclusions, developer tool cache exclusions, developer process exclusions, Dev Drive acceleration, and history cleanup.
* **Live ETW Performance Profiler (`-Analyze` / `-TopOffenders`):** Captures high-precision Event Tracing for Windows (ETW) logs using `New-MpPerformanceRecording` and generates reports identifying the **Top 10 Files, Processes, and Extensions** generating Defender scan latency.
* **Health Check & Audit Mode (`-Audit` / `-HealthCheck`):** Non-destructive read-only assessment of real-time protection, signature age, active exclusions, scan load limits, recent operational event logs, and color-coded health rating (`OPTIMAL`, `GOOD`, `ATTENTION NEEDED`).
* **Predefined Developer Exclusion Profiles (`-ApplyDeveloperExclusions`):** Automatically detects and excludes high-I/O developer tool caches across active profiles (`Node`, `DotNet`, `Rust`, `Python`, `Java`, `Go`, `IDE`):
  * **Node.js:** `%AppData%\npm-cache`, `%LocalAppData%\pnpm`, `%LocalAppData%\Yarn\Cache`
  * **.NET:** `%UserProfile%\.nuget\packages`
  * **Rust:** `%UserProfile%\.cargo`, `%UserProfile%\.rustup`
  * **Python:** `%LocalAppData%\pip\cache`, `%UserProfile%\.virtualenvs`
  * **Java:** `%UserProfile%\.gradle\caches`, `%UserProfile%\.gradle\wrapper`, `%UserProfile%\.m2\repository`
  * **Go:** `%UserProfile%\go\pkg`
  * **IDE & Editors:** `%LocalAppData%\JetBrains`, `%UserProfile%\.vscode\extensions`
* **Developer Process Exclusions (`-ExcludeDevProcesses`):** Idempotently excludes high-throughput developer binaries (`git.exe`, `node.exe`, `cargo.exe`, `rustc.exe`, `dotnet.exe`, `python.exe`, `msbuild.exe`, `cl.exe`, `tsc.exe`, `go.exe`, `java.exe`, `code.exe`).
* **Dev Drive (ReFS) Performance Mode (`-OptimizeDevDrive`):** Identifies ReFS volumes and activates Defender's asynchronous Dev Drive protection mode for maximum build throughput.
* **Intelligent Scan Scheduling & Battery Safeguards (`-OptimizeScheduledTasks`):**
  * Enables `ScanOnlyIfIdleEnabled` so scans pause immediately upon user activity.
  * Enables `EnableLowCpuPriority` to prevent background scans from competing with foreground applications.
  * Configures Task Scheduler to disallow scheduled scans on battery power (`DisallowStartIfOnBatteries`, `StopIfGoingOnBatteries`).
  * Disables catchup quick/full scans to eliminate aggressive CPU thrashing upon system boot or wakeup.
* **Configuration Snapshot Backup & Restore (`-BackupConfig` / `-RestoreConfig` / `-ResetToDefaults`):**
  * Exports all active preferences, limits, and exclusions to a timestamped JSON file.
  * Restores configuration snapshots seamlessly.
  * Reverts settings to Microsoft factory defaults when needed (`-ResetToDefaults`).
* **Safe Cache & Signature Hygiene (`-ResetSignatures`):** Purges corrupted signature caches via `MpCmdRun.exe -RemoveDefinitions -All` and pulls clean definitions directly via `-SignatureUpdate`.
* **Tamper-Safe Platform Reload (`-RestartEngine`):** Signals service restart via `MpCmdRun.exe -RestartPlatform` without violating PPL boundaries.
* **Language-Agnostic UAC Auto-Elevation:** Verifies administrative privileges using well-known SIDs (`WellKnownSidType::BuiltInAdministratorsSid`), ensuring 100% compatibility across English (`Administrators`) and Polish (`Administratorzy`) Windows systems with argument preservation.
* **Standard PowerShell Impact Mitigation:** Full native support for `-WhatIf` and `-Confirm` preview modes.

---

## 📂 Directory Structure

```shell
Optimize-WindowsDefender/
├── assets/
│   ├── Optimization.jpg            # Screenshot of complete optimization workflow execution
│   └── Standard_run.jpg            # Screenshot of zero-parameter run / architecture & maintenance guide
├── Optimize-WindowsDefender.ps1    # Main optimization, diagnostics, and tuning script
└── README.md                       # Comprehensive technical documentation
```

---

## 💻 System Requirements

* **Operating System:** Windows 10, Windows 11, Windows Server 2016 / 2019 / 2022 / 2025.
* **PowerShell Version:** Windows PowerShell 5.1 or PowerShell 7+.
* **Privileges:** Administrator privileges required for write and configuration tasks. Viewing help (`-h`) and running audit (`-Audit`) execute under standard user rights.
* **Security Compatibility:** Fully compatible with Microsoft Defender Tamper Protection and Protected Process Light (PPL).

---

## 📥 Getting Started

### 1. Unblock the Script (Required After Download)

When downloading PowerShell scripts from GitHub, Windows attaches an alternate data stream mark (`Zone.Identifier`). Unblock the file prior to execution:

```powershell
Unblock-File -Path .\Optimize-WindowsDefender.ps1
```

If execution is restricted by PowerShell policy, allow local script execution:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 📖 Parameter Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-All` | `[switch]` | `False` | Executes full optimization: backup, signatures, reload, 20% CPU limit, archive bypass, idle-only scans, battery guards, self/dev exclusions, and history cleanup. |
| `-Audit` | `[switch]` | `False` | Read-only diagnostic assessment of Defender state, signature age, exclusions, event logs, and health rating. Alias: `-HealthCheck`. |
| `-Analyze` | `[switch]` | `False` | Records a live ETW performance trace and displays the top 10 files, processes, and extensions causing scan latency. Alias: `-TopOffenders`. |
| `-AnalyzeDurationSeconds` | `[int]` | `15` | Duration in seconds for ETW performance recording (range: `5` to `120`). |
| `-ResetSignatures` | `[switch]` | `False` | Purges definition caches (`-RemoveDefinitions -All`) and downloads fresh definitions (`-SignatureUpdate`). |
| `-RestartEngine` | `[switch]` | `False` | Safely reloads Defender platform services via `MpCmdRun.exe -RestartPlatform`. |
| `-CpuLimit` | `[int]` | `20` | Sets average scan CPU utilization cap (allowed range: `5` to `100`). |
| `-DisableArchiveScanning` | `[switch]` | `False` | Disables unpacking and scanning of large compressed archives during scans. (Included in `-All`). |
| `-OptimizeScheduledTasks` | `[switch]` | `False` | Enables idle-only scanning, low CPU priority, disables catchup scans, and enforces battery guards. |
| `-OptimizeDevDrive` | `[switch]` | `False` | Detects ReFS Dev Drive volumes and enables asynchronous Performance Mode. |
| `-ApplySelfExclusion` | `[switch]` | `False` | Adds idempotent exclusions for `MsMpEng.exe` and `%ProgramData%\Microsoft\Windows Defender`. |
| `-ApplyDeveloperExclusions` | `[switch]` | `False` | Auto-detects and excludes developer package caches (npm, nuget, cargo, pip, gradle, go, etc.). |
| `-DevProfiles` | `[string[]]` | `'All'` | Target developer profiles: `All`, `Node`, `DotNet`, `Rust`, `Python`, `Java`, `Go`, `IDE`. |
| `-ExcludeDevProcesses` | `[switch]` | `False` | Excludes common developer binaries (`git.exe`, `node.exe`, `cargo.exe`, `dotnet.exe`, `python.exe`, etc.). |
| `-CustomExclusionProcesses` | `[string[]]` | `$null` | Array of additional custom process executable names to exclude. |
| `-CustomExclusionPaths` | `[string[]]` | `$null` | Array of folder directory paths to add to the Defender exclusion list. |
| `-CleanDetectionHistory` | `[switch]` | `False` | Purges stale detection records from the service `DetectionHistory` directory. |
| `-BackupConfig` | `[switch]` | `False` | Exports current Defender preferences to a timestamped JSON file in `C:\Logs\`. |
| `-RestoreConfig` | `[string]` | `$null` | Restores Defender preferences and exclusions from a specified JSON snapshot file. |
| `-ResetToDefaults` | `[switch]` | `False` | Reverts settings back to Microsoft factory defaults (50% CPU, archive scan enabled, etc.). |
| `-LogPath` | `[string]` | `C:\Logs\...` | Custom target path for the UTF-8 execution log file. |
| `-SkipAdminCheck` | `[switch]` | `False` | Bypasses automatic UAC elevation check (for unattended automation runners). |
| `-PassThru` | `[switch]` | `False` | Returns structured `PSCustomObject` containing pre/post metrics to the pipeline. |
| `-Help` / `-h` | `[switch]` | `False` | Displays the interactive console help guide and exits immediately. |

---

## 💡 Practical Examples

### 1. Complete System Optimization (`-All`)

Runs the full maintenance lifecycle: creates config backup, refreshes signatures, restarts platform, restricts scan CPU load factor to 20%, excludes Defender's internal directories, configures developer caches & binaries, activates battery guards, and clears stale detection logs:

```powershell
.\Optimize-WindowsDefender.ps1 -All
```

### 2. Read-Only Health Check & Status Audit (`-Audit`)

Evaluates Defender health without administrative elevation and outputs a comprehensive dashboard with event logs and recommendations:

```powershell
.\Optimize-WindowsDefender.ps1 -Audit
```

### 3. Live Performance Profiler & Top Offenders Report (`-Analyze`)

Profiles live Defender I/O for 20 seconds while performing builds or git operations to see what files and processes are slowing down the machine:

```powershell
.\Optimize-WindowsDefender.ps1 -Analyze -AnalyzeDurationSeconds 20
```

### 4. Developer Tuning (Package Caches + Dev Processes + 15% CPU Limit)

Optimizes a workstation for software development without disabling core protection:

```powershell
.\Optimize-WindowsDefender.ps1 -ApplyDeveloperExclusions -DevProfiles Node,DotNet,Rust -ExcludeDevProcesses -CpuLimit 15 -CustomExclusionPaths "C:\GitHub", "D:\Workspaces"
```

### 5. Configuration Backup & Restore

Safely snapshots settings before changes, and restores them later:

```powershell
# Backup configuration
.\Optimize-WindowsDefender.ps1 -BackupConfig

# Restore configuration
.\Optimize-WindowsDefender.ps1 -RestoreConfig "C:\Logs\20261107-DefenderConfig-Backup-ROMAN-PC-E590.json"
```

### 6. Non-Destructive Simulation (`-WhatIf`)

Previews all changes that would be performed without modifying system configuration:

```powershell
.\Optimize-WindowsDefender.ps1 -All -WhatIf
```

---

## 📸 Screenshots & Visual Verification

### 1. Interactive Help Menu & Syntax Guide (`.\Optimize-WindowsDefender.ps1`)
![Standard Run & Interactive Help Menu](assets/Standard_run.jpg)

### 2. Complete Maintenance & Optimization Execution (`.\Optimize-WindowsDefender.ps1 -All`)
![Optimization Execution Summary](assets/Optimization.jpg)

---

## 🔬 Technical Deep-Dive

### Protected Process Light (PPL) & Tamper Protection
Attempting to stop `WinDefend` using `Stop-Service`, `taskkill.exe`, or registry modifications fails with `Access Denied` on modern Windows systems due to kernel-level PPL enforcement. `Optimize-WindowsDefender.ps1` interacts strictly through:
1. **`MpCmdRun.exe` Platform Engine:** Dynamically located across `ProgramData\Microsoft\Windows Defender\Platform\CurrentVersion`, versioned platform folders, and system directories.
2. **`Set-MpPreference` / `Add-MpPreference`:** Microsoft's sanctioned CIM/WMI provider interfaces for Defender preferences.

### Elimination of CIM Query Bottlenecks
Standard scripts repeatedly invoke `Get-MpPreference` in loops, which costs 500–1500 ms per CIM round-trip. `Optimize-WindowsDefender.ps1` queries existing preferences once, builds case-insensitive in-memory hash sets (`HashSet<string>`), and performs instantaneous $O(1)$ membership tests before executing idempotent additions.

---

## 📄 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).
