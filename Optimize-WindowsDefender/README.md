# Optimize-WindowsDefender

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Developer and administrative workstations running heavy Git, Node.js, .NET, Rust, Python, or container builds frequently suffer high `MsMpEng.exe` CPU usage and I/O bottlenecks from real-time Microsoft Defender Antivirus scanning of package caches and build artifacts. IT administrators need a sanctioned, PPL-safe tool that audits Defender health, profiles top resource-hogging files (`-Analyze`), and tunes scan CPU caps, Dev Drive Performance Mode, and developer exclusions without disabling core protection or weakening Tamper Protection.

## Overview

`Optimize-WindowsDefender.ps1` provides performance tuning, live ETW performance profiling (`-Analyze`), health auditing (`-Audit`), signature hygiene, and configuration backup/restore for Microsoft Defender (`WinDefend` / `MsMpEng.exe`). Using sanctioned `MpCmdRun.exe` and `Set-MpPreference` / `Add-MpPreference` APIs, it manages scan CPU caps (`-CpuLimit`), archive scan bypass, idle-only/battery task guards, Dev Drive performance mode, developer workspace/process exclusions, and JSON snapshots (`-BackupConfig` / `-RestoreConfig`).

## Environment & Prerequisites

- **OS:** Windows 10 / Windows 11 (Developer Edition / Pro / Enterprise)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** Built-in `Defender` module and `MpCmdRun.exe`; no external modules required.

## Permissions Required

**Admin** — Modifying Defender preferences, reloading the platform engine, cleaning `DetectionHistory`, capturing ETW performance traces (`-Analyze`), and optimizing scheduled tasks require elevated Administrator privileges (`S-1-5-32-544`). The script auto-elevates via UAC unless `-SkipAdminCheck` is passed; `-Audit`, `-Help`, and zero-parameter runs work as a standard `User`.

## Safety & Impact

- **Risk Level:** `Modifies system state` — Modifies Microsoft Defender preferences, exclusions, scan CPU limits, scheduled tasks, and signature caches (except `-Audit` and `-Help`, which are `Read-Only / Non-destructive`).
- **WhatIf / Confirm & Backup:** Supports `-WhatIf` and `-Confirm` (`SupportsShouldProcess`) and includes built-in JSON configuration backup/restore (`-BackupConfig`, automatically included when running `-All`, and `-RestoreConfig <file>`). Also logs execution to `C:\Logs\...`.

## Usage Examples

```powershell
# Display built-in help and syntax guide without elevation
.\Optimize-WindowsDefender.ps1 -Help

# Non-destructive health check and status audit (User context)
.\Optimize-WindowsDefender.ps1 -Audit

# Live ETW performance profiler (20-second trace of top scanned files/processes)
.\Optimize-WindowsDefender.ps1 -Analyze -AnalyzeDurationSeconds 20

# Execute complete optimization sequence (creates backup, configures limits and exclusions)
.\Optimize-WindowsDefender.ps1 -All

# Apply targeted developer tuning and preview changes first with -WhatIf
.\Optimize-WindowsDefender.ps1 -ApplyDeveloperExclusions -DevProfiles Node,DotNet,Rust -ExcludeDevProcesses -CpuLimit 15 -CustomExclusionPaths "C:\GitHub", "D:\Workspaces"
.\Optimize-WindowsDefender.ps1 -All -WhatIf

# Backup and restore Defender preferences snapshot
.\Optimize-WindowsDefender.ps1 -BackupConfig
.\Optimize-WindowsDefender.ps1 -RestoreConfig "C:\Logs\20261107-DefenderConfig-Backup-HOST.json"
```

### Parameter Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-All` | `[switch]` | `$false` | Executes full optimization lifecycle (backup, signatures, reload, 20% CPU cap, archive bypass, idle/battery guards, self/dev exclusions, history cleanup). |
| `-Audit` | `[switch]` | `$false` | Read-only health check of signature age, engine state, exclusions, and events (`-HealthCheck`). |
| `-Analyze` | `[switch]` | `$false` | Records live ETW performance trace and displays top scanned files/processes/extensions (`-TopOffenders`). |
| `-AnalyzeDurationSeconds` | `[int]` | `15` | Duration in seconds (`5`–`120`) for ETW trace recording. |
| `-ResetSignatures` | `[switch]` | `$false` | Purges cached definitions and downloads fresh signatures via `MpCmdRun.exe`. |
| `-RestartEngine` | `[switch]` | `$false` | Reloads Defender platform services via `MpCmdRun.exe -RestartPlatform`. |
| `-CpuLimit` | `[int]` | `20` | Average CPU percentage cap during scans (`5`–`100`). |
| `-DisableArchiveScanning` | `[switch]` | `$false` | Disables deep archive scanning during scans. |
| `-OptimizeScheduledTasks` | `[switch]` | `$false` | Enforces idle-only scanning, low CPU priority, and battery safeguards. |
| `-OptimizeDevDrive` | `[switch]` | `$false` | Enables asynchronous Performance Mode on ReFS Dev Drive volumes. |
| `-ApplySelfExclusion` | `[switch]` | `$false` | Adds idempotent exclusions for `MsMpEng.exe` and `%ProgramData%\Microsoft\Windows Defender`. |
| `-ApplyDeveloperExclusions` | `[switch]` | `$false` | Auto-detects and excludes common developer package caches and workspaces. |
| `-DevProfiles` | `[string[]]` | `'All'` | Target profiles: `All`, `Node`, `DotNet`, `Rust`, `Python`, `Java`, `Go`, `IDE`. |
| `-ExcludeDevProcesses` | `[switch]` | `$false` | Excludes high-throughput developer binaries (`git.exe`, `node.exe`, `cargo.exe`, `dotnet.exe`, etc.). |
| `-CustomExclusionProcesses` | `[string[]]` | `$null` | Custom process executable names to exclude. |
| `-CustomExclusionPaths` | `[string[]]` | `$null` | Custom folder paths to exclude from real-time monitoring. |
| `-CleanDetectionHistory` | `[switch]` | `$false` | Removes stale detection event logs from `DetectionHistory`. |
| `-BackupConfig` | `[switch]` | `$false` | Exports current Defender preferences to a timestamped JSON snapshot in `C:\Logs\`. |
| `-RestoreConfig` | `[string]` | `$null` | Restores Defender preferences from a JSON backup file. |
| `-ResetToDefaults` | `[switch]` | `$false` | Reverts Defender settings to Microsoft factory defaults. |
| `-LogPath` | `[string]` | `C:\Logs\...` | Custom path for UTF-8 execution logs. |
| `-SkipAdminCheck` | `[switch]` | `$false` | Skips automatic UAC elevation check. |
| `-PassThru` | `[switch]` | `$false` | Outputs structured `PSCustomObject` results to the pipeline. |
| `-Help` | `[switch]` | `$false` | Displays console help and syntax guide (`-h`). |

### Screenshots

![Standard Run & Interactive Help Menu](assets/Standard_run.jpg)

![Optimization Execution Summary](assets/Optimization.jpg)

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
- **License:** MIT
