# PowerShell Script Launcher

**Version: 1.0.0**

A minimalist and robust PowerShell script designed to download and execute another script from GitHub by simply copying and pasting its content into a console.

---

## Description

This utility serves as a simple "launcher." Its primary purpose is to provide a reliable method for running a remote PowerShell script without needing to save any files beforehand. It is optimized for a copy-paste workflow, making it ideal for rapid deployments, remote troubleshooting, or initial machine setup.

The script handles all the necessary steps: UAC elevation, converting the GitHub URL, downloading the target script, unblocking it, and finally, executing it.

## Features

*   **Copy-Paste Execution:** Designed from the ground up to work flawlessly when pasted directly into a PowerShell console.
*   **Robust UAC Elevation:** Uses a sophisticated `-EncodedCommand` method to self-elevate, which works reliably without a source file path.
*   **Simple Configuration:** Requires editing only one variable (`$UrlToDownload`) at the top of the script.
*   **Automatic and Secure:**
    *   Intelligently converts standard GitHub URLs to their raw format.
    *   Automatically runs `Unblock-File` to remove the "Mark-of-the-Web."
    *   Uses TLS 1.2 for secure downloads.
*   **Lean and Focused:** Contains no complex parameter logic, ensuring maximum compatibility with the console's parser.

## Requirements

*   Windows 10 / Windows 11 / Windows Server 2019+
*   PowerShell 5.1 or later
*   Internet connection

## Usage

The script is designed for a simple, three-step process:

1.  **Configure:** Open the `run-from-github.ps1` script content in a text editor and set the `$UrlToDownload` variable to the GitHub URL of the script you wish to run.

    ```powershell
    # Paste the full GitHub URL of the script you want to download and run.
    $UrlToDownload = "https://github.com/someuser/repository/blob/main/their-script.ps1"
    ```

2.  **Copy:** Select and copy the *entire content* of the `run-from-github.ps1` script.

3.  **Paste and Run:** Open an administrative PowerShell console, paste the copied content, and press `Enter`.

The script will handle the UAC prompt (if not already admin), download the target script to `C:\Temp`, and execute it, showing all output in your current console window.

---

## Author

*   **Roman Pindela**
*   **Email**: `roman.pindela@gmail.com`
*   **GitHub**: https://github.com/romanpindela