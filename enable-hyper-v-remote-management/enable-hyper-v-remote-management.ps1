<#
================================================================================
  Script Name : enable-hyper-v-remote-management.ps1
  Author      : Roman Pindela
  Contact     : roman.pindela@gmail.com
  Version     : 1.2.0
  Release Date: 2026-10-18
  License     : MIT
  Repository  : https://github.com/romanpindela

  DESCRIPTION:
    Enterprise-grade PowerShell automation tool that configures a Windows 10,
    Windows 11, or Windows Server workstation (Client mode) or Hyper-V host
    (Server mode) for seamless remote management via Hyper-V Manager
    (virtmgmt.msc) and PowerShell Direct/Remoting in a Workgroup or LAN
    environment (English and Polish Windows editions).

    Key Capabilities:
    1. Zero-Parameter Interactive Help (-Help / -h):
       Displays complete syntax, parameter documentation, usage examples,
       version, and author details when launched without arguments—without
       triggering an unnecessary UAC prompt.
    2. Complete Workgroup Hyper-V Client Configuration (-ServerName / -ServerIP):
       Addresses the two primary barriers to Hyper-V Manager connectivity in
       Workgroup / non-domain environments:
       - Name Resolution (hosts file): Hyper-V Manager cannot connect via a raw
         IP address in Workgroup mode; it requires a resolvable hostname
         (NetBIOS/FQDN). The script safely backs up and updates
         C:\Windows\System32\drivers\etc\hosts with '<ServerIP> <ServerName>'
         and verifies resolution & connectivity via Test-Connection.
       - WinRM TrustedHosts & CredSSP Delegation: Starts and configures the
         WinRM service, appends '<ServerName>' to WSMan TrustedHosts, and
         enables the CredSSP Client role with credential delegation
         (Enable-WSManCredSSP -Role Client -DelegateComputer <ServerName>).
       - Local Group Policy (NTLM-Only Fresh Credentials Delegation):
         Automatically configures the Group Policy registry settings under
         HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation
         ('Allow delegating fresh credentials with NTLM-only server
         authentication' -> 'wsman/<ServerName>') and executes gpupdate /force.
       - Optional Hyper-V Client Tools Provisioning (-InstallManagementTools):
         Checks and optionally enables 'Microsoft-Hyper-V-Management-Clients'
         (virtmgmt.msc) and 'Microsoft-Hyper-V-Management-PowerShell'.
    3. Optional Hyper-V Server-Side Configuration (-Role Server):
       Can also be executed directly on the target Hyper-V Server to enable
       PSRemoting, CredSSP Server role, Server Manager remoting, and language-
       independent Windows Firewall rules for WMI/DCOM, WinRM, and Hyper-V
       Management Clients.
    4. Detailed Step-by-Step Telemetry, Execution Summary & End-User Guide:
       Displays granular progress for every stage of execution and concludes
       with a structured summary report, server-side prerequisite checklist,
       and step-by-step instructions for connecting in Hyper-V Manager.
    5. Input Sanitization & Defensive Validation:
       Protects against command injection, path traversal, and malformed IPv4
       addresses or hostnames.
    6. Language-Independent UAC Auto-Elevation:
       Verifies Administrator privileges using the well-known Windows SID
       (S-1-5-32-544 / BuiltInAdministratorsSid) for 100% compatibility across
       Polish ("Administratorzy") and English ("Administrators") Windows systems,
       and automatically elevates via UAC while preserving all CLI parameters.
    7. Detailed Audit Logging:
       Logs all operations with UTF-8 timestamps to:
       C:\Logs\<yyyyMMdd_HHmmss>-enable-hyper-v-remote-management-<ComputerName>-<UserName>.logs
================================================================================
.SYNOPSIS
    Configures a Windows client workstation (or server) for remote Hyper-V
    Manager connectivity in a Workgroup or LAN environment.

.DESCRIPTION
    Automates the complete client-side (and optional server-side) configuration
    required to connect to a remote Hyper-V host using Hyper-V Manager
    (virtmgmt.msc) without Active Directory:
    - Running without parameters or with -Help / -h displays full help, examples,
      version, and author information.
    - Running with -ServerName (and -ServerIP) updates the local hosts file for
      name resolution, verifies connectivity via Test-Connection, configures
      WinRM TrustedHosts, enables CredSSP Client delegation, configures the
      Local Group Policy registry policy 'Allow delegating fresh credentials
      with NTLM-only server authentication' (wsman/<ServerName>), refreshes
      Group Policy (gpupdate /force), and optionally installs Hyper-V Management
      Tools or stores credentials in Windows Credential Manager (cmdkey).
    - Prints detailed progress for every operation, a final execution summary,
      and concise step-by-step connection instructions for the user.

.PARAMETER ServerName
    The NetBIOS hostname or FQDN of the remote Hyper-V server (e.g., 'HV-SRV01').
    Required when configuring a client workstation (-Role Client). Because
    Hyper-V Manager does not allow connecting via raw IP address in Workgroup
    mode, this hostname is mapped in the local hosts file (when -ServerIP is
    provided) and authorized in TrustedHosts, CredSSP, and Group Policy.
    Aliases: -Server, -HostName, -ComputerName, -TargetServer, -s

.PARAMETER ServerIP
    The IPv4 address of the remote Hyper-V server in the LAN/VPN (e.g.,
    '10.10.1.10' or '192.168.1.50'). When provided, the script idempotently maps
    '<ServerIP> <ServerName>' in C:\Windows\System32\drivers\etc\hosts and
    verifies name resolution.
    Aliases: -IP, -IPAddress, -TargetIP, -i

.PARAMETER Role
    Specifies the configuration mode:
      - 'Client' (Default): Configures the local workstation to manage a remote
        Hyper-V server (hosts file, WinRM, TrustedHosts, CredSSP Client, NTLM
        Credential Delegation Group Policy, and optional Hyper-V GUI/PS tools).
      - 'Server': Configures the local machine as a Hyper-V Host ready to accept
        remote connections (Enable-PSRemoting, CredSSP Server role,
        Configure-SMRemoting, and WMI/WinRM/Hyper-V firewall rules).
    Aliases: -Mode

.PARAMETER InstallManagementTools
    Switch parameter. Enables the Windows Optional Features
    'Microsoft-Hyper-V-Management-Clients' (Hyper-V Manager GUI) and
    'Microsoft-Hyper-V-Management-PowerShell' on the client workstation if they
    are not yet enabled.
    Aliases: -EnableHyperVTools, -InstallTools

.PARAMETER SetPrivateNetworkProfile
    Switch parameter. Automatically switches active 'Public' network connection
    profiles to 'Private' so Windows Firewall and WinRM allow remote management
    traffic in a Workgroup LAN.

.PARAMETER IncludeIPInTrustedHosts
    Switch parameter. Also adds the -ServerIP address (in addition to
    -ServerName) to WSMan:\localhost\Client\TrustedHosts and CredSSP delegation.

.PARAMETER ServerUser
    Optional username on the remote Hyper-V server (e.g., 'Administrator' or
    'HV-SRV01\Administrator'). Used in the final connection instructions and
    when storing credentials via -StoreCredentials.
    Default: 'Administrator'
    Aliases: -User, -RemoteUser

.PARAMETER StoreCredentials
    Switch parameter. Prompts securely for the remote server user's password and
    saves the credentials in Windows Credential Manager (cmdkey.exe) for
    '<ServerName>' and 'TERMSRV/<ServerName>' (VMConnect).
    Aliases: -SaveCredentials

.PARAMETER LaunchHyperVManager
    Switch parameter. Launches the Hyper-V Manager GUI console (virtmgmt.msc)
    automatically after configuration finishes.
    Aliases: -OpenGUI, -StartManager

.PARAMETER Status
    Switch parameter. Audits and displays the current Hyper-V Remote Management
    configuration on the machine (hosts file entries, WinRM service,
    TrustedHosts, CredSSP status, NTLM Credential Delegation GPO registry keys,
    firewall rules, and Hyper-V Management Tools state) without modifying the OS.
    Aliases: -Check, -Verify, -Info

.PARAMETER DryRun
    Switch parameter. Simulates all configuration steps without making any
    changes to the operating system.
    Aliases: -Simulate, -Preview

.PARAMETER SkipAdminCheck
    Switch parameter. Skips automatic UAC Administrator privilege elevation check.

.PARAMETER PassThru
    Switch parameter. Returns the structured configuration summary object to the
    PowerShell pipeline.

.PARAMETER LogPath
    Custom file path for the execution log.
    Default: C:\Logs\<yyyyMMdd_HHmmss>-enable-hyper-v-remote-management-<ComputerName>-<UserName>.logs
    Aliases: -l, -Log

.PARAMETER NoLog
    Switch parameter. Disables writing execution logs to disk.

.PARAMETER Help
    Switch parameter (-Help / -h). Displays this help guide, usage examples,
    author details, and version information.
    Aliases: -h

.EXAMPLE
    .\enable-hyper-v-remote-management.ps1
    Displays the help screen, usage syntax, parameter reference, examples,
    version, and author details without requiring UAC elevation.

.EXAMPLE
    .\enable-hyper-v-remote-management.ps1 -ServerName "HV-SRV01" -ServerIP "10.10.1.10"
    Configures the workstation to manage Hyper-V server 'HV-SRV01' (10.10.1.10):
    updates the hosts file, verifies Test-Connection, adds 'HV-SRV01' to WinRM
    TrustedHosts, enables CredSSP Client delegation, configures the Group Policy
    NTLM-only credential delegation registry rule (wsman/HV-SRV01), and runs
    gpupdate /force.

.EXAMPLE
    .\enable-hyper-v-remote-management.ps1 -ServerName "HV-SRV01" -ServerIP "10.10.1.10" -InstallManagementTools -LaunchHyperVManager
    Performs the full client configuration, ensures Hyper-V Manager GUI and
    PowerShell tools are installed, and opens Hyper-V Manager (virtmgmt.msc).

.EXAMPLE
    .\enable-hyper-v-remote-management.ps1 -ServerName "HV-SRV01" -ServerIP "10.10.1.10" -SetPrivateNetworkProfile -IncludeIPInTrustedHosts
    Switches any Public network adapter profile to Private, configures hosts,
    and registers both 'HV-SRV01' and '10.10.1.10' in TrustedHosts and CredSSP.

.EXAMPLE
    .\enable-hyper-v-remote-management.ps1 -Role Server
    Executes the server-side configuration on a Hyper-V host: enables PSRemoting,
    CredSSP Server role, Server Manager Remoting, and WMI/WinRM/Hyper-V firewall
    rules (compatible with Polish and English Windows editions).

.EXAMPLE
    .\enable-hyper-v-remote-management.ps1 -Status
    Displays a complete diagnostic audit of the current Hyper-V remote
    management client/server settings on the local computer.

.EXAMPLE
    .\enable-hyper-v-remote-management.ps1 -ServerName "HV-SRV01" -ServerIP "10.10.1.10" -DryRun
    Simulates all client configuration changes (hosts, WinRM, CredSSP, GPO)
    without modifying the system.

.NOTES
    Author      : Roman Pindela
    Contact     : roman.pindela@gmail.com
    GitHub      : https://github.com/romanpindela
    Version     : 1.2.0
    Compatible  : Windows 10, Windows 11, Windows Server 2016/2019/2022/2025 (EN/PL)
    Privileges  : Requires Administrator privileges (auto-elevates via UAC using SID).
#>

[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("Server", "HostName", "ComputerName", "TargetServer", "s")]
    [string]$ServerName,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [Alias("IP", "IPAddress", "TargetIP", "i")]
    [string]$ServerIP,

    [Parameter(Mandatory = $false)]
    [Alias("Mode")]
    [ValidateSet("Client", "Server", IgnoreCase = $true)]
    [string]$Role = "Client",

    [Parameter(Mandatory = $false)]
    [Alias("EnableHyperVTools", "InstallTools")]
    [switch]$InstallManagementTools,

    [Parameter(Mandatory = $false)]
    [switch]$SetPrivateNetworkProfile,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeIPInTrustedHosts,

    [Parameter(Mandatory = $false)]
    [Alias("User", "RemoteUser")]
    [string]$ServerUser = "Administrator",

    [Parameter(Mandatory = $false)]
    [Alias("SaveCredentials")]
    [switch]$StoreCredentials,

    [Parameter(Mandatory = $false)]
    [Alias("OpenGUI", "StartManager")]
    [switch]$LaunchHyperVManager,

    [Parameter(Mandatory = $false)]
    [Alias("Check", "Verify", "Info")]
    [switch]$Status,

    [Parameter(Mandatory = $false)]
    [Alias("Simulate", "Preview")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [Alias("l", "Log")]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [switch]$NoLog,

    [Parameter(Mandatory = $false)]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ==============================================================================
# SCRIPT METADATA & CONFIGURATION
# ==============================================================================
$SCRIPT_INFO = @{
    Name        = "enable-hyper-v-remote-management"
    FileName    = "enable-hyper-v-remote-management.ps1"
    Version     = "1.2.0"
    Author      = "Roman Pindela"
    Contact     = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    ReleaseDate = "2026-10-18"
    License     = "MIT"
}

$script:ActiveLogFile = $null
$script:StartTime = Get-Date
$HOSTS_FILE_PATH = Join-Path -Path $env:SystemRoot -ChildPath "System32\drivers\etc\hosts"
$GPO_CRED_DELEGATION_PATH = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
$GPO_NTLM_SUBKEY_PATH = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly"
$GPO_FRESH_SUBKEY_PATH = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials"

# ==============================================================================
# LOGGING & CONSOLE OUTPUT FUNCTIONS
# ==============================================================================
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "STEP", "HEADER", "DETAIL")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    $colorMap = @{
        "INFO"    = [ConsoleColor]::White
        "SUCCESS" = [ConsoleColor]::Green
        "WARN"    = [ConsoleColor]::Yellow
        "ERROR"   = [ConsoleColor]::Red
        "STEP"    = [ConsoleColor]::Cyan
        "HEADER"  = [ConsoleColor]::Cyan
        "DETAIL"  = [ConsoleColor]::Gray
    }

    $effectiveColor = if ($PSBoundParameters.ContainsKey("Color")) {
        $Color
    }
    else {
        $colorMap[$Level]
    }

    try { [Console]::CursorLeft = 0 } catch {}
    Write-Host $Message -ForegroundColor $effectiveColor

    if (-not $NoLog -and -not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
        try {
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $cleanMessage = $Message -replace "^\r?\n", ""
            $logEntry = "[$timestamp] [$Level] $cleanMessage`r`n"
            [System.IO.File]::AppendAllText($script:ActiveLogFile, $logEntry, [System.Text.Encoding]::UTF8)
        }
        catch {
            # Never abort execution due to log file lock or write failure
        }
    }
}

function Initialize-LogFile {
    if ($NoLog) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $defaultLogDir = "C:\Logs"
        if (-not (Test-Path -Path $defaultLogDir)) {
            try {
                New-Item -Path $defaultLogDir -ItemType Directory -Force | Out-Null
            }
            catch {
                $defaultLogDir = [System.IO.Path]::GetTempPath()
            }
        }
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $computerName = [System.Environment]::MachineName
        $userName = [System.Environment]::UserName
        $script:ActiveLogFile = Join-Path -Path $defaultLogDir -ChildPath "$timestamp-$($SCRIPT_INFO.Name)-$computerName-$userName.logs"
    }
    else {
        $parentDir = [System.IO.Path]::GetDirectoryName($LogPath)
        if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }
        $script:ActiveLogFile = $LogPath
    }
}

# ==============================================================================
# INPUT SANITIZATION & SECURITY VALIDATION
# ==============================================================================
function Protect-HostNameInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$HostValue,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    if ([string]::IsNullOrWhiteSpace($HostValue)) {
        throw "Validation Error: Parameter '$ParameterName' cannot be empty or whitespace."
    }

    if ($HostValue.Length -gt 253) {
        throw "Validation Error: Parameter '$ParameterName' ('$HostValue') exceeds the maximum hostname length of 253 characters."
    }

    # Block raw IPv4 address passed as ServerName (Hyper-V Manager requires a NetBIOS/FQDN hostname in Workgroup mode)
    $parsedIp = $null
    if ([System.Net.IPAddress]::TryParse($HostValue, [ref]$parsedIp)) {
        throw "Validation Error: Parameter '$ParameterName' ('$HostValue') is an IP address. Hyper-V Manager in Workgroup mode requires a hostname (e.g., -ServerName 'HV-SRV01' -ServerIP '$HostValue')."
    }

    # Allow valid NetBIOS / DNS hostnames (alphanumeric, hyphens, and dots for FQDN)
    if ($HostValue -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$') {
        throw "Security Alert: Parameter '$ParameterName' ('$HostValue') is not a valid NetBIOS or DNS hostname. Only alphanumeric characters, hyphens ('-'), and dots ('.') are permitted."
    }
}

function Protect-IPv4AddressInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IpValue,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    if ([string]::IsNullOrWhiteSpace($IpValue)) {
        throw "Validation Error: Parameter '$ParameterName' cannot be empty or whitespace."
    }

    $parsedIp = $null
    if (-not [System.Net.IPAddress]::TryParse($IpValue.Trim(), [ref]$parsedIp) -or $parsedIp.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Validation Error: Parameter '$ParameterName' ('$IpValue') is not a valid IPv4 address (expected format: e.g., '10.10.1.10')."
    }
}

function Protect-UserNameInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserValue
    )

    if ([string]::IsNullOrWhiteSpace($UserValue) -or $UserValue.Length -gt 104) {
        throw "Validation Error: Invalid ServerUser value '$UserValue'."
    }

    if ($UserValue -match '[`$;&|><*?"/\r\n]') {
        throw "Security Alert: Parameter 'ServerUser' ('$UserValue') contains illegal or potentially dangerous characters."
    }
}

function Protect-FilePathInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw "Validation Error: Parameter '$ParameterName' cannot be empty or whitespace."
    }

    if ($PathValue.Length -gt 260) {
        throw "Validation Error: Parameter '$ParameterName' exceeds maximum path length of 260 characters."
    }

    if ($PathValue -match '[`$;&|><*?"\r\n]') {
        throw "Security Alert: Parameter '$ParameterName' ('$PathValue') contains illegal or potentially dangerous characters."
    }
}

# ==============================================================================
# HELP & DOCUMENTATION DISPLAY
# ==============================================================================
function Show-HelpGuide {
    try { [Console]::CursorLeft = 0 } catch {}
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Author : $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)
  GitHub : $($SCRIPT_INFO.GitHub)
  Date   : $($SCRIPT_INFO.ReleaseDate) | License: $($SCRIPT_INFO.License)
================================================================================
DESCRIPTION:
  Configures a Windows 10, Windows 11, or Windows Server client workstation
  (or target Hyper-V host) for remote management via Hyper-V Manager
  (virtmgmt.msc) in a Workgroup / non-domain LAN or VPN environment.

  Why This Script Is Needed (Workgroup Hyper-V Architecture):
  1. Hyper-V Manager does NOT support connecting directly via a raw IP address
     in Workgroup mode—it strictly requires a resolvable hostname (ComputerName).
  2. Workgroup authentication requires WinRM TrustedHosts, CredSSP Client/Server
     roles, WMI/DCOM firewall rules, and Local Group Policy NTLM-only Fresh
     Credentials Delegation ('wsman/<ServerName>') on the client PC.

  Core Capabilities:
  1. Zero-Parameter Help (-Help / -h): Displays full usage, examples, version,
     and author information when executed without arguments.
  2. Hosts File Name Resolution (-ServerName & -ServerIP): Backs up and updates
     C:\Windows\System32\drivers\etc\hosts with '<ServerIP> <ServerName>',
     flushes DNS cache, and verifies name resolution via Test-Connection.
  3. WinRM & TrustedHosts Configuration: Starts WinRM (Automatic), enables
     PSRemoting, and appends '<ServerName>' to WSMan:\localhost\Client\TrustedHosts.
  4. CredSSP Client & WSMan Delegation: Enables the CredSSP Client role and
     delegates credentials to '<ServerName>' via Enable-WSManCredSSP.
  5. Automated Group Policy (NTLM Credential Delegation): Configures the local
     Group Policy registry keys under:
     HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation
     ('Allow delegating fresh credentials with NTLM-only server authentication'
     -> 'wsman/<ServerName>') and runs 'gpupdate /force'.
  6. Optional Hyper-V Client Tools & Server Mode: Can install Hyper-V Manager
     GUI/PowerShell tools (-InstallManagementTools) or configure the Hyper-V
     Server itself (-Role Server).
  7. Detailed Step-by-Step Progress, Final Summary & Quick User Guide: Shows
     details of every operation and prints step-by-step instructions for
     connecting in Hyper-V Manager.
  8. Multi-Language UAC Auto-Elevation & Audit Logging: Uses Windows SID
     (S-1-5-32-544) for Polish/English Windows compatibility and logs to:
     C:\Logs\<yyyyMMdd_HHmmss>-enable-hyper-v-remote-management-<ComputerName>-<UserName>.logs

SYNTAX:
  # 1. Display Help (Default when run without parameters):
  .\enable-hyper-v-remote-management.ps1 [-Help | -h]

  # 2. Configure Client Workstation for Remote Hyper-V Server (Workgroup / LAN):
  .\enable-hyper-v-remote-management.ps1 -ServerName <Hostname> [-ServerIP <IPv4>]
      [-InstallManagementTools] [-SetPrivateNetworkProfile]
      [-IncludeIPInTrustedHosts] [-StoreCredentials] [-ServerUser <User>]
      [-LaunchHyperVManager] [-DryRun]

  # 3. Configure Hyper-V Server Host (Server-Side Prerequisites):
  .\enable-hyper-v-remote-management.ps1 -Role Server [-SetPrivateNetworkProfile] [-DryRun]

  # 4. Audit Current Hyper-V Remote Management Configuration:
  .\enable-hyper-v-remote-management.ps1 -Status [-ServerName <Hostname>]

PARAMETERS:
  -ServerName <String>        : Hostname (NetBIOS/FQDN) of the remote Hyper-V
                                server (e.g., 'HV-SRV01'). Required in Client
                                mode (Aliases: -Server, -HostName, -s).
  -ServerIP <String>          : IPv4 address of the remote Hyper-V server (e.g.,
                                '10.10.1.10'). Maps '<ServerIP> <ServerName>' in
                                C:\Windows\System32\drivers\etc\hosts
                                (Aliases: -IP, -IPAddress, -i).
  -Role <Client|Server>       : 'Client' (default) configures the workstation;
                                'Server' configures the Hyper-V host itself.
  -InstallManagementTools     : Enables 'Microsoft-Hyper-V-Management-Clients'
                                (virtmgmt.msc) & PowerShell module if missing.
  -SetPrivateNetworkProfile   : Switches Public network profiles to Private so
                                WinRM/CredSSP firewall rules are active.
  -IncludeIPInTrustedHosts    : Also adds -ServerIP to WinRM TrustedHosts and
                                CredSSP delegation list.
  -ServerUser <String>        : Remote administrator username on the Hyper-V
                                server (Default: 'Administrator').
  -StoreCredentials           : Prompts for password and saves credentials in
                                Windows Credential Manager (cmdkey).
  -LaunchHyperVManager        : Opens Hyper-V Manager (virtmgmt.msc) after setup.
  -Status                     : Audits current hosts, WinRM, TrustedHosts,
                                CredSSP, GPO, and firewall configuration.
  -DryRun                     : Simulates all operations without changing the OS.
  -LogPath <String>           : Custom log file path (Default: C:\Logs\...).
  -NoLog                      : Disables writing execution logs to disk.
  -Help / -h                  : Displays this help guide and exits.

PRACTICAL EXAMPLES:
  1. Display help, author, and version info (zero-parameter run):
     .\enable-hyper-v-remote-management.ps1

  2. Configure client PC to connect to Hyper-V server 'HV-SRV01' at 10.10.1.10:
     .\enable-hyper-v-remote-management.ps1 -ServerName "HV-SRV01" -ServerIP "10.10.1.10"

  3. Full client setup + install Hyper-V Manager GUI tools + launch Hyper-V Manager:
     .\enable-hyper-v-remote-management.ps1 -ServerName "HV-SRV01" -ServerIP "10.10.1.10" -InstallManagementTools -LaunchHyperVManager

  4. Configure client, switch Public network to Private, and store credentials:
     .\enable-hyper-v-remote-management.ps1 -ServerName "HV-SRV01" -ServerIP "10.10.1.10" -SetPrivateNetworkProfile -StoreCredentials -ServerUser "Administrator"

  5. Configure the Hyper-V Server itself (run on the Hyper-V host 10.10.1.10):
     .\enable-hyper-v-remote-management.ps1 -Role Server

  6. Audit current client/server configuration without making changes:
     .\enable-hyper-v-remote-management.ps1 -Status

  7. Simulate client configuration in Dry-Run mode:
     .\enable-hyper-v-remote-management.ps1 -ServerName "HV-SRV01" -ServerIP "10.10.1.10" -DryRun

FIRST RUN / UNBLOCKING NOTE:
  After downloading this script from GitHub, unblock it before running:
     Unblock-File -Path .\enable-hyper-v-remote-management.ps1
================================================================================
"@ -ForegroundColor Yellow
}

# ==============================================================================
# ZERO-PARAMETER & HELP CHECK
# ==============================================================================
$normalizedRole = if ([string]::IsNullOrWhiteSpace($Role)) { "Client" } else { (Get-Culture).TextInfo.ToTitleCase($Role.ToLowerInvariant()) }
$hasServerName = -not [string]::IsNullOrWhiteSpace($ServerName)
$hasActionTrigger = $Status -or ($normalizedRole -eq "Server") -or ($normalizedRole -eq "Client" -and $hasServerName)

if ($Help -or (-not $hasActionTrigger)) {
    if (-not $Help -and -not [string]::IsNullOrWhiteSpace($ServerIP) -and -not $hasServerName) {
        Write-Host "`n[!] WARNING: Parameter -ServerIP ('$ServerIP') was provided without -ServerName." -ForegroundColor Red
        Write-Host "    Hyper-V Manager in Workgroup mode requires a hostname (-ServerName <Name> -ServerIP <IP>).`n" -ForegroundColor Yellow
    }
    Show-HelpGuide
    return
}

# ==============================================================================
# VALIDATE & SANITIZE USER INPUTS BEFORE ELEVATION
# ==============================================================================
if ($hasServerName) {
    $ServerName = $ServerName.Trim()
    Protect-HostNameInput -HostValue $ServerName -ParameterName "ServerName"
}

if (-not [string]::IsNullOrWhiteSpace($ServerIP)) {
    $ServerIP = $ServerIP.Trim()
    Protect-IPv4AddressInput -IpValue $ServerIP -ParameterName "ServerIP"
}

if (-not [string]::IsNullOrWhiteSpace($ServerUser)) {
    $ServerUser = $ServerUser.Trim()
    Protect-UserNameInput -UserValue $ServerUser
}

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = $LogPath.Trim()
    Protect-FilePathInput -PathValue $LogPath -ParameterName "LogPath"
}

# ==============================================================================
# UAC AUTO-ELEVATION (LANGUAGE-INDEPENDENT SID VERIFICATION)
# ==============================================================================
# Check if the script is already running with Administrator privileges using SID (language-independent)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)

$isAdmin = $principal.IsInRole($adminSid)

if (-not $isAdmin -and -not $SkipAdminCheck) {
    # If not running as Admin, prompt for UAC consent and relaunch the script with elevated privileges
    Write-Host "Missing Administrator privileges. Requesting elevation..." -ForegroundColor Yellow

    $relaunchArgs = [System.Collections.Generic.List[string]]::new()
    $relaunchArgs.Add("-NoProfile")
    $relaunchArgs.Add("-ExecutionPolicy")
    $relaunchArgs.Add("Bypass")
    $relaunchArgs.Add("-File")
    $relaunchArgs.Add("`"$PSCommandPath`"")

    if ($hasServerName) {
        $relaunchArgs.Add("-ServerName")
        $relaunchArgs.Add("`"$ServerName`"")
    }
    if (-not [string]::IsNullOrWhiteSpace($ServerIP)) {
        $relaunchArgs.Add("-ServerIP")
        $relaunchArgs.Add("`"$ServerIP`"")
    }
    if (-not [string]::IsNullOrWhiteSpace($Role)) {
        $relaunchArgs.Add("-Role")
        $relaunchArgs.Add("`"$normalizedRole`"")
    }
    if ($InstallManagementTools) { $relaunchArgs.Add("-InstallManagementTools") }
    if ($SetPrivateNetworkProfile) { $relaunchArgs.Add("-SetPrivateNetworkProfile") }
    if ($IncludeIPInTrustedHosts) { $relaunchArgs.Add("-IncludeIPInTrustedHosts") }
    if (-not [string]::IsNullOrWhiteSpace($ServerUser) -and $ServerUser -ne "Administrator") {
        $relaunchArgs.Add("-ServerUser")
        $relaunchArgs.Add("`"$ServerUser`"")
    }
    if ($StoreCredentials) { $relaunchArgs.Add("-StoreCredentials") }
    if ($LaunchHyperVManager) { $relaunchArgs.Add("-LaunchHyperVManager") }
    if ($Status) { $relaunchArgs.Add("-Status") }
    if ($DryRun) { $relaunchArgs.Add("-DryRun") }
    if ($PassThru) { $relaunchArgs.Add("-PassThru") }
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $relaunchArgs.Add("-LogPath")
        $relaunchArgs.Add("`"$LogPath`"")
    }
    if ($NoLog) { $relaunchArgs.Add("-NoLog") }

    Start-Process powershell.exe -ArgumentList ($relaunchArgs -join " ") -Verb RunAs
    exit
}

# ==============================================================================
# INITIALIZE LOGGING & ENVIRONMENT BANNER
# ==============================================================================
Initialize-LogFile

$osCim = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
$csCim = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
$osCaption = if ($osCim) { $osCim.Caption.Trim() } else { [System.Environment]::OSVersion.VersionString }
$osVersion = if ($osCim) { "$($osCim.Version) (Build $($osCim.BuildNumber))" } else { "Unknown" }
$partOfDomain = if ($csCim) { [bool]$csCim.PartOfDomain } else { $false }
$domainOrWorkgroup = if ($csCim) {
    if ($csCim.PartOfDomain) { "Domain ($($csCim.Domain))" } else { "Workgroup ($($csCim.Workgroup))" }
} else { "Unknown" }

Write-Log "================================================================================" -Level HEADER
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - Initialization" -Level HEADER
Write-Log "================================================================================" -Level HEADER
Write-Log "  Author / Contact     : $($SCRIPT_INFO.Author) ($($SCRIPT_INFO.Contact))" -Level DETAIL
Write-Log "  Computer / User      : $([System.Environment]::MachineName) \ $([System.Environment]::UserName)" -Level DETAIL
Write-Log "  Operating System     : $osCaption [$osVersion]" -Level DETAIL
Write-Log "  Network Membership   : $domainOrWorkgroup" -Level DETAIL
Write-Log "  Elevated Admin (SID) : $isAdmin (S-1-5-32-544 Verified)" -Level DETAIL
Write-Log "  Operation Mode       : $(if ($Status) { 'STATUS AUDIT (Read-Only)' } elseif ($DryRun) { "DRY-RUN SIMULATION ($normalizedRole)" } else { "LIVE CONFIGURATION ($normalizedRole)" })" -Level INFO
if ($hasServerName) {
    Write-Log "  Target Hyper-V Host  : $ServerName $(if (-not [string]::IsNullOrWhiteSpace($ServerIP)) { "($ServerIP)" } else { '(DNS / Existing Resolution)' })" -Level INFO
}
if (-not $NoLog -and $script:ActiveLogFile) {
    Write-Log "  Active Log File      : $script:ActiveLogFile" -Level DETAIL
}
Write-Log "================================================================================" -Level HEADER

# ==============================================================================
# HELPER FUNCTIONS FOR INSPECTION & CONFIGURATION
# ==============================================================================
function Get-HostsFileEntries {
    $entries = [System.Collections.Generic.List[PSCustomObject]]::new()
    if (-not (Test-Path -LiteralPath $HOSTS_FILE_PATH -PathType Leaf)) {
        return $entries
    }

    $lines = Get-Content -LiteralPath $HOSTS_FILE_PATH -Encoding UTF8 -ErrorAction SilentlyContinue
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }
        $cleanLine = ($trimmed -split '#')[0].Trim()
        $tokens = $cleanLine -split '\s+'
        if ($tokens.Count -ge 2) {
            $ip = $tokens[0]
            $hostnames = $tokens[1..($tokens.Count - 1)]
            $entries.Add([PSCustomObject]@{
                LineNumber = $lineNum
                IPAddress  = $ip
                HostNames  = ($hostnames -join ", ")
                RawLine    = $line
            })
        }
    }
    return $entries
}

function Get-GpoDelegationList {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubKeyPath
    )

    $delegatedServers = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $SubKeyPath)) {
        return $delegatedServers
    }

    try {
        $itemProps = Get-ItemProperty -LiteralPath $SubKeyPath -ErrorAction SilentlyContinue
        if ($null -ne $itemProps) {
            foreach ($prop in $itemProps.PSObject.Properties) {
                if ($prop.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$') {
                    $val = [string]$prop.Value
                    if (-not [string]::IsNullOrWhiteSpace($val)) {
                        $delegatedServers.Add($val)
                    }
                }
            }
        }
    }
    catch {}
    return $delegatedServers
}

function Get-HyperVRemoteManagementState {
    param (
        [string]$TargetServerName
    )

    # 1. WinRM Service
    $winrmSvc = Get-Service -Name "WinRM" -ErrorAction SilentlyContinue
    $winrmStatus = if ($null -ne $winrmSvc) { [string]$winrmSvc.Status } else { "NotFound" }
    $winrmStartType = if ($null -ne $winrmSvc) { [string]$winrmSvc.StartType } else { "Unknown" }

    # 2. WSMan TrustedHosts & CredSSP
    $trustedHostsVal = "(Not Accessible / WinRM Stopped)"
    $credSspClientAuth = $false
    $credSspServerAuth = $false
    if ($winrmStatus -eq "Running") {
        try {
            $thItem = Get-Item -Path "WSMan:\localhost\Client\TrustedHosts" -ErrorAction SilentlyContinue
            if ($null -ne $thItem) {
                $trustedHostsVal = if ([string]::IsNullOrWhiteSpace($thItem.Value)) { "(Empty)" } else { [string]$thItem.Value }
            }
        }
        catch {
            $trustedHostsVal = "(Error Reading WSMan)"
        }

        try {
            $cAuth = Get-Item -Path "WSMan:\localhost\Client\Auth\CredSSP" -ErrorAction SilentlyContinue
            if ($null -ne $cAuth) { $credSspClientAuth = ($cAuth.Value -eq "true") }
        }
        catch {}

        try {
            $sAuth = Get-Item -Path "WSMan:\localhost\Service\Auth\CredSSP" -ErrorAction SilentlyContinue
            if ($null -ne $sAuth) { $credSspServerAuth = ($sAuth.Value -eq "true") }
        }
        catch {}
    }

    # 3. WSMan CredSSP DelegateComputers (from Registry/WSMan)
    $wsmanCredSspOut = @()
    try {
        $wsmanCredSspOut = @(Get-WSManCredSSP -ErrorAction SilentlyContinue)
    }
    catch {}

    # 4. GPO NTLM-Only Fresh Credentials Delegation Registry
    $ntlmFlag = 0
    $ntlmConcat = 0
    if (Test-Path -LiteralPath $GPO_CRED_DELEGATION_PATH) {
        $gpProps = Get-ItemProperty -LiteralPath $GPO_CRED_DELEGATION_PATH -ErrorAction SilentlyContinue
        if ($null -ne $gpProps) {
            if ($gpProps.PSObject.Properties.Name -contains "AllowFreshCredentialsWhenNTLMOnly") {
                $ntlmFlag = [int]$gpProps.AllowFreshCredentialsWhenNTLMOnly
            }
            if ($gpProps.PSObject.Properties.Name -contains "ConcatenateDefaults_AllowFreshNTLMOnly") {
                $ntlmConcat = [int]$gpProps.ConcatenateDefaults_AllowFreshNTLMOnly
            }
        }
    }
    $ntlmDelegatedList = Get-GpoDelegationList -SubKeyPath $GPO_NTLM_SUBKEY_PATH
    $freshDelegatedList = Get-GpoDelegationList -SubKeyPath $GPO_FRESH_SUBKEY_PATH

    # 5. Hyper-V Management Optional Features
    $guiFeatureState = "Unknown"
    $psFeatureState = "Unknown"
    $virtMgmtPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\virtmgmt.msc"
    $hasVirtMgmtMsc = Test-Path -LiteralPath $virtMgmtPath -PathType Leaf

    try {
        $hvFeatures = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='Microsoft-Hyper-V-Management-Clients' OR Name='Microsoft-Hyper-V-Management-PowerShell'" -ErrorAction SilentlyContinue
        foreach ($feat in $hvFeatures) {
            $mappedState = switch ($feat.InstallState) {
                1 { "Enabled" }
                2 { "Disabled" }
                3 { "Absent" }
                default { "Unknown ($($feat.InstallState))" }
            }
            if ($feat.Name -eq "Microsoft-Hyper-V-Management-Clients") { $guiFeatureState = $mappedState }
            if ($feat.Name -eq "Microsoft-Hyper-V-Management-PowerShell") { $psFeatureState = $mappedState }
        }
    }
    catch {}

    # 6. Network Profiles
    $netProfiles = @()
    try {
        $netProfiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | ForEach-Object {
            "$($_.InterfaceAlias): $($_.NetworkCategory)"
        })
    }
    catch {}

    # 7. Hosts Entries
    $allHosts = Get-HostsFileEntries
    $matchingHosts = if (-not [string]::IsNullOrWhiteSpace($TargetServerName)) {
        @($allHosts | Where-Object { $_.HostNames -match "(?i)\b$([regex]::Escape($TargetServerName))\b" })
    }
    else {
        @($allHosts)
    }

    return [PSCustomObject]@{
        WinRMStatus          = $winrmStatus
        WinRMStartType       = $winrmStartType
        TrustedHosts         = $trustedHostsVal
        CredSSPClientEnabled = $credSspClientAuth
        CredSSPServerEnabled = $credSspServerAuth
        WSManCredSSPReport   = ($wsmanCredSspOut -join " | ")
        GpoNtlmEnabled       = ($ntlmFlag -eq 1)
        GpoNtlmConcatenate   = ($ntlmConcat -eq 1)
        GpoNtlmServers       = @($ntlmDelegatedList)
        GpoFreshServers      = @($freshDelegatedList)
        HyperVGuiToolsState  = $guiFeatureState
        HyperVPsToolsState   = $psFeatureState
        VirtMgmtMscPresent   = $hasVirtMgmtMsc
        NetworkProfiles      = ($netProfiles -join "; ")
        HostsEntries         = $allHosts
        TargetHostEntries    = $matchingHosts
    }
}

function Show-StateReport {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$StateObject,

        [string]$Title = "CURRENT HYPER-V REMOTE MANAGEMENT CONFIGURATION STATUS"
    )

    Write-Log "`n--------------------------------------------------------------------------------" -Level HEADER
    Write-Log "  $Title" -Level STEP
    Write-Log "--------------------------------------------------------------------------------" -Level HEADER
    Write-Log "  WinRM Service Status        : $($StateObject.WinRMStatus) (StartType: $($StateObject.WinRMStartType))" -Level $(if ($StateObject.WinRMStatus -eq 'Running') { 'SUCCESS' } else { 'WARN' })
    Write-Log "  WSMan TrustedHosts          : $($StateObject.TrustedHosts)" -Level $(if ($StateObject.TrustedHosts -notin @('(Empty)', '(Not Accessible / WinRM Stopped)')) { 'SUCCESS' } else { 'WARN' })
    Write-Log "  CredSSP Client Role         : $(if ($StateObject.CredSSPClientEnabled) { 'Enabled' } else { 'Disabled' })" -Level $(if ($StateObject.CredSSPClientEnabled) { 'SUCCESS' } else { 'WARN' })
    Write-Log "  CredSSP Server Role         : $(if ($StateObject.CredSSPServerEnabled) { 'Enabled' } else { 'Disabled' })" -Level INFO
    if (-not [string]::IsNullOrWhiteSpace($StateObject.WSManCredSSPReport)) {
        Write-Log "  Get-WSManCredSSP Details    : $($StateObject.WSManCredSSPReport)" -Level DETAIL
    }
    Write-Log "  GPO NTLM-Only Delegation    : $(if ($StateObject.GpoNtlmEnabled) { 'Enabled (Registry Policy = 1)' } else { 'Not Configured / Disabled' })" -Level $(if ($StateObject.GpoNtlmEnabled) { 'SUCCESS' } else { 'WARN' })
    if ($StateObject.GpoNtlmServers.Count -gt 0) {
        Write-Log "  GPO Delegated SPNs (NTLM)   : $($StateObject.GpoNtlmServers -join ', ')" -Level SUCCESS
    }
    else {
        Write-Log "  GPO Delegated SPNs (NTLM)   : (None)" -Level WARN
    }
    Write-Log "  Hyper-V GUI Tools (Client)  : $($StateObject.HyperVGuiToolsState) (virtmgmt.msc: $(if ($StateObject.VirtMgmtMscPresent) { 'Present' } else { 'Missing' }))" -Level $(if ($StateObject.VirtMgmtMscPresent) { 'SUCCESS' } else { 'WARN' })
    Write-Log "  Hyper-V PowerShell Module   : $($StateObject.HyperVPsToolsState)" -Level INFO
    Write-Log "  Active Network Profiles     : $(if ($StateObject.NetworkProfiles) { $StateObject.NetworkProfiles } else { '(None Detected)' })" -Level DETAIL

    Write-Log "`n  Active Hosts File Mappings ($HOSTS_FILE_PATH):" -Level STEP
    if ($StateObject.HostsEntries.Count -eq 0) {
        Write-Log "    (No custom active host mappings found in hosts file)" -Level DETAIL
    }
    else {
        foreach ($h in $StateObject.HostsEntries) {
            Write-Log ("    Line {0,-3} : {1,-16} -> {2}" -f $h.LineNumber, $h.IPAddress, $h.HostNames) -Level INFO
        }
    }
    Write-Log "--------------------------------------------------------------------------------`n" -Level HEADER
}

# ==============================================================================
# HANDLE -STATUS MODE (AUDIT ONLY)
# ==============================================================================
if ($Status) {
    $currentAudit = Get-HyperVRemoteManagementState -TargetServerName $ServerName
    Show-StateReport -StateObject $currentAudit
    if ($PassThru) {
        return $currentAudit
    }
    return
}

# ==============================================================================
# HANDLE -ROLE SERVER MODE (HYPER-V HOST PREREQUISITE CONFIGURATION)
# ==============================================================================
if ($normalizedRole -eq "Server") {
    $serverSteps = 4
    Write-Log "`n[STEP 1/$serverSteps] Inspecting Network Profiles & Enabling PowerShell Remoting (WinRM)..." -Level STEP

    if ($SetPrivateNetworkProfile) {
        $pubProfiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -eq "Public" })
        foreach ($prof in $pubProfiles) {
            if ($DryRun) {
                Write-Log "  [DRY-RUN] Would change network profile '$($prof.Name)' ($($prof.InterfaceAlias)) from Public to Private." -Level WARN
            }
            else {
                Write-Log "  [*] Switching network profile '$($prof.Name)' ($($prof.InterfaceAlias)) from Public to Private..." -Level INFO
                Set-NetConnectionProfile -InterfaceIndex $prof.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
                Write-Log "  [+] Network profile '$($prof.InterfaceAlias)' set to Private." -Level SUCCESS
            }
        }
    }

    if ($DryRun) {
        Write-Log "  [DRY-RUN] Would execute: Enable-PSRemoting -Force -SkipNetworkProfileCheck" -Level WARN
    }
    else {
        Write-Log "  [*] Executing: Enable-PSRemoting -Force -SkipNetworkProfileCheck..." -Level INFO
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop | Out-Null
        Write-Log "  [+] PowerShell Remoting (WinRM) enabled and listening." -Level SUCCESS
    }

    Write-Log "`n[STEP 2/$serverSteps] Enabling CredSSP Server Role & Server Manager Remoting..." -Level STEP
    if ($DryRun) {
        Write-Log "  [DRY-RUN] Would execute: Enable-WSManCredSSP -Role Server -Force" -Level WARN
        Write-Log "  [DRY-RUN] Would execute: Configure-SMRemoting.exe -Enable (if present)" -Level WARN
    }
    else {
        Write-Log "  [*] Executing: Enable-WSManCredSSP -Role Server -Force..." -Level INFO
        Enable-WSManCredSSP -Role Server -Force -ErrorAction Stop | Out-Null
        Write-Log "  [+] WSMan CredSSP Server role enabled." -Level SUCCESS

        $smRemotingExe = Join-Path -Path $env:SystemRoot -ChildPath "System32\Configure-SMRemoting.exe"
        if (Test-Path -LiteralPath $smRemotingExe -PathType Leaf) {
            Write-Log "  [*] Executing: Configure-SMRemoting.exe -Enable..." -Level INFO
            $smOut = & $smRemotingExe -Enable 2>&1
            Write-Log "  [+] Configure-SMRemoting completed: $($smOut -join ' ')" -Level SUCCESS
        }
        else {
            Write-Log "  [i] Configure-SMRemoting.exe not present on this Windows edition (skipped)." -Level DETAIL
        }
    }

    Write-Log "`n[STEP 3/$serverSteps] Enabling Firewall Rules for WMI/DCOM, WinRM & Hyper-V Management..." -Level STEP
    # Language-independent rule name patterns + English/Polish display groups
    $fwRuleNamePatterns = @("WINRM-*", "WMI-*", "VM-Monitoring-*", "Hyper-V-*")
    $enabledFwCount = 0

    foreach ($pattern in $fwRuleNamePatterns) {
        $matchingRules = @(Get-NetFirewallRule -Name $pattern -ErrorAction SilentlyContinue)
        if ($matchingRules.Count -gt 0) {
            if ($DryRun) {
                Write-Log "  [DRY-RUN] Would enable $($matchingRules.Count) firewall rules matching '$pattern'." -Level WARN
                $enabledFwCount += $matchingRules.Count
            }
            else {
                $matchingRules | Enable-NetFirewallRule -ErrorAction SilentlyContinue
                $enabledFwCount += $matchingRules.Count
                Write-Log "  [+] Enabled $($matchingRules.Count) firewall rule(s) matching Name '$pattern'." -Level SUCCESS
            }
        }
    }

    $fwDisplayGroups = @(
        "Windows Management Instrumentation (WMI)",
        "Instrumentacja zarządzania systemu Windows (WMI)",
        "Windows Remote Management",
        "Zdalne zarządzanie systemem Windows",
        "Hyper-V Management Clients",
        "Klienci zarządzania funkcji Hyper-V",
        "Hyper-V"
    )
    foreach ($grp in $fwDisplayGroups) {
        $grpRules = @(Get-NetFirewallRule -DisplayGroup $grp -ErrorAction SilentlyContinue)
        if ($grpRules.Count -gt 0) {
            if ($DryRun) {
                Write-Log "  [DRY-RUN] Would enable DisplayGroup '$grp' ($($grpRules.Count) rules)." -Level WARN
            }
            else {
                $grpRules | Enable-NetFirewallRule -ErrorAction SilentlyContinue
                Write-Log "  [+] Enabled Firewall DisplayGroup '$grp' ($($grpRules.Count) rules)." -Level SUCCESS
            }
        }
    }

    Write-Log "`n[STEP 4/$serverSteps] Auditing Final Server State..." -Level STEP
    $finalServerState = Get-HyperVRemoteManagementState -TargetServerName $ServerName
    Show-StateReport -StateObject $finalServerState -Title "HYPER-V SERVER REMOTE MANAGEMENT SUMMARY"
    if ($PassThru) {
        return $finalServerState
    }
    return
}

# ==============================================================================
# CLIENT MODE WORKFLOW (WORKSTATION CONFIGURATION FOR HYPER-V MANAGER)
# ==============================================================================
$totalSteps = 6
$initialState = Get-HyperVRemoteManagementState -TargetServerName $ServerName

$stepResults = [ordered]@{
    NetworkProfileAction   = "Unchanged"
    ManagementToolsAction  = "Unchanged"
    HostsFileAction        = "Skipped (No -ServerIP specified)"
    HostsBackupPath        = $null
    NameResolutionVerified = $false
    ResolvedIPAddress      = $null
    PingReachable          = $false
    WinRMPort5985Open      = $false
    RpcPort135Open         = $false
    WinRMServiceAction     = "Unchanged"
    TrustedHostsBefore     = $initialState.TrustedHosts
    TrustedHostsAfter      = $initialState.TrustedHosts
    CredSSPClientAction    = "Unchanged"
    GpoRegistryAction      = "Unchanged"
    GpUpdateStatus         = "Not Executed"
    FirewallClientAction   = "Unchanged"
    CredentialsStored      = $false
    RebootRequired         = $false
}

# ------------------------------------------------------------------------------
# STEP 1: PRE-FLIGHT CHECKS, NETWORK PROFILE & HYPER-V MANAGEMENT TOOLS
# ------------------------------------------------------------------------------
Write-Log "`n[STEP 1/$totalSteps] Pre-Flight Checks, Network Profile & Hyper-V Management Tools..." -Level STEP

# 1A. Network Connection Profile Check
$activeNetProfiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
if ($activeNetProfiles.Count -gt 0) {
    foreach ($np in $activeNetProfiles) {
        Write-Log "  [*] Network Adapter '$($np.InterfaceAlias)' (Network: '$($np.Name)') -> Category: $($np.NetworkCategory)" -Level INFO
        if ($np.NetworkCategory -eq "Public") {
            if ($SetPrivateNetworkProfile) {
                if ($DryRun) {
                    Write-Log "      [DRY-RUN] Would switch '$($np.InterfaceAlias)' from Public to Private." -Level WARN
                    $stepResults.NetworkProfileAction = "Simulated Switch to Private"
                }
                else {
                    Write-Log "      [*] Switching '$($np.InterfaceAlias)' from Public to Private..." -Level INFO
                    Set-NetConnectionProfile -InterfaceIndex $np.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
                    Write-Log "      [+] Network Category for '$($np.InterfaceAlias)' changed to Private." -Level SUCCESS
                    $stepResults.NetworkProfileAction = "Switched Public -> Private"
                }
            }
            else {
                Write-Log "      [!] Note: Interface '$($np.InterfaceAlias)' is set to 'Public'. WinRM/CredSSP works best on 'Private' networks (use -SetPrivateNetworkProfile to switch automatically)." -Level WARN
                $stepResults.NetworkProfileAction = "Public Profile Detected (Advisory Issued)"
            }
        }
        else {
            $stepResults.NetworkProfileAction = "Verified ($($np.NetworkCategory))"
        }
    }
}

# 1B. Hyper-V Management Client Tools Check (virtmgmt.msc & PowerShell module)
Write-Log "  [*] Checking Hyper-V Client Management Tools on this workstation..." -Level INFO
Write-Log "      - Hyper-V GUI Management Tools (virtmgmt.msc) : $($initialState.HyperVGuiToolsState) (Binary Present: $($initialState.VirtMgmtMscPresent))" -Level DETAIL
Write-Log "      - Hyper-V PowerShell Module                   : $($initialState.HyperVPsToolsState)" -Level DETAIL

if ($InstallManagementTools) {
    $featuresToEnable = @("Microsoft-Hyper-V-Management-Clients", "Microsoft-Hyper-V-Management-PowerShell")
    foreach ($featName in $featuresToEnable) {
        if ($DryRun) {
            Write-Log "      [DRY-RUN] Would enable Windows Optional Feature: '$featName' (-All -NoRestart)" -Level WARN
            $stepResults.ManagementToolsAction = "Simulated Enable (DryRun)"
        }
        else {
            Write-Log "      [*] Enabling Windows Optional Feature: '$featName'..." -Level INFO
            try {
                $dismRes = Enable-WindowsOptionalFeature -Online -FeatureName $featName -All -NoRestart -ErrorAction Stop
                if ($dismRes -and $dismRes.RestartNeeded) {
                    $stepResults.RebootRequired = $true
                }
                Write-Log "      [+] Feature '$featName' enabled (RestartNeeded: $(if ($dismRes) { $dismRes.RestartNeeded } else { $false }))." -Level SUCCESS
                $stepResults.ManagementToolsAction = "Enabled Hyper-V Client & PowerShell Tools"
            }
            catch {
                Write-Log "      [!] Could not enable feature '$featName': $($_.Exception.Message)" -Level WARN
                $stepResults.ManagementToolsAction = "Partial / Warning ($($_.Exception.Message))"
            }
        }
    }
}
elseif (-not $initialState.VirtMgmtMscPresent) {
    Write-Log "  [!] Hyper-V Manager console (virtmgmt.msc) is not currently enabled on this PC." -Level WARN
    Write-Log "      Tip: Re-run with -InstallManagementTools to automatically install Hyper-V Manager GUI & PowerShell tools." -Level DETAIL
    $stepResults.ManagementToolsAction = "Not Installed (Use -InstallManagementTools)"
}
else {
    Write-Log "  [+] Hyper-V Manager GUI console (virtmgmt.msc) is installed and ready." -Level SUCCESS
    $stepResults.ManagementToolsAction = "Already Installed (virtmgmt.msc Present)"
}

# ------------------------------------------------------------------------------
# STEP 2: NAME RESOLUTION (HOSTS FILE) & CONNECTIVITY VERIFICATION
# ------------------------------------------------------------------------------
Write-Log "`n[STEP 2/$totalSteps] Configuring Name Resolution (hosts file) & Testing Connectivity..." -Level STEP
Write-Log "  [i] Workgroup Requirement: Hyper-V Manager requires a resolvable hostname ('$ServerName') and cannot connect via raw IP." -Level DETAIL

if (-not [string]::IsNullOrWhiteSpace($ServerIP)) {
    Write-Log "  [*] Target Mapping: $ServerIP  ->  $ServerName (File: $HOSTS_FILE_PATH)" -Level INFO

    if (-not (Test-Path -LiteralPath $HOSTS_FILE_PATH -PathType Leaf)) {
        throw "System Error: Hosts file was not found at '$HOSTS_FILE_PATH'."
    }

    $rawHostsLines = @(Get-Content -LiteralPath $HOSTS_FILE_PATH -Encoding UTF8 -ErrorAction Stop)
    $exactMatchFound = $false
    $updatedExistingLine = $false
    $newHostsLines = [System.Collections.Generic.List[string]]::new()
    $escapedHostRegex = "(?i)(^|\s)$([regex]::Escape($ServerName))(\s|$|#)"

    foreach ($line in $rawHostsLines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            $newHostsLines.Add($line)
            continue
        }

        $codePart = ($trimmed -split '#')[0].Trim()
        $tokens = $codePart -split '\s+'
        if ($tokens.Count -ge 2) {
            $lineIp = $tokens[0]
            $lineHosts = $tokens[1..($tokens.Count - 1)]
            $containsTargetHost = $false
            foreach ($h in $lineHosts) {
                if ($h.Equals($ServerName, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $containsTargetHost = $true
                    break
                }
            }

            if ($containsTargetHost) {
                if ($lineIp -eq $ServerIP -and -not $exactMatchFound) {
                    $exactMatchFound = $true
                    $newHostsLines.Add($line)
                }
                elseif ($lineIp -ne $ServerIP -and -not $updatedExistingLine -and -not $exactMatchFound) {
                    # Replace or update mapping for this hostname
                    if ($lineHosts.Count -eq 1) {
                        $updatedLine = "{0,-15} {1} # Updated by enable-hyper-v-remote-management ({2})" -f $ServerIP, $ServerName, (Get-Date -Format "yyyy-MM-dd")
                        $newHostsLines.Add($updatedLine)
                        $updatedExistingLine = $true
                        Write-Log "      [*] Updating existing hosts entry for '$ServerName' ($lineIp -> $ServerIP)..." -Level INFO
                    }
                    else {
                        # Keep other hostnames on old IP line and add separate line for ServerName
                        $remainingHosts = @($lineHosts | Where-Object { -not $_.Equals($ServerName, [System.StringComparison]::OrdinalIgnoreCase) })
                        $newHostsLines.Add(("{0,-15} {1}" -f $lineIp, ($remainingHosts -join " ")))
                    }
                }
                continue
            }
        }

        $newHostsLines.Add($line)
    }

    if ($exactMatchFound) {
        Write-Log "  [+] Hosts file already contains exact mapping: '$ServerIP    $ServerName' (No modification needed)." -Level SUCCESS
        $stepResults.HostsFileAction = "Already Present ($ServerIP -> $ServerName)"
    }
    else {
        if (-not $updatedExistingLine) {
            $newEntryLine = "{0,-15} {1} # Added by enable-hyper-v-remote-management ({2})" -f $ServerIP, $ServerName, (Get-Date -Format "yyyy-MM-dd")
            $newHostsLines.Add($newEntryLine)
        }

        if ($DryRun) {
            Write-Log "  [DRY-RUN] Would back up '$HOSTS_FILE_PATH' and write mapping: '$ServerIP    $ServerName'." -Level WARN
            $stepResults.HostsFileAction = "Simulated Add/Update ($ServerIP -> $ServerName)"
        }
        else {
            # Create backup of hosts file in C:\Logs (or temp) before editing
            $backupDir = if ($script:ActiveLogFile) { [System.IO.Path]::GetDirectoryName($script:ActiveLogFile) } else { [System.IO.Path]::GetTempPath() }
            $backupFileName = "hosts.backup.$((Get-Date).ToString('yyyyMMdd_HHmmss'))"
            $backupFullPath = Join-Path -Path $backupDir -ChildPath $backupFileName
            Copy-Item -LiteralPath $HOSTS_FILE_PATH -Destination $backupFullPath -Force -ErrorAction SilentlyContinue
            $stepResults.HostsBackupPath = $backupFullPath
            Write-Log "  [*] Created backup of hosts file at: '$backupFullPath'" -Level DETAIL

            # Write updated hosts file using UTF8 without BOM (standard Windows hosts compatibility)
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllLines($HOSTS_FILE_PATH, $newHostsLines.ToArray(), $utf8NoBom)

            $actionVerb = if ($updatedExistingLine) { "Updated" } else { "Added" }
            Write-Log "  [+] $actionVerb hosts entry: '$ServerIP    $ServerName' in '$HOSTS_FILE_PATH'." -Level SUCCESS
            $stepResults.HostsFileAction = "$actionVerb Mapping ($ServerIP -> $ServerName)"

            # Flush DNS client cache so resolution is immediate
            try {
                Clear-DnsClientCache -ErrorAction SilentlyContinue
                Write-Log "  [+] Local DNS client resolver cache flushed (Clear-DnsClientCache)." -Level DETAIL
            }
            catch {}
        }
    }
}
else {
    Write-Log "  [i] Parameter -ServerIP was not specified; relying on existing DNS or hosts file entry for '$ServerName'." -Level INFO
}

# Verify Name Resolution & Network Reachability (Test-Connection)
Write-Log "  [*] Verifying hostname resolution & network reachability for '$ServerName'..." -Level INFO
try {
    $resolvedAddresses = @([System.Net.Dns]::GetHostAddresses($ServerName) | Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork })
    if ($resolvedAddresses.Count -gt 0) {
        $resolvedIpStr = ($resolvedAddresses | ForEach-Object { $_.IPAddressToString }) -join ", "
        $stepResults.NameResolutionVerified = $true
        $stepResults.ResolvedIPAddress = $resolvedIpStr
        Write-Log "  [+] Name Resolution Verified: '$ServerName' resolves to IPv4 [$resolvedIpStr]." -Level SUCCESS
    }
    elseif ($DryRun -and -not [string]::IsNullOrWhiteSpace($ServerIP)) {
        $stepResults.NameResolutionVerified = $true
        $stepResults.ResolvedIPAddress = "$ServerIP (Simulated via DryRun)"
        Write-Log "  [DRY-RUN] '$ServerName' will resolve to '$ServerIP' once hosts file is written." -Level WARN
    }
    else {
        Write-Log "  [!] Warning: Hostname '$ServerName' could not be resolved to an IPv4 address. Provide -ServerIP <IPv4> to map it in the hosts file." -Level WARN
    }
}
catch {
    if ($DryRun -and -not [string]::IsNullOrWhiteSpace($ServerIP)) {
        $stepResults.NameResolutionVerified = $true
        $stepResults.ResolvedIPAddress = "$ServerIP (Simulated via DryRun)"
        Write-Log "  [DRY-RUN] '$ServerName' will resolve to '$ServerIP' once hosts file is written." -Level WARN
    }
    else {
        Write-Log "  [!] Warning: DNS/hosts lookup failed for '$ServerName' ($($_.Exception.Message))." -Level WARN
    }
}

$targetTestHost = if ($stepResults.NameResolutionVerified -and -not $DryRun) { $ServerName } elseif (-not [string]::IsNullOrWhiteSpace($ServerIP)) { $ServerIP } else { $ServerName }
if (-not [string]::IsNullOrWhiteSpace($targetTestHost)) {
    Write-Log "  [*] Running Test-Connection to '$targetTestHost' (ICMP Ping + TCP 5985 WinRM & TCP 135 RPC)..." -Level DETAIL
    try {
        $pingOk = Test-Connection -ComputerName $targetTestHost -Count 2 -Quiet -ErrorAction SilentlyContinue
        $stepResults.PingReachable = [bool]$pingOk
        if ($pingOk) {
            Write-Log "  [+] ICMP Ping to '$targetTestHost' : REACHABLE" -Level SUCCESS
        }
        else {
            Write-Log "  [!] ICMP Ping to '$targetTestHost' : No response (Host may block ICMP or be offline; continuing client setup)." -Level WARN
        }
    }
    catch {
        Write-Log "  [!] ICMP Ping check skipped/failed: $($_.Exception.Message)" -Level WARN
    }

    # Quick TCP socket check (1500ms timeout) for WinRM HTTP (5985) and RPC (135)
    foreach ($portInfo in @(
        @{ Port = 5985; Label = "WinRM HTTP (TCP 5985)"; Key = "WinRMPort5985Open" },
        @{ Port = 135;  Label = "RPC/DCOM Endpoint Mapper (TCP 135)"; Key = "RpcPort135Open" }
    )) {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        try {
            $asyncRes = $tcpClient.BeginConnect($targetTestHost, $portInfo.Port, $null, $null)
            $waitOk = $asyncRes.AsyncWaitHandle.WaitOne(1500, $false)
            if ($waitOk -and $tcpClient.Connected) {
                $tcpClient.EndConnect($asyncRes)
                $stepResults[$portInfo.Key] = $true
                Write-Log "  [+] Remote Port $($portInfo.Label) on '$targetTestHost' : OPEN" -Level SUCCESS
            }
            else {
                Write-Log "  [i] Remote Port $($portInfo.Label) on '$targetTestHost' : Not reachable yet (Ensure Step 2 server commands are run on '$ServerName')." -Level DETAIL
            }
        }
        catch {
            Write-Log "  [i] Remote Port $($portInfo.Label) on '$targetTestHost' : Not reachable yet." -Level DETAIL
        }
        finally {
            $tcpClient.Close()
            $tcpClient.Dispose()
        }
    }
}

# ------------------------------------------------------------------------------
# STEP 3: WINRM SERVICE & WSMAN TRUSTEDHOSTS CONFIGURATION
# ------------------------------------------------------------------------------
Write-Log "`n[STEP 3/$totalSteps] Configuring WinRM Service & WSMan TrustedHosts..." -Level STEP

$targetsToTrust = [System.Collections.Generic.List[string]]::new()
$targetsToTrust.Add($ServerName)
if ($IncludeIPInTrustedHosts -and -not [string]::IsNullOrWhiteSpace($ServerIP)) {
    $targetsToTrust.Add($ServerIP)
}

if ($DryRun) {
    Write-Log "  [DRY-RUN] Would ensure 'WinRM' service is Automatic & Running (Enable-PSRemoting -Force -SkipNetworkProfileCheck)." -Level WARN
    Write-Log "  [DRY-RUN] Would execute: Set-Item WSMan:\localhost\Client\TrustedHosts -Value `"$($targetsToTrust -join ',')`" -Concatenate -Force" -Level WARN
    $stepResults.WinRMServiceAction = "Simulated Start & Automatic"
    $stepResults.TrustedHostsAfter = if ($initialState.TrustedHosts -in @("(Empty)", "(Not Accessible / WinRM Stopped)", "(Error Reading WSMan)")) { ($targetsToTrust -join ",") } else { "$($initialState.TrustedHosts),$($targetsToTrust -join ',')" }
}
else {
    # Ensure WinRM service is Automatic and Running
    $winrmSvc = Get-Service -Name "WinRM" -ErrorAction Stop
    if ($winrmSvc.StartType -ne [System.ServiceProcess.ServiceStartMode]::Automatic) {
        Write-Log "  [*] Setting WinRM service StartupType to Automatic..." -Level INFO
        Set-Service -Name "WinRM" -StartupType Automatic -ErrorAction Stop
    }
    if ($winrmSvc.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        Write-Log "  [*] Starting WinRM service..." -Level INFO
        Start-Service -Name "WinRM" -ErrorAction Stop
        $winrmSvc.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromSeconds(10))
    }

    Write-Log "  [*] Ensuring local WSMan configuration is initialized (Enable-PSRemoting -Force -SkipNetworkProfileCheck)..." -Level DETAIL
    try {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction SilentlyContinue | Out-Null
    }
    catch {}
    $stepResults.WinRMServiceAction = "Running (Automatic)"
    Write-Log "  [+] WinRM service is Running (StartupType: Automatic)." -Level SUCCESS

    # Read current TrustedHosts
    $currentThItem = Get-Item -Path "WSMan:\localhost\Client\TrustedHosts" -ErrorAction Stop
    $currentThRaw = if ($null -ne $currentThItem -and -not [string]::IsNullOrWhiteSpace($currentThItem.Value)) { $currentThItem.Value.Trim() } else { "" }
    $stepResults.TrustedHostsBefore = if ([string]::IsNullOrWhiteSpace($currentThRaw)) { "(Empty)" } else { $currentThRaw }

    Write-Log "  [*] Current WSMan TrustedHosts : $($stepResults.TrustedHostsBefore)" -Level DETAIL

    if ($currentThRaw -eq "*") {
        Write-Log "  [+] WSMan TrustedHosts is already set to wildcard '*' (All hosts trusted)." -Level SUCCESS
        $stepResults.TrustedHostsAfter = "*"
    }
    else {
        $existingThList = @($currentThRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $addedAnyTh = $false

        foreach ($trustEntry in $targetsToTrust) {
            $alreadyInTh = $false
            foreach ($item in $existingThList) {
                if ($item.Equals($trustEntry, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $alreadyInTh = $true
                    break
                }
            }

            if (-not $alreadyInTh) {
                Write-Log "  [>] Executing: Set-Item WSMan:\localhost\Client\TrustedHosts -Value `"$trustEntry`" -Concatenate -Force" -Level INFO
                Set-Item -Path "WSMan:\localhost\Client\TrustedHosts" -Value $trustEntry -Concatenate -Force -ErrorAction Stop
                $existingThList += $trustEntry
                $addedAnyTh = $true
                Write-Log "  [+] Added '$trustEntry' to WSMan:\localhost\Client\TrustedHosts." -Level SUCCESS
            }
            else {
                Write-Log "  [+] '$trustEntry' is already present in WSMan:\localhost\Client\TrustedHosts." -Level SUCCESS
            }
        }

        $updatedThItem = Get-Item -Path "WSMan:\localhost\Client\TrustedHosts" -ErrorAction SilentlyContinue
        $stepResults.TrustedHostsAfter = if ($null -ne $updatedThItem -and -not [string]::IsNullOrWhiteSpace($updatedThItem.Value)) { $updatedThItem.Value } else { "(Empty)" }
        Write-Log "  [+] Effective WSMan TrustedHosts: $($stepResults.TrustedHostsAfter)" -Level INFO
    }
}

# ------------------------------------------------------------------------------
# STEP 4: CREDSSP CLIENT ROLE & DELEGATECOMPUTER CONFIGURATION
# ------------------------------------------------------------------------------
Write-Log "`n[STEP 4/$totalSteps] Configuring WSMan CredSSP Client Role & Credential Delegation..." -Level STEP

if ($DryRun) {
    foreach ($trustEntry in $targetsToTrust) {
        Write-Log "  [DRY-RUN] Would execute: Enable-WSManCredSSP -Role Client -DelegateComputer `"$trustEntry`" -Force" -Level WARN
    }
    $stepResults.CredSSPClientAction = "Simulated Enable (DelegateComputer: $($targetsToTrust -join ', '))"
}
else {
    foreach ($trustEntry in $targetsToTrust) {
        Write-Log "  [>] Executing: Enable-WSManCredSSP -Role Client -DelegateComputer `"$trustEntry`" -Force" -Level INFO
        Enable-WSManCredSSP -Role Client -DelegateComputer $trustEntry -Force -ErrorAction Stop | Out-Null
        Write-Log "  [+] Enabled CredSSP Client role and delegated credentials to 'wsman/$trustEntry'." -Level SUCCESS
    }

    $credSspDetails = @(Get-WSManCredSSP -ErrorAction SilentlyContinue)
    foreach ($line in $credSspDetails) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Write-Log "      > $line" -Level DETAIL
        }
    }
    $stepResults.CredSSPClientAction = "Enabled (Delegated: wsman/$($targetsToTrust -join ', wsman/'))"
}

# ------------------------------------------------------------------------------
# STEP 5: LOCAL GROUP POLICY (REGISTRY) - NTLM-ONLY FRESH CREDENTIALS DELEGATION
# ------------------------------------------------------------------------------
Write-Log "`n[STEP 5/$totalSteps] Configuring Local Group Policy for NTLM-Only Fresh Credentials Delegation..." -Level STEP
Write-Log "  [i] Policy Path: Computer Configuration > Administrative Templates > System > Credentials Delegation" -Level DETAIL
Write-Log "  [i] Policy Name: Allow delegating fresh credentials with NTLM-only server authentication" -Level DETAIL
Write-Log "      (Polish UI : Zezwalaj na delegowanie nowych poswiadczen z uwierzytelnianiem serwera tylko NTLM)" -Level DETAIL

$spnEntriesToRegister = [System.Collections.Generic.List[string]]::new()
foreach ($trustEntry in $targetsToTrust) {
    $spnEntriesToRegister.Add("wsman/$trustEntry")
}

if ($DryRun) {
    Write-Log "  [DRY-RUN] Would configure registry policy key: '$GPO_CRED_DELEGATION_PATH'" -Level WARN
    Write-Log "            - AllowFreshCredentialsWhenNTLMOnly = 1 (DWORD)" -Level WARN
    Write-Log "            - ConcatenateDefaults_AllowFreshNTLMOnly = 1 (DWORD)" -Level WARN
    Write-Log "            - Subkey '$GPO_NTLM_SUBKEY_PATH' -> '$($spnEntriesToRegister -join ', ')'" -Level WARN
    Write-Log "  [DRY-RUN] Would execute: gpupdate /target:computer /force" -Level WARN
    $stepResults.GpoRegistryAction = "Simulated GPO Registry Update ($($spnEntriesToRegister -join ', '))"
    $stepResults.GpUpdateStatus = "Simulated (DryRun)"
}
else {
    # Ensure base policy key exists
    if (-not (Test-Path -LiteralPath $GPO_CRED_DELEGATION_PATH)) {
        Write-Log "  [*] Creating registry policy key: $GPO_CRED_DELEGATION_PATH" -Level DETAIL
        New-Item -Path $GPO_CRED_DELEGATION_PATH -Force -ErrorAction Stop | Out-Null
    }

    # Enable both 'AllowFreshCredentialsWhenNTLMOnly' and 'AllowFreshCredentials' + ConcatenateDefaults
    New-ItemProperty -LiteralPath $GPO_CRED_DELEGATION_PATH -Name "AllowFreshCredentialsWhenNTLMOnly" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -LiteralPath $GPO_CRED_DELEGATION_PATH -Name "ConcatenateDefaults_AllowFreshNTLMOnly" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -LiteralPath $GPO_CRED_DELEGATION_PATH -Name "AllowFreshCredentials" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -LiteralPath $GPO_CRED_DELEGATION_PATH -Name "ConcatenateDefaults_AllowFresh" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    Write-Log "  [+] Enabled Group Policy flags 'AllowFreshCredentialsWhenNTLMOnly=1' & 'ConcatenateDefaults_AllowFreshNTLMOnly=1'." -Level SUCCESS

    foreach ($subKeyPath in @($GPO_NTLM_SUBKEY_PATH, $GPO_FRESH_SUBKEY_PATH)) {
        if (-not (Test-Path -LiteralPath $subKeyPath)) {
            New-Item -Path $subKeyPath -Force -ErrorAction Stop | Out-Null
        }

        $existingSpns = Get-GpoDelegationList -SubKeyPath $subKeyPath
        $nextIndex = 1
        $propsObj = Get-ItemProperty -LiteralPath $subKeyPath -ErrorAction SilentlyContinue
        if ($null -ne $propsObj) {
            foreach ($p in $propsObj.PSObject.Properties) {
                $numVal = 0
                if ([int]::TryParse($p.Name, [ref]$numVal)) {
                    if ($numVal -ge $nextIndex) {
                        $nextIndex = $numVal + 1
                    }
                }
            }
        }

        foreach ($spn in $spnEntriesToRegister) {
            $alreadyExists = $false
            foreach ($ex in $existingSpns) {
                if ($ex.Equals($spn, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $alreadyExists = $true
                    break
                }
            }

            if (-not $alreadyExists) {
                New-ItemProperty -LiteralPath $subKeyPath -Name ([string]$nextIndex) -Value $spn -PropertyType String -Force -ErrorAction Stop | Out-Null
                Write-Log "  [+] Added delegated SPN '$spn' (Entry #$nextIndex) to '$([System.IO.Path]::GetFileName($subKeyPath))'." -Level SUCCESS
                $existingSpns.Add($spn)
                $nextIndex++
            }
            else {
                Write-Log "  [+] Delegated SPN '$spn' is already registered in '$([System.IO.Path]::GetFileName($subKeyPath))'." -Level SUCCESS
            }
        }
    }

    $verifiedNtlmSpns = Get-GpoDelegationList -SubKeyPath $GPO_NTLM_SUBKEY_PATH
    $stepResults.GpoRegistryAction = "Configured ($($verifiedNtlmSpns -join ', '))"

    # Run gpupdate /target:computer /force so Group Policy refreshes immediately
    Write-Log "  [>] Executing: gpupdate /target:computer /force..." -Level INFO
    try {
        $gpProc = Start-Process -FilePath "gpupdate.exe" -ArgumentList "/target:computer", "/force" -Wait -PassThru -NoNewWindow -ErrorAction Stop
        if ($gpProc.ExitCode -eq 0) {
            Write-Log "  [+] Group Policy refreshed successfully (gpupdate /force ExitCode: 0)." -Level SUCCESS
            $stepResults.GpUpdateStatus = "Refreshed Successfully (ExitCode 0)"
        }
        else {
            Write-Log "  [!] gpupdate completed with ExitCode: $($gpProc.ExitCode) (Registry policy is active)." -Level WARN
            $stepResults.GpUpdateStatus = "Completed (ExitCode $($gpProc.ExitCode))"
        }
    }
    catch {
        Write-Log "  [!] Warning: gpupdate execution reported: $($_.Exception.Message)" -Level WARN
        $stepResults.GpUpdateStatus = "Registry Applied (gpupdate skipped)"
    }
}

# ------------------------------------------------------------------------------
# STEP 6: CLIENT FIREWALL RULES, OPTIONAL CMDKEY CREDENTIALS & FINAL VERIFICATION
# ------------------------------------------------------------------------------
Write-Log "`n[STEP 6/$totalSteps] Finalizing Client Firewall Rules, Optional Credentials & Post-Verification..." -Level STEP

# 6A. Enable WMI / WinRM client firewall rules (language-independent by rule Name pattern)
$clientFwRules = @(Get-NetFirewallRule -Name "WINRM-*", "WMI-*" -ErrorAction SilentlyContinue)
if ($clientFwRules.Count -gt 0) {
    if ($DryRun) {
        Write-Log "  [DRY-RUN] Would ensure $($clientFwRules.Count) local WMI/WinRM firewall rules are enabled." -Level WARN
        $stepResults.FirewallClientAction = "Simulated ($($clientFwRules.Count) WMI/WinRM rules)"
    }
    else {
        $clientFwRules | Enable-NetFirewallRule -ErrorAction SilentlyContinue
        Write-Log "  [+] Enabled $($clientFwRules.Count) local Windows Firewall rules for WMI/DCOM & WinRM communication." -Level SUCCESS
        $stepResults.FirewallClientAction = "Enabled ($($clientFwRules.Count) WMI/WinRM rules)"
    }
}

# 6B. Optional Windows Credential Manager (cmdkey) Registration
$qualifiedUser = if ($ServerUser -match '\\') { $ServerUser } else { "$ServerName\$ServerUser" }
if ($StoreCredentials) {
    if ($DryRun) {
        Write-Log "  [DRY-RUN] Would prompt for password and store credentials in Windows Vault (cmdkey) for '$ServerName' as '$qualifiedUser'." -Level WARN
        $stepResults.CredentialsStored = $true
    }
    else {
        Write-Log "  [*] Prompting for password for remote account '$qualifiedUser' on '$ServerName'..." -Level INFO
        $secPass = Read-Host -Prompt "      Enter password for $qualifiedUser" -AsSecureString
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPass)
        try {
            $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            if (-not [string]::IsNullOrEmpty($plainPass)) {
                & cmdkey.exe "/add:$ServerName" "/user:$qualifiedUser" "/pass:$plainPass" | Out-Null
                & cmdkey.exe "/add:TERMSRV/$ServerName" "/user:$qualifiedUser" "/pass:$plainPass" | Out-Null
                Write-Log "  [+] Stored credentials in Windows Credential Manager (cmdkey) for '$ServerName' and 'TERMSRV/$ServerName'." -Level SUCCESS
                $stepResults.CredentialsStored = $true
            }
            else {
                Write-Log "  [!] Empty password entered; skipped saving credentials to cmdkey." -Level WARN
            }
        }
        finally {
            if ($bstr -ne [IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
            $plainPass = $null
        }
    }
}

# 6C. Launch Hyper-V Manager GUI if requested
$finalState = if ($DryRun) { $initialState } else { Get-HyperVRemoteManagementState -TargetServerName $ServerName }
if ($LaunchHyperVManager) {
    $virtMgmtExe = Join-Path -Path $env:SystemRoot -ChildPath "System32\virtmgmt.msc"
    if ($DryRun) {
        Write-Log "  [DRY-RUN] Would launch Hyper-V Manager GUI console: '$virtMgmtExe'" -Level WARN
    }
    elseif (Test-Path -LiteralPath $virtMgmtExe -PathType Leaf) {
        Write-Log "  [*] Launching Hyper-V Manager GUI console (virtmgmt.msc)..." -Level INFO
        Start-Process -FilePath "mmc.exe" -ArgumentList "`"$virtMgmtExe`""
        Write-Log "  [+] Hyper-V Manager console launched." -Level SUCCESS
    }
    else {
        Write-Log "  [!] Cannot launch virtmgmt.msc because Hyper-V Management Tools are not installed yet (use -InstallManagementTools)." -Level WARN
    }
}

# ==============================================================================
# FINAL EXECUTION SUMMARY & END-USER CONNECTION GUIDE
# ==============================================================================
$elapsed = (Get-Date) - $script:StartTime
$durationFormatted = "{0:mm}m {0:ss}.{0:fff}s" -f $elapsed

Write-Log "`n================================================================================" -Level HEADER
Write-Log "  HYPER-V REMOTE MANAGEMENT CLIENT CONFIGURATION SUMMARY" -Level HEADER
Write-Log "================================================================================" -Level HEADER
Write-Log "  Script & Version          : $($SCRIPT_INFO.FileName) v$($SCRIPT_INFO.Version)" -Level INFO
Write-Log "  Execution Mode            : $(if ($DryRun) { 'DRY-RUN (Simulation Only)' } else { 'LIVE CONFIGURATION (Client Mode)' })" -Level INFO
Write-Log "  Target Hyper-V Server     : $ServerName $(if (-not [string]::IsNullOrWhiteSpace($ServerIP)) { "($ServerIP)" } elseif ($stepResults.ResolvedIPAddress) { "($($stepResults.ResolvedIPAddress))" } else { '' })" -Level SUCCESS
Write-Log "  1. Hosts File Mapping     : $($stepResults.HostsFileAction)" -Level $(if ($stepResults.HostsFileAction -match 'Added|Updated|Already Present') { 'SUCCESS' } else { 'INFO' })
if ($stepResults.HostsBackupPath) {
    Write-Log "     Hosts Backup File      : $($stepResults.HostsBackupPath)" -Level DETAIL
}
Write-Log "  2. Name Resolution & Ping : Resolved=$(if ($stepResults.NameResolutionVerified) { "Yes ($($stepResults.ResolvedIPAddress))" } else { 'No' }) | Ping=$(if ($stepResults.PingReachable) { 'Reachable' } else { 'No Response' }) | WinRM(5985)=$(if ($stepResults.WinRMPort5985Open) { 'Open' } else { 'Closed/Filtered' })" -Level INFO
Write-Log "  3. WinRM & TrustedHosts   : Service=$($stepResults.WinRMServiceAction) | TrustedHosts='$($stepResults.TrustedHostsAfter)'" -Level SUCCESS
Write-Log "  4. CredSSP Client Role    : $($stepResults.CredSSPClientAction)" -Level SUCCESS
Write-Log "  5. Group Policy (NTLM)    : $($stepResults.GpoRegistryAction) | GPUpdate: $($stepResults.GpUpdateStatus)" -Level SUCCESS
Write-Log "  6. Client Tools & FW      : Tools=$($stepResults.ManagementToolsAction) | Firewall=$($stepResults.FirewallClientAction)" -Level INFO
if ($stepResults.CredentialsStored) {
    Write-Log "  7. Stored Credentials     : Saved in Windows Credential Manager for '$qualifiedUser'" -Level SUCCESS
}
if ($stepResults.RebootRequired) {
    Write-Log "  [!] Reboot Status         : A system restart is required to finish enabling Hyper-V GUI tools." -Level WARN
}
Write-Log "  Total Duration            : $durationFormatted" -Level DETAIL
if (-not $NoLog -and $script:ActiveLogFile) {
    Write-Log "  Execution Log File        : $script:ActiveLogFile" -Level INFO
}

Write-Log "`n--------------------------------------------------------------------------------" -Level HEADER
Write-Log "  QUICK USER INSTRUCTIONS: HOW TO CONNECT IN HYPER-V MANAGER" -Level STEP
Write-Log "--------------------------------------------------------------------------------" -Level HEADER
Write-Log "  STEP A - Verify Prerequisites on the Remote Hyper-V Server ($ServerName):" -Level INFO
Write-Log "     Ensure the following commands have been run as Administrator on '$ServerName':" -Level DETAIL
Write-Log "       Enable-PSRemoting -Force" -Level WARN
Write-Log "       Enable-WSManCredSSP -Role Server -Force" -Level WARN
Write-Log "       Configure-SMRemoting.exe -Enable" -Level WARN
Write-Log "       Enable-NetFirewallRule -Name 'WINRM-*','WMI-*','VM-Monitoring-*','Hyper-V-*'" -Level WARN
Write-Log "     (Or simply run on the server: .\enable-hyper-v-remote-management.ps1 -Role Server)" -Level DETAIL
Write-Log "" -Level DETAIL
Write-Log "  STEP B - Connect from This Client PC in Hyper-V Manager (virtmgmt.msc):" -Level INFO
Write-Log "     1. Open 'Hyper-V Manager' (Menadzer funkcji Hyper-V) or run: virtmgmt.msc" -Level DETAIL
Write-Log "     2. In the right/left pane, click 'Connect to Server...' (Polacz z serwerem...)." -Level DETAIL
Write-Log "     3. Select 'Another computer:' (Inny komputer:) and enter the HOSTNAME:" -Level DETAIL
Write-Log "          $ServerName" -Level SUCCESS
Write-Log "        (IMPORTANT: Do NOT enter the raw IP address '$($ServerIP)'; always use '$ServerName')." -Level WARN
Write-Log "     4. Check the box 'Connect as another user' (Polacz jako inny uzytkownik)" -Level DETAIL
Write-Log "        and click 'Set User...' (Ustaw uzytkownika...)." -Level DETAIL
Write-Log "     5. Enter the remote server's local Administrator credentials in the format:" -Level DETAIL
Write-Log "          User name : $qualifiedUser" -Level SUCCESS
Write-Log "          Password  : <Remote Server Administrator Password>" -Level DETAIL
Write-Log "     6. Click OK to establish the remote Hyper-V management session." -Level DETAIL
Write-Log "================================================================================`n" -Level HEADER

if ($PassThru) {
    return [PSCustomObject]@{
        ScriptName             = $SCRIPT_INFO.Name
        ScriptVersion          = $SCRIPT_INFO.Version
        ComputerName           = [System.Environment]::MachineName
        UserName               = [System.Environment]::UserName
        Role                   = $normalizedRole
        DryRun                 = [bool]$DryRun
        ServerName             = $ServerName
        ServerIP               = $ServerIP
        ResolvedIPAddress      = $stepResults.ResolvedIPAddress
        NameResolutionVerified = $stepResults.NameResolutionVerified
        PingReachable          = $stepResults.PingReachable
        WinRMPort5985Open      = $stepResults.WinRMPort5985Open
        RpcPort135Open         = $stepResults.RpcPort135Open
        HostsFileAction        = $stepResults.HostsFileAction
        TrustedHostsBefore     = $stepResults.TrustedHostsBefore
        TrustedHostsAfter      = $stepResults.TrustedHostsAfter
        CredSSPClientAction    = $stepResults.CredSSPClientAction
        GpoRegistryAction      = $stepResults.GpoRegistryAction
        GpUpdateStatus         = $stepResults.GpUpdateStatus
        ManagementToolsAction  = $stepResults.ManagementToolsAction
        FirewallClientAction   = $stepResults.FirewallClientAction
        CredentialsStored      = $stepResults.CredentialsStored
        RebootRequired         = $stepResults.RebootRequired
        DurationSeconds        = [math]::Round($elapsed.TotalSeconds, 2)
        LogFile                = $script:ActiveLogFile
    }
}
