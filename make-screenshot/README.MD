# Administrative PowerShell Toolkit

A collection of local administrative scripts for diagnostics and reporting.

## Overview
Due to Windows Security hardening and Session 0 isolation, these scripts are designed to be executed **locally** on the target machine. They can be triggered manually via PowerShell or automated using the Windows Task Scheduler.

## Scripts
- **Invoke-LocalScreenshot.ps1**: Captures the primary desktop screen and saves it as a PNG file in a specified directory.
- **Invoke-SystemDiagnostic.ps1**: Generates a brief report on system resources (RAM, Disk) and service status.

## Installation & Usage
1. Place the scripts in a trusted directory (e.g., `C:\Scripts`).
2. Run them via PowerShell:
   ```powershell
   .\Invoke-LocalScreenshot.ps1 -OutputDirectory "C:\Backups\Screenshots"
To view help, use the help switch:

PowerShell
.\Invoke-LocalScreenshot.ps1 -Help
Automation (Task Scheduler)
To automate these tasks:

Open Task Scheduler.

Create a task.

In Actions, add:

Program: powershell.exe

Arguments: -ExecutionPolicy Bypass -File "C:\Scripts\Invoke-LocalScreenshot.ps1"

Contact
Author: Roman Pindela

Email: roman.pindela@gmail.com

GitHub: romanpindela

Version: 1.0.0