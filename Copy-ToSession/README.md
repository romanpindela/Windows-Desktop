# Copy-ToSession

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Deploying installers, patches, or configuration folders to remote hosts across segmented networks is difficult when administrative SMB shares are unavailable or manual WinRM file transfers skip destination directory checks and session cleanup. Administrators need a reliable WinRM wrapper that validates local source paths, ensures the target folder exists remotely, pushes files cleanly, and closes the `PSSession`.

## Overview

`Copy-ToSession.ps1` validates local paths specified via `-LocalPath`, prompts for credentials, opens a `PSSession` to `-ComputerName`, creates `-RemotePath` on the remote host if missing, transfers files or directories recursively via `Copy-Item -ToSession`, and closes the session cleanly.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** WinRM / PowerShell Remoting enabled and reachable on the target host (TCP 5985/5986); no third-party modules required.

## Permissions Required

**User** (locally, assuming read access to `-LocalPath`) — The remote credentials prompted via `Get-Credential` must have WinRM/PSSession access (typically `Administrators` or `Remote Management Users`) and write permissions to `-RemotePath` on `-ComputerName`.

## Safety & Impact

- **Risk Level:** `Modifies system state` — Creates `-RemotePath` on the target computer if missing and overwrites matching destination files during transfer (`Copy-Item -Force -Recurse`).
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and does not create backups before overwriting remote files.

## Usage Examples

```powershell
# Display built-in help and examples
.\Copy-ToSession.ps1 -ShowHelp
.\Copy-ToSession.ps1 -h

# Copy a single local file to a remote computer
.\Copy-ToSession.ps1 -ComputerName 'SRV1' -LocalPath 'C:\temp\data.txt' -RemotePath 'C:\remote_temp\'

# Copy multiple local files in a single session
.\Copy-ToSession.ps1 -ComputerName 'SRV1' -LocalPath 'C:\temp\a.txt', 'C:\temp\b.txt' -RemotePath 'C:\remote_temp\'

# Copy an entire local directory recursively
.\Copy-ToSession.ps1 -ComputerName 'SRV1' -LocalPath 'C:\LocalFolder' -RemotePath 'C:\remote_temp\'
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-ComputerName` | | `[string]` | `$null` | Hostname or IP address of the remote computer. |
| `-LocalPath` | | `[string[]]` | `$null` | One or more local file or directory paths to copy. |
| `-RemotePath` | | `[string]` | `$null` | Destination base directory path on the remote computer. |
| `-ShowHelp` | `-h`, `-Help` | `[switch]` | `$false` | Displays help and usage examples. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
