# Invoke-GitHubScript

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.0%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-lightgrey.svg)](https://www.microsoft.com/windows)

## Problem Statement

During ad-hoc troubleshooting or provisioning on fresh Windows machines, cloning an entire repository or manually downloading a `.ps1` file via a browser, stripping `Zone.Identifier` blocks, enforcing TLS 1.2, and adjusting execution policy adds friction. Administrators need a quick launcher that converts a GitHub web URL (`/blob/`) into its raw endpoint, downloads and unblocks the script into `C:\PowerShell`, and runs it with optional arguments.

## Overview

`Invoke-GitHubScript.ps1` accepts a GitHub file URL (`-UrlToDownload`), optional target arguments (`-ScriptArgs`), and a local cache folder (`-DestinationPath`, defaulting to `C:\PowerShell`). It checks Administrator privileges using SID `S-1-5-32-544` (requesting UAC elevation automatically while preserving positional arguments), enforces TLS 1.2, translates `/blob/` URLs to `raw.githubusercontent.com`, downloads the target script via `Invoke-WebRequest -UseBasicParsing`, runs `Unblock-File`, and invokes the downloaded script with `-ScriptArgs`.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server 2016/2019/2022/2025+
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** HTTPS access (port 443) to `github.com` and `raw.githubusercontent.com`; native `Invoke-WebRequest` and `Unblock-File`.

## Permissions Required

**Admin** — Verifies Local Administrator privileges (`BuiltInAdministratorsSid` / `S-1-5-32-544`) and automatically triggers UAC elevation when run from an unprivileged session so downloaded scripts can perform system-level operations and write to `C:\PowerShell`.

## Safety & Impact

- **Risk Level:** `Modifies system state` — Creates `-DestinationPath` (`C:\PowerShell`), writes the downloaded `.ps1` script, removes its `Zone.Identifier` stream, and immediately executes arbitrary downloaded PowerShell code from `-UrlToDownload` (plus whatever system changes the downloaded script performs). Only point `-UrlToDownload` at trusted, audited scripts.
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no backups before overwriting a identically named file in `-DestinationPath`.

## Usage Examples

```powershell
# Display Comment-Based Help and parameter documentation
Get-Help .\Invoke-GitHubScript.ps1 -Full

# Download and execute the default SharePoint Sync script with -AutoDiscover
.\Invoke-GitHubScript.ps1

# Download and run Get-WifiProfiles from GitHub cleanly
.\Invoke-GitHubScript.ps1 -UrlToDownload "https://github.com/romanpindela/Windows-Desktop/blob/main/Get-WifiProfiles/Get-WifiProfiles.ps1" -ScriptArgs ""

# Download a custom script to D:\Tools and pass multiple arguments
.\Invoke-GitHubScript.ps1 -UrlToDownload "https://github.com/romanpindela/Microsoft-365/blob/main/SharePoint/Sync-SharePointLibrary/Sync-SharePointLibrary.ps1" -ScriptArgs "-AutoDiscover -All" -DestinationPath "D:\Tools"
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-UrlToDownload` | *(Positional 0)* | `[string]` | `Sync-SharePointLibrary.ps1` URL | GitHub `/blob/` or `raw.githubusercontent.com` URL of the `.ps1` script. |
| `-ScriptArgs` | *(Positional 1)* | `[string]` | `"-AutoDiscover"` | Argument string forwarded to the downloaded script. |
| `-DestinationPath` | *(Positional 2)* | `[string]` | `"C:\PowerShell"` | Local directory where the script is saved before execution. |

### ExecutionPolicy Scopes Reference (For Copy-Paste Bootstrap)

| Option | Scope (`-Scope`) | Registry Level | Persistence | When to Use |
| :--- | :--- | :--- | :--- | :--- |
| **Machine** | `LocalMachine` | `HKLM:\SOFTWARE\Microsoft\PowerShell...` | **Permanent** | Baseline workstations/servers enabling signed/local scripts for all users. |
| **User** | `CurrentUser` | `HKCU:\SOFTWARE\Microsoft\PowerShell...` | **Permanent** | Shared hosts restricting policy changes to the current profile. |
| **Session** | `Process` | None (in-memory) | **Temporary** | One-time remote troubleshooting where permanent registry edits are undesirable. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
- **License:** MIT
