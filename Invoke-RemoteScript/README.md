# Invoke-RemoteScript

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Deploying or running local `.ps1` administration scripts across remote machines via SMB file copies leaves temporary script files behind on target disks and runs into execution-policy or share-permission issues. Administrators need a way to execute local `.ps1` scripts directly in remote memory over WinRM with full parameter passing.

## Overview

`Invoke-RemoteScript.ps1` validates that `-ScriptPath` points to an existing local `.ps1` file, establishes a WinRM `PSSession` to `-ComputerName`, converts the script contents to a `[scriptblock]`, executes it remotely via `Invoke-Command` in memory (supporting optional `-ArgumentList` and `-Credential`), and closes the session cleanly.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** WinRM / PowerShell Remoting enabled and reachable on `-ComputerName`; no external modules required.

## Permissions Required

**User** (locally, assuming read access to `-ScriptPath`) — Supplied or prompted `-Credential` must belong to `Administrators` or `Remote Management Users` on `-ComputerName` and hold sufficient remote privileges for the payload script's actions.

## Safety & Impact

- **Risk Level:** `Modifies system state` (depends on target `.ps1` script) — Executes local `.ps1` code in-memory on the remote target without writing the script file to the remote disk.
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no backups.

## Usage Examples

```powershell
# Display built-in help and examples (also shown if required arguments are omitted)
.\Invoke-RemoteScript.ps1 -ShowHelp
.\Invoke-RemoteScript.ps1 -h

# Execute a local audit script on a remote server (prompts for credentials)
.\Invoke-RemoteScript.ps1 -ComputerName 'SRV-PROD01' -ScriptPath 'C:\Scripts\Get-Audit.ps1'

# Pass arguments and pre-captured credentials
$Credential = Get-Credential
.\Invoke-RemoteScript.ps1 -ComputerName '10.10.1.5' -ScriptPath '.\Deploy.ps1' -ArgumentList 'Prod', 123 -Credential $Credential
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-ComputerName` | | `[string]` | `$null` | Hostname or IP address of the remote computer. |
| `-ScriptPath` | | `[string]` | `$null` | Local path to an existing `.ps1` script file. |
| `-Credential` | | `[PSCredential]` | `$null` | Optional credentials for remote authentication. |
| `-ArgumentList` | | `[object[]]` | `$null` | Optional arguments forwarded to the remote script. |
| `-ShowHelp` | `-h`, `-Help` | `[switch]` | `$false` | Displays help, parameter descriptions, and examples. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
