# Restart-PrintSpooler

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Corrupted or stalled print jobs frequently jam the Windows Print Spooler queue (`C:\Windows\System32\spool\PRINTERS`), blocking all subsequent printing and leaving printers stuck in a `Paused` state until an administrator manually stops the service, deletes locked `.SPL`/`.SHD` spool files, restarts `Spooler`, and resumes queued printers.

## Overview

`Restart-PrintSpooler.ps1` verifies Administrator privileges via language-independent SID (`S-1-5-32-544`, auto-elevating via UAC if needed), stops the `Spooler` service, deletes all pending files inside `%SystemRoot%\System32\spool\PRINTERS`, restarts the `Spooler` service, and automatically resumes any `Paused` printers via CIM `Resume` method unless `-SkipPrinterResume` is specified.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server (English and Polish editions)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** Native Windows `Spooler` service and CIM `Win32_Printer`; no external modules required.

## Permissions Required

**Admin** — Stopping/starting the `Spooler` service, clearing `%SystemRoot%\System32\spool\PRINTERS`, and resuming printer queues require elevated Administrator privileges (`S-1-5-32-544`). When started unprivileged without `-Help`/`-H`, the script automatically requests UAC elevation while preserving `-SkipPrinterResume`.

## Safety & Impact

- **Risk Level:** `Modifies system state` — Temporarily stops the `Spooler` service, **permanently deletes all queued print jobs** in `%SystemRoot%\System32\spool\PRINTERS\*`, starts `Spooler`, and unpauses paused printers (unless `-SkipPrinterResume` is passed).
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and does not back up deleted spool job files.

## Usage Examples

```powershell
# Display built-in help and options without elevation
.\Restart-PrintSpooler.ps1 -Help
.\Restart-PrintSpooler.ps1 -H

# Stop Spooler, clear stuck print jobs, restart Spooler, and resume paused printers
.\Restart-PrintSpooler.ps1

# Reset Spooler and clear jobs while keeping intentionally paused printers paused
.\Restart-PrintSpooler.ps1 -SkipPrinterResume
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-SkipPrinterResume` | | `[switch]` | `$false` | Skips automatically resuming `Paused` printers after spooler restart. |
| `-Help` | | `[switch]` | `$false` | Displays help and exits. |
| `-H` | | `[switch]` | `$false` | Short switch to display help and exit. |

### Screenshots

![Standard Run](assets/screenshot-standard-run.jpg)

![Help Output](assets/screenshot-help.jpg)

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
