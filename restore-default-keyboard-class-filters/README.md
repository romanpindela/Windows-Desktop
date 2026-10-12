# restore-default-keyboard-class-filters (Windows Keyboard Driver Recovery)

Enterprise PowerShell automation script to diagnose, audit, back up, and restore default Windows Keyboard Class filter drivers (`UpperFilters` and `LowerFilters`) in the Windows registry. Resolves keyboard unresponsiveness and Device Manager **Code 19**, **Code 10**, and **Code 39** errors caused by orphaned, corrupt, or conflicting third-party driver filters.

---

## Project Information

| Parameter | Value |
| :--- | :--- |
| **Project Name** | restore-default-keyboard-class-filters |
| **Author** | Roman Pindela |
| **Contact** | roman.pindela@gmail.com |
| **GitHub** | [https://github.com/romanpindela](https://github.com/romanpindela) |
| **Version** | 1.2.0 |
| **Release Date** | 2026-10-12 |
| **License** | MIT |
| **Repository** | [Windows-Desktop](https://github.com/romanpindela/Windows-Desktop) |

---

## Problem & Root Cause Analysis

### Background: Windows Keyboard Driver Stack
In the Windows NT architecture, hardware device drivers are structured in layered driver stacks managed under device class GUIDs in the system registry:
- **Keyboard Device Class GUID**: `{4d36e96b-e325-11ce-bfc1-08002be10318}`
- **Registry Key Path**:  
  `HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}`

Under standard, out-of-the-box Windows configurations:
* **`UpperFilters`** is a Multi-String (`REG_MULTI_SZ`) value that must contain **only** `kbdclass` (the native Microsoft Keyboard Class Driver).
* **`LowerFilters`** should **not exist** for the Keyboard class.

```
       [ Application / Windows Subsystem ]
                       │
       ┌───────────────▼───────────────┐
       │   Third-Party Upper Filters   │  ◄── Injected by 3rd-party software (e.g. klkbdflt, rzklfilter)
       └───────────────┬───────────────┘
                       │
       ┌───────────────▼───────────────┐
       │       kbdclass.sys            │  ◄── Native Microsoft Keyboard Class Driver
       └───────────────┬───────────────┘
                       │
       ┌───────────────▼───────────────┐
       │   Third-Party Lower Filters   │  ◄── Injected lower filter drivers (invalid by default)
       └───────────────┬───────────────┘
                       │
       ┌───────────────▼───────────────┐
       │ Function Driver (i8042 / kbdhid) │
       └───────────────┬───────────────┘
                       │
             [ Physical Keyboard ]
```

### What Causes the Problem?
Many third-party software products install custom kernel-mode filter drivers into the keyboard driver stack to intercept, monitor, or modify keystrokes:
1. **Antivirus & Endpoint Security Suites**: Kaspersky (`klkbdflt`), Bitdefender, Sophos, Avast, or anti-keylogger utilities.
2. **Remote Desktop & Virtualization Software**: VMware Tools (`vmkbd`), VirtualBox, Citrix Workspace, TeamViewer, AnyDesk, HP Remote Graphics.
3. **Gaming & Macro Peripherals**: Razer Synapse (`rzklfilter`), Corsair iCUE (`corsairservice`), Logitech G HUB, SteelSeries GG.
4. **Third-party Touchpad / KVM / Accessibility Suites**: Incomplete OEM drivers or legacy filter drivers.

### The Breakdown (How the Failure Occurs)
When these programs are uninstalled, updated, or encounter driver signature enforcement issues:
1. The uninstaller frequently deletes the driver binary (`.sys`) from `C:\Windows\System32\drivers` or removes the underlying service from `HKLM\SYSTEM\CurrentControlSet\Services`.
2. However, the uninstaller **fails to remove its entry** from the `UpperFilters` or `LowerFilters` registry values in the Keyboard Class GUID.
3. During Windows startup, the Plug and Play (PnP) manager parses the `UpperFilters` and `LowerFilters` lists and attempts to load every referenced driver into the kernel stack in sequence.
4. If **any single driver** in the list is missing, corrupted, or fails to start, **the entire keyboard driver stack fails to initialize**.
5. As a result:
   - Physical keyboards (internal laptop keyboards, USB HID keyboards, Bluetooth keyboards, PS/2 keyboards) **completely stop responding** once Windows loads (even if they worked in BIOS/UEFI).
   - In Device Manager (`devmgmt.msc`), the keyboard device shows a yellow warning triangle with one of the following error codes:
     - **Code 19 (`CM_PROB_REGISTRY_ERROR`)**: *"Windows cannot start this hardware device because its configuration information (in the registry) is incomplete or damaged."*
     - **Code 10 (`CM_PROB_FAILED_START`)**: *"This device cannot start."*
     - **Code 39 (`CM_PROB_DRIVER_FAILED_LOAD`)**: *"Windows cannot load the device driver for this hardware. The driver may be corrupted or missing."*

---

## How the Script Works

`restore-default-keyboard-class-filters.ps1` automates the diagnosis, backup, remediation, and verification of the keyboard driver filter stack:

1. **Security & Elevation Validation**:
   - Uses language-independent Well-Known SIDs (`[Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid`) to verify elevated permissions across English, Polish, and localized Windows editions.
   - Automatically prompts for UAC elevation and relaunches the script with elevated rights if running non-elevated for actions requiring modification.
   - Sanitizes all path inputs against injection or illegal characters.
2. **Diagnostic State Inspection (`-Audit`)**:
   - Reads `UpperFilters` and `LowerFilters` directly using high-performance .NET registry APIs.
   - Evaluates whether the current configuration matches the clean Windows standard (`kbdclass` only, no `LowerFilters`).
3. **Automated Pre-Repair Registry Backup**:
   - Before applying any change, exports the exact registry key using `reg.exe export` to a timestamped file:  
     `C:\RegBackup_Keyboard\KeyboardClass_YYYYMMDD_HHMMSS.reg`.
   - Validates that the backup file exists and has non-zero size before modifying registry values.
4. **Clean State Restoration (`-Repair`)**:
   - Sets `UpperFilters` to a `MultiString` (`REG_MULTI_SZ`) containing strictly `kbdclass`.
   - Safely removes any unauthorized `LowerFilters` property if present.
5. **Post-Repair Verification**:
   - Re-queries the registry to verify that `UpperFilters` contains only `kbdclass` and `LowerFilters` is deleted.
6. **Activity Logging & Reboot Advisory**:
   - Writes detailed execution logs with microsecond timestamps to `C:\Logs\<Timestamp>-<Host>-<User>-restore-default-keyboard-class-filters.txt`.
   - Informs the administrator that a system reboot is required to reload the clean kernel driver stack.

---

## Key Features

- **Safe-by-Default CLI**: Running without parameters displays the built-in help guide, preventing accidental execution.
- **Cross-Language Windows Support**: Compatible with Polish and English Windows 10, 11, and Windows Server (desktop and server SKUs).
- **Automated UAC Elevation**: Language-independent SID verification automatically requests elevation when repair operations are requested.
- **Non-Destructive Audit Mode (`-Audit`)**: Safely inspects and reports driver health without modifying registry values.
- **Automated Safety Backups**: Automatically creates `.reg` backups prior to applying changes.
- **PowerShell Pipeline & Parameterization**: Configurable backup paths (`-BackupPath`), log paths (`-LogPath`), and unattended execution (`-Force`).
- **Clean Code & Strict Standards**: Adheres to PowerShell Clean Code practices, `Set-StrictMode`, `SupportsShouldProcess` (`-WhatIf`), and native `.NET` error handling.

---

## Directory Structure

```shell
restore-default-keyboard-class-filters/
├── restore-default-keyboard-class-filters.ps1   # Main PowerShell repair & audit script
└── README.md                                   # Comprehensive technical documentation
```

---

## System Requirements

- **Operating System**: Windows 10 / Windows 11 / Windows Server 2016 / 2019 / 2022 / 2025 (x64 / x86 / ARM64).
- **PowerShell Version**: Windows PowerShell 5.1 or PowerShell 7.x+.
- **Privileges**: Administrator rights (script includes auto-elevation via UAC).

---

## Important: Unblock File After Download

When downloading scripts from GitHub or external sources, Windows marks them with an alternative data stream (`Zone.Identifier`). You must unblock the script prior to execution:

```powershell
Unblock-File -Path .\restore-default-keyboard-class-filters.ps1
```

If script execution is disabled on the system, set the execution policy for the process:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
```

---

## Usage Guide & Examples

### 1. Display Built-In Help Menu
Running without parameters or with `-h` / `-Help` displays parameter descriptions and usage examples:

```powershell
.\restore-default-keyboard-class-filters.ps1
# Or explicitly:
.\restore-default-keyboard-class-filters.ps1 -h
.\restore-default-keyboard-class-filters.ps1 -Help
```

---

### 2. Audit Current Keyboard Filter State (Read-Only)
Inspects the current registry filters and displays the diagnostic health summary without making changes:

```powershell
.\restore-default-keyboard-class-filters.ps1 -Audit
```

*Example Output:*
```text
================================================================================
  restore-default-keyboard-class-filters v1.2.0
  Author  : Roman Pindela | Contact: roman.pindela@gmail.com
  GitHub  : https://github.com/romanpindela
  Session : Standard User (Non-Elevated)
  Log     : C:\Logs\20261012_222326-ROMAN-PC-E590-Roman-restore-default-keyboard-class-filters.txt
================================================================================

[Step 1] Auditing Keyboard Class filters in Windows Registry...
  Registry Class Key : HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}
  Device Class Name  : Keyboard
  UpperFilters       : SynTP, kbdclass
  LowerFilters       : <None>
  Overall Health     : [ATTENTION REQUIRED] Non-default or corrupted filter stack detected!

[Audit Complete] Diagnostic summary finished. No changes were made.
RECOMMENDATION: Run with -Repair parameter to restore default filters.

Execution finished at 2026-10-12 22:23:27.
Log file location: C:\Logs\20261012_222326-ROMAN-PC-E590-Roman-restore-default-keyboard-class-filters.txt
================================================================================
```

---

### 3. Repair Filters with Interactive Confirmation
Prompts the user before taking action, exports a `.reg` backup, resets `UpperFilters` to `kbdclass`, and removes rogue `LowerFilters`:

```powershell
.\restore-default-keyboard-class-filters.ps1 -Repair
```

---

### 4. Unattended / Silent Repair (`-Force`)
Suppresses interactive confirmation prompts for automated deployment, SCCM, Intune, or remote management:

```powershell
.\restore-default-keyboard-class-filters.ps1 -Repair -Force
```

---

### 5. Custom Backup Directory and Log Path
Specify custom paths for the registry export and the execution log file:

```powershell
.\restore-default-keyboard-class-filters.ps1 -Repair -BackupPath "D:\Backups\Registry" -LogPath "C:\Logs\KeyboardRepair.txt" -Force
```

---

### 6. Create Standalone Registry Backup Only (`-BackupOnly`)
Exports the keyboard class key to a `.reg` file without altering any registry values:

```powershell
.\restore-default-keyboard-class-filters.ps1 -BackupOnly -BackupPath "C:\RegBackup_Keyboard"
```

---

### 7. Dry-Run Simulation (`-WhatIf`)
Simulates the modification without writing to the registry:

```powershell
.\restore-default-keyboard-class-filters.ps1 -Repair -WhatIf
```

---

## Technical Reference & Manual Recovery

### Registry Key Details
| Property | Value |
| :--- | :--- |
| **Registry Path** | `HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}` |
| **Class** | `Keyboard` |
| **Default UpperFilters** | `kbdclass` (`REG_MULTI_SZ`) |
| **Default LowerFilters** | *(Must not exist)* |

### Manual Rollback Procedure
If you ever need to restore previous settings from a backup created by the script:
1. Open PowerShell or Command Prompt as Administrator.
2. Locate the backup file in `C:\RegBackup_Keyboard\` (e.g. `KeyboardClass_20261012_223000.reg`).
3. Import the backup file using `reg.exe`:
   ```powershell
   reg.exe import "C:\RegBackup_Keyboard\KeyboardClass_20261012_223000.reg"
   ```
4. Restart the computer.

---

## Exit Codes & Diagnostic Indicators

| Code / Status | Meaning | Action / Result |
| :--- | :--- | :--- |
| **Exit 0** | Success / Completed | Requested action completed successfully (help displayed, audit finished, or repair applied). |
| **Exit 1** | Security / Elevation / Registry Error | Script encountered an unhandled exception or failed to elevate. Detailed exception written to console and log. |
| **Elevation Prompt** | Missing Administrator Privileges | Automatically requests elevation via UAC when `-Repair` or `-BackupOnly` is invoked. |

---

## Version History

### Version 1.2.0 (2026-10-12)
* **Automatic UAC Elevation**: Added language-independent Well-Known SID verification (`BuiltInAdministratorsSid`) with automatic elevated process relaunch for modification tasks.
* **Non-Destructive Audit Mode**: Implemented `-Audit` switch for read-only diagnostics without requiring elevation.
* **Pre-Repair Registry Backup**: Added automated timestamped `.reg` export prior to any registry modifications.
* **Clean Code & Resilience**: Refactored to native .NET Registry APIs, `SupportsShouldProcess` (`-WhatIf`), and input sanitization.
* **Documentation**: Overhauled `README.md` with deep technical problem analysis, driver stack diagrams, and usage examples.
* **Unblock-File Guidance**: Added instructions for unblocking downloaded scripts.

---

## Contact & Support

For issues, questions, or contributions:
- **Author**: Roman Pindela
- **Email**: [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)
- **GitHub**: [https://github.com/romanpindela](https://github.com/romanpindela)
- **Repository**: [https://github.com/romanpindela/Windows-Desktop](https://github.com/romanpindela/Windows-Desktop)