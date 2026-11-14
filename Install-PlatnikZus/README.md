# Install-PlatnikZus

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Preparing Windows workstations for ZUS Płatnik manually requires checking `.NET Framework 4.8+` prerequisites and hunting down current installer and patch executables before setup can begin. Helpdesk technicians need an automated script that prepares runtime dependencies and downloads the official Płatnik packages to a consistent staging directory on Polish and English Windows editions.

## Overview

`Install-PlatnikZus.ps1` verifies and installs the required `.NET Framework 4.8+` runtime via `winget`, prepares `C:\Temp`, and downloads the official ZUS Płatnik installer (`install.exe`) and patch (`P2StartFix2.exe`). It supports environment-only preparation (`-PrepareEnvironment`) or full preparation plus selective download (`-PrepareAndDownload` with `-Download All | InstallerOnly | PatchOnly`), while displaying help when run with `-Help` or no action switch.

## Environment & Prerequisites

- **OS:** Windows 10 / Windows 11 (language-agnostic: Polish and English editions)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** Internet access and Windows Package Manager (`winget`) if `.NET Framework 4.8+` needs to be installed.

## Permissions Required

**Admin** — Installing prerequisites via `winget` and writing staged installers to system locations requires Administrator privileges (`S-1-5-32-544`); the script automatically prompts for UAC elevation when executing preparation/download actions (`-Help` displays without elevation).

## Safety & Impact

- **Risk Level:** `Modifies system state` — Installs `.NET Framework` (when missing via `winget`), creates `C:\Temp`, and downloads executable installers from the configured URLs.
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no backups before downloading files into `C:\Temp`.

## Usage Examples

```powershell
# Display built-in help and parameter usage
.\Install-PlatnikZus.ps1 -Help
.\Install-PlatnikZus.ps1 -h

# Check and install .NET Framework 4.8+ prerequisites only
.\Install-PlatnikZus.ps1 -PrepareEnvironment

# Prepare environment and download both the installer and patch to C:\Temp
.\Install-PlatnikZus.ps1 -PrepareAndDownload

# Prepare environment and download only the Płatnik patch
.\Install-PlatnikZus.ps1 -PrepareAndDownload -Download PatchOnly

# Prepare environment and download only the main installer from a custom URL
.\Install-PlatnikZus.ps1 -PrepareAndDownload -Download InstallerOnly -InstallerUrl "https://example.com/install.exe"
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-InstallerUrl` | | `[string]` | ZUS CDN URL | Direct URL for the main ZUS Płatnik installer (`install.exe`). |
| `-PatchUrl` | | `[string]` | ZUS CDN URL | Direct URL for the ZUS Płatnik patch (`P2StartFix2.exe`). |
| `-Download` | | `[string]` | `All` | Files to download in `-PrepareAndDownload` mode: `All`, `InstallerOnly`, or `PatchOnly`. |
| `-PrepareEnvironment` | | `[switch]` | `$false` | Checks and installs required `.NET Framework 4.8+` prerequisites only. |
| `-PrepareAndDownload` | | `[switch]` | `$false` | Prepares prerequisites and downloads the selected Płatnik package(s) to `C:\Temp`. |
| `-Help` | `-h` | `[switch]` | `$false` | Displays interactive help and usage examples. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
