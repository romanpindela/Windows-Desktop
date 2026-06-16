# Show-Alert

## Description
The `show-alert.ps1` script displays a graphical message (popup window) with custom text and a red background on a dimmed screen that blocks access to the desktop. It uses native Windows Forms and DWM API for proper window styling (e.g., forcing a red title bar in Windows 10/11 systems).

## Features
- Automatically spawns a pop-up window in the center of the screen.
- Parameterization of the message content (`-Message`) and header (`-Title`).
- Maximization/minimization or resizing is blocked for security reasons.
- Complete block of system shortcuts: `Alt+Tab`, `Alt+F4`, `Ctrl+Esc`, Windows Key, and `F1` via global keyboard capturing (*Low-Level Keyboard Hook*).
- Dimmed background with click blocking on all other applications (requires using the provided *Close* button).
> **Note:** The `Ctrl+Alt+Del` and `Win+L` combinations are hardware and system protected by the Windows architecture (*Secure Attention Sequence*) to protect against ransomware. They cannot be blocked by user-level applications.

## Usage
The script can be run without parameters (displays the default message) or with custom options:

```powershell
# Default message
.\show-alert.ps1

# Custom message
.\show-alert.ps1 -Message "Critical server error. Please contact the IT administrator." -Title "CRITICAL ERROR"

# Display help
.\show-alert.ps1 -h
```

## Autor
**Roman Pindela**
- Email: roman.pindela@gmail.com
- GitHub: romanpindela
- Wersja: 1.0.0

## Execution View

### Standard Run
![Standard Run](assets/screenshot-standard-run.jpg)

### Help Output (-Help)
![Help Output](assets/screenshot-help.jpg)
