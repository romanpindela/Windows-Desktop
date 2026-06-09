# Unblock PowerShell Scripts Utility

A professional, secure, and production-ready PowerShell utility designed to recursively unblock PowerShell files (`.ps1`, `.psm1`, `.psd1`) that have been downloaded from external sources like GitHub and are restricted by Windows **Mark of the Web (MotW)**.

[![PowerShell Compatibility](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.0%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%28Desktop%20%2F%20Server%29-lightgrey.svg)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Key Features

* **Recursive Directory Processing:** Automatically scans and clears the hidden `Zone.Identifier` alternative data stream from entire directory subtrees.
* **OS Localization Agnostic:** Uses Well-Known Security Identifiers (SID: `S-1-5-32-544`) to seamlessly verify administrative privileges across both **English (`Administrators`)** and **Polish (`Administratorzy`)** Windows operating systems.
* **Color-Coded Status Output:** High-visibility console reporting using distinct color mappings:
  * `[UNBLOCKED]` (**Green**) for modified files.
  * `[SKIPPED]` (**Dark Gray**) for files already clean and safe.
  * `[FAILED]` (**Red**) for access or system execution issues.
* **Defensive Input Sanitization:** Robust protection against malformed path injections and path traversal attempts.
* **Fail-Safe Execution:** Displays a comprehensive help interface when executed without arguments to prevent accidental mass modifications.

---

## Technical Prerequisites

* **Operating System:** Windows 10 / 11 or Windows Server (2016 / 2019 / 2022 / 2026)
* **PowerShell Version:** Windows PowerShell 5.1 or PowerShell Core (7.x+)
* **Privileges:** Elevated session (**Run as Administrator**).

---

## Usage Guide & Practical Examples

### 1. View Built-in Help Menu
To display localized parameter definitions, metadata, and script usage options:
```powershell
.\unblock-powershell-scripts.ps1 -Help
# or using the short alias
.\unblock-powershell-scripts.ps1 -h