# Open-Session

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Connecting interactively to a remote Windows workstation or server over PowerShell Remoting (`Enter-PSSession`) requires typing credential prompts and session parameters repeatedly when switching across LAN hosts. Administrators need a fast, zero-boilerplate command launcher to authenticate and drop straight into a remote interactive PowerShell shell.

## Overview

`Open-Session.ps1` accepts a target `-ComputerName` (or positional hostname/IP), prompts for remote credentials via `Get-Credential`, and establishes an interactive WinRM session with `Enter-PSSession`. Omitting `-ComputerName` or passing `-Help` / `-H` prints usage instructions.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** WinRM / PowerShell Remoting enabled and reachable on `-ComputerName`; no external modules required.

## Permissions Required

**User** (locally) — The credentials supplied at the `Get-Credential` prompt must be authorized for WinRM remoting on the target host (member of `Administrators` or `Remote Management Users`).

## Safety & Impact

- **Risk Level:** `Read-Only / Non-destructive` — Opens an interactive WinRM shell session only without altering local or remote configuration by itself (any subsequent actions depend on commands typed interactively inside the session).
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no backups.

## Usage Examples

```powershell
# Display built-in help and options (also shown when ComputerName is omitted)
.\Open-Session.ps1 -Help
.\Open-Session.ps1 -H

# Open an interactive PowerShell Remoting session by hostname
.\Open-Session.ps1 SERVER01

# Open an interactive PowerShell Remoting session by IP address
.\Open-Session.ps1 10.10.1.4
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-ComputerName` | *(Positional 0)* | `[string]` | `$null` | Hostname or IP address of the remote computer. |
| `-Help` | | `[switch]` | `$false` | Displays help and usage details. |
| `-H` | | `[switch]` | `$false` | Short switch to display help and exit. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
