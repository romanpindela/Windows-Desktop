# Windows-Desktop Automation & Management

A collection of professional PowerShell scripts designed to automate routine administrative tasks, audit security posture, optimize system performance, manage software deployment, and streamline remote administration across **Windows 10**, **Windows 11**, and **Windows Server** environments.

---

## 📋 Table of Contents (All Scripts)

Sorted alphabetically by standardized script name (`Verb-Noun`).

| Script Name | Description | Problem Solved | Category Tag | Permissions |
| :--- | :--- | :--- | :--- | :--- |
| [Add-NetworkPrinter](Add-NetworkPrinter/README.md) | Automates TCP/IP network printer port creation, driver installation, and queue setup across LAN workstations. | Eliminates manual TCP/IP printer port, INF/ZIP driver deployment, and queue setup steps. | Printing | Admin |
| [Audit-BitLockerAndTpmStatus](Audit-BitLockerAndTpmStatus/README.md) | Audits TPM 2.0 readiness, UEFI Secure Boot, BitLocker encryption status, and AD/Entra ID key escrow. | Identifies unencrypted endpoints and missing BitLocker recovery key escrows for NIS2 compliance. | Security & Audit | Admin |
| [Audit-EndpointPersistence](Audit-EndpointPersistence/README.md) | Audits Windows Auto-Start Execution Points (ASEP), unquoted service paths (CWE-428), and Authenticode signatures. | Detects unauthorized persistence mechanisms, startup hijacks, and unsigned autorun binaries. | Security & Audit | Admin |
| [Audit-LocalAdministrators](Audit-LocalAdministrators/README.md) | Audits members of the local Administrators group (`S-1-5-32-544`), orphaned SIDs, and LAPS/account hygiene. | Uncovers privilege sprawl, dormant admin accounts, and unresolvable SIDs across AD and Entra ID. | Security & Audit | Admin |
| [Audit-LocalFirewallAndListeningPorts](Audit-LocalFirewallAndListeningPorts/README.md) | Audits Windows Defender Firewall profiles, unrestricted high-risk inbound rules, listening sockets, and owning processes. | Exposes dangerous wildcard inbound firewall rules and untrusted or unsigned network listeners. | Security & Audit | Admin |
| [Audit-WindowsUpdateAndPatchStatus](Audit-WindowsUpdateAndPatchStatus/README.md) | Audits Windows Update health, installed patch age SLAs, pending reboot flags, WSUS policies, and missing updates. | Surfaces unpatched systems, stalled reboot loops, disabled update services, and broken update policies. | Security & Audit | Admin |
| [Block-Win11Upgrade](Block-Win11Upgrade/README.md) | Configures Windows Update target-release policies to pin Windows 10 `22H2` or remove the upgrade block. | Prevents unwanted automatic upgrades from Windows 10 to Windows 11 in managed environments. | System Maintenance | Admin |
| [Copy-FromSession](Copy-FromSession/README.md) | Establishes a WinRM `PSSession`, validates remote paths, and copies files or folders to the local machine. | Transfers files and directories from remote hosts cleanly over WinRM without requiring SMB shares. | Remote Management | User |
| [Copy-ToSession](Copy-ToSession/README.md) | Establishes a WinRM `PSSession`, creates missing remote folders, and copies local files or directories remotely. | Pushes installers and configuration directories to remote hosts over WinRM with clean session teardown. | Remote Management | User |
| [Enable-Hibernation](Enable-Hibernation/README.md) | Enables or disables Windows hibernation (`powercfg /hibernate`) and toggles Start Menu visibility. | Resolves missing Start Menu Hibernate options or reclaims `hiberfil.sys` disk space consistently. | System Maintenance | Admin |
| [Enable-HyperVRemoteManagement](Enable-HyperVRemoteManagement/README.md) | Configures workgroup `hosts` mappings, WinRM `TrustedHosts`, CredSSP delegation, GPO rules, and Hyper-V tools. | Fixes workgroup Hyper-V Manager (`virtmgmt.msc`) authentication and raw-IP connection failures. | Remote Management | Admin |
| [Enable-RemoteManagement](Enable-RemoteManagement/README.md) | Enables PowerShell Remoting (`WinRM`), configures optional `TrustedHosts`, and grants `Remote Management Users` access. | Automates PSRemoting setup and language-independent (`S-1-5-32-580`) user authorization checks. | Remote Management | Admin |
| [Enable-StorageSense](Enable-StorageSense/README.md) | Configures Storage Sense retention policies, clears update/delivery caches, removes bloatware Appx apps, and runs `SilentCleanup`. | Automates low-disk remediation across Windows 10/11 endpoints using native cleanup mechanisms. | System Maintenance | Admin |
| [Get-DiskHealth](Get-DiskHealth/README.md) | Maps physical disks to partitions/volumes and inspects SMART health via `smartctl` or native storage counters. | Surfaces SSD/HDD wear, temperature, error rates, and drive topology with optional HTML export. | Files & Storage | Admin |
| [Get-RemoteHealthReport](Get-RemoteHealthReport/README.md) | Runs a multi-category local or remote CIM/WMI audit covering hardware, disks, top processes, network, security, and events. | Eliminates manual cross-checking of WMI classes and event logs during endpoint troubleshooting. | System Maintenance | Admin |
| [Get-WifiProfiles](Get-WifiProfiles/README.md) | Lists saved Wi-Fi SSIDs, security modes, cleartext passphrases, and active link metrics across EN/PL Windows. | Recovers stored wireless credentials and active adapter signal/IP telemetry without GUI navigation. | Networking | User |
| [Install-Applications](Install-Applications/README.md) | Installs, upgrades, searches, and audits Windows x64 applications via `winget`, JSON manifests, and registry checks. | Standardizes bulk workstation provisioning with user-scope fallback and `winget` self-repair. | Software Management | Admin |
| [Install-PlatnikZus](Install-PlatnikZus/README.md) | Installs `.NET Framework 4.8+` via `winget` and downloads official ZUS Płatnik installer and patch packages. | Streamlines workstation prerequisite setup and package staging for ZUS Płatnik deployments. | Software Management | Admin |
| [Install-WireGuardClient](Install-WireGuardClient/README.md) | Deploys or updates the WireGuard VPN client via `winget`, imports `.conf` profiles to DPAPI storage, and manages tunnels. | Automates WireGuard rollouts with key-redacted config validation and optional tunnel service startup. | Software Management | Admin |
| [Invoke-GitHubScript](Invoke-GitHubScript/README.md) | Downloads `.ps1` scripts from GitHub `/blob/` or raw URLs, unblocks them, and executes them with arguments. | Eliminates manual cloning, TLS 1.2 setup, and `Unblock-File` steps when running scripts on fresh hosts. | Software Management | Admin |
| [Invoke-LocalScreenshot](Invoke-LocalScreenshot/README.md) | Captures the primary display screen using .NET Graphics and saves a timestamped PNG screenshot locally. | Enables automated desktop screen captures during interactive user troubleshooting or Task Scheduler jobs. | Desktop Utilities | User |
| [Invoke-RemoteCommand](Invoke-RemoteCommand/README.md) | Connects to a remote host over WinRM and executes a provided or interactively prompted PowerShell command. | Simplifies running quick ad-hoc diagnostic or administrative commands against remote endpoints. | Remote Management | User |
| [Invoke-RemoteScript](Invoke-RemoteScript/README.md) | Executes a local `.ps1` script directly in remote memory over a WinRM `PSSession` with optional arguments. | Runs multi-step local PowerShell scripts on remote servers without leaving script files on disk. | Remote Management | User |
| [Invoke-WindowsRepair](Invoke-WindowsRepair/README.md) | Automates `DISM` health checks/restores (`CheckHealth`, `ScanHealth`, `RestoreHealth`) and `sfc /scannow` with logging. | Repairs corrupted Windows Component Store images and system binaries in one logged workflow. | System Maintenance | Admin |
| [Manage-PrinterDiscovery](Manage-PrinterDiscovery/README.md) | Enables, disables, or audits Windows automatic network printer discovery (`NcdAutoSetup`). | Stops unsolicited background mapping of broadcasted LAN printers while keeping manual setup intact. | Printing | Admin |
| [Manage-SmbShareAccess](Manage-SmbShareAccess/README.md) | Administers Windows SMB shares and underlying NTFS ACLs (`List`, `Show`, `Create`, `Remove`, `Grant`, `Revoke`, `Deny`). | Keeps SMB Share and NTFS permissions synchronized with consistency auditing and `-WhatIf` support. | Files & Storage | Admin |
| [Manage-WindowsOptionalFeatures](Manage-WindowsOptionalFeatures/README.md) | Lists, inspects, enables, and disables Windows Optional Features via DISM and CIM with bulk and dry-run support. | Simplifies inspecting dependencies and toggling Windows features cleanly across EN/PL systems. | System Maintenance | Admin |
| [New-JunctionPoint](New-JunctionPoint/README.md) | Validates paths and creates an NTFS Directory Junction (`New-Item -ItemType Junction`) safely without overwriting targets. | Relocates folder paths cleanly across drives with built-in path validation instead of manual `mklink /J`. | Files & Storage | User |
| [Open-Session](Open-Session/README.md) | Prompts for credentials and opens an interactive WinRM session (`Enter-PSSession`) to a remote Windows host. | Reduces boilerplate when launching interactive remote PowerShell consoles across LAN machines. | Remote Management | User |
| [Optimize-WindowsDefender](Optimize-WindowsDefender/README.md) | Tunes Microsoft Defender scan CPU caps, schedules, Dev Drive mode, and dev exclusions with ETW profiling and backups. | Resolves `MsMpEng.exe` CPU/I/O bottlenecks on developer workstations without disabling protection. | Security & Audit | Admin |
| [Restart-PrintSpooler](Restart-PrintSpooler/README.md) | Stops the Print Spooler service, purges stuck spool files, restarts `Spooler`, and resumes paused printers. | Clears wedged print queues and paused printer states automatically on user workstations or servers. | Printing | Admin |
| [Restore-DefaultKeyboardClassFilters](Restore-DefaultKeyboardClassFilters/README.md) | Audits, backs up (`.reg`), and resets Keyboard Class `UpperFilters`/`LowerFilters` to default `kbdclass`. | Fixes non-working keyboards caused by corrupt filter drivers (Device Manager Codes 10, 19, 39). | System Maintenance | Admin |
| [Restore-KeyboardSettings](Restore-KeyboardSettings/README.md) | Resets per-user keyboard layout to Polish (Programmers), disables Sticky/Filter/Toggle Keys, and refreshes Explorer. | Restores consistent typing layout, repeat rates, and clean accessibility flags for affected users. | System Maintenance | User |
| [Set-MicrosoftDefenderConfiguration](Set-MicrosoftDefenderConfiguration/README.md) | Audits, repairs services, clears policy overrides, and enforces Microsoft Defender Antivirus, Firewall, and SmartScreen hardening. | Re-enables disabled Defender protections, Controlled Folder Access, PUA blocking, and security baselines. | Security & Audit | Admin |
| [Show-Alert](Show-Alert/README.md) | Displays a topmost modal red WinForms warning dialog locally or on a remote interactive desktop (`Invoke-InteractiveScript.ps1`). | Delivers urgent visual notices directly to logged-on users despite WinRM Session 0 isolation. | Desktop Utilities | User |
| [Test-PrintSpooler](Test-PrintSpooler/README.md) | Performs a read-only check of the `Spooler` service state, queued print job count, and paused printers. | Quickly diagnoses stalled printing symptoms without making destructive queue changes. | Printing | User |
| [Unblock-PowerShellScripts](Unblock-PowerShellScripts/README.md) | Recursively scans directories and strips `Zone.Identifier` streams from downloaded `.ps1`, `.psm1`, and `.psd1` files. | Eliminates Mark-of-the-Web execution warnings across folders of downloaded PowerShell scripts. | Security & Audit | Admin |
| [Uninstall-Applications](Uninstall-Applications/README.md) | Searches installed apps via `.NET` Registry/WinGet and silently uninstalls targets via WinGet, MSI, or registry strings. | Standardizes multi-package software removal across 64-bit/32-bit/HKCU hives with `-WhatIf` preview. | Software Management | Admin |
| [Update-TextInFiles](Update-TextInFiles/README.md) | Performs safe in-memory literal, regex, and `[scriptblock]` find-and-replace across files with diff preview and backups. | Prevents encoding loss, binary file corruption, and locking errors during bulk configuration edits. | Files & Storage | User |

---

## 🚀 Key Features

* **Task Automation:** Automates repetitive administrative, software lifecycle, and maintenance tasks to save time and reduce human error.
* **Security & Compliance Auditing:** Read-only enterprise auditing scripts for BitLocker/TPM, local Administrators, Firewall/ports, ASEP persistence, and Windows Update hygiene.
* **Remote Management:** Scripts tailored for seamless execution via WinRM, `PSSession`, Hyper-V Manager, or interactive Session 0 bypass.
* **Admin-Friendly Standards:** Consistent `Verb-Noun` naming, Comment-Based Help (`Get-Help`), language-independent SID elevation (`S-1-5-32-544`), and structured logging.

## 🛠️ Prerequisites

* **OS:** Windows 10 / Windows 11 / Windows Server
* **PowerShell:** 5.1+ (PowerShell 7+ supported across most tools)
* **Execution Policy:** Must allow local script execution (e.g., `RemoteSigned` or `Bypass` for a process):
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

## 📦 Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/romanpindela/Windows-Desktop.git
   cd Windows-Desktop
   ```

2. **Unblock downloaded scripts if needed:**
   ```powershell
   Unblock-File -Path .\Add-NetworkPrinter\Add-NetworkPrinter.ps1
   ```

---

## 🖨️ Featured Scripts & Tools

### [Add-NetworkPrinter](Add-NetworkPrinter/README.md)
* **Script:** [`Add-NetworkPrinter.ps1`](Add-NetworkPrinter/Add-NetworkPrinter.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise-grade automation script for deploying network TCP/IP printers in local area networks (LAN) with ICMP/port-9100 diagnostics and system/INF/ZIP driver provisioning.
* **Quick Example:**
  ```powershell
  .\Add-NetworkPrinter\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e"
  ```

### [Manage-WindowsOptionalFeatures](Manage-WindowsOptionalFeatures/README.md)
* **Script:** [`Manage-WindowsOptionalFeatures.ps1`](Manage-WindowsOptionalFeatures/Manage-WindowsOptionalFeatures.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise-grade PowerShell tool for inspecting, listing details, enabling, and disabling Windows Optional Features (`DISM` / `Win32_OptionalFeature`) with `-DryRun` simulation and CSV/JSON export.
* **Quick Example:**
  ```powershell
  .\Manage-WindowsOptionalFeatures\Manage-WindowsOptionalFeatures.ps1 -List
  .\Manage-WindowsOptionalFeatures\Manage-WindowsOptionalFeatures.ps1 -Action Enable -FeatureName "TelnetClient", "Containers-DisposableClientVM"
  ```

### [Update-TextInFiles](Update-TextInFiles/README.md)
* **Script:** [`Update-TextInFiles.ps1`](Update-TextInFiles/Update-TextInFiles.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Safe, atomic literal, regex, and `[scriptblock]` search-and-replace utility across files and directory trees with binary protection, `-ShowDiff` preview, `-WhatIf`/`-Confirm`, and `.bak` / `-BackupDirectory` backups.
* **Quick Example:**
  ```powershell
  .\Update-TextInFiles\Update-TextInFiles.ps1 -Path ".\Docs" -Filter "*.md" -FindText "old-domain.com" -ReplaceWith "new-domain.com" -CreateBackup -ShowDiff
  ```

### [Optimize-WindowsDefender](Optimize-WindowsDefender/README.md)
* **Script:** [`Optimize-WindowsDefender.ps1`](Optimize-WindowsDefender/Optimize-WindowsDefender.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Performance tuning, live ETW profiling (`-Analyze`), health auditing (`-Audit`), and configuration snapshot suite for Microsoft Defender Antivirus (`WinDefend` / `MsMpEng.exe`).
* **Quick Example:**
  ```powershell
  .\Optimize-WindowsDefender\Optimize-WindowsDefender.ps1 -All
  .\Optimize-WindowsDefender\Optimize-WindowsDefender.ps1 -Audit
  ```

### Security Audit Suite (`Audit-*`)
* [Audit-BitLockerAndTpmStatus](Audit-BitLockerAndTpmStatus/README.md) (`.\Audit-BitLockerAndTpmStatus\Audit-BitLockerAndTpmStatus.ps1 -OpenReport`)
* [Audit-EndpointPersistence](Audit-EndpointPersistence/README.md) (`.\Audit-EndpointPersistence\Audit-EndpointPersistence.ps1 -OpenReport`)
* [Audit-LocalAdministrators](Audit-LocalAdministrators/README.md) (`.\Audit-LocalAdministrators\Audit-LocalAdministrators.ps1 -GenerateHtmlReport`)
* [Audit-LocalFirewallAndListeningPorts](Audit-LocalFirewallAndListeningPorts/README.md) (`.\Audit-LocalFirewallAndListeningPorts\Audit-LocalFirewallAndListeningPorts.ps1 -ShowReportInBrowser`)
* [Audit-WindowsUpdateAndPatchStatus](Audit-WindowsUpdateAndPatchStatus/README.md) (`.\Audit-WindowsUpdateAndPatchStatus\Audit-WindowsUpdateAndPatchStatus.ps1 -r -OpenReport`)
