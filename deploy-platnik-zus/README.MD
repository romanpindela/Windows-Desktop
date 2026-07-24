# ZUS Płatnik Automated Installer

**Version: 1.0.0**

A professional PowerShell script to automate the complete, unattended installation of ZUS Płatnik on Windows 10 and Windows 11.

---

## Description

This tool streamlines the preparation for a manual ZUS Płatnik installation. It intelligently checks the system for required dependencies (.NET Framework 4.8+, VSTO Runtime, WSE 3.0), automatically installing them if they are missing.

Once the environment is verified and all prerequisites are met, the script downloads the latest official Płatnik installer and its corresponding patch to the **C:\Temp** folder, ready for you to run manually.

The script provides a user-friendly experience with a detailed progress bar and robust, language-independent checks, ensuring it works reliably on both Polish and English versions of Windows.

## Features

*   **Automatic UAC Elevation**: Prompts for Administrator rights if not already elevated.
*   **Automated Prerequisite Management**: Checks for and installs .NET Framework 4.8+, VSTO 2010 Runtime, and WSE 3.0.
*   **Installer Download**: Downloads the main Płatnik installer and the latest patch to the `C:\Temp` folder.
*   **Progress Tracking**: A step-by-step progress bar shows exactly what the script is doing.
*   **Error Handling**: Gracefully handles unexpected errors and provides clear feedback.
*   **Self-Contained**: No external modules required, uses native PowerShell and `winget`.
*   **Language Independent**: Core functions (like admin checks) use SIDs to work on any Windows language.

## Requirements

*   Windows 10 / Windows 11 / Windows Server 2019+
*   PowerShell 5.1 or later
*   Internet connection (for downloading prerequisites and Płatnik)
*   `winget` package manager (included by default in modern Windows versions)

## Important: Unblocking the Script

After downloading the script from the internet (e.g., from GitHub), Windows will likely block it for security reasons. You must unblock it before execution.

Open a PowerShell terminal in the script's directory and run:

```powershell
Unblock-File -Path '.\deploy-zus-platnik.ps1'
```

## Usage

The script is designed to be simple to use. Administrator privileges are required and will be requested automatically.

### Prepare Environment and Download All Files (Default)

To run the script with default behavior, which downloads both the installer and the patch:

```powershell
# Navigate to the script's directory first
cd C:\path\to\script

.\deploy-zus-platnik.ps1
```

### Prepare and Download Only the Patch

To prepare the environment but only download the patch file:
```powershell
.\deploy-zus-platnik.ps1 -Download PatchOnly
```

### Displaying Help

To see the built-in help menu with parameter descriptions and examples:

```powershell
.\deploy-zus-platnik.ps1 -Help
```

## Parameters

| Parameter          | Description                                                              | Default Value                                                              |
| ------------------ | ------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| `-InstallerUrl`    | The URL for the main ZUS Płatnik installer executable.                   | `https://redir.cache.orange.pl/zus/pobierz/dystrybucja/a1_10_02_002/pelna/install.exe` |
| `-PatchUrl`        | The URL for the ZUS Płatnik patch executable.                            | `https://redir.cache.orange.pl/zus/pobierz/dystrybucja/a1_10_02_002/dodatki/P2StartFix2.exe` |
| `-Download`        | Specifies which files to download: `All`, `InstallerOnly`, `PatchOnly`.  | `All`                                                                      |
| `-Help` / `-h`     | Displays the detailed help message and exits.                            | `[switch]`                                                                 |

---

## Author

*   **Roman Pindela**
*   **Email**: `roman.pindela@gmail.com`
*   **GitHub**: https://github.com/romanpindela

## Version History

*   **v1.0.0** (2026-07-24)
    *   Initial release.
    *   Added core functionality for downloading and silent installation.
    *   Implemented prerequisite checks and installation for .NET and SQL LocalDB.
    *   Integrated automatic UAC elevation and detailed progress bar.
    *   Created comprehensive help function and README documentation.
