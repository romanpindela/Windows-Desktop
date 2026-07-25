# Download and Run Script Utility

**Version: 1.2.0**

A professional PowerShell utility to securely download a script from a GitHub URL, unblock it, and optionally execute it.

---

## Description

This script is designed for administrators and power users who need a reliable way to fetch and run PowerShell scripts directly from GitHub. It takes a standard GitHub URL, automatically converts it to the raw content link, and handles the entire process of downloading, unblocking (removing the "Mark-of-the-Web"), and executing the script.

It is built with safety and flexibility in mind, featuring mandatory parameters to prevent accidental execution, automatic UAC elevation for administrative tasks, and clear, professional console output.

## Features

*   **Parameter-Driven:** No hardcoded values. Specify the URL and destination via parameters.
*   **Dual-Mode Operation:** Can be run from a file using the `-Url` parameter or by pasting its contents directly into a console (after setting the internal `$HardcodedUrl` variable).
*   **Automatic UAC Elevation**: Prompts for Administrator rights if needed to write to protected locations like `C:\Temp`.
*   **Secure by Default:**
    *   Requires the `-Url` parameter, preventing execution without a target.
    *   Does not execute the downloaded script unless the `-Execute` switch is explicitly used.
    *   Automatically runs `Unblock-File` to ensure the script can run in stricter execution policy environments.
*   **Professional Help:** Includes a comprehensive, built-in help menu accessible via `-Help` or `-h`.

## Requirements

*   Windows 10 / Windows 11 / Windows Server 2019+
*   PowerShell 5.1 or later
*   Internet connection

## Important: Unblocking the Script

After downloading this utility script itself from the internet, Windows will likely block it. You must unblock it before you can run it.

Open a PowerShell terminal in the script's directory and run:

```powershell
Unblock-File -Path '.\download-run-script.ps1'
```

## Usage

The script requires the `-Url` parameter to function. Administrator privileges will be requested automatically if needed.

### Method 1: Run From File (Recommended)

#### Example 1: Download a Script (No Execution)

```powershell
.\download-run-script.ps1 -Url "https://github.com/someuser/repository/blob/main/their-script.ps1"
```

### Example 2: Download and Execute a Script

Downloads the script and immediately runs it.

```powershell
.\download-run-script.ps1 -Url "https://github.com/someuser/repository/blob/main/their-script.ps1" -Execute
```

### Example 3: Download to a Custom Location

Downloads the script to a specific folder.

```powershell
.\download-run-script.ps1 -Url "https://github.com/someuser/repository/blob/main/their-script.ps1" -DestinationPath "C:\MyScripts"
```

## Parameters

| Parameter         | Description                                                              | Default Value |
| ----------------- | ------------------------------------------------------------------------ | ------------- |
| `-Url`            | **(Mandatory)** The full GitHub URL of the `.ps1` file to download.      | `N/A`         |
| `-DestinationPath`| The local folder for the download.                                       | `C:\Temp`     |
| `-Execute`        | A switch to run the script after it's downloaded.                        | `[switch]`    |
| `-Help` / `-h`    | Displays the detailed help message and exits.                            | `[switch]`    |

---

## Author

*   **Roman Pindela**
*   **Email**: `roman.pindela@gmail.com`
*   **GitHub**: https://github.com/romanpindela
