# Enable-RemoteManagement

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Enabling PowerShell Remoting (`WinRM`) for non-built-in administrator or delegated user accounts on Windows endpoints requires setting execution policy, activating the WinRM service and firewall listeners, and adding the account to the `Remote Management Users` group (`S-1-5-32-580`) while verifying that the user exists. System administrators need a single script that validates the account and configures WinRM remoting reliably.

## Overview

`Enable-RemoteManagement.ps1` sets PowerShell execution policy to `RemoteSigned` for `CurrentUser`, runs `Enable-PSRemoting -Force`, optionally updates `WSMan:\localhost\Client\TrustedHosts` (`-TrustedHostPattern`), validates `-TargetUser` existence, adds the user to the `Remote Management Users` group via language-independent SID `S-1-5-32-580`, and lists all authorized members.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server (Polish and English editions)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Dependencies:** Native PowerShell Remoting (`WinRM`) and `LocalAccounts` / ADSI; no external modules required.

## Permissions Required

**Admin** — Running `Enable-PSRemoting`, configuring `TrustedHosts`, and adding accounts to local security groups require elevated Administrator privileges. If started unprivileged without `-ShowHelp`, the script automatically requests UAC elevation (`Start-Process -Verb RunAs`). Note that `-TrustedHostPattern` or custom `-TargetUser` values should be passed from an elevated session because auto-relaunch starts without forwarding original CLI arguments.

## Safety & Impact

- **Risk Level:** `Modifies system state` — Changes `CurrentUser` ExecutionPolicy, enables WinRM with default firewall rules (`Any` source scope unless restricted manually afterward), modifies `Remote Management Users` membership, and optionally updates `TrustedHosts`.
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no configuration backups prior to applying WinRM or group membership changes.

## Usage Examples

```powershell
# Display built-in help and usage details
.\Enable-RemoteManagement.ps1 -ShowHelp
.\Enable-RemoteManagement.ps1 -h

# Enable PSRemoting and grant access to the default Administrator account
.\Enable-RemoteManagement.ps1

# Grant remote management access to a specific user and configure TrustedHosts
.\Enable-RemoteManagement.ps1 -TargetUser 'rpindela' -TrustedHostPattern '10.10.1.*'
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-TargetUser` | | `[string]` | `Administrator` | Local user or `Domain\User` granted membership in `Remote Management Users`. |
| `-TrustedHostPattern` | | `[string]` | `$null` | Optional hostname/IP wildcard added to `WSMan:\localhost\Client\TrustedHosts`. |
| `-ShowHelp` | `-h`, `-Help` | `[switch]` | `$false` | Displays interactive help, version, and author details. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
