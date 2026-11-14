# Copy-FromSession

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Copying files, log bundles, or directories back from remote Windows machines often fails when SMB file shares (`C$`) are blocked by firewalls or when manual `New-PSSession` / `Copy-Item -FromSession` / cleanup steps are error-prone. Administrators need a wrapper that authenticates cleanly over WinRM, verifies remote source paths before transfer, creates the destination directory if missing, and tears down the session even if an error occurs.

## Overview

`Copy-FromSession.ps1` prompts for remote credentials, opens a WinRM `PSSession` to `-ComputerName`, validates all `-RemotePath` entries on the remote machine, creates `-LocalPath` if needed, copies files or folders recursively with `Copy-Item -FromSession`, and removes the session in a `finally` block.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** WinRM / PowerShell Remoting enabled and reachable on the target host (TCP 5985/5986); no third-party modules required.

## Permissions Required

**User** (locally, assuming write access to `-LocalPath`) — The remote credentials prompted via `Get-Credential` must have WinRM/PSSession permission (typically `Administrators` or `Remote Management Users`) and read access to `-RemotePath` on `-ComputerName`.

## Safety & Impact

- **Risk Level:** `Modifies system state` — Creates `-LocalPath` if missing and overwrites matching local destination files during transfer (`Copy-Item -Force -Recurse`). Does not modify files on the remote machine.
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and does not create backups before overwriting local files.

## Usage Examples

```powershell
# Display built-in help and examples
.\Copy-FromSession.ps1 -ShowHelp
.\Copy-FromSession.ps1 -h

# Retrieve a single file from a remote server
.\Copy-FromSession.ps1 -ComputerName 'SRV1' -RemotePath 'C:\remote_temp\data.txt' -LocalPath 'C:\local_temp\'

# Retrieve multiple files in a single session
.\Copy-FromSession.ps1 -ComputerName 'SRV1' -RemotePath 'C:\remote_temp\a.txt', 'C:\remote_temp\b.txt' -LocalPath 'C:\local_temp\'

# Retrieve an entire directory recursively
.\Copy-FromSession.ps1 -ComputerName 'SRV1' -RemotePath 'C:\RemoteFolder' -LocalPath 'C:\local_temp\'
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-ComputerName` | | `[string]` | `$null` | Hostname or IP address of the remote computer. |
| `-RemotePath` | | `[string[]]` | `$null` | One or more file or directory paths on the remote computer. |
| `-LocalPath` | | `[string]` | `$null` | Absolute destination directory path on the local computer. |
| `-ShowHelp` | `-h`, `-Help` | `[switch]` | `$false` | Displays help and usage examples. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
