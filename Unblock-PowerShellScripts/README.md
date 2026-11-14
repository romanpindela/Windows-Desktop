# Unblock-PowerShellScripts

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

PowerShell scripts and modules (`.ps1`, `.psm1`, `.psd1`) downloaded from GitHub or the internet carry the NTFS `Zone.Identifier` alternate data stream (Mark of the Web), causing `RemoteSigned` execution policy security prompts or blocked execution until each file is manually unblocked. Administrators need a bulk utility that recursively detects and strips `Zone.Identifier` streams across a target folder with confirmation prompts and summary counts.

## Overview

`Unblock-PowerShellScripts.ps1` verifies Administrator privileges via SID `S-1-5-32-544`, recursively scans `-Path` for `.ps1`, `.psm1`, and `.psd1` files containing a `Zone.Identifier` alternate data stream, prompts for user confirmation unless `-Force` is specified, removes the block via `Unblock-File`, and prints unblocked/failed summary statistics.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server (English and Polish editions)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** Native `Unblock-File` and NTFS alternate data stream inspection (`Get-Item -Stream "Zone.Identifier"`); no external modules required.

## Permissions Required

**Admin** — Enforces Administrator check (`S-1-5-32-544`) via `Test-IsAdministrator` before processing files and exits with code `1` if not elevated (`-HelpMe` / `-Help` / `-h` displays help as a standard `User`).

## Safety & Impact

- **Risk Level:** `Modifies system state` — Permanently strips the `Zone.Identifier` (Mark of the Web) NTFS alternate data stream from matching `.ps1`, `.psm1`, and `.psd1` files under `-Path`. Only unblock scripts from verified, trusted sources.
- **WhatIf / Confirm & Backup:** Prompts interactively (`Y/N`) before unblocking unless `-Force` is specified; does not implement `-WhatIf` / `-Confirm` (`SupportsShouldProcess` not enabled) and creates no backups of removed `Zone.Identifier` streams.

## Usage Examples

```powershell
# Display built-in help and usage details without elevation
.\Unblock-PowerShellScripts.ps1 -HelpMe
.\Unblock-PowerShellScripts.ps1 -Help
.\Unblock-PowerShellScripts.ps1 -h

# Prompt to recursively unblock downloaded PowerShell scripts in a directory
.\Unblock-PowerShellScripts.ps1 -Path "C:\Users\Roman\Downloads\Scripts"

# Silently unblock all blocked PowerShell files in the current directory
.\Unblock-PowerShellScripts.ps1 -Path "." -Force
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-Path` | *(Positional 0)* | `[string]` | `$null` | Target directory scanned recursively for blocked `.ps1`, `.psm1`, and `.psd1` files. |
| `-Force` | | `[switch]` | `$false` | Bypasses the interactive confirmation prompt before unblocking. |
| `-HelpMe` | `-h`, `-Help` | `[switch]` | `$false` | Displays custom help menu and usage examples. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
