# invoke-remote-command

A professional and clean PowerShell utility designed to execute custom string commands on a remote Windows computer interactively. It establishes a connection via PowerShell Remoting (WinRM), securely handles administrative credentials, and returns the output directly to your local console.

## Features

- **Interactive Mode:** If the remote command is omitted during execution, the script dynamically prompts the user for input in the console.
- **Secure Credential Handling:** Automatically prompts for network credentials using standard Windows secure entry if a pre-defined credential object is not provided.
- **Safe Execution:** Implements structured exception handling (`try/catch`) and validation to prevent running empty commands or crashing upon connection failure.
- **Built-in Documentation:** Includes localized help screens accessible via switches.

## Requirements

- **PowerShell** 5.1 or higher[cite: 1].
- **WinRM Enabled:** PowerShell Remoting must be enabled and configured on the target remote machine[cite: 1].
- **Network Permissions:** Proper administrative rights on the target system to invoke remote blocks.

## Usage

### Getting Help
To view the quick reference guide and usage syntax directly in the console, use the help switch:
```powershell
.\invoke-remote-command.ps1 -Help
# or
.\invoke-remote-command.ps1 -h

## Examples

### 1. Interactive Command Execution
Specify the target computer name only[cite: 5]. The script will prompt you for both network credentials and the exact string command to execute[cite: 5]:

```powershell
.\invoke-remote-command.ps1 -ComputerName "10.10.1.4"