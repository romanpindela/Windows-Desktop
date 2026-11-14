# Invoke-RemoteCommand

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Running quick ad-hoc diagnostic or administrative commands (such as `whoami`, `ipconfig`, or service checks) on remote Windows endpoints over WinRM normally requires manually building `PSCredential` objects, wrapping strings into script blocks, and invoking `Invoke-Command` repeatedly. Administrators need a concise CLI wrapper that prompts only for missing credentials or command strings and runs them directly over PowerShell Remoting.

## Overview

`Invoke-RemoteCommand.ps1` connects to `-ComputerName` using `Invoke-Command` over WinRM, converts `-RemoteCommand` (or an interactive `Read-Host` prompt) into a `[scriptblock]`, and executes it remotely with provided or prompted `-Credential` objects.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** WinRM / PowerShell Remoting enabled and reachable on `-ComputerName`; no external modules required.

## Permissions Required

**User** (locally) — The credentials supplied via `-Credential` or the interactive prompt must have PowerShell Remoting access on `-ComputerName` (typically `Administrators` or `Remote Management Users`) and sufficient privileges on the target host for the executed command.

## Safety & Impact

- **Risk Level:** `Modifies system state` (depends on remote command executed) — Executes arbitrary remote PowerShell commands (`[scriptblock]::Create($RemoteCommand)`); safe when running read-only queries, state-changing when executing administrative modifications.
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no backups.

## Usage Examples

```powershell
# Display built-in help and usage details
.\Invoke-RemoteCommand.ps1 -ShowHelp
.\Invoke-RemoteCommand.ps1 -h

# Prompt interactively for credentials and remote command on target host
.\Invoke-RemoteCommand.ps1 -ComputerName '10.10.1.4'

# Execute a specific command non-interactively with saved credentials
$cred = Get-Credential
.\Invoke-RemoteCommand.ps1 -ComputerName 'SRV1' -Credential $cred -RemoteCommand 'whoami'
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-ComputerName` | | `[string]` | *(Mandatory)* | Hostname or IP address of the remote target machine. |
| `-Credential` | | `[PSCredential]` | `$null` | Optional credentials for remote WinRM authentication. |
| `-RemoteCommand` | | `[string]` | `$null` | PowerShell command string to execute on the target computer. |
| `-ShowHelp` | `-h`, `-Help` | `[switch]` | `$false` | Displays help and usage details. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
