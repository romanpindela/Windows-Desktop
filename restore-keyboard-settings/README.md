# Windows 11 Keyboard Customizer & Fixer

A PowerShell script designed for Windows 11 (optimized for laptops/notebooks) that automatically repairs, resets, and configures default keyboard settings—specifically optimized for the **Polish (Programmers)** layout.

## 🚀 Features

* **Enforces Polish (Programmers) Layout:** Sets `pl-PL` with the programmers' layout as the primary input method and cleans up accidental language profiles (fixing the notorious inverted `Y` and `Z` issue).
* **Completely Disables Sticky Keys:** Disables the feature via the Windows Registry and **blocks the 5x SHIFT shortcut**, preventing accidental activation during gaming or fast typing.
* **Disables Filter Keys & Toggle Keys:** Resolves issues with ignored fast keystrokes and annoying system beeps when pressing toggle keys (like Caps Lock).
* **Resets Keyboard Delay & Repeat Rate:** Restores factory-default, optimal responsiveness when holding down keys.

## 🛠 How to Use

1. Download the `FixKeyboardSettings.ps1` file to your computer.
2. Open the Start Menu, search for **PowerShell**, right-click it, and select **"Run as administrator"**.
3. (Optional) If your system blocks script execution, run the following command in the console and press `A` to confirm:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope Process