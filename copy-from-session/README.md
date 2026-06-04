# copy-from-session.ps1

A utility script to seamlessly, intelligently, and securely retrieve remote files and directories to your local machine using PowerShell Remoting (PSSession).

## Features
- **Intelligent Routing:** Automatically detects whether you are retrieving single files, multiple files, or an entire directory.
  - *Files* drop directly into the target local folder.
  - *Folders* replicate themselves and their entire recursive tree seamlessly.
- **Auto-Provisioning:** If the local target directory (`LocalPath`) does not exist on your machine, the script automatically creates it before initiating the transfer to prevent errors.
- **Source Validation:** Validates the existence of remote source paths over the PSSession before attempting the transfer.
- **Secure Authentication:** Dynamically prompts for credentials to ensure secure access.
- **Session Management:** Automatically handles the creation and destruction of the PSSession.
- **Reverse Transfer:** Acts as the exact inverse of `Copy-ToSession.ps1`, pulling data to the local host.
- **Clean Architecture:** Strict parameter validation and `try/catch/finally` blocks for safety.

## Parameters

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `-ComputerName` | `String` | Yes | Target remote computer hostname or IP. |
| `-RemotePath` | `String[]` | Yes | Remote file/folder path(s) to retrieve. Accepts single paths or comma-separated lists. |
| `-LocalPath` | `String` | Yes | Local destination base directory. |

## Usage Examples

### 1. Retrieving a single file
```powershell
.\copy-from-session.ps1 -ComputerName "192.168.1.100" -RemotePath "C:\Logs\Server.log" -LocalPath "C:\Local\Audit\"


2. Retrieving multiple files simultaneously
PowerShell
.\copy-from-session.ps1 -ComputerName "192.168.1.100" -RemotePath "C:\Logs\1.log", "C:\Logs\2.log" -LocalPath "C:\Local\Audit\"
3. Retrieving a complete directory (and its contents)
PowerShell
.\copy-from-session.ps1 -ComputerName "192.168.1.100" -RemotePath "C:\Logs\Archive" -LocalPath "C:\Local\Audit\"
Author Information
Author: Roman Pindela

Email: roman.pindela@gmail.com

GitHub: romanpindela

Version: 1.1.0