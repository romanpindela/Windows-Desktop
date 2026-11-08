# TASK SPECIFICATION: Audit-LocalAdministrators

## 1. PROJECT CONTEXT & REPOSITORY SCAFFOLDING
- **Repository Root:** `c:\Dane\rpindela\GitHub\Windows-Desktop\`
- **Target Directory:** `c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-LocalAdministrators\`
- **Assets Directory:** `c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-LocalAdministrators\assets\`
- **Main Script File:** `Audit-LocalAdministrators.ps1` (Encoding: UTF-8 with BOM)
- **Documentation:** `README.md` (Encoding: UTF-8)
- **Specification Output:** `SPECIFICATION-Audit-LocalAdministrators.md`

### Directory Creation Snippet
```powershell
$targetPath = "c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-LocalAdministrators"
$assetsPath = Join-Path -Path $targetPath -ChildPath "assets"
if (-not (Test-Path -Path $assetsPath)) {
    New-Item -Path $assetsPath -ItemType Directory -Force | Out-Null
}
```

---

## 2. METADATA & VERSION CONTROL
- **Author:** Roman Pindela
- **Email:** roman.pindela@gmail.com
- **GitHub:** https://github.com/romanpindela
- **Initial Version:** 1.0.0 (SemVer)
- **Date:** 2026-11-08
- **Language / Encoding:** English strictly for all code, comments, log output, help screens, and README. PowerShell script saved with UTF-8 BOM.

---

## 3. BUSINESS LOGIC & ENHANCED REQUIREMENTS

### Core Purpose
Audit all members of the local Administrators security group (`S-1-5-32-544`) on Windows 10/11 endpoints. Enumerate local accounts, domain accounts, and Entra ID (Azure AD) joins/roles. Classify accounts, detect security anomalies, output structured console data, record detailed execution logs to `C:\Logs\`, and optionally generate a self-contained, responsive HTML audit report.

### Key Functional Requirements

1. **Language-Independent SID Resolution:**
   - Resolve the local Administrators group strictly via Well-Known SID: `S-1-5-32-544` (never hardcode localized names like `"Administratorzy"` or `"Administrators"`).
   - Resolve member account SIDs, distinguishing between:
     - Well-Known Local Administrator (`S-1-5-21-*-500`)
     - Local Standard User accounts elevated to Admin
     - Active Directory Domain Users / Groups
     - Entra ID (Azure AD) SIDs (e.g., `S-1-12-1-*` representing Azure AD Joined Device Local Administrator role / Global Admin)

2. **Account Status & Risk Classification:**
   - Retrieve account enablement status (`Enabled` vs `Disabled`), password last set, and last logon timestamp (via WMI/CIM/ADSI or `Get-LocalUser` with fallback to native Win32 APIs).
   - Detect security anomalies:
     - Unresolved/Orphaned SIDs (deleted accounts lingering in the local Administrators group).
     - Active built-in Administrator (`RID 500`) without proper management/LAPS.
     - Unexpected domain security groups or generic accounts.

3. **Execution Logging (`C:\Logs\`):**
   - Verify presence of `C:\Logs\`, create if missing.
   - Format log file name: `C:\Logs\<yyyyMMdd-HHmmss>-Audit-LocalAdministrators-<COMPUTERNAME>-<USERNAME>.log`
   - Log format: `[yyyy-MM-dd HH:mm:ss.fff] [<LEVEL>] <Message>` (Levels: `INFO`, `VERBOSE`, `WARN`, `ERROR`, `DEBUG`).

4. **Standalone HTML Report Generation:**
   - Parameter `-GenerateHtmlReport` (or `-ReportPath <string>`). Default path if flag passed without path: `C:\Logs\<yyyyMMdd-HHmmss>-Audit-LocalAdministrators-<COMPUTERNAME>.html`.
   - Standalone: Zero external CDN dependencies (no remote bootstrap/fonts). Completely inline modern CSS.
   - Design: Apple-inspired modern dark/light mode responsive card layout with summary badge widgets (Total Admins, Local Accounts, Domain Accounts, Orphaned SIDs, Risk Level) and a sortable/filterable HTML table.

5. **UAC Elevation:**
   - Enforce Administrator privileges on startup. If not elevated, restart elevated process preserving parameters via `Start-Process powershell.exe -Verb RunAs ...`.

6. **Execution Modes & Safety:**
   - Support `[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]`.
   - Provide `-Help` / `-h` alias, and auto-invoke `Show-ScriptHelp` if executed without arguments.

---

## 4. ARCHITECTURE & CODING STANDARDS

### Clean Code Constraints
- `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`.
- Zero `PSScriptAnalyzer` errors/warnings (rules: `PSAvoidUsingWriteHost` handled via allowed console interaction wrappers or `Write-Information`, `PSUseApprovedVerbs`, proper parameter validation).
- Dedicated sections: `begin {}`, `process {}`, and `end {}`.
- Return clean structured objects `[PSCustomObject]` to the PowerShell pipeline to allow chaining with `Export-Csv`, `Out-GridView`, or downstream automation.

### Parameters Specification

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `-GenerateHtmlReport` | `[switch]` | No | `$false` | Generates a standalone, styled HTML report. |
| `-ReportPath` | `[string]` | No | `C:\Logs\...` | Custom target directory or file path for the HTML report. |
| `-ExportCsv` | `[switch]` | No | `$false` | Exports raw pipeline objects to a CSV file in `C:\Logs\`. |
| `-CsvPath` | `[string]` | No | `C:\Logs\...` | Custom target file path for CSV export. |
| `-LogDirectory` | `[string]` | No | `C:\Logs` | Target directory for execution logs. |
| `-IncludeDisabled` | `[switch]` | No | `$true` | Include disabled administrator accounts in the output. |
| `-Help`, `-h` | `[switch]` | No | `$false` | Displays visual CLI help and exits. |

---

## 5. DOCUMENTATION SPECIFICATION (`README.md`)

Must include:
- Status badges (PowerShell 5.1/7+, License, PSScriptAnalyzer Clean).
- Architecture diagram (Mermaid flow showing UAC check -> SID resolution -> Member enumeration -> Anomaly detection -> Log / HTML export).
- Prerequisites and execution policy unblock command.
- Example CLI invocations (interactive, automated logging, HTML export).
- Table of exported fields and anomaly definitions.

---

## 6. ROOT REPOSITORY INDEXING

Ensure the root `c:\Dane\rpindela\GitHub\Windows-Desktop\README.md` is updated with an entry under the Desktop Auditing & Security section:

```markdown
| [Audit-LocalAdministrators](./Audit-LocalAdministrators) | Audits members of the local Administrators group (SID S-1-5-32-544), detects orphaned SIDs, logs to C:\Logs, and generates standalone HTML reports. | PowerShell 5.1 / 7+ |
```

---

## 7. EXECUTION DIRECTIVE FOR ANTIGRAVITY

Generate the entire production script `Audit-LocalAdministrators.ps1` and `README.md` with zero omissions, placeholders, or `TODO` comments. Ensure all CSS for the HTML report is fully embedded inline and test all regex patterns for Entra ID / Well-Known SIDs.
