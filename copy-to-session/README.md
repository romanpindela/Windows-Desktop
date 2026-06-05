# copy-to-session.ps1

A utility script to seamlessly, intelligently, and securely transfer local files and directories to a remote machine using PowerShell Remoting (PSSession).

## Features
- **Intelligent Routing:** Automatically detects whether you are sending single files, multiple files, or an entire directory. 
  - *Files* drop directly into the target folder.
  - *Folders* replicate themselves and their entire recursive tree seamlessly.
- **Auto-Provisioning:** If the target directory (`RemotePath`) does not exist on the remote host, the script automatically creates it before initiating the transfer to prevent naming collisions.
- **Secure Authentication:** Dynamically prompts for credentials to ensure secure access.
- **Session Management:** Automatically handles the creation and destruction of the PSSession to prevent memory leaks.
- **Clean Architecture:** Strict parameter validation and connection cleanup happens in a `finally` block even if the copy process fails.

## Parameters

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `-ComputerName` | `String` | Yes | Target remote computer hostname or IP. |
| `-LocalPath` | `String[]` | Yes | Local file/folder path(s) to transfer. Accepts single paths or comma-separated lists. |
| `-RemotePath` | `String` | Yes | Destination base directory on the remote machine. |

## Usage Examples

### 1. Copying a single file
```powershell
.\copy-to-session.ps1 -ComputerName "192.168.1.100" -LocalPath "C:\Data\Logs\error.log" -RemotePath "C:\Backup\Logs\"



2. Copying multiple files simultaneously
PowerShell
.\copy-to-session.ps1 -ComputerName "192.168.1.100" -LocalPath "C:\Data\1.txt", "C:\Data\2.txt" -RemotePath "C:\Backup\Logs\"
3. Copying a complete directory (and its contents)
PowerShell
.\copy-to-session.ps1 -ComputerName "192.168.1.100" -LocalPath "C:\Data\FullFolder" -RemotePath "C:\Backup\Logs\"
Author Information
Author: Roman Pindela

Email: roman.pindela@gmail.com

GitHub: romanpindela

Version: 1.1.0