# Manage-SmbShareAccess: `manage-smb-share-access.ps1`

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011%20%2F%20Server-lightgrey.svg)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

A comprehensive, enterprise-grade PowerShell automation utility to administer every aspect of **Windows SMB Network Shares** and backing **NTFS directory Access Control Lists (ACLs)** across Windows Desktop and Windows Server environments.

---

## Capabilities & Architecture

Managing Windows shared resources requires synchronizing two independent security perimeters:
1. **SMB Share Permissions** (governed by the `SmbShare` module at the network boundary).
2. **NTFS Directory Permissions** (governed by filesystem ACLs on disk).

`manage-smb-share-access.ps1` provides an end-to-end management lifecycle:

```plaintext
                               manage-smb-share-access.ps1
                                            │
        ┌───────────────────┬───────────────┴───────────────┬───────────────────┐
        ▼                   ▼                               ▼                   ▼
    1. Inventory       2. Audit & Inspection          3. Provisioning     4. Dual-Layer Security
   (-Action List)      (-Action Show)                (-Action Create)     (-Action Grant/Revoke/Deny)
   • Enumerate shares  • Share configuration         • Folder creation    • SMB Grant/Revoke/Block
   • Hidden shares ($) • SMB Access Control Entries  • ABE enforcement    • NTFS Allow/Deny/Remove
   • Active sessions   • NTFS Directory ACLs         • SMB Encryption     • Inheritance protection
                       • Consistency Analysis        • Caching policies   • Effective right check
```

### Key Highlights

* **Full Share Lifecycle:** Discover (`List`), audit (`Show`), provision (`Create`), decommission (`Remove`), and secure (`Grant`/`Revoke`/`Deny`).
* **Advanced SMB Features:** Toggle **Access-Based Enumeration (ABE)**, **SMB 3.0+ Encryption**, offline caching policies, and concurrent user limits.
* **Dual-Layer Synchronization:** Atomically applies permissions on both SMB and NTFS in a single execution.
* **Automatic UAC Elevation:** Detects administrative token state using language-independent Built-in Administrator SIDs and prompts for elevation when necessary.
* **Bilingual OS Support (PL / EN):** Functions seamlessly across Polish and English editions of Windows 10, Windows 11, and Windows Server 2019/2022/2025. Resolves identities through `System.Security.Principal.SecurityIdentifier` (SID).
* **Inheritance Protection:** Never breaks directory ACL inheritance when revoking or updating rules. Only targeted explicit rules are modified.
* **Permission Consistency Analysis:** Inspects effective rights post-execution and emits warnings if SMB or NTFS settings restrict each other (e.g., SMB FullControl vs. NTFS Read).
* **Simulation & Safety (`-WhatIf` / `-Confirm`):** Full support for standard PowerShell `SupportsShouldProcess` flags.
* **Structured Auditing & Logging:** Real-time colorized console feedback combined with structured logging to `C:\Logs\manage-smb-share-access_yyyyMMdd.log`.

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
Unblock-File -Path ".\manage-smb-share-access.ps1"
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

| Parameter | Type | Applicable Actions | Default | Description |
| :--- | :--- | :--- | :---: | :--- |
| `-Action` | `[string]` | **All** | — | Operation: `List`, `Show`, `Create`, `Remove`, `Grant`, `Revoke`, `Deny`. |
| `-ShareName` | `[string]` | `Show`, `Create`, `Remove`, `Grant`, `Revoke`, `Deny` (Optional for `List`) | — | Name of the SMB network share. |
| `-Path` | `[string]` | `Create` | — | Physical local folder path on disk (e.g., `D:\Shares\Projekty`). |
| `-AccountName` | `[string[]]` | `Grant`, `Revoke`, `Deny` | — | One or more accounts (e.g., `DOMAIN\user`, `BUILTIN\Users`, `.\LocalUser`). |
| `-AccessRight` | `[string]` | `Grant`, `Deny` | `Read` | Permission level: `Read`, `Change`, or `FullControl`. |
| `-ApplyToNtfs` | `[switch]` | `Grant`, `Revoke`, `Deny` | `$true` | Synchronize permissions to NTFS ACLs. Pass `-ApplyToNtfs:$false` for SMB only. |
| `-Description` | `[string]` | `Create` | — | Descriptive remark for the share. |
| `-EnableABE` | `[switch]` | `Create` | `$false` | Enables Access-Based Enumeration (hides folders users cannot access). |
| `-EncryptData` | `[switch]` | `Create` | `$false` | Enforces SMB 3.0+ end-to-end data encryption over the network. |
| `-CachingMode` | `[string]` | `Create` | `Manual` | Offline files caching: `None`, `Manual`, `Programs`, `Documents`, `BranchCache`. |
| `-ConcurrentUserLimit` | `[int]` | `Create` | `0` | Maximum simultaneous user connections (0 = unlimited). |
| `-IncludeHidden` | `[switch]` | `List` | `$false` | Include administrative/hidden shares ending in `$` (e.g., `C$`, `ADMIN$`). |
| `-LogPath` | `[string]` | All | `C:\Logs` | Destination directory for log files. |
| `-Help`, `-h` | `[switch]` | All | — | Displays interactive help and syntax reference. |
| `-WhatIf` | `[switch]` | All modification actions | — | Simulates the operation without making changes. |
| `-Confirm` | `[switch]` | All modification actions | — | Prompts for confirmation before applying modifications. |

> **Note:** Invoking the script without any parameters safely displays the built-in help guide and exits without making changes.

---

## Usage Examples

### 1. Discover & Inventory Shares (`List`)

```powershell
# List all non-hidden SMB shares:
.\manage-smb-share-access.ps1 -Action List

# Include administrative / hidden shares:
.\manage-smb-share-access.ps1 -Action List -IncludeHidden

# Filter by share name pattern:
.\manage-smb-share-access.ps1 -Action List -ShareName "Raporty*"
```

### 2. Audit & Inspect Permissions (`Show`)

Produces a structured multi-layer report (Share config, SMB permissions, NTFS ACLs, and Consistency Analysis):

```powershell
.\manage-smb-share-access.ps1 -Action Show -ShareName "RaportyFinansowe"
```

### 3. Create / Enable an SMB Share (`Create`)

Creates the directory if missing, registers the share, and enforces security policies:

```powershell
.\manage-smb-share-access.ps1 -Action Create -ShareName "Projekty" -Path "D:\Shares\Projekty" -Description "Dział Projektów" -EnableABE -EncryptData
```

### 4. Grant Access Across SMB and NTFS (`Grant`)

```powershell
# Grant Read access to a domain user:
.\manage-smb-share-access.ps1 -Action Grant -ShareName "RaportyFinansowe" -AccountName "DOMENA\k.nowak" -AccessRight Read

# Grant Change (Modify) access to a local security group:
.\manage-smb-share-access.ps1 -Action Grant -ShareName "Projekty" -AccountName "EdytorzyProjektow" -AccessRight Change

# Grant access on SMB only (skip NTFS):
.\manage-smb-share-access.ps1 -Action Grant -ShareName "Public" -AccountName "BUILTIN\Users" -AccessRight Read -ApplyToNtfs:$false
```

### 5. Revoke Access Across SMB and NTFS (`Revoke`)

Removes SMB share permissions and purges explicit NTFS ACEs while preserving folder inheritance:

```powershell
.\manage-smb-share-access.ps1 -Action Revoke -ShareName "Dane" -AccountName "DOMENA\b.kowalski"
```

### 6. Explicitly Block / Deny Access (`Deny`)

```powershell
.\manage-smb-share-access.ps1 -Action Deny -ShareName "Poufne" -AccountName "DOMENA\j.nowak" -AccessRight FullControl
```

### 7. Disable / Remove an SMB Share (`Remove`)

Safely deletes the SMB network share definition while leaving the backing directory and files on disk intact:

```powershell
.\manage-smb-share-access.ps1 -Action Remove -ShareName "StaryProjekt"
```

### 8. Simulation Mode (`-WhatIf`)

```powershell
.\manage-smb-share-access.ps1 -Action Revoke -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -WhatIf
```

---

## Running Automated Tests

The project includes an extensive test suite powered by **Pester**:

```powershell
Invoke-Pester -Script ".\Tests\manage-smb-share-access.Tests.ps1"
```

---

## Logging & Auditing

Execution logs are structured and automatically stored at:
```plaintext
C:\Logs\manage-smb-share-access_yyyyMMdd.log
```

Log entry format:
```plaintext
[2026-11-04 11:20:00] [INFO] [Init] Executing manage-smb-share-access.ps1 v2.0.0 [Action: Grant]
[2026-11-04 11:20:01] [INFO] [SmbAction] Granting SMB share access (Change) to 'DOMENA\k.nowak'...
[2026-11-04 11:20:01] [INFO] [NtfsAction] Applied NTFS Allow rule: Change (Modify, Synchronize).
[2026-11-04 11:20:02] [INFO] [Consistency] [CONSISTENCY OK] Permissions between SMB and NTFS are balanced.
```

---

## Author & Version Information

* **Author:** Roman Pindela
* **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
* **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **Script Version:** 2.0.0
* **License:** MIT License
