# Unblock PowerShell Files Utility

A professional, secure, and production-ready PowerShell script designed to recursively unblock PowerShell files (`.ps1`, `.psm1`, `.psd1`) that have been downloaded from external sources like GitHub and are restricted by Windows **Mark of the Web (MotW)**.

## Key Features

* **Recursive Processing:** Scans and clears the `Zone.Identifier` alternative data stream from entire directory trees.
* **Color-Coded Status Output:** Clearly distinct messages for `[UNBLOCKED]` (Green), `[SKIPPED]` (Dark Gray), and `[FAILED]` (Red) entries.
* **OS Localization Agnostic:** Uses Well-Known SIDs to seamlessly verify administrative roles on both **English (Administrators)** and **Polish (Administratorzy)** Windows environments.
* **Input Sanitization:** Built-in safeguards against malicious or malformed input paths to protect system integrity.
* **Fail-Safe Mode:** Displays a comprehensive help interface when executed without arguments to prevent unintended executions.

---

## Technical Prerequisites

* **Operating System:** Windows 10 / 11 or Windows Server (2016 / 2019 / 2022)
* **PowerShell Version:** PowerShell 5.1 or PowerShell Core (7.x+)
* **Privileges:** Must be executed within an **Elevated (Administrator)** session.

---

## Usage Guide

### 1. View Help Menu
To display detailed metadata, parameter specifications, and examples:
```powershell
.\unblock-powershell-scripts.ps1 -Help
# or alternatively
.\unblock-powershell-scripts.ps1 -h