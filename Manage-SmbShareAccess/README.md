# Manage-SmbShareAccess

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Administering Windows file shares across separate SMB Share permissions and underlying filesystem NTFS ACLs is error-prone: permissive share rules paired with restrictive NTFS ACLs (or vice versa) create confusing access failures or accidental data exposure, while removing shares manually risks deleting backing data. File-server administrators need a single audited tool that manages share lifecycle and synchronizes SMB + NTFS permissions while preserving folder inheritance and supporting dry-run simulation.

## Overview

`Manage-SmbShareAccess.ps1` administers Windows SMB network shares and backing NTFS directory ACLs through seven actions (`List`, `Show`, `Create`, `Remove`, `Grant`, `Revoke`, `Deny`). It provides side-by-side SMB/NTFS permission consistency checks, supports Access-Based Enumeration (`-EnableABE`), SMB encryption (`-EncryptData`), language-independent UAC auto-elevation (`S-1-5-32-544`), centralized daily logging (`C:\Logs\`), and includes a Pester unit test suite under `Tests\Manage-SmbShareAccess.Tests.ps1`.

## Environment & Prerequisites

- **OS:** Windows 10, Windows 11, or Windows Server 2019+ (English and Polish editions)
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Modules / Dependencies:** Built-in `SmbShare` module and `FileServer` / NTFS ACL .NET APIs; optional `Pester` module to execute tests in `Tests\`.

## Permissions Required

**Admin** — Querying, creating, removing, and updating SMB share access (`SmbShare`) and NTFS folder ACLs require Local Administrator privileges (`S-1-5-32-544`); the script automatically prompts for UAC elevation when run from a standard session (omitting parameters or passing `-Help` / `-h` displays help without elevation).

## Safety & Impact

- **Risk Level:** `Modifies system state` (for `Create`, `Remove`, `Grant`, `Revoke`, `Deny`; `List` and `Show` are `Read-Only / Non-destructive`) — `Remove` deletes the SMB share definition only and leaves files/folders intact on disk; `Grant`/`Revoke`/`Deny` modify SMB and NTFS ACLs while preserving folder inheritance.
- **WhatIf / Confirm & Backup:** Full support for PowerShell `-WhatIf` and `-Confirm` (`SupportsShouldProcess`) on state-changing actions; does not create automatic ACL/share configuration backups (writes daily audit logs under `C:\Logs\`).

## Usage Examples

```powershell
# Display built-in help and syntax reference
.\Manage-SmbShareAccess.ps1 -Help

# List all non-hidden SMB shares (or include administrative $ shares)
.\Manage-SmbShareAccess.ps1 -Action List
.\Manage-SmbShareAccess.ps1 -Action List -IncludeHidden

# Audit SMB and NTFS ACLs side-by-side with consistency analysis
.\Manage-SmbShareAccess.ps1 -Action Show -ShareName "RaportyFinansowe"

# Create an encrypted share with Access-Based Enumeration enabled
.\Manage-SmbShareAccess.ps1 -Action Create -ShareName "Projekty" -Path "D:\Shares\Projekty" -Description "Team Projects" -EnableABE -EncryptData

# Grant or revoke access on both SMB and NTFS (or simulate with -WhatIf)
.\Manage-SmbShareAccess.ps1 -Action Grant -ShareName "RaportyFinansowe" -AccountName "DOMENA\k.nowak" -AccessRight Read
.\Manage-SmbShareAccess.ps1 -Action Revoke -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -WhatIf

# Explicitly deny access or safely remove a share without deleting files
.\Manage-SmbShareAccess.ps1 -Action Deny -ShareName "Poufne" -AccountName "DOMENA\j.nowak" -AccessRight FullControl
.\Manage-SmbShareAccess.ps1 -Action Remove -ShareName "StaryProjekt"

# Run the Pester test suite
Invoke-Pester -Script ".\Tests\Manage-SmbShareAccess.Tests.ps1"
```

### Parameters

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-Action` | | `[string]` | `$null` | Operation: `List`, `Show`, `Create`, `Remove`, `Grant`, `Revoke`, or `Deny`. |
| `-ShareName` | | `[string]` | `$null` | SMB share name (required except optional filter in `List`). |
| `-Path` | | `[string]` | `$null` | Physical directory path on disk (required for `Create`). |
| `-AccountName` | | `[string[]]` | `$null` | Account(s) targeted by `Grant`, `Revoke`, or `Deny`. |
| `-AccessRight` | | `[string]` | `Read` | Permission level: `Read`, `Change`, or `FullControl`. |
| `-ApplyToNtfs` | | `[bool]` | `$true` | Synchronizes `Grant`/`Revoke`/`Deny` changes with underlying NTFS ACLs. |
| `-Description` | | `[string]` | `$null` | Optional share description for `Create`. |
| `-EnableABE` | | `[switch]` | `$false` | Enables Access-Based Enumeration when creating a share. |
| `-EncryptData` | | `[switch]` | `$false` | Enables SMB 3.0+ encryption on the share. |
| `-CachingMode` | | `[string]` | `Manual` | Offline caching: `None`, `Manual`, `Programs`, `Documents`, or `BranchCache`. |
| `-ConcurrentUserLimit` | | `[int]` | `0` | Concurrent connection limit (`0` = unlimited). |
| `-IncludeHidden` | | `[switch]` | `$false` | Includes `$`-suffixed administrative shares in `List`. |
| `-LogPath` | | `[string]` | `C:\Logs\` | Directory for daily execution log files. |
| `-Help` | `-h` | `[switch]` | `$false` | Displays interactive help and syntax reference. |

## Author

- **Roman Pindela**
- **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
- **License:** MIT
