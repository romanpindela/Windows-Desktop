# Restore-KeyboardSettings

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg?logo=powershell)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows)](https://www.microsoft.com/windows)

## Problem Statement

Windows users frequently encounter disrupted typing behavior when accidentally triggering accessibility shortcuts (Sticky Keys via 5x Shift, Filter Keys, or Toggle Keys) or losing the **Polish (Programmers)** keyboard layout (`0415:00000415`), resulting in missing diacritics, unintended `Ctrl+Shift` layout switching, or sluggish key repeat rates. Users need a quick per-user reset script to restore standard typing defaults immediately.

## Overview

`Restore-KeyboardSettings.ps1` sets the active user language list to Polish (Programmers) (`pl-PL` with `0415:00000415`), disables Sticky Keys (`Flags=506`), Filter Keys (`Flags=122`), and Toggle Keys (`Flags=58`) under `HKCU:\Control Panel\Accessibility`, restores standard repeat delay (`KeyboardDelay=1`) and speed (`KeyboardSpeed=31`) under `HKCU:\Control Panel\Desktop`, and restarts `explorer.exe` to apply shell changes.

## Environment & Prerequisites

- **OS:** Windows 10 / Windows 11
- **PowerShell:** Windows PowerShell 5.1 or PowerShell 7.x+
- **Modules / Dependencies:** Built-in `International` module (`New-WinUserLanguageList`, `Set-WinUserLanguageList`); no third-party modules required.

## Permissions Required

**User** — All modifications target the current user's profile (`HKCU:` registry keys, per-user language list, and the user's `explorer.exe` shell process), so administrative elevation is not required.

## Safety & Impact

- **Risk Level:** `Modifies system state` (current user profile) — Overwrites `Set-WinUserLanguageList -Force` (replacing other configured input languages with Polish Programmers only), updates `HKCU:` keyboard accessibility/repeat registry values, and forcefully restarts `explorer.exe` (`Stop-Process -Name explorer -Force`, which briefly closes Explorer windows and taskbar).
- **WhatIf / Confirm & Backup:** Does not support `-WhatIf` / `-Confirm` and creates no backups prior to replacing user language list or registry settings.

## Usage Examples

```powershell
# Display script synopsis and description via PowerShell Get-Help
Get-Help .\Restore-KeyboardSettings.ps1 -Full

# Reset current user keyboard layout to Polish (Programmers), disable accessibility shortcuts, and refresh Explorer
.\Restore-KeyboardSettings.ps1
```

## Author

- **Roman Pindela**
