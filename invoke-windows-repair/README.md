# Windows Health Checker & Repair Tool

An automated, enterprise-grade PowerShell script for verifying and repairing Windows system image health and protected core files using DISM and SFC utilities. Built with language-agnostic security architecture and native UAC elevation capabilities.

## Technical Metadata
* **Version:** 1.2.0
* **Author:** Roman Pindela
* **Contact:** roman.pindela@gmail.com
* **GitHub Repository:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **Target Platforms:** Windows 10, Windows 11, Windows Server (2016/2019/2022)
* **Supported Locales:** Fully language-independent (Supports all international editions including English and Polish)

---

## Implemented Stability Controls

The script handles the optimization and health checking of major sub-systems impacting OS lifecycle stability:
1. **Component Store Servicing (DISM):** Sequentially verifies image corruption state (`/CheckHealth`), isolates systemic package errors (`/ScanHealth`), and applies delta patches via secure downstream infrastructure hooks (`/RestoreHealth`).
2. **System File Integrity Validation (SFC):** Parses, scans, and reconstructs damaged cryptographic hashes of core operating system binaries.
3. **WMI Repository Verification:** Integrates infrastructure status metrics to ensure that performance bottlenecks do not stem from instrumented database fragmentation.
4. **Windows Update Pipeline Resiliency:** Addresses update loop anomalies by logging operational throughput without localized dependencies.
5. **Driver Verifier Integration & Fast Startup Warnings:** Designed to bypass persistent state caching issues that introduce kernel-level stability decay over extended runtime windows.

---

## Security & Initialization Policy

### 1. Language-Agnostic SID Architecture
The script completely bypasses highly volatile localized group name parsing strings (e.g., matching `"Administratorzy"` vs `"Administrators"`). Instead, it implements raw security evaluation utilizing the well-known binary Security Identifier structure (**SID: S-1-5-32-544**):
```powershell
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
```

### 2. Automatic UAC Elevation
If executed inside an unprivileged user process context, the utility flags the security disparity, intercepts further pipeline processing, requests explicit User Account Control consent parameters, and transparently spawns a secondary execution token in an elevated scope.

### 3. Execution Protection Bypass
Files downloaded straight from remote public version-control instances (such as GitHub) are implicitly sandboxed by the NT File System via alternate data stream security descriptors (*Zone.Identifier* flag). 

Before launching the toolkit within strict enterprise execution environments, execute the following cmdlet to strip the zone flag from the target asset:
```powershell
Unblock-File -Path "C:\Path\To\Your\Scripts\invoke-windows-repair.ps1"
```

---

## Parameter Mapping & Configuration

The utility exposes explicitly typed and validated parameters, rejecting arbitrary unmapped pipeline input vectors to block exploitation surfaces.

| Parameter | Type | Default Value | Validated Scope | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-Action` | `String` | `"All"` | `All`, `Check`, `Scan`, `Restore`, `Sfc` | Restricts the execution phase to specific modular sub-tasks or cascades all steps. |
| `-LogPath` | `String` | `"C:\Windows\Logs\SystemRepair_Log.txt"` | Any valid NTFS/ReFS path string | Declares the file system destination for recording verbose execution stream data. |
| `-Help` | `Switch` | `False` | N/A | Halts code execution to print the administrative usage console interface. |

---

## Usage Examples

### 1. Full Automated Cascade (Default behavior)
Triggers all DISM stages sequentially followed by a comprehensive SFC scan, automatically generating log parent directories if missing:
```powershell
.\invoke-windows-repair.ps1 -Action All
```

### 2. Isolated Component Integrity Scan
Executes deep component servicing validation layer without triggering state alteration or network requests, diverting logs to a custom path:
```powershell
.\invoke-windows-repair.ps1 -Action Scan -LogPath "D:\DebugLogs\SystemScan.txt"
```

### 3. Display Help Interface
Invokes the safety boundary, preventing script initialization while displaying software specifications, license metadata, and examples:
```powershell
.\invoke-windows-repair.ps1 -Help
```

---

## Version Control History & Changelog

### [1.2.0] - 2026-06
* **Added:** Language-independent SID validation framework mapping token states directly to `S-1-5-32-544`.
* **Added:** Native user elevation bypass routine invoking automatic UAC credential token challenge handlers.
* **Added:** Positional argument protection boundary to safely catch malformed parameter manipulation schemes.
* **Changed:** Refactored entire execution logic from hardcoded constants to dynamic type-validated parameter blocks.