# Invoke-RemoteScript

A professional, secure, and clean PowerShell utility designed to execute local `.ps1` script files directly on remote Windows environments via WinRM. 

Instead of copying script files to the remote file system, this utility reads the local file context and runs it entirely in-memory within the remote session, reducing the footprint and maintaining security.

## Features

- **Zero-Footprint Execution:** Runs local scripts in the remote RAM without saving temporary files to the remote disk.
- **Input Validation:** Built-in mechanisms to prevent execution with malicious, empty, or unexpected arguments.
- **Interactive Fallback:** Prompt-driven credential requests when parameters are omitted.
- **Clean Code Standard:** Structured architecture following industry-standard PowerShell logging, error handling, and formatting rules.

## Requirements

- **PowerShell** 5.1 or PowerShell Core (7.x+)
- **WinRM Enabled:** The remote machine must have PowerShell Remoting enabled (`Enable-PSRemoting`).
- **Network Permissions:** Appropriate administrative privileges on the target machine.

## Usage

### Interactive Help Screen
To view all available parameters and usage guidelines, run the script without arguments or use the help flags:
```powershell
.\invoke-remote-script -Help
# or
.\invoke-remote-script -h