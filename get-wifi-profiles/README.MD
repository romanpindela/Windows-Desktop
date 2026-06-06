# get-wifi-profiles

Displays saved Wi-Fi profiles, passwords, security settings and active network configuration.

## Features

- Lists all saved Wi-Fi profiles
- Shows stored Wi-Fi passwords
- Displays Wi-Fi authentication/security type
- Shows active IPv4 configuration
- Displays:
  - IPv4 address
  - Prefix length
  - Default gateway
  - DNS servers
- Built-in help system
- Clean Code compliant
- No hardcoded environment-specific values

## Requirements

- Windows 10 / Windows 11
- PowerShell 5.1+
- Administrator privileges recommended

## Usage

Display help:

```powershell
.\get-wifi-profiles.ps1 -Help
```

or

```powershell
.\get-wifi-profiles.ps1 -h
```

Run scan:

```powershell
.\get-wifi-profiles.ps1
```

## Example Output

| SSID | Password | Security | IPv4 | Prefix | Gateway |
|--------|--------|--------|--------|--------|--------|
| HomeWiFi | Secret123 | WPA2-Personal | 192.168.1.100 | /24 | 192.168.1.1 |

## Security Notes

The script only reads information already stored on the local Windows machine.

No credentials are transmitted outside the computer.

## Version

1.0.0

## Author

**Roman Pindela**

Email: roman.pindela@gmail.com

GitHub:
https://github.com/romanpindela