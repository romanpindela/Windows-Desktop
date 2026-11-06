# Replace-TextInFiles Utility

A high-performance, robust, and production-ready PowerShell utility for bulk search-and-replace operations in text files across directories and projects.

[![PowerShell Compatibility](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.0%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%28Desktop%20%2F%20Server%29-lightgrey.svg)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Key Features

* **Non-Destructive & In-Memory Pipeline:** Prevents file locking and data loss typical of `(Get-Content) | Set-Content` by reading files with `-Raw`, verifying modifications in memory, and writing to a temporary file before atomic replacement.
* **Dual-PowerShell Compatibility:** Seamless execution under both **Windows PowerShell 5.1** and **PowerShell 7+**.
* **Safety First (`-WhatIf` & `-Confirm`):** Full native support for `SupportsShouldProcess` allowing dry-run simulations before applying changes.
* **Preserves Encodings, Diacritics & Line Endings:** Full support for `utf8` (PS7 BOM-less, PS5.1 BOM), `utf8NoBOM`, `ascii`, and `unicode`. Maintains `CRLF` and `LF` line endings and Polish/international diacritics.
* **Smart Modification Tracking:** Files are modified only if matching strings or patterns are detected, keeping file timestamps intact on untouched files.
* **Optional Automatic Backups:** Automatically generates `.bak` copies before overwriting any file when `-CreateBackup` is enabled.
* **Structured Audit Logging:** Writes detailed timestamped audit logs to `C:\Logs` with `[INFO]`, `[WARN]`, `[ERROR]`, and `[ACTION]` entries when `-EnableLogging` is specified.
* **Directory Exclusion:** Safely ignores dependency and VCS folders like `.git`, `.vs`, and `node_modules` by default.

---

## Technical Prerequisites

* **Operating System:** Windows 10, Windows 11, Windows Server 2016+
* **PowerShell Version:** Windows PowerShell 5.1 or PowerShell 7+
* **Privileges:** Standard user session (Run as Administrator required only when targeting protected directories).

---

## Parameters

| Parameter | Type | Required | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-Path` | `string` | **Yes** | — | Target directory path to scan. (Aliases: `-Folder`, `-Directory`) |
| `-FindText` | `string` | **Yes** | — | Literal string or Regular Expression pattern to search for. |
| `-ReplaceWith` | `string` | No | `""` | Replacement text (empty string removes matches). |
| `-Filter` | `string` | No | `*.*` | File mask filter (e.g. `*.md`, `*.config`). |
| `-Recurse` | `switch` | No | `$false` | Recursively processes subdirectories. |
| `-UseRegex` | `switch` | No | `$false` | Treats `-FindText` as a Regular Expression pattern. |
| `-CaseSensitive` | `switch` | No | `$false` | Performs case-sensitive matching. |
| `-ExcludeDirectories`| `string[]` | No | `@('.git', '.vs', 'node_modules')` | List of folder names to exclude from processing. |
| `-Encoding` | `string` | No | `'utf8'` | File encoding (`utf8`, `utf8NoBOM`, `ascii`, `unicode`). |
| `-CreateBackup` | `switch` | No | `$false` | Creates a `.bak` backup before modifying files. |
| `-EnableLogging` | `switch` | No | `$false` | Writes execution logs to `C:\Logs\`. |
| `-Help` | `switch` | No | `$false` | Displays interactive help guide (Aliases: `-h`, `-HelpMe`). |

---

## Usage Guide & Practical Examples

### 1. Interactive Help Menu
```powershell
.\Replace-TextInFiles.ps1 -Help
# or
.\Replace-TextInFiles.ps1 -h
```

### 2. Remove Tag from Markdown Files (Recursive)
```powershell
.\Replace-TextInFiles.ps1 -Path ".\Docs" -Filter "*.md" -FindText "#stary-tag" -ReplaceWith "" -Recurse
```

### 3. Dry-Run Simulation with Regular Expressions (`-WhatIf`)
```powershell
.\Replace-TextInFiles.ps1 -Path "C:\Projekty" -Filter "*.json" -FindText 'v\d+\.\d+\.\d+' -ReplaceWith 'v2.0.0' -UseRegex -WhatIf
```

### 4. Safe Production Update with Backups and Logging
```powershell
.\Replace-TextInFiles.ps1 -Path "D:\Configs" -Filter "*.config" -FindText "Server=old-db" -ReplaceWith "Server=new-db" -CreateBackup -EnableLogging
```

---

## 📸 Screenshots & Visual Verification

### 1. Standard Run & Interactive Help Menu (`.\Replace-TextInFiles.ps1 -Help`)
![Standard Run & Interactive Help Menu](assets/Standard_run.jpg)

### 2. Search & Replace Execution Results
![Search & Replace Execution Results](assets/Replace_results.jpg)

---

## Pipeline Output

The script returns a `[PSCustomObject]` summary to the PowerShell pipeline:

```powershell
Path          : C:\Projekty\Docs
FilesScanned  : 24
FilesModified : 5
FilesFailed   : 0
Duration      : 00:00:01.234
Mode          : Execute
```
