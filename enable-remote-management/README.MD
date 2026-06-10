# README.md

# enable-remote-management

A clean, robust, and enterprise-grade PowerShell utility designed to be executed **locally** on a Windows machine. It automatically initializes PowerShell Remoting (WinRM), strictly validates target user account existence, delegates secure remote access permissions, and outputs a visual summary of authorized entities.

## Features

- **Identity Verification Check:** Proactively queries the local security subsystem or Active Directory identity services to verify that the target user exists before performing system changes. If the target identity is invalid, the script prints a clear red alert and terminates.
- **Local Infrastructure Initialization:** Invokes `Enable-PSRemoting` to handle the local WinRM listener footprint and setup default firewall paths.
- **Execution Policy Configuration:** Automatically sets the PowerShell `ExecutionPolicy` to `RemoteSigned` for the `CurrentUser` scope to prevent local script execution blocks and displays a colorized list of current system policies.
- **Auto-Elevation (UAC):** Automatically detects if the terminal lacks Administrator privileges and prompts the user to relaunch the script with elevated permissions.
- **Access Delegation Control:** Automatically binds the confirmed user identity to the local `Remote Management Users` group.
- **Live Auditing Block:** Compiles a terminal diagnostic report listing both implicit (Administrators) and explicit (Remote Management Users) accounts permitted to establish network shells.
- **Colorized Output Metrics:** Leverages colorized logs to stream environment states, warning logs, or critical termination signals.

## Network & Firewall Notes (Critical)

> [!IMPORTANT]
> - **Default Scope:** This utility provisions WinRM using **default firewall rule configurations** (allowing connection endpoints from Any source address).
> - **Subnet Restriction Requirement:** If compliance policies require restricting traffic to explicit management subnets, you must manually implement or deploy a custom inbound packet filtering rule in the Windows Advanced Firewall architecture.

## Requirements

- **PowerShell Version:** PowerShell 5.1 or PowerShell Core (7.x+).
- **Execution Level:** Must be executed locally. If the session is not elevated, the script will automatically request **Administrator privileges** via a UAC prompt.

## Usage

### Direct Terminal Help
Access arguments, configuration parameters, and operational remarks instantly:
```powershell
.\enable-remote-management.ps1 -Help
# or
.\enable-remote-management.ps1 -h