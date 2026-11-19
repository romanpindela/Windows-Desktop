<#
.SYNOPSIS
    Diagnoses Windows network connectivity, DNS resolution, VPN DNS leaks, TCP port reachability,
    routing tables, and Path MTU, with an optional safe stack repair mode.

.DESCRIPTION
    Diagnose-NetworkAndDns.ps1 is an enterprise troubleshooting utility for Windows 10, Windows 11,
    and Windows Server endpoints designed to rapidly isolate user-side LAN, Wi-Fi, DNS, and VPN
    connectivity failures in a single structured pass.

    Core diagnostic phases:
      1. Active Network Adapters & VPN Detection:
         - Enumerates active physical and virtual adapters (IPv4/IPv6, link speed, DHCP, DNS servers).
         - Detects active VPN tunnels (WireGuard, OpenVPN, Cisco AnyConnect, FortiClient, GlobalProtect,
           TAP/TUN, WAN Miniport, and built-in Windows VPN connections).
      2. Default Gateway Reachability:
         - Tests ICMP reachability, round-trip latency, and packet loss against all active IPv4 default
           gateways using language-independent .NET Ping APIs.
      3. DNS Comparison & VPN DNS Leak Heuristics:
         - Resolves target hostnames via locally configured DNS servers and compares responses and
           latency against public reference resolvers (default: 1.1.1.1 and 8.8.8.8).
         - Evaluates VPN DNS leak indicators: NRPT rules, non-VPN DNS bindings on lower-metric
           interfaces while a VPN adapter is active, and resolution divergence.
      4. TCP Port Connectivity Matrix:
         - Performs fast asynchronous TCP socket probes against key administrative and application ports
           (default: 443, 445, 3389, 5985) with configurable timeout.
      5. Routing & Tunnel Topology:
         - Inspects IPv4 default routes (0.0.0.0/0), interface metrics, and VPN split-tunnel vs
           full-tunnel routing behavior.
      6. Interface MTU & Path MTU Discovery:
         - Reads interface NlMtu values and runs a binary-search ICMP Don't-Fragment (DF) probe to
           identify Path MTU bottlenecks or VPN fragmentation blackholes.
      7. Safe Network Stack Repair (-Repair):
         - Guarded by SupportsShouldProcess (-WhatIf / -Confirm) and SID-based UAC elevation
           (S-1-5-32-544). Flushes DNS client cache, clears ARP neighbor cache, and optionally resets
           the Winsock catalog (netsh winsock reset).

.PARAMETER Run
    Executes the full read-only network, DNS, VPN, TCP port, routing, and MTU diagnostic suite.
    Aliases: -Diagnose, -All

.PARAMETER Repair
    Executes safe network stack repair operations (DNS cache flush, ARP cache clear, and Winsock
    catalog reset). Requires Administrator privileges (SID S-1-5-32-544) and supports -WhatIf / -Confirm.

.PARAMETER SkipWinsockReset
    When used with -Repair, skips 'netsh winsock reset' (only flushes DNS and ARP caches, avoiding
    a reboot recommendation).

.PARAMETER TargetHost
    One or more hostnames to resolve during DNS comparison and leak testing.
    Default: @('cloudflare.com', 'microsoft.com', 'google.com')

.PARAMETER PublicDnsServers
    Public reference DNS servers used to compare against locally configured DNS servers.
    Default: @('1.1.1.1', '8.8.8.8')

.PARAMETER PortTarget
    Optional target host or IP address for TCP port probing (ports 445, 3389, 5985, etc.).
    If omitted, probes the active default gateway for LAN/admin ports and 'microsoft.com' for port 443.

.PARAMETER Ports
    TCP ports to test during connectivity diagnostics.
    Default: @(443, 445, 3389, 5985)

.PARAMETER TcpTimeoutMs
    Timeout in milliseconds for each TCP port probe. Range: 250-15000. Default: 2000.

.PARAMETER MtuTarget
    Target IP or hostname for ICMP Don't-Fragment Path MTU discovery. Default: '1.1.1.1'.

.PARAMETER GenerateHtmlReport
    Generates a standalone responsive HTML diagnostic report with Dark/Light theme toggle.
    Aliases: -ExportHtml

.PARAMETER ReportPath
    Custom file path or directory for the HTML report.
    Aliases: -ExportPath

.PARAMETER OpenReport
    Automatically opens the generated HTML report in the default browser upon completion.

.PARAMETER ExportJson
    Exports the full diagnostic result object to a JSON file.

.PARAMETER JsonPath
    Custom file path or directory for the JSON export.

.PARAMETER PassThru
    Returns the structured diagnostic [PSCustomObject] to the PowerShell pipeline.

.PARAMETER EnableLogging
    Enables structured execution logging to C:\Logs\ (or -LogDirectory).
    Aliases: -Log

.PARAMETER LogDirectory
    Target directory for log files and default report exports. Default: 'C:\Logs'.

.PARAMETER SkipAdminCheck
    Bypasses automatic UAC elevation when running -Repair (useful for automated testing or -WhatIf).

.PARAMETER Help
    Displays the interactive console help screen and exits cleanly.
    Aliases: -h

.EXAMPLE
    .\Diagnose-NetworkAndDns.ps1 -Help
    Displays interactive help, parameter documentation, and usage examples.

.EXAMPLE
    .\Diagnose-NetworkAndDns.ps1 -Run
    Runs the full read-only network, DNS, VPN leak, TCP port, routing, and Path MTU diagnostic suite.

.EXAMPLE
    .\Diagnose-NetworkAndDns.ps1 -Run -PortTarget "dc01.corp.local" -GenerateHtmlReport -OpenReport
    Runs full diagnostics targeting dc01.corp.local for TCP ports and opens the HTML report.

.EXAMPLE
    .\Diagnose-NetworkAndDns.ps1 -Repair -WhatIf
    Previews safe network repair actions (DNS flush, ARP clear, Winsock reset) without applying changes.

.EXAMPLE
    .\Diagnose-NetworkAndDns.ps1 -Run -Repair -SkipWinsockReset -EnableLogging
    Runs diagnostics and flushes DNS + ARP caches with structured logging enabled.

.EXAMPLE
    .\Invoke-GitHubScript.ps1 -UrlToDownload "https://github.com/romanpindela/Windows-Desktop/blob/main/Diagnose-NetworkAndDns/Diagnose-NetworkAndDns.ps1" -ScriptArgs "-Help"
    Downloads and displays help for Diagnose-NetworkAndDns.ps1 directly from GitHub.

.NOTES
    Author:       Roman Pindela
    Email:        roman.pindela@gmail.com
    GitHub:       https://github.com/romanpindela
    Repository:   Windows-Desktop
    Version:      1.0.0
    Date:         2026-11-19
    Requires:     Windows 10 / 11 / Windows Server 2016+, PowerShell 5.1+ or PowerShell 7+
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false)]
    [Alias('Diagnose', 'All')]
    [switch]$Run,

    [Parameter(Mandatory = $false)]
    [switch]$Repair,

    [Parameter(Mandatory = $false)]
    [switch]$SkipWinsockReset,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$TargetHost = @('cloudflare.com', 'microsoft.com', 'google.com'),

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$PublicDnsServers = @('1.1.1.1', '8.8.8.8'),

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$PortTarget,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 65535)]
    [int[]]$Ports = @(443, 445, 3389, 5985),

    [Parameter(Mandatory = $false)]
    [ValidateRange(250, 15000)]
    [int]$TcpTimeoutMs = 2000,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MtuTarget = '1.1.1.1',

    [Parameter(Mandatory = $false)]
    [Alias('ExportHtml')]
    [switch]$GenerateHtmlReport,

    [Parameter(Mandatory = $false)]
    [Alias('ExportPath')]
    [ValidateNotNullOrEmpty()]
    [string]$ReportPath,

    [Parameter(Mandatory = $false)]
    [switch]$OpenReport,

    [Parameter(Mandatory = $false)]
    [switch]$ExportJson,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$JsonPath,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [Alias('Log')]
    [switch]$EnableLogging,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(Mandatory = $false)]
    [switch]$SkipAdminCheck,

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $script:ScriptName       = 'Diagnose-NetworkAndDns'
    $script:ScriptVersion    = '1.0.0'
    $script:ScriptAuthor     = 'Roman Pindela'
    $script:ScriptEmail      = 'roman.pindela@gmail.com'
    $script:ScriptGitHub     = 'https://github.com/romanpindela'
    $script:LastModified     = '2026-11-19'
    $script:SessionTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFilePath      = $null
    $script:EffectiveLogDir  = $LogDirectory
    $script:ShouldExitEarly  = $false

    # --------------------------------------------------------------------------
    # Helper: Interactive Console Help
    # --------------------------------------------------------------------------
    function Show-ScriptHelp {
        [CmdletBinding()]
        param ()

        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host " $($script:ScriptName).ps1 v$($script:ScriptVersion) - Network, DNS & VPN Diagnostics" -ForegroundColor White
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host "Author: $($script:ScriptAuthor) | Email: $($script:ScriptEmail) | GitHub: $($script:ScriptGitHub)" -ForegroundColor DarkGray
        Write-Host "Version: $($script:ScriptVersion) | Last Modified: $($script:LastModified)" -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Diagnoses default gateways, DNS comparison (local vs 1.1.1.1 / 8.8.8.8), VPN DNS' -ForegroundColor Gray
        Write-Host 'leak indicators, TCP ports (443/445/3389/5985), routing, and Path MTU, with an' -ForegroundColor Gray
        Write-Host 'optional safe -Repair mode for DNS, ARP, and Winsock remediation.' -ForegroundColor Gray
        Write-Host ''
        Write-Host 'PARAMETERS:' -ForegroundColor Yellow
        Write-Host '  -Run, -Diagnose, -All   Run full read-only network & DNS diagnostic suite.' -ForegroundColor White
        Write-Host '  -Repair                 Flush DNS/ARP caches and reset Winsock (Admin + -WhatIf).' -ForegroundColor White
        Write-Host '  -SkipWinsockReset       Skip netsh winsock reset during -Repair.' -ForegroundColor White
        Write-Host '  -TargetHost <String[]>  Hostnames for DNS resolution comparison.' -ForegroundColor White
        Write-Host '  -PublicDnsServers <[]>  Public DNS resolvers (Default: 1.1.1.1, 8.8.8.8).' -ForegroundColor White
        Write-Host '  -PortTarget <String>    Target host/IP for TCP port matrix.' -ForegroundColor White
        Write-Host '  -Ports <Int[]>          TCP ports to probe (Default: 443, 445, 3389, 5985).' -ForegroundColor White
        Write-Host '  -TcpTimeoutMs <Int>     TCP probe timeout in ms (Default: 2000).' -ForegroundColor White
        Write-Host '  -MtuTarget <String>     Target for Path MTU DF-bit probe (Default: 1.1.1.1).' -ForegroundColor White
        Write-Host '  -GenerateHtmlReport     Export standalone HTML report (-ExportHtml).' -ForegroundColor White
        Write-Host '  -ReportPath <Path>      Custom HTML report file or directory (-ExportPath).' -ForegroundColor White
        Write-Host '  -OpenReport             Open generated HTML report in default browser.' -ForegroundColor White
        Write-Host '  -ExportJson             Export diagnostic results to JSON.' -ForegroundColor White
        Write-Host '  -JsonPath <Path>        Custom JSON file or directory.' -ForegroundColor White
        Write-Host '  -PassThru               Return structured [PSCustomObject] to pipeline.' -ForegroundColor White
        Write-Host '  -EnableLogging, -Log    Write timestamped execution log to C:\Logs\.' -ForegroundColor White
        Write-Host '  -LogDirectory <Path>    Override log/report output folder (Default: C:\Logs).' -ForegroundColor White
        Write-Host '  -SkipAdminCheck         Bypass UAC elevation check for -Repair testing.' -ForegroundColor White
        Write-Host '  -Help, -h               Display this help screen and exit.' -ForegroundColor White
        Write-Host ''
        Write-Host 'EXAMPLES:' -ForegroundColor Yellow
        Write-Host '  .\Diagnose-NetworkAndDns.ps1 -Run' -ForegroundColor Gray
        Write-Host '  .\Diagnose-NetworkAndDns.ps1 -Run -PortTarget "10.0.0.1" -GenerateHtmlReport -OpenReport' -ForegroundColor Gray
        Write-Host '  .\Diagnose-NetworkAndDns.ps1 -Repair -WhatIf' -ForegroundColor Gray
        Write-Host '  .\Diagnose-NetworkAndDns.ps1 -Run -Repair -SkipWinsockReset -EnableLogging' -ForegroundColor Gray
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host ''
    }

    # --------------------------------------------------------------------------
    # Helper: Structured File Logging
    # --------------------------------------------------------------------------
    function Initialize-LogDirectory {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$PreferredDirectory
        )

        try {
            if (-not (Test-Path -Path $PreferredDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $PreferredDirectory -Force | Out-Null
            }
            return $PreferredDirectory
        }
        catch {
            $fallback = Join-Path -Path $env:TEMP -ChildPath 'Logs'
            if (-not (Test-Path -Path $fallback -PathType Container)) {
                New-Item -ItemType Directory -Path $fallback -Force | Out-Null
            }
            return $fallback
        }
    }

    function Write-LogEntry {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
            [string]$Level = 'INFO'
        )

        Write-Verbose "[$Level] $Message"
        if (-not $EnableLogging -or [string]::IsNullOrWhiteSpace($script:LogFilePath)) {
            return
        }

        $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
        try {
            [System.IO.File]::AppendAllLines($script:LogFilePath, [string[]]@($line), [System.Text.Encoding]::UTF8)
        }
        catch {
            Write-Verbose "Failed to append log entry: $($_.Exception.Message)"
        }
    }

    # --------------------------------------------------------------------------
    # Helper: SID-Based Administrator Check & UAC Elevation (S-1-5-32-544)
    # --------------------------------------------------------------------------
    function Test-IsAdministrator {
        [CmdletBinding()]
        [OutputType([bool])]
        param ()

        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $adminSid  = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
        return $principal.IsInRole($adminSid)
    }

    function Invoke-UacElevation {
        [CmdletBinding()]
        param ()

        $exePath = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
        $argList = New-Object System.Collections.Generic.List[string]
        $argList.Add('-NoProfile')
        $argList.Add('-ExecutionPolicy')
        $argList.Add('Bypass')
        $argList.Add('-File')
        $argList.Add("`"$PSCommandPath`"")

        foreach ($kvp in $PSBoundParameters.GetEnumerator()) {
            $key = $kvp.Key
            $val = $kvp.Value
            if ($val -is [switch]) {
                if ($val.IsPresent) {
                    $argList.Add("-$key")
                }
            }
            elseif ($val -is [array]) {
                $joined = ($val | ForEach-Object { "`"$_`"" }) -join ','
                $argList.Add("-$key")
                $argList.Add($joined)
            }
            else {
                $argList.Add("-$key")
                $argList.Add("`"$val`"")
            }
        }

        Write-Host '[!] Administrator privileges (SID S-1-5-32-544) are required for -Repair. Requesting UAC elevation...' -ForegroundColor Yellow
        Start-Process -FilePath $exePath -ArgumentList ($argList -join ' ') -Verb RunAs
    }

    # --------------------------------------------------------------------------
    # Helper: HTML Encoding
    # --------------------------------------------------------------------------
    function ConvertTo-SafeHtml {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory = $false)]
            [AllowNull()]
            [string]$Text
        )

        if ($null -eq $Text) { return '' }
        return [System.Net.WebUtility]::HtmlEncode($Text)
    }

    # --------------------------------------------------------------------------
    # Diagnostic Module 1: Active Network Adapters & VPN Detection
    # --------------------------------------------------------------------------
    function Get-ActiveNetworkAdapterSummary {
        [CmdletBinding()]
        param ()

        $vpnPattern = 'VPN|WireGuard|OpenVPN|TAP-Windows|Wintun|AnyConnect|Forti|GlobalProtect|Pulse|Juniper|Check Point|WAN Miniport|Tailscale|ZeroTier|NordLynx|Proton|Cisco|PANGP'
        $adapters = @()
        $ipConfigs = @()

        try {
            $netAdapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' })
            $ipConfigs   = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue)
        }
        catch {
            Write-LogEntry -Message "Get-NetAdapter failed: $($_.Exception.Message)" -Level 'WARN'
            $netAdapters = @()
        }

        $activeVpnConnections = @()
        try {
            $activeVpnConnections = @(Get-VpnConnection -ErrorAction SilentlyContinue | Where-Object { $_.ConnectionStatus -eq 'Connected' })
        }
        catch {
            Write-Verbose "Get-VpnConnection not available or returned no results."
        }
        $activeVpnNames = @($activeVpnConnections | ForEach-Object { $_.Name })

        foreach ($adapter in $netAdapters) {
            $cfg = $ipConfigs | Where-Object { $_.InterfaceIndex -eq $adapter.ifIndex } | Select-Object -First 1
            $ipv4 = if ($cfg -and $cfg.IPv4Address) { (@($cfg.IPv4Address | ForEach-Object { $_.IPAddress }) -join ', ') } else { 'None' }
            $gw   = if ($cfg -and $cfg.IPv4DefaultGateway) { (@($cfg.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join ', ') } else { 'None' }
            $dns  = if ($cfg -and $cfg.DNSServer) {
                $servers = @($cfg.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | ForEach-Object { $_.ServerAddresses })
                if ($servers.Count -gt 0) { $servers -join ', ' } else { 'None' }
            } else { 'None' }

            $ipIf = Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
            $metric = if ($ipIf) { $ipIf.InterfaceMetric } else { $null }
            $mtu    = if ($ipIf) { $ipIf.NlMtu } else { $null }

            $isVpn = ($adapter.InterfaceDescription -match $vpnPattern) -or
                     ($adapter.Name -match $vpnPattern) -or
                     ($activeVpnNames -contains $adapter.Name)

            $adapters += [PSCustomObject]@{
                Name                 = $adapter.Name
                InterfaceIndex       = $adapter.ifIndex
                InterfaceDescription = $adapter.InterfaceDescription
                Status               = [string]$adapter.Status
                LinkSpeed            = $adapter.LinkSpeed
                MacAddress           = $adapter.MacAddress
                IPv4Address          = $ipv4
                DefaultGateway       = $gw
                DnsServers           = $dns
                InterfaceMetric      = $metric
                InterfaceMtu         = $mtu
                IsVpnAdapter         = [bool]$isVpn
            }
        }

        return [PSCustomObject]@{
            Adapters             = $adapters
            VpnDetected          = (@($adapters | Where-Object { $_.IsVpnAdapter }).Count -gt 0) -or ($activeVpnConnections.Count -gt 0)
            VpnAdapterNames      = @($adapters | Where-Object { $_.IsVpnAdapter } | Select-Object -ExpandProperty Name)
            WindowsVpnTunnels    = @($activeVpnConnections | Select-Object -ExpandProperty Name)
        }
    }

    # --------------------------------------------------------------------------
    # Diagnostic Module 2: Default Gateway Reachability (Language-Independent)
    # --------------------------------------------------------------------------
    function Test-GatewayConnectivity {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [object[]]$Adapters
        )

        $results = @()
        $gateways = @($Adapters | Where-Object { $_.DefaultGateway -and $_.DefaultGateway -ne 'None' } |
            ForEach-Object {
                foreach ($g in ($_.DefaultGateway -split ',\s*')) {
                    [PSCustomObject]@{
                        InterfaceName = $_.Name
                        GatewayIp     = $g.Trim()
                        IsVpn         = $_.IsVpnAdapter
                    }
                }
            } | Sort-Object GatewayIp -Unique)

        if ($gateways.Count -eq 0) {
            return @([PSCustomObject]@{
                InterfaceName  = 'None'
                GatewayIp      = 'None'
                Reachable      = $false
                Sent           = 0
                Received       = 0
                PacketLossPct  = 100
                AvgLatencyMs   = $null
                Status         = 'FAIL'
                Notes          = 'No IPv4 default gateway detected on active adapters.'
            })
        }

        $ping = New-Object System.Net.NetworkInformation.Ping
        try {
            foreach ($gw in $gateways) {
                $sent = 4
                $received = 0
                $rtts = New-Object System.Collections.Generic.List[long]

                for ($i = 0; $i -lt $sent; $i++) {
                    try {
                        $reply = $ping.Send($gw.GatewayIp, 1500)
                        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                            $received++
                            $rtts.Add($reply.RoundtripTime)
                        }
                    }
                    catch {
                        Write-Verbose "Gateway ping attempt $($i + 1) to $($gw.GatewayIp) threw: $($_.Exception.Message)"
                    }
                }

                $lossPct = [math]::Round((($sent - $received) / $sent) * 100, 1)
                $avgMs   = if ($rtts.Count -gt 0) { [math]::Round(($rtts | Measure-Object -Average).Average, 1) } else { $null }

                $status = if ($received -eq $sent -and $avgMs -le 50) { 'PASS' }
                          elseif ($received -gt 0) { 'WARN' }
                          else { 'FAIL' }

                $notes = if ($status -eq 'PASS') { 'Gateway responsive with zero packet loss.' }
                         elseif ($received -gt 0) { "Intermittent gateway response ($lossPct% loss, avg ${avgMs}ms)." }
                         else { 'Gateway did not respond to ICMP (may be unreachable or blocking ICMP).' }

                $results += [PSCustomObject]@{
                    InterfaceName = $gw.InterfaceName
                    GatewayIp     = $gw.GatewayIp
                    Reachable     = ($received -gt 0)
                    Sent          = $sent
                    Received      = $received
                    PacketLossPct = $lossPct
                    AvgLatencyMs  = $avgMs
                    Status        = $status
                    Notes         = $notes
                }
            }
        }
        finally {
            $ping.Dispose()
        }

        return $results
    }

    # --------------------------------------------------------------------------
    # Diagnostic Module 3: DNS Comparison & VPN DNS Leak Heuristics
    # --------------------------------------------------------------------------
    function Test-DnsResolutionAndLeak {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string[]]$Hosts,

            [Parameter(Mandatory = $true)]
            [string[]]$PublicResolvers,

            [Parameter(Mandatory = $true)]
            [object]$AdapterSummary
        )

        $comparisons = @()

        foreach ($h in $Hosts) {
            # Local system DNS resolution
            $localSw = [System.Diagnostics.Stopwatch]::StartNew()
            $localIps = @()
            $localOk  = $false
            $localErr = $null
            try {
                $localRes = @(Resolve-DnsName -Name $h -Type A -DnsOnly -NoHostsFile -ErrorAction Stop | Where-Object { $_.QueryType -eq 'A' })
                $localIps = @($localRes | ForEach-Object { $_.IPAddress } | Sort-Object -Unique)
                $localOk  = ($localIps.Count -gt 0)
            }
            catch {
                $localErr = $_.Exception.Message
            }
            $localSw.Stop()

            # Public resolvers comparison
            $publicDetails = @()
            $anyPublicOk   = $false
            foreach ($pub in $PublicResolvers) {
                $pubSw = [System.Diagnostics.Stopwatch]::StartNew()
                $pubIps = @()
                $pubOk  = $false
                $pubErr = $null
                try {
                    $pubRes = @(Resolve-DnsName -Name $h -Type A -Server $pub -DnsOnly -NoHostsFile -ErrorAction Stop | Where-Object { $_.QueryType -eq 'A' })
                    $pubIps = @($pubRes | ForEach-Object { $_.IPAddress } | Sort-Object -Unique)
                    $pubOk  = ($pubIps.Count -gt 0)
                    if ($pubOk) { $anyPublicOk = $true }
                }
                catch {
                    $pubErr = $_.Exception.Message
                }
                $pubSw.Stop()

                $publicDetails += [PSCustomObject]@{
                    Server    = $pub
                    Success   = $pubOk
                    LatencyMs = $pubSw.ElapsedMilliseconds
                    Addresses = ($pubIps -join ', ')
                    Error     = $pubErr
                }
            }

            $status = if ($localOk -and $anyPublicOk) { 'PASS' }
                      elseif (-not $localOk -and $anyPublicOk) { 'FAIL' }
                      elseif ($localOk -and -not $anyPublicOk) { 'WARN' }
                      else { 'FAIL' }

            $notes = if ($localOk -and $anyPublicOk) {
                'Local DNS and public resolvers both succeeded.'
            }
            elseif (-not $localOk -and $anyPublicOk) {
                'Local DNS failed while public DNS succeeded (local DNS misconfiguration or upstream outage).'
            }
            elseif ($localOk -and -not $anyPublicOk) {
                'Local DNS succeeded; direct UDP/53 to public resolvers blocked (common behind corporate firewall/VPN).'
            }
            else {
                'Both local and public DNS resolution failed (no internet or DNS blocked).'
            }

            $comparisons += [PSCustomObject]@{
                TargetHost       = $h
                LocalDnsOk       = $localOk
                LocalLatencyMs   = $localSw.ElapsedMilliseconds
                LocalAddresses   = if ($localIps.Count -gt 0) { $localIps -join ', ' } else { 'FAILED' }
                LocalError       = $localErr
                PublicResults    = $publicDetails
                PublicSummary    = ($publicDetails | ForEach-Object {
                    if ($_.Success) { "$($_.Server): OK ($($_.LatencyMs)ms)" } else { "$($_.Server): FAIL" }
                }) -join ' | '
                Status           = $status
                Notes            = $notes
            }
        }

        # VPN DNS Leak Heuristics
        $nrptRules = @()
        try {
            $nrptRules = @(Get-DnsClientNrptRule -ErrorAction SilentlyContinue)
        }
        catch {
            Write-Verbose "Get-DnsClientNrptRule unavailable."
        }

        $leakRisk   = 'NotApplicable'
        $leakStatus = 'PASS'
        $leakNotes  = 'No active VPN adapter detected; VPN DNS leak check not applicable.'

        if ($AdapterSummary.VpnDetected) {
            $vpnAdapters    = @($AdapterSummary.Adapters | Where-Object { $_.IsVpnAdapter })
            $nonVpnAdapters = @($AdapterSummary.Adapters | Where-Object { -not $_.IsVpnAdapter -and $_.DnsServers -ne 'None' })

            $vpnMinMetric    = ($vpnAdapters | Where-Object { $null -ne $_.InterfaceMetric } | Measure-Object -Property InterfaceMetric -Minimum).Minimum
            $nonVpnMinMetric = ($nonVpnAdapters | Where-Object { $null -ne $_.InterfaceMetric } | Measure-Object -Property InterfaceMetric -Minimum).Minimum

            $vpnHasDns = (@($vpnAdapters | Where-Object { $_.DnsServers -ne 'None' }).Count -gt 0)
            $directPublicDnsReachable = (@($comparisons | ForEach-Object { $_.PublicResults } | Where-Object { $_.Success }).Count -gt 0)

            $findings = New-Object System.Collections.Generic.List[string]
            if (-not $vpnHasDns) {
                $findings.Add('Active VPN interface has no IPv4 DNS server assigned; queries fall back to physical NIC DNS.')
            }
            if ($null -ne $vpnMinMetric -and $null -ne $nonVpnMinMetric -and $nonVpnMinMetric -le $vpnMinMetric -and $nrptRules.Count -eq 0) {
                $findings.Add("Non-VPN adapter metric ($nonVpnMinMetric) is <= VPN adapter metric ($vpnMinMetric) without NRPT rules.")
            }
            if ($directPublicDnsReachable -and $nrptRules.Count -eq 0) {
                $findings.Add('Direct UDP/53 queries to public resolvers (1.1.1.1 / 8.8.8.8) bypass local DNS enforcement.')
            }

            if ($findings.Count -ge 2 -or (-not $vpnHasDns)) {
                $leakRisk   = 'High'
                $leakStatus = 'WARN'
                $leakNotes  = $findings -join ' '
            }
            elseif ($findings.Count -eq 1) {
                $leakRisk   = 'Moderate'
                $leakStatus = 'WARN'
                $leakNotes  = $findings -join ' '
            }
            else {
                $leakRisk   = 'Low'
                $leakStatus = 'PASS'
                $leakNotes  = "VPN adapter ($($AdapterSummary.VpnAdapterNames -join ', ')) holds preferred DNS metric or NRPT enforcement."
            }
        }

        return [PSCustomObject]@{
            Comparisons    = $comparisons
            VpnDetected    = $AdapterSummary.VpnDetected
            NrptRuleCount  = $nrptRules.Count
            DnsLeakRisk    = $leakRisk
            DnsLeakStatus  = $leakStatus
            DnsLeakNotes   = $leakNotes
        }
    }

    # --------------------------------------------------------------------------
    # Diagnostic Module 4: Fast Async TCP Port Connectivity Matrix
    # --------------------------------------------------------------------------
    function Test-TcpPortMatrix {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [string]$ExplicitTarget,

            [Parameter(Mandatory = $true)]
            [int[]]$PortList,

            [Parameter(Mandatory = $true)]
            [int]$TimeoutMs,

            [Parameter(Mandatory = $true)]
            [object[]]$GatewayResults
        )

        $portDescriptions = @{
            443  = 'HTTPS'
            445  = 'SMB / File Sharing'
            3389 = 'RDP (Remote Desktop)'
            5985 = 'WinRM (HTTP)'
            5986 = 'WinRM (HTTPS)'
            53   = 'DNS (TCP)'
            80   = 'HTTP'
            22   = 'SSH'
        }

        $primaryGwObj = $GatewayResults | Where-Object { $_.GatewayIp -ne 'None' } | Select-Object -First 1
        $primaryGw = if ($primaryGwObj) { $primaryGwObj.GatewayIp } else { $null }
        $results = @()

        foreach ($port in $PortList) {
            $target = if (-not [string]::IsNullOrWhiteSpace($ExplicitTarget)) {
                $ExplicitTarget
            }
            elseif ($port -eq 443) {
                'microsoft.com'
            }
            elseif (-not [string]::IsNullOrWhiteSpace($primaryGw)) {
                $primaryGw
            }
            else {
                '127.0.0.1'
            }

            $service = if ($portDescriptions.ContainsKey($port)) { $portDescriptions[$port] } else { 'Custom TCP' }
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $connected = $false
            $errorMsg  = $null

            $client = New-Object System.Net.Sockets.TcpClient
            try {
                $iar = $client.BeginConnect($target, $port, $null, $null)
                $waitOk = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
                if ($waitOk -and $client.Connected) {
                    $client.EndConnect($iar)
                    $connected = $true
                }
                else {
                    $errorMsg = "Timed out after ${TimeoutMs}ms"
                }
            }
            catch {
                $errorMsg = $_.Exception.InnerException.Message
                if ([string]::IsNullOrWhiteSpace($errorMsg)) {
                    $errorMsg = $_.Exception.Message
                }
            }
            finally {
                $sw.Stop()
                $client.Dispose()
            }

            $status = if ($connected) { 'PASS' }
                      elseif ($port -eq 443) { 'FAIL' }
                      else { 'INFO' }

            $results += [PSCustomObject]@{
                Target    = $target
                Port      = $port
                Service   = $service
                Open      = $connected
                LatencyMs = $sw.ElapsedMilliseconds
                Status    = $status
                Notes     = if ($connected) { 'TCP handshake succeeded.' } else { $errorMsg }
            }
        }

        return $results
    }

    # --------------------------------------------------------------------------
    # Diagnostic Module 5: Routing & Tunnel Topology
    # --------------------------------------------------------------------------
    function Get-RoutingSummary {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [object]$AdapterSummary
        )

        $defaultRoutes = @()
        try {
            $routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -AddressFamily IPv4 -ErrorAction Stop |
                Sort-Object -Property RouteMetric, InterfaceMetric)

            foreach ($r in $routes) {
                $adapter = $AdapterSummary.Adapters | Where-Object { $_.InterfaceIndex -eq $r.InterfaceIndex } | Select-Object -First 1
                $defaultRoutes += [PSCustomObject]@{
                    DestinationPrefix = $r.DestinationPrefix
                    NextHop           = $r.NextHop
                    InterfaceAlias    = $r.InterfaceAlias
                    InterfaceIndex    = $r.InterfaceIndex
                    RouteMetric       = $r.RouteMetric
                    InterfaceMetric   = $r.InterfaceMetric
                    TotalMetric       = ($r.RouteMetric + $r.InterfaceMetric)
                    IsVpnRoute        = if ($adapter) { $adapter.IsVpnAdapter } else { $false }
                }
            }
        }
        catch {
            Write-LogEntry -Message "Get-NetRoute failed: $($_.Exception.Message)" -Level 'WARN'
        }

        $tunnelMode = 'No VPN'
        if ($AdapterSummary.VpnDetected) {
            $primaryRoute = $defaultRoutes | Select-Object -First 1
            if ($primaryRoute -and $primaryRoute.IsVpnRoute) {
                $tunnelMode = 'Full-Tunnel VPN (default route via VPN)'
            }
            else {
                $tunnelMode = 'Split-Tunnel VPN (default route via physical NIC)'
            }
        }

        return [PSCustomObject]@{
            DefaultRoutes = $defaultRoutes
            TunnelMode    = $tunnelMode
            RouteCount    = $defaultRoutes.Count
            Status        = if ($defaultRoutes.Count -gt 0) { 'PASS' } else { 'FAIL' }
        }
    }

    # --------------------------------------------------------------------------
    # Diagnostic Module 6: Interface MTU & Path MTU Discovery (DF-bit Binary Search)
    # --------------------------------------------------------------------------
    function Test-PathMtu {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Target,

            [Parameter(Mandatory = $true)]
            [object[]]$Adapters
        )

        $ping = New-Object System.Net.NetworkInformation.Ping
        $options = New-Object System.Net.NetworkInformation.PingOptions(128, $true)
        $bestPayload = $null
        $probeReachable = $false

        try {
            # Quick reachability check with small DF packet (1200 bytes payload)
            $smallBuf = New-Object byte[] 1200
            $initReply = $ping.Send($Target, 1500, $smallBuf, $options)
            if ($initReply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $probeReachable = $true
                $low  = 1200
                $high = 1472
                $bestPayload = 1200

                while ($low -le $high) {
                    $mid = [int][math]::Floor(($low + $high) / 2)
                    $buf = New-Object byte[] $mid
                    $reply = $ping.Send($Target, 1500, $buf, $options)
                    if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                        $bestPayload = $mid
                        $low = $mid + 1
                    }
                    else {
                        $high = $mid - 1
                    }
                }
            }
        }
        catch {
            Write-LogEntry -Message "Path MTU probe to '$Target' failed: $($_.Exception.Message)" -Level 'WARN'
        }
        finally {
            $ping.Dispose()
        }

        $discoveredMtu = if ($null -ne $bestPayload) { $bestPayload + 28 } else { $null }
        $minAdapterMtu = ($Adapters | Where-Object { $null -ne $_.InterfaceMtu } | Measure-Object -Property InterfaceMtu -Minimum).Minimum

        $status = if (-not $probeReachable) { 'WARN' }
                  elseif ($discoveredMtu -ge 1400) { 'PASS' }
                  else { 'WARN' }

        $notes = if (-not $probeReachable) {
            "ICMP DF probe to $Target did not succeed (ICMP blocked or offline)."
        }
        elseif ($discoveredMtu -eq 1500) {
            'Standard Ethernet Path MTU (1500 bytes) verified without fragmentation.'
        }
        else {
            "Reduced Path MTU detected ($discoveredMtu bytes; payload $bestPayload + 28B header) - typical for PPPoE/VPN tunnels."
        }

        return [PSCustomObject]@{
            Target             = $Target
            ProbeReachable     = $probeReachable
            MaxIcmpPayload     = $bestPayload
            DiscoveredPathMtu  = $discoveredMtu
            MinInterfaceMtu    = $minAdapterMtu
            Status             = $status
            Notes              = $notes
        }
    }

    # --------------------------------------------------------------------------
    # Remediation Module: Safe Network Stack Repair (-Repair)
    # --------------------------------------------------------------------------
    function Repair-NetworkStack {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [Parameter(Mandatory = $false)]
            [switch]$SkipWinsock
        )

        $actions = @()
        $rebootRecommended = $false

        # 1. Flush DNS Client Cache
        if ($PSCmdlet.ShouldProcess('Local Windows DNS Client Cache', 'Clear-DnsClientCache')) {
            try {
                Clear-DnsClientCache -ErrorAction Stop
                Write-LogEntry -Message 'Cleared DNS client cache via Clear-DnsClientCache.' -Level 'SUCCESS'
                $actions += [PSCustomObject]@{ Action = 'Flush DNS Cache'; Status = 'SUCCESS'; Notes = 'DNS client cache cleared.' }
            }
            catch {
                Write-LogEntry -Message "Failed to clear DNS cache: $($_.Exception.Message)" -Level 'ERROR'
                $actions += [PSCustomObject]@{ Action = 'Flush DNS Cache'; Status = 'FAIL'; Notes = $_.Exception.Message }
            }
        }
        else {
            $actions += [PSCustomObject]@{ Action = 'Flush DNS Cache'; Status = 'WHATIF'; Notes = 'Skipped due to -WhatIf / user declined.' }
        }

        # 2. Clear ARP / Neighbor Cache
        if ($PSCmdlet.ShouldProcess('Local IPv4 ARP Neighbor Cache', 'netsh interface ip delete arpcache')) {
            try {
                $arpOut = & netsh.exe interface ip delete arpcache 2>&1
                $arpExit = $LASTEXITCODE
                if ($arpExit -eq 0) {
                    Write-LogEntry -Message 'Cleared IPv4 ARP neighbor cache.' -Level 'SUCCESS'
                    $actions += [PSCustomObject]@{ Action = 'Clear ARP Cache'; Status = 'SUCCESS'; Notes = 'IPv4 ARP cache cleared.' }
                }
                else {
                    $msg = ($arpOut | Out-String).Trim()
                    Write-LogEntry -Message "ARP cache clear returned exit code ${arpExit}: $msg" -Level 'WARN'
                    $actions += [PSCustomObject]@{ Action = 'Clear ARP Cache'; Status = 'WARN'; Notes = $msg }
                }
            }
            catch {
                Write-LogEntry -Message "Failed to clear ARP cache: $($_.Exception.Message)" -Level 'ERROR'
                $actions += [PSCustomObject]@{ Action = 'Clear ARP Cache'; Status = 'FAIL'; Notes = $_.Exception.Message }
            }
        }
        else {
            $actions += [PSCustomObject]@{ Action = 'Clear ARP Cache'; Status = 'WHATIF'; Notes = 'Skipped due to -WhatIf / user declined.' }
        }

        # 3. Reset Winsock Catalog (unless skipped)
        if (-not $SkipWinsock) {
            if ($PSCmdlet.ShouldProcess('Windows Winsock Catalog', 'netsh winsock reset')) {
                try {
                    $wsOut = & netsh.exe winsock reset 2>&1
                    $wsExit = $LASTEXITCODE
                    if ($wsExit -eq 0) {
                        $rebootRecommended = $true
                        Write-LogEntry -Message 'Reset Winsock catalog successfully. System reboot recommended.' -Level 'SUCCESS'
                        $actions += [PSCustomObject]@{ Action = 'Reset Winsock Catalog'; Status = 'SUCCESS'; Notes = 'Winsock catalog reset. Reboot recommended to complete.' }
                    }
                    else {
                        $msg = ($wsOut | Out-String).Trim()
                        Write-LogEntry -Message "Winsock reset returned exit code ${wsExit}: $msg" -Level 'WARN'
                        $actions += [PSCustomObject]@{ Action = 'Reset Winsock Catalog'; Status = 'WARN'; Notes = $msg }
                    }
                }
                catch {
                    Write-LogEntry -Message "Failed to reset Winsock catalog: $($_.Exception.Message)" -Level 'ERROR'
                    $actions += [PSCustomObject]@{ Action = 'Reset Winsock Catalog'; Status = 'FAIL'; Notes = $_.Exception.Message }
                }
            }
            else {
                $actions += [PSCustomObject]@{ Action = 'Reset Winsock Catalog'; Status = 'WHATIF'; Notes = 'Skipped due to -WhatIf / user declined.' }
            }
        }
        else {
            $actions += [PSCustomObject]@{ Action = 'Reset Winsock Catalog'; Status = 'SKIPPED'; Notes = 'Skipped via -SkipWinsockReset.' }
        }

        return [PSCustomObject]@{
            Executed          = $true
            RebootRecommended = $rebootRecommended
            Actions           = $actions
        }
    }

    # --------------------------------------------------------------------------
    # Reporting: Console Output
    # --------------------------------------------------------------------------
    function Write-ConsoleReport {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Report
        )

        $statusColor = @{
            'PASS'    = 'Green'
            'SUCCESS' = 'Green'
            'WARN'    = 'Yellow'
            'FAIL'    = 'Red'
            'INFO'    = 'Cyan'
            'WHATIF'  = 'Magenta'
            'SKIPPED' = 'DarkGray'
        }

        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host " NETWORK & DNS DIAGNOSTIC REPORT | $($Report.ComputerName) | $($Report.Timestamp)" -ForegroundColor White
        Write-Host " $($script:ScriptName).ps1 v$($script:ScriptVersion) | Author: $($script:ScriptAuthor) ($($script:ScriptGitHub))" -ForegroundColor DarkGray
        Write-Host '================================================================================' -ForegroundColor Cyan

        # 1. Adapters & VPN
        Write-Host "`n[1] ACTIVE NETWORK ADAPTERS & VPN STATUS" -ForegroundColor Yellow
        $vpnLabel = if ($Report.AdapterSummary.VpnDetected) { "DETECTED ($($Report.AdapterSummary.VpnAdapterNames -join ', '))" } else { 'None' }
        Write-Host "    Active VPN  : $vpnLabel" -ForegroundColor $(if ($Report.AdapterSummary.VpnDetected) { 'Cyan' } else { 'Gray' })
        Write-Host "    Tunnel Mode : $($Report.RoutingSummary.TunnelMode)" -ForegroundColor Gray
        foreach ($a in $Report.AdapterSummary.Adapters) {
            $tag = if ($a.IsVpnAdapter) { '[VPN]' } else { '[NIC]' }
            Write-Host ("    {0,-6} {1,-22} IP: {2,-16} GW: {3,-15} DNS: {4} (MTU: {5}, Metric: {6})" -f $tag, $a.Name, $a.IPv4Address, $a.DefaultGateway, $a.DnsServers, $a.InterfaceMtu, $a.InterfaceMetric) -ForegroundColor White
        }

        # 2. Default Gateways
        Write-Host "`n[2] DEFAULT GATEWAY REACHABILITY" -ForegroundColor Yellow
        foreach ($g in $Report.GatewayTests) {
            $c = $statusColor[$g.Status]
            Write-Host ("    [{0,-4}] {1,-16} ({2}) | Loss: {3}% | Avg: {4} ms | {5}" -f $g.Status, $g.GatewayIp, $g.InterfaceName, $g.PacketLossPct, $(if ($null -ne $g.AvgLatencyMs) { $g.AvgLatencyMs } else { 'N/A' }), $g.Notes) -ForegroundColor $c
        }

        # 3. DNS Comparison & Leak Check
        Write-Host "`n[3] DNS RESOLUTION COMPARISON (LOCAL vs PUBLIC)" -ForegroundColor Yellow
        foreach ($d in $Report.DnsDiagnostics.Comparisons) {
            $c = $statusColor[$d.Status]
            Write-Host ("    [{0,-4}] {1,-18} Local: {2} ({3}ms) | {4}" -f $d.Status, $d.TargetHost, $(if ($d.LocalDnsOk) { 'OK' } else { 'FAIL' }), $d.LocalLatencyMs, $d.PublicSummary) -ForegroundColor $c
        }
        $lc = $statusColor[$Report.DnsDiagnostics.DnsLeakStatus]
        Write-Host ("    [{0,-4}] VPN DNS Leak Risk: {1} (NRPT Rules: {2}) - {3}" -f $Report.DnsDiagnostics.DnsLeakStatus, $Report.DnsDiagnostics.DnsLeakRisk, $Report.DnsDiagnostics.NrptRuleCount, $Report.DnsDiagnostics.DnsLeakNotes) -ForegroundColor $lc

        # 4. TCP Port Matrix
        Write-Host "`n[4] TCP PORT CONNECTIVITY MATRIX" -ForegroundColor Yellow
        foreach ($p in $Report.TcpPortTests) {
            $c = $statusColor[$p.Status]
            $state = if ($p.Open) { 'OPEN' } else { 'CLOSED/FILTERED' }
            Write-Host ("    [{0,-4}] {1}:{2,-5} ({3,-20}) -> {4,-15} ({5}ms) {6}" -f $p.Status, $p.Target, $p.Port, $p.Service, $state, $p.LatencyMs, $p.Notes) -ForegroundColor $c
        }

        # 5. Routing & Path MTU
        Write-Host "`n[5] ROUTING & PATH MTU DISCOVERY" -ForegroundColor Yellow
        foreach ($r in $Report.RoutingSummary.DefaultRoutes) {
            Write-Host ("    [INFO] 0.0.0.0/0 -> {0,-16} via {1,-22} (Total Metric: {2})" -f $r.NextHop, $r.InterfaceAlias, $r.TotalMetric) -ForegroundColor Gray
        }
        $mc = $statusColor[$Report.PathMtu.Status]
        $mtuDisplay = if ($null -ne $Report.PathMtu.DiscoveredPathMtu) { "$($Report.PathMtu.DiscoveredPathMtu) bytes" } else { 'Undetermined' }
        Write-Host ("    [{0,-4}] Path MTU to {1}: {2} | {3}" -f $Report.PathMtu.Status, $Report.PathMtu.Target, $mtuDisplay, $Report.PathMtu.Notes) -ForegroundColor $mc

        # 6. Repair Results (if executed)
        if ($Report.RepairResults) {
            Write-Host "`n[6] NETWORK STACK REPAIR SUMMARY" -ForegroundColor Yellow
            foreach ($act in $Report.RepairResults.Actions) {
                $ac = $statusColor[$act.Status]
                Write-Host ("    [{0,-7}] {1,-24} -> {2}" -f $act.Status, $act.Action, $act.Notes) -ForegroundColor $ac
            }
            if ($Report.RepairResults.RebootRecommended) {
                Write-Host '    [!] A system restart is recommended to finalize the Winsock catalog reset.' -ForegroundColor Yellow
            }
        }

        $oc = $statusColor[$Report.OverallStatus]
        Write-Host ''
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host " OVERALL DIAGNOSTIC VERDICT: [$($Report.OverallStatus)]" -ForegroundColor $oc
        Write-Host '================================================================================' -ForegroundColor Cyan
        Write-Host ''
    }

    # --------------------------------------------------------------------------
    # Reporting: Standalone Responsive HTML Dashboard
    # --------------------------------------------------------------------------
    function Export-HtmlDiagnosticReport {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Report,

            [Parameter(Mandatory = $true)]
            [string]$DestinationPath
        )

        $badgeClass = {
            param([string]$S)
            switch ($S) {
                'PASS'    { 'badge-pass' }
                'SUCCESS' { 'badge-pass' }
                'WARN'    { 'badge-warn' }
                'FAIL'    { 'badge-fail' }
                default   { 'badge-info' }
            }
        }

        $adapterRows = ($Report.AdapterSummary.Adapters | ForEach-Object {
            "<tr><td>$(ConvertTo-SafeHtml $_.Name)</td><td>$(if ($_.IsVpnAdapter) { '<span class="badge badge-info">VPN</span>' } else { 'Physical/Virtual' })</td><td>$(ConvertTo-SafeHtml $_.IPv4Address)</td><td>$(ConvertTo-SafeHtml $_.DefaultGateway)</td><td>$(ConvertTo-SafeHtml $_.DnsServers)</td><td>$($_.InterfaceMtu)</td><td>$($_.InterfaceMetric)</td></tr>"
        }) -join "`n"

        $gwRows = ($Report.GatewayTests | ForEach-Object {
            "<tr><td><span class=`"badge $(& $badgeClass $_.Status)`">$($_.Status)</span></td><td>$(ConvertTo-SafeHtml $_.GatewayIp)</td><td>$(ConvertTo-SafeHtml $_.InterfaceName)</td><td>$($_.PacketLossPct)%</td><td>$(if ($null -ne $_.AvgLatencyMs) { "$($_.AvgLatencyMs) ms" } else { 'N/A' })</td><td>$(ConvertTo-SafeHtml $_.Notes)</td></tr>"
        }) -join "`n"

        $dnsRows = ($Report.DnsDiagnostics.Comparisons | ForEach-Object {
            "<tr><td><span class=`"badge $(& $badgeClass $_.Status)`">$($_.Status)</span></td><td>$(ConvertTo-SafeHtml $_.TargetHost)</td><td>$(ConvertTo-SafeHtml $_.LocalAddresses) ($($_.LocalLatencyMs) ms)</td><td>$(ConvertTo-SafeHtml $_.PublicSummary)</td><td>$(ConvertTo-SafeHtml $_.Notes)</td></tr>"
        }) -join "`n"

        $tcpRows = ($Report.TcpPortTests | ForEach-Object {
            "<tr><td><span class=`"badge $(& $badgeClass $_.Status)`">$($_.Status)</span></td><td>$(ConvertTo-SafeHtml $_.Target)</td><td>$($_.Port)</td><td>$(ConvertTo-SafeHtml $_.Service)</td><td>$(if ($_.Open) { 'OPEN' } else { 'CLOSED/FILTERED' })</td><td>$($_.LatencyMs) ms</td><td>$(ConvertTo-SafeHtml $_.Notes)</td></tr>"
        }) -join "`n"

        $routeRows = ($Report.RoutingSummary.DefaultRoutes | ForEach-Object {
            "<tr><td>$(ConvertTo-SafeHtml $_.DestinationPrefix)</td><td>$(ConvertTo-SafeHtml $_.NextHop)</td><td>$(ConvertTo-SafeHtml $_.InterfaceAlias)</td><td>$($_.TotalMetric)</td><td>$(if ($_.IsVpnRoute) { 'Yes' } else { 'No' })</td></tr>"
        }) -join "`n"

        $repairSection = ''
        if ($Report.RepairResults) {
            $repRows = ($Report.RepairResults.Actions | ForEach-Object {
                "<tr><td><span class=`"badge $(& $badgeClass $_.Status)`">$($_.Status)</span></td><td>$(ConvertTo-SafeHtml $_.Action)</td><td>$(ConvertTo-SafeHtml $_.Notes)</td></tr>"
            }) -join "`n"
            $repairSection = @"
        <section class="card">
            <h2>Network Stack Repair Summary</h2>
            <table>
                <thead><tr><th>Status</th><th>Action</th><th>Details</th></tr></thead>
                <tbody>$repRows</tbody>
            </table>
        </section>
"@
        }

        $html = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Network &amp; DNS Diagnostic Report - $(ConvertTo-SafeHtml $Report.ComputerName)</title>
<style>
  :root { --bg:#0f172a; --card:#1e293b; --text:#e2e8f0; --muted:#94a3b8; --border:#334155; --accent:#38bdf8; }
  [data-theme="light"] { --bg:#f8fafc; --card:#ffffff; --text:#0f172a; --muted:#475569; --border:#e2e8f0; --accent:#0284c7; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background:var(--bg); color:var(--text); margin:0; padding:24px; line-height:1.5; }
  .container { max-width:1200px; margin:0 auto; }
  header { display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; margin-bottom:20px; border-bottom:1px solid var(--border); padding-bottom:16px; }
  h1 { margin:0; font-size:1.5rem; }
  h2 { margin-top:0; font-size:1.1rem; color:var(--accent); }
  .meta { color:var(--muted); font-size:0.9rem; }
  .btn { background:var(--card); color:var(--text); border:1px solid var(--border); padding:8px 14px; border-radius:6px; cursor:pointer; font-size:0.85rem; }
  .grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(220px, 1fr)); gap:14px; margin-bottom:20px; }
  .kpi { background:var(--card); border:1px solid var(--border); border-radius:10px; padding:16px; }
  .kpi-label { font-size:0.8rem; color:var(--muted); text-transform:uppercase; }
  .kpi-val { font-size:1.3rem; font-weight:700; margin-top:4px; }
  .card { background:var(--card); border:1px solid var(--border); border-radius:10px; padding:18px; margin-bottom:18px; overflow-x:auto; }
  table { width:100%; border-collapse:collapse; font-size:0.88rem; }
  th, td { text-align:left; padding:9px 10px; border-bottom:1px solid var(--border); }
  th { color:var(--muted); font-weight:600; }
  .badge { display:inline-block; padding:2px 8px; border-radius:999px; font-size:0.75rem; font-weight:700; }
  .badge-pass { background:#14532d; color:#86efac; }
  .badge-warn { background:#713f12; color:#fde047; }
  .badge-fail { background:#7f1d1d; color:#fca5a5; }
  .badge-info { background:#0c4a6e; color:#7dd3fc; }
  footer { text-align:center; color:var(--muted); font-size:0.8rem; margin-top:24px; }
</style>
</head>
<body>
<div class="container">
  <header>
    <div>
      <h1>Network &amp; DNS Diagnostic Report</h1>
      <div class="meta">Host: <strong>$(ConvertTo-SafeHtml $Report.ComputerName)</strong> | Generated: $(ConvertTo-SafeHtml $Report.Timestamp) | Script v$($script:ScriptVersion)</div>
    </div>
    <div>
      <button class="btn" onclick="document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'">Toggle Theme</button>
      <button class="btn" onclick="window.print()">Print</button>
    </div>
  </header>

  <div class="grid">
    <div class="kpi"><div class="kpi-label">Overall Status</div><div class="kpi-val"><span class="badge $(& $badgeClass $Report.OverallStatus)">$($Report.OverallStatus)</span></div></div>
    <div class="kpi"><div class="kpi-label">VPN Status</div><div class="kpi-val">$(if ($Report.AdapterSummary.VpnDetected) { 'Active' } else { 'None' })</div></div>
    <div class="kpi"><div class="kpi-label">DNS Leak Risk</div><div class="kpi-val"><span class="badge $(& $badgeClass $Report.DnsDiagnostics.DnsLeakStatus)">$($Report.DnsDiagnostics.DnsLeakRisk)</span></div></div>
    <div class="kpi"><div class="kpi-label">Discovered Path MTU</div><div class="kpi-val">$(if ($null -ne $Report.PathMtu.DiscoveredPathMtu) { "$($Report.PathMtu.DiscoveredPathMtu) B" } else { 'N/A' })</div></div>
  </div>

  <section class="card">
    <h2>Active Network Adapters</h2>
    <table>
      <thead><tr><th>Name</th><th>Type</th><th>IPv4</th><th>Gateway</th><th>DNS Servers</th><th>MTU</th><th>Metric</th></tr></thead>
      <tbody>$adapterRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>Default Gateway Reachability</h2>
    <table>
      <thead><tr><th>Status</th><th>Gateway</th><th>Interface</th><th>Loss</th><th>Avg RTT</th><th>Notes</th></tr></thead>
      <tbody>$gwRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>DNS Resolution Comparison &amp; VPN Leak Check</h2>
    <p class="meta"><strong>VPN Leak Assessment:</strong> $(ConvertTo-SafeHtml $Report.DnsDiagnostics.DnsLeakNotes)</p>
    <table>
      <thead><tr><th>Status</th><th>Host</th><th>Local DNS</th><th>Public Resolvers</th><th>Notes</th></tr></thead>
      <tbody>$dnsRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>TCP Port Connectivity Matrix</h2>
    <table>
      <thead><tr><th>Status</th><th>Target</th><th>Port</th><th>Service</th><th>State</th><th>Latency</th><th>Notes</th></tr></thead>
      <tbody>$tcpRows</tbody>
    </table>
  </section>

  <section class="card">
    <h2>Default Routes &amp; Path MTU</h2>
    <p class="meta"><strong>Tunnel Mode:</strong> $(ConvertTo-SafeHtml $Report.RoutingSummary.TunnelMode) | <strong>Path MTU:</strong> $(ConvertTo-SafeHtml $Report.PathMtu.Notes)</p>
    <table>
      <thead><tr><th>Prefix</th><th>Next Hop</th><th>Interface</th><th>Total Metric</th><th>VPN</th></tr></thead>
      <tbody>$routeRows</tbody>
    </table>
  </section>

  $repairSection

  <footer>Generated by Diagnose-NetworkAndDns.ps1 v$($script:ScriptVersion) | Roman Pindela (github.com/romanpindela)</footer>
</div>
</body>
</html>
"@

        $parentDir = Split-Path -Path $DestinationPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -Path $parentDir -PathType Container)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($DestinationPath, $html, [System.Text.Encoding]::UTF8)
    }

    # --------------------------------------------------------------------------
    # Entry Guard: -Help or Zero Arguments
    # --------------------------------------------------------------------------
    if ($Help -or $PSBoundParameters.Count -eq 0) {
        Show-ScriptHelp
        $script:ShouldExitEarly = $true
        return
    }

    if (-not $Run -and -not $Repair) {
        $Run = $true
    }

    if ($Repair -and -not $SkipAdminCheck -and -not (Test-IsAdministrator)) {
        Invoke-UacElevation
        $script:ShouldExitEarly = $true
        return
    }

    if ($EnableLogging -or $GenerateHtmlReport -or $ExportJson) {
        $script:EffectiveLogDir = Initialize-LogDirectory -PreferredDirectory $LogDirectory
    }

    if ($EnableLogging) {
        $script:LogFilePath = Join-Path -Path $script:EffectiveLogDir -ChildPath "$($script:SessionTimestamp)-$($script:ScriptName)-$($env:COMPUTERNAME)-$($env:USERNAME).log"
        Write-LogEntry -Message "Started $($script:ScriptName) v$($script:ScriptVersion) on $($env:COMPUTERNAME) as $($env:USERNAME)." -Level 'INFO'
    }
}

process {
    if ($script:ShouldExitEarly) {
        return
    }

    try {
        $adapterSummary = $null
        $gatewayTests   = @()
        $dnsDiagnostics = $null
        $tcpPortTests   = @()
        $routingSummary = $null
        $pathMtu        = $null
        $repairResults  = $null

        if ($Run) {
            Write-Progress -Activity 'Network & DNS Diagnostics' -Status 'Inspecting active network adapters and VPN interfaces...' -PercentComplete 15
            $adapterSummary = Get-ActiveNetworkAdapterSummary
            Write-LogEntry -Message "Detected $($adapterSummary.Adapters.Count) active adapter(s); VPN detected: $($adapterSummary.VpnDetected)." -Level 'INFO'

            Write-Progress -Activity 'Network & DNS Diagnostics' -Status 'Testing default gateway reachability...' -PercentComplete 30
            $gatewayTests = @(Test-GatewayConnectivity -Adapters $adapterSummary.Adapters)

            Write-Progress -Activity 'Network & DNS Diagnostics' -Status 'Comparing local DNS vs public resolvers and checking VPN DNS leak...' -PercentComplete 50
            $dnsDiagnostics = Test-DnsResolutionAndLeak -Hosts $TargetHost -PublicResolvers $PublicDnsServers -AdapterSummary $adapterSummary

            Write-Progress -Activity 'Network & DNS Diagnostics' -Status 'Probing TCP port connectivity matrix...' -PercentComplete 68
            $tcpPortTests = @(Test-TcpPortMatrix -ExplicitTarget $PortTarget -PortList $Ports -TimeoutMs $TcpTimeoutMs -GatewayResults $gatewayTests)

            Write-Progress -Activity 'Network & DNS Diagnostics' -Status 'Analyzing routing table and Path MTU...' -PercentComplete 85
            $routingSummary = Get-RoutingSummary -AdapterSummary $adapterSummary
            $pathMtu        = Test-PathMtu -Target $MtuTarget -Adapters $adapterSummary.Adapters
        }

        if ($Repair) {
            Write-Progress -Activity 'Network & DNS Diagnostics' -Status 'Executing safe network stack repair...' -PercentComplete 92
            $repairResults = Repair-NetworkStack -SkipWinsock:$SkipWinsockReset
        }

        Write-Progress -Activity 'Network & DNS Diagnostics' -Completed

        # Compute overall status
        $allStatuses = New-Object System.Collections.Generic.List[string]
        foreach ($g in $gatewayTests) { $allStatuses.Add($g.Status) }
        if ($dnsDiagnostics) {
            foreach ($c in $dnsDiagnostics.Comparisons) { $allStatuses.Add($c.Status) }
            $allStatuses.Add($dnsDiagnostics.DnsLeakStatus)
        }
        foreach ($p in $tcpPortTests) { $allStatuses.Add($p.Status) }
        if ($routingSummary) { $allStatuses.Add($routingSummary.Status) }
        if ($pathMtu) { $allStatuses.Add($pathMtu.Status) }
        if ($repairResults) {
            foreach ($a in $repairResults.Actions) { $allStatuses.Add($a.Status) }
        }

        $overallStatus = if ($allStatuses -contains 'FAIL') { 'FAIL' }
                         elseif ($allStatuses -contains 'WARN') { 'WARN' }
                         else { 'PASS' }

        $reportObject = [PSCustomObject]@{
            ComputerName   = $env:COMPUTERNAME
            UserName       = $env:USERNAME
            Timestamp      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            OverallStatus  = $overallStatus
            AdapterSummary = $adapterSummary
            GatewayTests   = $gatewayTests
            DnsDiagnostics = $dnsDiagnostics
            TcpPortTests   = $tcpPortTests
            RoutingSummary = $routingSummary
            PathMtu        = $pathMtu
            RepairResults  = $repairResults
        }

        if ($Run) {
            Write-ConsoleReport -Report $reportObject
        }
        elseif ($Repair -and $repairResults) {
            Write-Host "`n[REPAIR SUMMARY]" -ForegroundColor Yellow
            foreach ($act in $repairResults.Actions) {
                Write-Host ("  [{0,-7}] {1,-24} -> {2}" -f $act.Status, $act.Action, $act.Notes) -ForegroundColor Cyan
            }
            Write-Host ''
        }

        # Optional HTML Export
        if ($GenerateHtmlReport -or -not [string]::IsNullOrWhiteSpace($ReportPath)) {
            $defaultHtml = Join-Path -Path $script:EffectiveLogDir -ChildPath "$($script:ScriptName)_$($env:COMPUTERNAME)_$($script:SessionTimestamp).html"
            $finalHtml = if ([string]::IsNullOrWhiteSpace($ReportPath)) {
                $defaultHtml
            }
            elseif (Test-Path -Path $ReportPath -PathType Container) {
                Join-Path -Path $ReportPath -ChildPath (Split-Path -Path $defaultHtml -Leaf)
            }
            else {
                $ReportPath
            }

            if ($Run) {
                Export-HtmlDiagnosticReport -Report $reportObject -DestinationPath $finalHtml
                Write-Host "[+] HTML report saved to: $finalHtml" -ForegroundColor Green
                Write-LogEntry -Message "HTML report exported to $finalHtml" -Level 'SUCCESS'

                if ($OpenReport) {
                    Start-Process -FilePath $finalHtml
                }
            }
        }

        # Optional JSON Export
        if ($ExportJson -or -not [string]::IsNullOrWhiteSpace($JsonPath)) {
            $defaultJson = Join-Path -Path $script:EffectiveLogDir -ChildPath "$($script:ScriptName)_$($env:COMPUTERNAME)_$($script:SessionTimestamp).json"
            $finalJson = if ([string]::IsNullOrWhiteSpace($JsonPath)) {
                $defaultJson
            }
            elseif (Test-Path -Path $JsonPath -PathType Container) {
                Join-Path -Path $JsonPath -ChildPath (Split-Path -Path $defaultJson -Leaf)
            }
            else {
                $JsonPath
            }

            $parentJson = Split-Path -Path $finalJson -Parent
            if (-not [string]::IsNullOrWhiteSpace($parentJson) -and -not (Test-Path -Path $parentJson -PathType Container)) {
                New-Item -ItemType Directory -Path $parentJson -Force | Out-Null
            }
            $jsonContent = $reportObject | ConvertTo-Json -Depth 6
            [System.IO.File]::WriteAllText($finalJson, $jsonContent, [System.Text.Encoding]::UTF8)
            Write-Host "[+] JSON report saved to: $finalJson" -ForegroundColor Green
            Write-LogEntry -Message "JSON report exported to $finalJson" -Level 'SUCCESS'
        }

        if ($PassThru) {
            Write-Output $reportObject
        }
    }
    catch {
        Write-LogEntry -Message "Unhandled error during execution: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

end {
    if (-not $script:ShouldExitEarly -and $EnableLogging) {
        Write-LogEntry -Message "Completed $($script:ScriptName) execution." -Level 'INFO'
        Write-Host "[i] Log file: $($script:LogFilePath)" -ForegroundColor DarkGray
    }
}
