# spooler-diagnosis.ps1

A professional administrative script for diagnosing the Windows Print Spooler service on local or remote machines.

## Features
- **Service Validation:** Checks the current state of the Print Spooler service.
- **Queue Analysis:** Queries WMI/CIM to detect the number of stuck print jobs.
- **Printer Status Check:** Retrieves a list of installed printers and highlights any paused devices in color.
- **Remote Capable:** Can target remote servers securely.
- **Clean Architecture:** Built according to CleanCode principles with proper error handling.

## Parameters

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `-ComputerName` | `String` | No | Target computer name (Defaults to local host). |
| `-ShowHelp` (`-h`) | `Switch` | No | Displays the interactive script help menu. |

## Usage Examples
```powershell
# Local diagnosis
.\spooler-diagnosis.ps1

# Remote diagnosis
.\spooler-diagnosis.ps1 -ComputerName "SRV-PRINT-01"

Author Information
Author: Roman Pindela

Email: roman.pindela@gmail.com

GitHub: romanpindela

Version: 1.1.0