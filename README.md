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
   git clone https://github.com/romanpindela/Windows-Desktop.git
   cd Windows-Desktop
   ```

2. **Unblock downloaded scripts:**
   ```powershell
   Unblock-File -Path .\Add-NetworkPrinter\Add-NetworkPrinter.ps1
   ```

---

## 🖨️ Featured Scripts & Tools

### [Add-NetworkPrinter](Add-NetworkPrinter/README.md)
* **Script:** [`Add-NetworkPrinter.ps1`](Add-NetworkPrinter/Add-NetworkPrinter.ps1)
* **Author:** Roman Pindela (`roman.pindela@gmail.com`)
* **Description:** Enterprise-grade automation script for deploying network TCP/IP printers in local area networks (LAN).
  * **Network Diagnostics:** Automatically verifies Print Spooler service, performs ICMP Ping and RAW TCP port 9100 availability tests.
  * **Driver Flexibility:** Supports installing via pre-existing system drivers (e.g. `KONICA MINOLTA Universal PCL`), local `.inf` files/directories, or downloading driver archives (.zip / .inf) directly over HTTPS.
  * **Reliable Setup:** Idempotently creates TCP/IP ports and printer queues with optional automated test page printing (`-PrintTestPage`).
  * **Standards Compliant:** Interactive console help on zero parameters (`-h`), language-independent UAC auto-elevation (supports English and Polish Windows), and strict input sanitization.
* **Quick Example:**
  ```powershell
  # Deploy network printer using system driver (e.g., Konica Minolta C224e at 10.10.1.71)
  .\Add-NetworkPrinter\Add-NetworkPrinter.ps1 -PrinterIP "10.10.1.71" -PrinterName "Konica Minolta C224e"
  ```
