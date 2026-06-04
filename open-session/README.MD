# Open Session

**Version:** 1.0.0

Interactive PowerShell Remoting utility for connecting to remote Windows computers using PowerShell Remoting (WinRM).

---

## Overview

Open Session simplifies establishing interactive PowerShell remoting sessions by prompting for credentials and connecting directly to a specified remote computer.

The script supports both hostnames and IP addresses and includes a built-in help system.

---

## Features

* Interactive PowerShell Remoting session
* Secure credential prompt
* Hostname and IP address support
* Built-in help system
* Version information
* Lightweight and portable

---

## Requirements

* Windows PowerShell 5.1 or PowerShell 7+
* PowerShell Remoting (WinRM) enabled on the target computer
* Network connectivity to the target host
* Appropriate permissions on the remote system

---

## Installation

Clone the repository:

```powershell
git clone https://github.com/romanpindela/open-session.git
```

Navigate to the project directory:

```powershell
cd open-session
```

---

## Usage

```powershell
.\open-session.ps1 <ComputerName>
```

---

## Examples

Connect using hostname:

```powershell
.\open-session.ps1 SERVER01
```

Connect using IP address:

```powershell
.\open-session.ps1 10.10.1.4
```

Display help:

```powershell
.\open-session.ps1 -Help
```

or

```powershell
.\open-session.ps1 -H
```

Display PowerShell native help:

```powershell
Get-Help .\open-session.ps1 -Full
```

---

## How It Works

1. Prompts the user for credentials.
2. Establishes a PowerShell Remoting connection.
3. Opens an interactive remote session.
4. The session remains active until:

```powershell
Exit-PSSession
```

is executed.

---

## Troubleshooting

### Verify WinRM

```powershell
Test-WSMan SERVER01
```

### Enable PowerShell Remoting

```powershell
Enable-PSRemoting -Force
```

### View TrustedHosts

```powershell
Get-Item WSMan:\localhost\Client\TrustedHosts
```

### Add a Trusted Host

```powershell
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "10.10.1.4" -Force
```

---

## Version History

### v1.0.0

* Initial public release
* Interactive PowerShell Remoting support
* Credential prompt
* Help system (`-Help`, `-H`)
* Native PowerShell help integration
* Error handling
* Version information

---

## Author

### Roman Pindela

Systems Administrator | Automation Engineer | PowerShell Developer

📧 Email: [roman.pindela@gmail.com](mailto:roman.pindela@gmail.com)

🐙 GitHub: https://github.com/romanpindela

For questions, suggestions, or contributions, please open an issue or contact the author directly.

---

## License

MIT License

Copyright (c) 2025 Roman Pindela

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.
