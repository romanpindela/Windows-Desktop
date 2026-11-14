# New-JunctionPoint

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Applications or user workflows often expect data at fixed local directories even when storage space requires relocating those folders to another drive or consolidated directory, and creating NTFS junctions manually with `mklink /J` in `cmd.exe` often skips path validation or accidentally collides with existing folders.

## Overview

`New-JunctionPoint.ps1` validates that both `-JunctionPath` and `-TargetPath` are non-empty absolute paths, confirms `-TargetPath` is an existing directory, verifies `-JunctionPath` does not already exist, and creates an NTFS Directory Junction (`New-Item -ItemType Junction`). Running without parameters or with `-ShowHelp` prints usage help.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server (NTFS volume)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** Native PowerShell `New-Item -ItemType Junction`; no external modules required.

## Permissions Required

**User** — Standard NTFS permissions to create items in the parent directory of `-JunctionPath` and read `-TargetPath` are sufficient (`Admin` is only required if `-JunctionPath` resides inside a protected system directory such as `C:\Program Files`).

## Safety & Impact

- **Risk Level:** `Modifies system state` — Creates a new NTFS Directory Junction object at `-JunctionPath` (aborts with an error if `-JunctionPath` already exists so existing directories or files are not overwritten).
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no backups (aborts safely on path collision).

## Usage Examples

```powershell
# Display built-in help and usage examples (also shown when parameters are omitted)
.\New-JunctionPoint.ps1 -ShowHelp
.\New-JunctionPoint.ps1 -h

# Create an NTFS Directory Junction from C:\MyLink pointing to D:\Data\Folder
.\New-JunctionPoint.ps1 -JunctionPath 'C:\MyLink' -TargetPath 'D:\Data\Folder'
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-JunctionPath` | | `[string]` | `$null` | Full path where the new NTFS Directory Junction will be created. |
| `-TargetPath` | | `[string]` | `$null` | Full path to the existing target directory. |
| `-ShowHelp` | `-h`, `-Help` | `[switch]` | `$false` | Displays help and usage examples. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
