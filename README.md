# Windows-Desktop Automation & Management

A collection of professional PowerShell scripts designed to automate routine tasks, optimize system performance, and facilitate efficient remote management across **Windows 10** and **Windows 11** Desktop environments.

These tools are built to help IT Administrators and power users streamline daily operations, maintain system health, and enforce configurations without manual intervention.

## 🚀 Key Features

* **Task Automation:** Automates repetitive administrative and maintenance tasks to save time and reduce human error.
* **Remote Management:** Scripts tailored for seamless execution via WinRM, PSSession, or deployment tools.
* **System Optimization:** Utilities for auditing, tweaking, and maintaining Windows 10/11 desktops.
* **Admin-Friendly:** Clean, commented, and modular PowerShell code ready for integration into corporate environments or helpdesk workflows.

## 🛠️ Prerequisites

* **OS:** Windows 10 / Windows 11
* **PowerShell:** 5.1+ (PowerShell 7+ recommended for modern features)
* **Execution Policy:** Must be set to allow script execution (e.g., `RemoteSigned` or `Bypass` for specific sessions).
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```

## 📦 Getting Started

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/romanpindela/Windows-Desktop.git](https://github.com/romanpindela/Windows-Desktop.git)
