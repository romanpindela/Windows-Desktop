# Manage Windows Optional Features (`Manage-WindowsOptionalFeatures`)

**Version:** 1.2.0  
**Release Date:** 2026-10-18  
**Author:** Roman Pindela  
**License:** MIT  

An enterprise-grade, clean-code PowerShell automation script for inspecting, listing details, enabling, and disabling **Windows Optional Features** (DISM / `Win32_OptionalFeature`) across **Windows 10**, **Windows 11**, and **Windows Server** (English and Polish editions).

---

## 📋 Project Information

| Parameter | Value |
| :--- | :--- |
| **Project Name** | Manage Windows Optional Features |
| **Script Name** | `Manage-WindowsOptionalFeatures.ps1` |
| **Author** | Roman Pindela |
| **Email** | [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com) |
| **GitHub** | [https://github.com/romanpindela](https://github.com/romanpindela) |
| **Version** | 1.2.0 |
| **Release Date** | 2026-10-18 |
| **License** | MIT |

---

## 🚀 Overview

Managing Windows Optional Features (such as **Hyper-V**, **Windows Sandbox**, **Windows Subsystem for Linux (WSL)**, **.NET Framework 3.5**, **Telnet Client**, or **SMBv1**) across workstations often requires navigating legacy Control Panel dialogs (`optionalfeatures.exe`) or remembering verbose DISM switches. Furthermore, standard `Get-WindowsOptionalFeature -Online` calls return empty `DisplayName` and `Description` fields unless each feature is queried individually.

`Manage-WindowsOptionalFeatures.ps1` solves these challenges by providing a unified, safe, and standards-compliant CLI tool:
1. **Zero-Parameter Interactive Help (`-Help` / `-h`):** Displays full usage documentation, common Windows 10/11 feature names, examples, version, and author details when launched without arguments—without triggering an unnecessary UAC prompt.
2. **Enable or Disable Windows Features (`Enable` / `Disable`):** Enables or disables single or multiple features (via `-Action Enable|Disable` or switches `-Enable` / `-Disable`), automatically resolving parent dependencies (`-IncludeParentFeatures`) and controlling reboot behavior safely (`-NoRestart` by default, or `-Restart` when requested).
3. **Comprehensive Feature Details Listing (`List` / `Details`):** Combines DISM (`Get-WindowsOptionalFeature`) with CIM (`Win32_OptionalFeature`) so every listed feature immediately displays its full `FeatureName`, localized `DisplayName`, `State`, `RestartRequired`, `Description`, and `CustomProperties`—both during catalog inspection and before/after every state change.

---

## 🌟 Key Features

* **Zero-Parameter Console Help:** Running `.\Manage-WindowsOptionalFeatures.ps1` without parameters prints a clear help guide with syntax, common feature names, examples, version (`1.2.0`), and author details.
* **Enable & Disable Modes:** Supports both `-Action Enable` / `-Action Disable` (positional or named) and convenient `-Enable` / `-Disable` switches for one or multiple features, wildcard patterns, or bulk `.txt` / `.csv` files (`-InputFile`).
* **Full Feature Detail Cards:** Lists complete metadata for each feature (`FeatureName`, `DisplayName`, `State`, `RestartRequired`, `Description`, `CustomProperties`) when listing features and before/after enabling or disabling.
* **Language-Independent UAC Auto-Elevation:** Validates Administrator privileges using the well-known Windows Security Identifier (`S-1-5-32-544` / `WellKnownSidType::BuiltInAdministratorsSid`), ensuring 100% compatibility across both **Polish (`Administratorzy`)** and **English (`Administrators`)** Windows systems. Automatically prompts for UAC elevation and preserves all command-line parameters.
* **Input Sanitization & Defensive Validation:** Protects against command injection, shell metacharacters, and invalid feature/file paths.
* **Dry-Run Simulation (`-DryRun`) & Bilingual Prompts:** Preview changes safely before modifying the OS, with interactive confirmation supporting both English (`Y/N`) and Polish (`T/N`) responses (or unattended `-Force`).
* **Detailed Audit Logging & Export:** Automatically writes UTF-8 execution logs to `C:\Logs\<yyyyMMdd_HHmmss>-Manage-WindowsOptionalFeatures-<ComputerName>-<UserName>.logs` and supports exporting feature catalogs or results to `.csv` or `.json` via `-ExportPath`.

---

## 📂 Directory Structure

```shell
Manage-WindowsOptionalFeatures/
├── Manage-WindowsOptionalFeatures.ps1   # Main PowerShell script
└── README.md                            # Technical documentation and usage guide
```

---

## 💻 System Requirements

* **Operating System:** Windows 10, Windows 11, Windows Server 2016 / 2019 / 2022 / 2025 (x64 and ARM64, English & Polish editions).
* **PowerShell Version:** Windows PowerShell 5.1 or PowerShell 7+.
* **Privileges:** Administrator privileges required for querying and modifying DISM Windows Optional Features (the script automatically requests UAC elevation if started in a non-elevated console). Viewing help (`-h` or zero parameters) runs without elevation.

---

## 📥 Getting Started

### 1. Unblock the Script (Required After Downloading from GitHub)

When downloading PowerShell scripts from GitHub or the Internet, Windows attaches an `Alternate Data Stream (Zone.Identifier)` that may block execution. Unblock the file before running it:

```powershell
Unblock-File -Path .\Manage-WindowsOptionalFeatures.ps1
```

If script execution is disabled by your local policy, allow signed/local scripts for the current user:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 📖 Parameter Reference

| Parameter | Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-Action` | `-Mode`, `-Operation` | `[string]` | `$null` | Operation to execute: `Enable`, `Disable`, `List`, or `Details`. |
| `-FeatureName` | `-Name`, `-Feature`, `-f` | `[string[]]` | `$null` | One or more feature names or wildcard patterns (e.g., `TelnetClient`, `*Hyper-V*`). |
| `-Enable` | | `[switch]` | `$false` | Shortcut switch for `-Action Enable`. |
| `-Disable` | | `[switch]` | `$false` | Shortcut switch for `-Action Disable`. |
| `-List` | `-ShowAll`, `-Get` | `[switch]` | `$false` | Shortcut switch for `-Action List` (lists all or filtered features with details). |
| `-State` | `-FilterState`, `-Status` | `[string]` | `All` | Filters listed features by state: `All`, `Enabled`, `Disabled`, `DisabledWithPayloadRemoved`, `EnablePending`, `DisablePending`. |
| `-Detailed` | | `[switch]` | `$false` | Prints full multi-line detail cards (including complete `Description` and `CustomProperties`) for every feature. |
| `-IncludeParentFeatures` | | `[bool]` | `$true` | Automatically enables required parent features when enabling (`Enable-WindowsOptionalFeature -All`). |
| `-RemovePayload` | | `[switch]` | `$false` | Removes feature binary payload from WinSxS when disabling (`-Remove`). |
| `-Source` | | `[string[]]` | `$null` | Offline source path(s) (e.g., `D:\sources\sxs` for `NetFx3`). |
| `-LimitAccess` | | `[switch]` | `$false` | Prevents DISM from contacting Windows Update when `-Source` is specified. |
| `-InputFile` | `-FilePath`, `-Path` | `[string]` | `$null` | Path to a `.txt` or `.csv` file containing feature names to process. |
| `-Restart` | | `[switch]` | `$false` | Automatically restarts the computer if a feature change requires a reboot (default is `-NoRestart`). |
| `-ExportPath` | `-ExportCsv`, `-OutFile` | `[string]` | `$null` | Exports feature details or operation results to a `.csv` or `.json` file. |
| `-DryRun` | `-Simulate`, `-Preview` | `[switch]` | `$false` | Simulates enabling/disabling and displays current feature details without modifying the OS. |
| `-Force` | | `[switch]` | `$false` | Suppresses interactive confirmation prompts (`Y/N` / `T/N`). |
| `-SkipAdminCheck` | | `[switch]` | `$false` | Skips the automatic UAC elevation check. |
| `-PassThru` | | `[switch]` | `$false` | Outputs structured feature detail/result objects to the PowerShell pipeline. |
| `-LogPath` | `-Log`, `-l` | `[string]` | `C:\Logs\...` | Custom path for the UTF-8 execution log file. |
| `-NoLog` | | `[switch]` | `$false` | Disables writing execution logs to disk. |
| `-Help` | `-h` | `[switch]` | `$false` | Displays interactive help, examples, version, and author information. |

---

## 🗂️ Common Windows 10 / 11 Optional Feature Names

| Feature Name (`-FeatureName`) | Display Name / Purpose |
| :--- | :--- |
| `TelnetClient` | Telnet Client CLI tool |
| `NetFx3` | .NET Framework 3.5 (includes .NET 2.0 and 3.0) |
| `Microsoft-Windows-Subsystem-Linux` | Windows Subsystem for Linux (WSL) |
| `VirtualMachinePlatform` | Virtual Machine Platform (required for WSL 2) |
| `Containers-DisposableClientVM` | Windows Sandbox isolated desktop environment |
| `Microsoft-Hyper-V-All` | Hyper-V (All Hypervisor & Management Tools) |
| `SMB1Protocol` | SMB 1.0/CIFS File Sharing Support (recommended to disable) |
| `WorkFolders-Client` | Work Folders Client |
| `Printing-XPSServices-Features` | Microsoft XPS Document Writer |
| `Client-ProjFS` | Windows Projected File System |

---

## 💡 Practical Usage Examples

### Example 1: Display Help, Version, and Author Information (Zero-Parameter Run)
Running the script without parameters or with `-Help` / `-h` prints full instructions and examples without requiring UAC elevation:
```powershell
.\Manage-WindowsOptionalFeatures.ps1
```
or
```powershell
.\Manage-WindowsOptionalFeatures.ps1 -Help
```

---

### Example 2: List All Windows Optional Features with Details
Lists all features available in Windows 10/11 along with their `FeatureName`, `State`, localized `DisplayName`, `RestartRequired` status, and `Description`:
```powershell
.\Manage-WindowsOptionalFeatures.ps1 -List
```

---

### Example 3: List Only Enabled Features with Full Multi-Line Detail Cards
Filters for currently enabled features and prints complete property sheets for every option:
```powershell
.\Manage-WindowsOptionalFeatures.ps1 -List -State Enabled -Detailed
```

---

### Example 4: Inspect Full Details of Specific Features (Wildcard Search)
Displays detailed property cards for any feature matching Hyper-V, WSL, or Sandbox:
```powershell
.\Manage-WindowsOptionalFeatures.ps1 -Action Details -FeatureName "*Hyper-V*", "*Linux*", "*Sandbox*"
```
*(Tip: Providing `-FeatureName` without `-Action` automatically defaults to `Details` mode.)*

---

### Example 5: Enable a Windows Optional Feature (`TelnetClient`)
Enables the Telnet Client feature, displaying full feature details before and after the change:
```powershell
.\Manage-WindowsOptionalFeatures.ps1 -Action Enable -FeatureName "TelnetClient"
```
Or using the `-Enable` switch:
```powershell
.\Manage-WindowsOptionalFeatures.ps1 -Enable -FeatureName "TelnetClient" -Force
```

---

### Example 6: Enable Multiple Features at Once (WSL 2 + Windows Sandbox)
Enables Windows Subsystem for Linux, Virtual Machine Platform, and Windows Sandbox in one unattended run:
```powershell
.\Manage-WindowsOptionalFeatures.ps1 -Action Enable -FeatureName "Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform", "Containers-DisposableClientVM" -Force
```

---

### Example 7: Disable Legacy or Unused Features (`SMB1Protocol`, `WorkFolders-Client`)
Disables SMBv1 and Work Folders Client (with optional `-DryRun` preview first):
```powershell
# Preview first with -DryRun:
.\Manage-WindowsOptionalFeatures.ps1 -Action Disable -FeatureName "SMB1Protocol", "WorkFolders-Client" -DryRun

# Execute disable operation:
.\Manage-WindowsOptionalFeatures.ps1 -Action Disable -FeatureName "SMB1Protocol", "WorkFolders-Client" -Force
```

---

### Example 8: Export Full Details of All Windows Optional Features to CSV or JSON
Generates a complete audit report of all Windows 10/11 optional features:
```powershell
.\Manage-WindowsOptionalFeatures.ps1 -List -ExportPath "C:\Logs\WindowsOptionalFeatures_Audit.csv"
```

---

## 🔄 Execution Workflow

```mermaid
flowchart TD
    A["Start: Manage-WindowsOptionalFeatures.ps1"] --> B{"Parameters Provided?"}
    B -- "No / -Help / -h" --> C["Display Help, Examples, Version & Author (Exit)"]
    B -- "Yes" --> D["Validate & Sanitize Inputs (FeatureName, Paths)"]
    D --> E{"Is Elevated Admin? (SID S-1-5-32-544)"}
    E -- "No" --> F["Prompt UAC & Relaunch Elevated with Parameters"]
    E -- "Yes" --> G["Initialize Logging (C:\Logs\...)"]
    G --> H["Query DISM (Get-WindowsOptionalFeature) & CIM (Win32_OptionalFeature)"]
    H --> I{"Selected Action?"}
    I -- "List / Details" --> J["Filter by FeatureName / State & Build Detail Cards"]
    J --> K["Display Detailed Catalog & Summary (+ Optional Export)"]
    I -- "Enable / Disable" --> L["Display BEFORE Feature Details Card(s)"]
    L --> M{"-DryRun Active?"}
    M -- "Yes" --> N["Print Simulation Summary & Exit"]
    M -- "No" --> O{"User Confirmation (Y/T or -Force)?"}
    O -- "Confirmed" --> P["Execute Enable/Disable-WindowsOptionalFeature (-Online -NoRestart)"]
    P --> Q["Re-Query DISM & Display AFTER Feature Details Card(s)"]
    Q --> R["Print Execution Summary (+ Optional CSV/JSON Export & Reboot Check)"]
```

---

## 🔒 Security & Quality Standards

1. **Automatic UAC Elevation (Multi-Language Safe):** Verifies Administrator privileges via well-known SID `S-1-5-32-544` (`[Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid`), working identically on Polish (`Administratorzy`) and English (`Administrators`) editions of Windows 10/11.
2. **Strict Input Validation:** Defends against command injection by validating feature names (`^[a-zA-Z0-9._\-\*\?]+$`) and rejecting file paths containing shell metacharacters.
3. **Idempotent Execution:** Checks the current feature state before executing DISM changes—features that are already `Enabled` or `Disabled` are safely skipped without unnecessary DISM overhead.
4. **Enterprise Audit Logging:** Writes detailed, UTF-8 timestamped logs to `C:\Logs\<yyyyMMdd_HHmmss>-Manage-WindowsOptionalFeatures-<ComputerName>-<UserName>.logs`.

---

## 📜 Version History

* **v1.2.0 (2026-10-18):**
  * Implemented automatic UAC elevation prompt that relaunches the script with Administrator privileges if they are missing, preserving all CLI parameters.
  * Replaced manual administrator group name checks with secure, language-independent SID verification (`S-1-5-32-544`).
  * Added hybrid DISM + CIM (`Win32_OptionalFeature`) metadata resolution so every listed option includes localized `DisplayName`, `Description`, `State`, `RestartRequired`, and `CustomProperties`.
  * Added `-Action Enable|Disable|List|Details`, shortcut switches (`-Enable`, `-Disable`, `-List`), `-DryRun`, `-ExportPath`, and default logging to `C:\Logs`.

---

## 👤 Author & Support

* **Author:** Roman Pindela
* **Email:** [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
* **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **License:** MIT
