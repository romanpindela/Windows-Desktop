# Invoke-WindowsRepair

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Diagnosing and repairing corrupted Windows Component Store files and protected system binaries manually requires remembering exact `DISM.exe` and `sfc.exe` flags, ensuring elevation across localized Windows editions, and capturing logs of every phase cleanly. Administrators need an automated, language-agnostic repair runner with targeted phase selection and persistent logging.

## Overview

`Invoke-WindowsRepair.ps1` automates Windows image health checks and system file repairs using `dism.exe` (`/CheckHealth`, `/ScanHealth`, `/RestoreHealth`) and `sfc.exe` (`/scannow`). It validates Administrator privileges via SID (`BuiltInAdministratorsSid`), runs either the complete sequence (`-Action All`, default) or individual steps (`Check`, `Scan`, `Restore`, `Sfc`), and logs timestamped progress to `C:\Windows\Logs\SystemRepair_Log.txt` (or `-LogPath`).

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server (English and Polish editions)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** Native `dism.exe` and `sfc.exe`; internet or Windows Update/WSUS access may be required when `DISM /RestoreHealth` downloads clean payload files.

## Permissions Required

**Admin** — Executing `DISM` and `SFC` servicing commands and writing to `C:\Windows\Logs\SystemRepair_Log.txt` require elevated Administrator privileges (`BuiltInAdministratorsSid`); the script automatically prompts for UAC elevation when started unprivileged (`-Help` displays without elevation).

## Safety & Impact

- **Risk Level:** `Modifies system state` — `All`, `Restore`, and `Sfc` modes repair Windows Component Store and protected OS system files; `Check` and `Scan` modes are diagnostic read-only scans (though all modes write logs to `-LogPath`).
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm`; relies on native Windows Component Store/CBS transaction logging (`CBS.log` / `dism.log`) rather than creating separate user backups.

## Usage Examples

```powershell
# Display built-in help menu and usage examples
.\Invoke-WindowsRepair.ps1 -Help

# Run the complete repair sequence (DISM CheckHealth, ScanHealth, RestoreHealth, and SFC)
.\Invoke-WindowsRepair.ps1 -Action All

# Run only a quick component store scan and save logs to a custom path
.\Invoke-WindowsRepair.ps1 -Action Scan -LogPath "C:\CustomLogs\Repair.txt"

# Run only System File Checker (sfc /scannow)
.\Invoke-WindowsRepair.ps1 -Action Sfc
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-Action` | | `[string]` | `All` | Operation to run: `All`, `Check`, `Scan`, `Restore`, or `Sfc`. |
| `-LogPath` | | `[string]` | `C:\Windows\Logs\SystemRepair_Log.txt` | Destination path for UTF-8 execution logs. |
| `-Help` | | `[switch]` | `$false` | Displays help guide and examples. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
