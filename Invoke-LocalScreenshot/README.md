# Invoke-LocalScreenshot

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Support technicians and automation jobs occasionally need to capture what is displayed on the active user's desktop screen programmatically (for remote troubleshooting or via Task Scheduler in an interactive session) without relying on external GUI screenshot tools.

## Overview

`Invoke-LocalScreenshot.ps1` uses .NET `System.Windows.Forms.Screen` and `System.Drawing.Graphics` (`CopyFromScreen`) to capture the entire primary display and save a timestamped PNG image (`screenshot-yyyy.MM.dd_HH.mm.ss.png`) inside `-OutputDirectory` (defaulting to `C:\temp`).

## Environment & Prerequisites

- **OS:** Windows 10 / Windows 11 (must execute inside an active interactive desktop session, not headless Session 0)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** .NET assemblies `System.Windows.Forms` and `System.Drawing`; no external modules required.

## Permissions Required

**User** — Runs cleanly under the interactive user context as long as the user has write permissions to `-OutputDirectory`.

## Safety & Impact

- **Risk Level:** `Modifies system state` (writes file only) — Creates `-OutputDirectory` if missing and saves a timestamped `.png` screenshot image without altering OS settings or applications.
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no backups (each run generates a uniquely timestamped PNG file).

## Usage Examples

```powershell
# Display built-in help and options
.\Invoke-LocalScreenshot.ps1 -ShowHelp
.\Invoke-LocalScreenshot.ps1 -h

# Capture primary screen to the default C:\temp directory
.\Invoke-LocalScreenshot.ps1

# Capture primary screen to a custom directory
.\Invoke-LocalScreenshot.ps1 -OutputDirectory "C:\Screenshots"
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-OutputDirectory` | | `[string]` | `C:\temp` | Directory path where the PNG screenshot is saved (created if absent). |
| `-ShowHelp` | `-h`, `-Help` | `[switch]` | `$false` | Displays help and usage details. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
