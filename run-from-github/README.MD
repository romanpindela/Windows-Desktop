# PowerShell Script Launcher (Run from GitHub)

**Version: 1.2.0**

[![PowerShell Compatibility](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.0%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%28Desktop%20%2F%20Server%29-lightgrey.svg)](https://www.microsoft.com/windows)
[![Privileges](https://img.shields.io/badge/Privileges-Administrator-red.svg)](https://docs.microsoft.com/en-us/windows/security/identity-protection/user-account-control/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A reliable, **Copy-Paste** PowerShell launcher designed to automatically download, unblock, and execute any PowerShell script directly from a GitHub repository by simply pasting a single command block into an elevated (**Administrator**) PowerShell console.

Supports passing optional arguments and switch parameters (e.g., `-AutoDiscover`, `-All`, `-SiteName`) directly to the target script.

---

## 📋 Table of Contents

- [How It Works](#-how-it-works)
- [Comparison of 3 ExecutionPolicy Scopes](#-comparison-of-3-executionpolicy-scopes)
- [🚀 Ready-to-Copy Code Blocks](#-ready-to-copy-code-blocks)
  - [⚡ Example with Parameters: SharePoint Sync (Sync-SharePointLibrary.ps1 -AutoDiscover)](#-example-with-parameters-sharepoint-sync-sync-sharepointlibraryps1--autodiscover)
  - [Option 1: Machine-Wide (LocalMachine)](#option-1-machine-wide-localmachine)
  - [Option 2: Current User (CurrentUser)](#option-2-current-user-currentuser)
  - [Option 3: Current Session Only (Process)](#option-3-current-session-only-process)
- [⚙️ How to Pass Parameters to the Target Script](#️-how-to-pass-parameters-to-the-target-script)
- [🔧 Code Breakdown & Architecture](#-code-breakdown--architecture)
- [💻 Technical Requirements](#-technical-requirements)
- [👤 Author](#-author)

---

## 🔍 How It Works

The main purpose of this launcher is to allow immediate execution of a GitHub-hosted PowerShell script on a fresh machine or during an IT support / troubleshooting session without having to manually create files, clone repositories, or download archives through a web browser.

Each code block performs a complete operational lifecycle in a single paste:
1. **Administrator Privileges Check:** Verifies elevated permissions using a language-independent Well-Known SID (`S-1-5-32-544`).
2. **Unlock PowerShell (`Set-ExecutionPolicy`):** Adjusts script execution policy to the desired scope (`LocalMachine`, `CurrentUser`, or `Process`).
3. **Prepare Destination Folder (`C:\PowerShell`):** Verifies and creates the target directory automatically if it does not already exist.
4. **Enforce TLS 1.2 & GitHub URL Handling:** Forces TLS 1.2 protocol for secure downloading and automatically transforms standard GitHub web URLs (`/blob/`) into direct raw content endpoints (`raw.githubusercontent.com`).
5. **Download Script:** Fetches the target script via `Invoke-WebRequest`.
6. **Unblock File (`Unblock-File`):** Strips the Windows Mark of the Web (MotW / `Zone.Identifier` NTFS alternate data stream).
7. **Execute Script with Arguments:** Invokes the downloaded script in the current console context, passing configured arguments (via the `$ScriptArgs` variable), and outputs the results.

---

## 📊 Comparison of 3 ExecutionPolicy Scopes

| Option | Scope (`-Scope`) | Registry Level | Persistence | When to Use? |
| :--- | :--- | :--- | :--- | :--- |
| **1. Machine** | `LocalMachine` | `HKLM:\SOFTWARE\Microsoft\PowerShell...` | **Permanent** (system-wide) | Workstations, admin servers, baseline image provisioning, when all users on the device need script execution enabled. |
| **2. User** | `CurrentUser` | `HKCU:\SOFTWARE\Microsoft\PowerShell...` | **Permanent** (user profile) | Shared computers, when enabling script execution only for the current administrator/user account without altering system-wide or other user settings. |
| **3. Session** | `Process` | None (process memory only) | **Temporary** (resets on window close) | One-time deployments, diagnostic runs, security audits, and hardened environments where permanent registry changes are prohibited. |

---

## 🚀 Ready-to-Copy Code Blocks

> [!IMPORTANT]
> Make sure to open **PowerShell as Administrator** (`Run as Administrator`) before pasting any of the blocks below.
> You can easily adjust `$UrlToDownload` and `$ScriptArgs` to fit any GitHub-hosted script and arguments.

---

### ⚡ Example with Parameters: SharePoint Sync (Sync-SharePointLibrary.ps1 -AutoDiscover)

The following block downloads the enterprise-grade SharePoint Online document library sync utility from the [Microsoft-365](https://github.com/romanpindela/Microsoft-365) repository and runs it with the `-AutoDiscover` switch (automatically searches for and interactively lists all SharePoint sites accessible to the signed-in user in Microsoft 365).

It uses the safe `Process` scope (temporary `Bypass` execution policy), leaving no permanent changes in the Windows registry.

#### Full Script Block (clean and ready to paste):

```powershell
# ==============================================================================
# SYNC-SHAREPOINTLIBRARY WITH -AUTODISCOVER PARAMETER (Scope: Process)
# ==============================================================================
# 1. Configure script URL, arguments, and destination folder
$UrlToDownload   = "https://github.com/romanpindela/Microsoft-365/blob/main/SharePoint/Sync-SharePointLibrary/Sync-SharePointLibrary.ps1"
$ScriptArgs      = "-AutoDiscover"
$DestinationPath = "C:\PowerShell"

# 2. Verify Administrator privileges (language-independent SID check)
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
if (-not $principal.IsInRole($adminSid)) {
    Write-Error "Administrator privileges required! Please run PowerShell as Administrator."
    return
}

# 3. Temporarily set execution policy to Bypass for the current session only
Write-Host "Setting ExecutionPolicy to Bypass for current process..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# 4. Check and create destination directory
if (-not (Test-Path -LiteralPath $DestinationPath)) {
    Write-Host "Creating directory: $DestinationPath..." -ForegroundColor Yellow
    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
}

# 5. Enforce TLS 1.2 and convert standard GitHub URL to Raw URL
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($UrlToDownload -like "*github.com/*/blob/*") {
    $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
} else {
    $rawUrl = $UrlToDownload
}

$fileName        = Split-Path -Path $rawUrl.Split('?')[0] -Leaf
$destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

# 6. Download script from GitHub
Write-Host "Downloading '$fileName' to '$DestinationPath'..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

# 7. Unblock file (remove Mark-of-the-Web) and execute with arguments
if (Test-Path -LiteralPath $destinationFile) {
    Unblock-File -LiteralPath $destinationFile
    Write-Host "[OK] Script unblocked successfully." -ForegroundColor Green
    
    if ([string]::IsNullOrWhiteSpace($ScriptArgs)) {
        Write-Host "`n--- Executing downloaded script: $fileName ---`n" -ForegroundColor Yellow
        & $destinationFile
    } else {
        Write-Host "`n--- Executing downloaded script: $fileName $ScriptArgs ---`n" -ForegroundColor Yellow
        Invoke-Expression "& `"$destinationFile`" $ScriptArgs"
    }
    
    Write-Host "`n--- Finished executing: $fileName ---`n" -ForegroundColor Yellow
} else {
    Write-Error "Error: Downloaded file was not found at: $destinationFile"
}
```

#### One-Liner (Fast execution with -AutoDiscover):

```powershell
& { $u="https://github.com/romanpindela/Microsoft-365/blob/main/SharePoint/Sync-SharePointLibrary/Sync-SharePointLibrary.ps1"; $a="-AutoDiscover"; $p="C:\PowerShell"; if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){throw "Administrator privileges required!"}; Set-ExecutionPolicy Bypass -Scope Process -Force; if(-not(Test-Path $p)){New-Item -Path $p -ItemType Directory -Force|Out-Null}; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=if($u -like "*github.com/*/blob/*"){$u -replace "github.com","raw.githubusercontent.com" -replace "/blob/","/"}else{$u}; $f=Join-Path $p (Split-Path $r.Split('?')[0] -Leaf); Invoke-WebRequest -Uri $r -OutFile $f -UseBasicParsing; Unblock-File -LiteralPath $f; if($a){Invoke-Expression "& `"$f`" $a"}else{& $f} }
```

#### One-Liner (Silent synchronization with -AutoDiscover -All):

```powershell
& { $u="https://github.com/romanpindela/Microsoft-365/blob/main/SharePoint/Sync-SharePointLibrary/Sync-SharePointLibrary.ps1"; $a="-AutoDiscover -All"; $p="C:\PowerShell"; if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){throw "Administrator privileges required!"}; Set-ExecutionPolicy Bypass -Scope Process -Force; if(-not(Test-Path $p)){New-Item -Path $p -ItemType Directory -Force|Out-Null}; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=if($u -like "*github.com/*/blob/*"){$u -replace "github.com","raw.githubusercontent.com" -replace "/blob/","/"}else{$u}; $f=Join-Path $p (Split-Path $r.Split('?')[0] -Leaf); Invoke-WebRequest -Uri $r -OutFile $f -UseBasicParsing; Unblock-File -LiteralPath $f; if($a){Invoke-Expression "& `"$f`" $a"}else{& $f} }
```

---

### Option 1: Machine-Wide (LocalMachine)

Unlocks PowerShell script execution globally for all users on the computer.

#### Full Script Block (clean and ready to paste):

```powershell
# ==============================================================================
# OPTION 1: MACHINE-WIDE (Scope: LocalMachine)
# ==============================================================================
# 1. Configure script URL, arguments, and destination folder
$UrlToDownload   = "https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"
$ScriptArgs      = "" # Optional arguments (e.g. "-AutoDiscover", "-All", "-Verbose")
$DestinationPath = "C:\PowerShell"

# 2. Verify Administrator privileges (language-independent SID check)
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
if (-not $principal.IsInRole($adminSid)) {
    Write-Error "Administrator privileges required! Please run PowerShell as Administrator."
    return
}

# 3. Enable script execution machine-wide
Write-Host "Setting ExecutionPolicy to RemoteSigned for LocalMachine..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# 4. Check and create destination directory
if (-not (Test-Path -LiteralPath $DestinationPath)) {
    Write-Host "Creating directory: $DestinationPath..." -ForegroundColor Yellow
    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
}

# 5. Enforce TLS 1.2 and convert standard GitHub URL to Raw URL
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($UrlToDownload -like "*github.com/*/blob/*") {
    $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
} else {
    $rawUrl = $UrlToDownload
}

$fileName        = Split-Path -Path $rawUrl.Split('?')[0] -Leaf
$destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

# 6. Download script from GitHub
Write-Host "Downloading '$fileName' to '$DestinationPath'..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

# 7. Unblock file (remove Mark-of-the-Web) and execute with optional arguments
if (Test-Path -LiteralPath $destinationFile) {
    Unblock-File -LiteralPath $destinationFile
    Write-Host "[OK] Script unblocked successfully." -ForegroundColor Green
    
    if ([string]::IsNullOrWhiteSpace($ScriptArgs)) {
        Write-Host "`n--- Executing downloaded script: $fileName ---`n" -ForegroundColor Yellow
        & $destinationFile
    } else {
        Write-Host "`n--- Executing downloaded script: $fileName $ScriptArgs ---`n" -ForegroundColor Yellow
        Invoke-Expression "& `"$destinationFile`" $ScriptArgs"
    }
    
    Write-Host "`n--- Finished executing: $fileName ---`n" -ForegroundColor Yellow
} else {
    Write-Error "Error: Downloaded file was not found at: $destinationFile"
}
```

#### One-Liner (Fast execution):

```powershell
& { $u="https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"; $a=""; $p="C:\PowerShell"; if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){throw "Administrator privileges required!"}; Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force; if(-not(Test-Path $p)){New-Item -Path $p -ItemType Directory -Force|Out-Null}; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=if($u -like "*github.com/*/blob/*"){$u -replace "github.com","raw.githubusercontent.com" -replace "/blob/","/"}else{$u}; $f=Join-Path $p (Split-Path $r.Split('?')[0] -Leaf); Invoke-WebRequest -Uri $r -OutFile $f -UseBasicParsing; Unblock-File -LiteralPath $f; if($a){Invoke-Expression "& `"$f`" $a"}else{& $f} }
```

---

### Option 2: Current User (CurrentUser)

Unlocks script execution only for the current user's profile (persistent setting in `HKCU`).

#### Full Script Block (clean and ready to paste):

```powershell
# ==============================================================================
# OPTION 2: CURRENT USER (Scope: CurrentUser)
# ==============================================================================
# 1. Configure script URL, arguments, and destination folder
$UrlToDownload   = "https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"
$ScriptArgs      = "" # Optional arguments (e.g. "-AutoDiscover", "-All", "-Verbose")
$DestinationPath = "C:\PowerShell"

# 2. Verify Administrator privileges (language-independent SID check)
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
if (-not $principal.IsInRole($adminSid)) {
    Write-Error "Administrator privileges required! Please run PowerShell as Administrator."
    return
}

# 3. Enable script execution for the current user
Write-Host "Setting ExecutionPolicy to RemoteSigned for CurrentUser..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 4. Check and create destination directory
if (-not (Test-Path -LiteralPath $DestinationPath)) {
    Write-Host "Creating directory: $DestinationPath..." -ForegroundColor Yellow
    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
}

# 5. Enforce TLS 1.2 and convert standard GitHub URL to Raw URL
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($UrlToDownload -like "*github.com/*/blob/*") {
    $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
} else {
    $rawUrl = $UrlToDownload
}

$fileName        = Split-Path -Path $rawUrl.Split('?')[0] -Leaf
$destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

# 6. Download script from GitHub
Write-Host "Downloading '$fileName' to '$DestinationPath'..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

# 7. Unblock file (remove Mark-of-the-Web) and execute with optional arguments
if (Test-Path -LiteralPath $destinationFile) {
    Unblock-File -LiteralPath $destinationFile
    Write-Host "[OK] Script unblocked successfully." -ForegroundColor Green
    
    if ([string]::IsNullOrWhiteSpace($ScriptArgs)) {
        Write-Host "`n--- Executing downloaded script: $fileName ---`n" -ForegroundColor Yellow
        & $destinationFile
    } else {
        Write-Host "`n--- Executing downloaded script: $fileName $ScriptArgs ---`n" -ForegroundColor Yellow
        Invoke-Expression "& `"$destinationFile`" $ScriptArgs"
    }
    
    Write-Host "`n--- Finished executing: $fileName ---`n" -ForegroundColor Yellow
} else {
    Write-Error "Error: Downloaded file was not found at: $destinationFile"
}
```

#### One-Liner (Fast execution):

```powershell
& { $u="https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"; $a=""; $p="C:\PowerShell"; if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){throw "Administrator privileges required!"}; Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; if(-not(Test-Path $p)){New-Item -Path $p -ItemType Directory -Force|Out-Null}; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=if($u -like "*github.com/*/blob/*"){$u -replace "github.com","raw.githubusercontent.com" -replace "/blob/","/"}else{$u}; $f=Join-Path $p (Split-Path $r.Split('?')[0] -Leaf); Invoke-WebRequest -Uri $r -OutFile $f -UseBasicParsing; Unblock-File -LiteralPath $f; if($a){Invoke-Expression "& `"$f`" $a"}else{& $f} }
```

---

### Option 3: Current Session Only (Process)

Unlocks script execution **only within the current PowerShell process**. Does not write to or alter the Windows registry and automatically expires when the console window is closed.

#### Full Script Block (clean and ready to paste):

```powershell
# ==============================================================================
# OPTION 3: CURRENT SESSION ONLY (Scope: Process)
# ==============================================================================
# 1. Configure script URL, arguments, and destination folder
$UrlToDownload   = "https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"
$ScriptArgs      = "" # Optional arguments (e.g. "-AutoDiscover", "-All", "-Verbose")
$DestinationPath = "C:\PowerShell"

# 2. Verify Administrator privileges (language-independent SID check)
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
if (-not $principal.IsInRole($adminSid)) {
    Write-Error "Administrator privileges required! Please run PowerShell as Administrator."
    return
}

# 3. Set execution policy to Bypass for this session only
Write-Host "Setting ExecutionPolicy to Bypass for current session (Process)..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# 4. Check and create destination directory
if (-not (Test-Path -LiteralPath $DestinationPath)) {
    Write-Host "Creating directory: $DestinationPath..." -ForegroundColor Yellow
    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
}

# 5. Enforce TLS 1.2 and convert standard GitHub URL to Raw URL
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($UrlToDownload -like "*github.com/*/blob/*") {
    $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
} else {
    $rawUrl = $UrlToDownload
}

$fileName        = Split-Path -Path $rawUrl.Split('?')[0] -Leaf
$destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

# 6. Download script from GitHub
Write-Host "Downloading '$fileName' to '$DestinationPath'..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

# 7. Unblock file (remove Mark-of-the-Web) and execute with optional arguments
if (Test-Path -LiteralPath $destinationFile) {
    Unblock-File -LiteralPath $destinationFile
    Write-Host "[OK] Script unblocked successfully." -ForegroundColor Green
    
    if ([string]::IsNullOrWhiteSpace($ScriptArgs)) {
        Write-Host "`n--- Executing downloaded script: $fileName ---`n" -ForegroundColor Yellow
        & $destinationFile
    } else {
        Write-Host "`n--- Executing downloaded script: $fileName $ScriptArgs ---`n" -ForegroundColor Yellow
        Invoke-Expression "& `"$destinationFile`" $ScriptArgs"
    }
    
    Write-Host "`n--- Finished executing: $fileName ---`n" -ForegroundColor Yellow
} else {
    Write-Error "Error: Downloaded file was not found at: $destinationFile"
}
```

#### One-Liner (Fast execution):

```powershell
& { $u="https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"; $a=""; $p="C:\PowerShell"; if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){throw "Administrator privileges required!"}; Set-ExecutionPolicy Bypass -Scope Process -Force; if(-not(Test-Path $p)){New-Item -Path $p -ItemType Directory -Force|Out-Null}; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=if($u -like "*github.com/*/blob/*"){$u -replace "github.com","raw.githubusercontent.com" -replace "/blob/","/"}else{$u}; $f=Join-Path $p (Split-Path $r.Split('?')[0] -Leaf); Invoke-WebRequest -Uri $r -OutFile $f -UseBasicParsing; Unblock-File -LiteralPath $f; if($a){Invoke-Expression "& `"$f`" $a"}else{& $f} }
```

---

## ⚙️ How to Pass Parameters to the Target Script

Parameters are defined in the `$ScriptArgs` variable (in the readable script block) or `$a` (in the one-liner command).

The following table demonstrates common argument scenarios using [`Sync-SharePointLibrary.ps1`](https://github.com/romanpindela/Microsoft-365/blob/main/SharePoint/Sync-SharePointLibrary/Sync-SharePointLibrary.ps1):

| Scenario | `$ScriptArgs` Value | Description |
| :--- | :--- | :--- |
| **No parameters** | `""` | Standard script execution without additional flags. |
| **Site discovery (AutoDiscover)** | `"-AutoDiscover"` | Discovers accessible SharePoint sites and presents an interactive numbered menu. |
| **Silent tenant-wide sync** | `"-AutoDiscover -All"` | Discovers and immediately synchronizes all accessible sites without prompting. |
| **Specific site collection** | `"-SiteName 'automatyka'"` | Synchronizes the default document library ("Documents" / "Dokumenty") from the specified site. |
| **Specific site and library title** | `"-SiteName 'management' -DocumentLibraryTitle 'Confidential'"` | Synchronizes a specific document library display title from the target site. |
| **Force re-registration** | `"-AutoDiscover -Force"` | Forces re-sync registration even if the library is already detected locally. |

---

## 🔧 Code Breakdown & Architecture

1. **Administrator Privileges Verification:**
   ```powershell
   $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
   $principal = New-Object Security.Principal.WindowsPrincipal($identity)
   $adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
   $principal.IsInRole($adminSid)
   ```
   *Why this approach:* Using the Well-Known SID `S-1-5-32-544` ensures 100% reliability across all Windows localized editions (e.g., Polish `Administratorzy`, English `Administrators`, German `Administratoren`).

2. **Unlocking Execution Policy:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   ```
   *Why this approach:* The default Windows PowerShell execution policy is often `Restricted`. Adjusting the appropriate scope allows the script to run cleanly without interactive confirmation prompts (`-Force`).

3. **Destination Directory Creation (`C:\PowerShell`):**
   ```powershell
   if (-not (Test-Path -LiteralPath $DestinationPath)) {
       New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
   }
   ```
   *Why this approach:* Storing scripts in `C:\PowerShell` avoids cluttering user profiles or temporary directories, and `-Force` prevents errors if the folder already exists.

4. **URL Conversion & TLS 1.2 Enforcement:**
   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   if ($UrlToDownload -like "*github.com/*/blob/*") {
       $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
   }
   ```
   *Why this approach:* Windows PowerShell 5.1 defaults to legacy SSL3/TLS 1.0 protocols, which GitHub rejects. Forcing TLS 1.2 is mandatory. Automatic URL conversion lets you paste regular browser GitHub URLs directly without needing to locate the "Raw" link manually.

5. **File Download:**
   ```powershell
   Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing
   ```
   *Why this approach:* The `-UseBasicParsing` parameter prevents errors on Windows Server Core and systems where Internet Explorer first-launch configuration was never completed.

6. **Unblocking File (`Unblock-File`):**
   ```powershell
   Unblock-File -LiteralPath $destinationFile
   ```
   *Why this approach:* Files downloaded from the Internet are flagged with the NTFS `Zone.Identifier` stream (Mark of the Web), which can block execution even under `RemoteSigned`. This command immediately clears the restriction.

7. **Script Execution (with Optional Parameters):**
   ```powershell
   if ([string]::IsNullOrWhiteSpace($ScriptArgs)) {
       & $destinationFile
   } else {
       Invoke-Expression "& `"$destinationFile`" $ScriptArgs"
   }
   ```
   *Why this approach:* When `$ScriptArgs` is empty, the script is directly executed via the call operator `&`. When parameters are passed (such as switches `-AutoDiscover` or string arguments), `Invoke-Expression` dynamically binds arguments in PowerShell exactly as if typed into the console.

---

## 💻 Technical Requirements

* **Operating System:** Windows 10, Windows 11, Windows Server 2016 / 2019 / 2022 / 2025+
* **PowerShell Version:** Windows PowerShell 5.1 or PowerShell 7+
* **Privileges:** Elevated console session (**Run as Administrator**)
* **Network Connectivity:** HTTPS access to `github.com` and `raw.githubusercontent.com` (port 443)

---

## 👤 Author

* **Roman Pindela**
* **Email:** `roman.pindela@gmail.com`
* **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **Related Repositories:**
  - [Windows-Desktop](https://github.com/romanpindela/Windows-Desktop)
  - [Microsoft-365](https://github.com/romanpindela/Microsoft-365)