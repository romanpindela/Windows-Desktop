# Spooler Restart

**Version:** 1.2.0

Windows Print Spooler recovery utility for clearing stuck print jobs and restarting the Print Spooler service.

---

## Overview

Spooler Restart is a lightweight PowerShell utility designed to quickly recover Windows printing services when print jobs become stuck in the queue.

The script automatically:

1. Stops the Print Spooler service
2. Removes all pending print jobs
3. Restarts the Print Spooler service
4. Checks for paused printers and automatically attempts to resume them
5. Prompts for UAC elevation if not run as Administrator

---

## Features

* Clears stuck print jobs
* Restarts the Print Spooler service
* Automatically detects and resumes paused printers via WMI/CIM
* Multi-language OS support (language-agnostic Administrator privilege validation)
* Automatic UAC elevation prompt
* Built-in help system
* Error handling
* Lightweight and portable

Skip automatic resuming of paused printers:

```powershell
.\spooler-restart.ps1 -SkipPrinterResume
```


## Download and Usage

A compiled standalone executable (`.exe`) is available for download, so you do not need to run the raw scripts manually.

### Instructions

1. **Download** the compiled `.exe` file from this repository.
2. **Run as Administrator:** Right-click the `.exe` file and select **"Run as administrator"**. This step is required for the application to apply the necessary system changes.
3. Once successfully executed, the tool will grant you access to printing functionality in Windows.

> **Note for developers:** The tools and files used to compile this executable from the original script are located in the `dev/convert-ps2exe` directory.

---



## Requirements

* Windows PowerShell 5.1 or PowerShell 7+
* Local Administrator privileges (script automatically prompts for elevation)
* Windows Print Spooler service installed

### Resume Paused Printers (Default)

```powershell
Invoke-CimMethod -InputObject $CimPrinter -MethodName Resume
```

---

## Usage

Run the script (will automatically prompt for Administrator privileges if needed):

```powershell
.\spooler-restart.ps1
```

Display help:

```powershell
.\spooler-restart.ps1 -Help
```

or

```powershell
.\spooler-restart.ps1 -H
```

Display native PowerShell help:

```powershell
Get-Help .\spooler-restart.ps1 -Full
```

---

## How It Works

The script performs the following operations:

### Stop Print Spooler

```powershell
Stop-Service Spooler -Force
```

### Clear Print Queue

```powershell
Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
```

### Start Print Spooler

```powershell
Start-Service Spooler
```

---

## Example Output

```text
Spooler-Restart v1.2.0

Stopping Print Spooler service...
Removing pending print jobs...
Starting Print Spooler service...

Print Spooler successfully restarted.

Checking printer statuses...
--- Printer Status List ---
  > Brother DCP-L2550DN series - Status: Normal
  > KONICA MINOLTA C224e Pracownia - Status: Paused

Attempting to resume paused printers...
  [OK] Resumed: KONICA MINOLTA C224e Pracownia
```

---

## Version History

### v1.2.0

* Added automatic UAC elevation request using language-independent SID
* Removed redundant manual admin check code

### v1.0.0

* Initial public release
* Print Spooler restart functionality
* Automatic print queue cleanup
* Administrator privilege validation
* Help system (-Help, -H)
* Native PowerShell help integration
* Error handling

---

## Author

### Roman Pindela

Systems Administrator | Automation Engineer | PowerShell Developer

Email: [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)

GitHub: https://github.com/romanpindela

For questions, suggestions, feature requests, or contributions, please open an issue on GitHub or contact the author directly.

---

## License

MIT License

Copyright (c) 2025 Roman Pindela

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.
