# Manage-SmbShareAccess: Set-SmbShareAccessRule

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011%20%2F%20Server-lightgrey.svg)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

A robust, enterprise-grade PowerShell automation utility to administer and synchronize **SMB Share permissions** and **NTFS file system Access Control Lists (ACLs)** across Windows Desktop and Windows Server environments.

---

## Overview

In Windows, effective network file access is the intersection of two distinct security layers:
1. **SMB Share Permissions** (managed via the `SmbShare` module).
2. **NTFS File System Permissions** (managed via directory Access Control Lists).

Mismatches between these layers frequently lead to security vulnerabilities or unexpected permission denials. `Set-SmbShareAccessRule.ps1` bridges this gap by providing an atomic, automated workflow that applies consistent permissions across both layers simultaneously.

### Key Capabilities

* **Dual-Layer Synchronization:** Grants, revokes, or blocks access on both SMB and NTFS in a single operation.
* **Automatic UAC Elevation:** Detects administrative token state using language-independent Built-in Administrator SIDs and prompts for elevation when necessary.
* **Bilingual OS Support:** Functions seamlessly across Polish and English editions of Windows (Windows 10, Windows 11, and Windows Server 2019/2022/2025). Resolves identities through `System.Security.Principal.SecurityIdentifier` (SID).
* **Inheritance Protection:** Never breaks directory ACL inheritance when revoking or updating rules. Only targeted explicit rules are modified.
* **Permission Consistency Analysis:** Inspects effective rights post-execution and emits warnings if SMB or NTFS settings restrict each other (e.g., SMB FullControl vs. NTFS Read).
* **Simulation & Safety (`-WhatIf` / `-Confirm`):** Full support for standard PowerShell `SupportsShouldProcess` flags.
* **Comprehensive Logging:** Real-time colorized console feedback combined with structured logging to `C:\Logs\Manage-SmbShareAccess_yyyyMMdd.log`.

---

## Requirements

* **Operating System:** Windows 10, Windows 11 (Pro, Enterprise, Education) or Windows Server 2019+.
* **PowerShell Version:** Windows PowerShell 5.1 or PowerShell Core 7+.
* **Privileges:** Local Administrator privileges (auto-elevated if started unprivileged in an interactive session).
* **Modules:** `SmbShare` and `Microsoft.PowerShell.Security` (built into Windows).

---

## Installation & Security Unblocking

If you download or clone this script from GitHub onto a Windows machine, the file will be flagged with the `Zone.Identifier` alternate data stream (downloaded from the Internet). Before execution, unblock the script:

```powershell
Unblock-File -Path ".\Set-SmbShareAccessRule.ps1"
```

To unblock all scripts in the repository folder:

```powershell
Get-ChildItem -Path ".\Manage-SmbShareAccess" -Recurse | Unblock-File
```

---

## Permission Mapping Architecture

| Level (`-AccessRight`) | SMB AccessRight | NTFS FileSystemRights | NTFS Inheritance Flags |
| :--- | :--- | :--- | :--- |
| `Read` | `Read` | `ReadAndExecute, Synchronize` | `ContainerInherit, ObjectInherit` |
| `Change` | `Change` | `Modify, Synchronize` | `ContainerInherit, ObjectInherit` |
| `FullControl` | `Full` | `FullControl` | `ContainerInherit, ObjectInherit` |

---

## Parameters

| Parameter | Type | Required | Default | Description |
| :--- | :--- | :---: | :---: | :--- |
| `-ShareName` | `[string]` | **Yes** | — | Name of the SMB network share. |
| `-AccountName` | `[string[]]` | **Yes** | — | One or more accounts (e.g., `DOMAIN\user`, `BUILTIN\Users`, `.\LocalUser`). |
| `-Action` | `[string]` | **Yes** | — | Action to execute: `Grant`, `Revoke`, or `Deny`. |
| `-AccessRight` | `[string]` | No | `Read` | Access level: `Read`, `Change`, or `FullControl`. |
| `-ApplyToNtfs` | `[switch]` | No | `$true` | Synchronize permissions to NTFS ACLs. Pass `-ApplyToNtfs:$false` for SMB only. |
| `-LogPath` | `[string]` | No | `C:\Logs` | Destination folder for log files. |
| `-Help`, `-h` | `[switch]` | No | — | Displays the interactive help and syntax reference. |
| `-WhatIf` | `[switch]` | No | — | Simulates the operation without making changes. |
| `-Confirm` | `[switch]` | No | — | Prompts for confirmation before applying modifications. |

> **Note:** Invoking the script without any parameters safely displays the built-in help guide and exits without making changes.

---

## Usage Examples

### Example 1: Grant Read Access to a Domain Account (SMB + NTFS)

```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "RaportyFinansowe" -AccountName "DOMENA\k.nowak" -Action Grant -AccessRight Read
```

### Example 2: Grant Modify (Change) Access to a Local Group

```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "Projekty" -AccountName "EdytorzyProjektow" -Action Grant -AccessRight Change
```

### Example 3: Revoke Access Across SMB and NTFS

Removes SMB share permissions and purges explicit NTFS ACEs while preserving folder inheritance:

```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -Action Revoke
```

### Example 4: Modify SMB Share Only (Skip NTFS)

```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "Public" -AccountName "BUILTIN\Users" -Action Grant -AccessRight Read -ApplyToNtfs:$false
```

### Example 5: Simulation Mode (`-WhatIf`)

Test actions safely before applying changes to production shares:

```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -Action Revoke -WhatIf
```

### Example 6: Display Interactive Help

```powershell
.\Set-SmbShareAccessRule.ps1 -Help
# or
.\Set-SmbShareAccessRule.ps1 -h
```

---

## Running Automated Tests

The project includes unit and parameter validation tests powered by **Pester**:

```powershell
Invoke-Pester -Script ".\Tests\Set-SmbShareAccessRule.Tests.ps1"
```

---

## Logging & Auditing

Execution logs are structured and automatically stored at:
```plaintext
C:\Logs\Manage-SmbShareAccess_yyyyMMdd.log
```

Log entry format:
```plaintext
[2026-11-04 11:08:00] [INFO] [ShareValidation] SMB Share found. Physical directory path: 'D:\Shares\Dane'
[2026-11-04 11:08:01] [INFO] [SmbAction] Granting SMB share access (Change) to 'DOMENA\k.nowak'...
[2026-11-04 11:08:01] [INFO] [NtfsAction] Successfully applied NTFS Allow rule: Change (Modify, Synchronize).
[2026-11-04 11:08:02] [INFO] [Consistency] [CONSISTENCY OK] Permissions between SMB and NTFS are balanced.
```

---

## Author & Version Information

* **Author:** Roman Pindela
* **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
* **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **Script Version:** 1.0.0
* **License:** MIT License
