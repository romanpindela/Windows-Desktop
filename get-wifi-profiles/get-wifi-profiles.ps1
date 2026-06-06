<#
.SYNOPSIS
    Displays saved Wi-Fi profiles, passwords and active Wi-Fi configuration.

.DESCRIPTION
    Retrieves saved Wi-Fi profiles from Windows and displays:
    - SSID
    - Stored password
    - Security type
    - Current connection status

    For the currently connected Wi-Fi profile additionally displays:
    - IPv4 address
    - Prefix length
    - Default gateway
    - DNS servers
    - Signal strength
    - Radio type
    - Channel

.AUTHOR
    Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela

.VERSION
    2.0.0
#>

[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$h
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Help {

    Write-Host ""
    Write-Host "get-wifi-profiles.ps1"
    Write-Host ""
    Write-Host "Displays saved Wi-Fi profiles and active Wi-Fi configuration."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "    .\get-wifi-profiles.ps1"
    Write-Host "    .\get-wifi-profiles.ps1 -Help"
    Write-Host "    .\get-wifi-profiles.ps1 -h"
    Write-Host ""
    Write-Host "Author : Roman Pindela"
    Write-Host "Version: 2.0.0"
    Write-Host "GitHub : https://github.com/romanpindela"
    Write-Host ""
}

function Get-CurrentWifiInformation {

    $wifiInterfaceData = netsh wlan show interfaces

    $ssid = (
        $wifiInterfaceData |
        Select-String '^ *SSID *:' |
        Select-Object -First 1
    )

    if (-not $ssid) {
        return $null
    }

    $currentSsid = ($ssid.Line -split ':',2)[1].Trim()

    $signal = (
        $wifiInterfaceData |
        Select-String '^ *Signal *:' |
        Select-Object -First 1
    )

    $radioType = (
        $wifiInterfaceData |
        Select-String '^ *Radio type *:' |
        Select-Object -First 1
    )

    $channel = (
        $wifiInterfaceData |
        Select-String '^ *Channel *:' |
        Select-Object -First 1
    )

    $ipConfig = Get-NetIPConfiguration |
        Where-Object {
            $_.NetAdapter.Status -eq "Up" -and
            $_.IPv4DefaultGateway -ne $null
        } |
        Select-Object -First 1

    [PSCustomObject]@{
        SSID       = $currentSsid
        Signal     = if($signal){($signal.Line -split ':',2)[1].Trim()}else{""}
        RadioType  = if($radioType){($radioType.Line -split ':',2)[1].Trim()}else{""}
        Channel    = if($channel){($channel.Line -split ':',2)[1].Trim()}else{""}
        IPv4       = $ipConfig.IPv4Address.IPAddress
        Prefix     = $ipConfig.IPv4Address.PrefixLength
        Gateway    = $ipConfig.IPv4DefaultGateway.NextHop
        DNS        = ($ipConfig.DNSServer.ServerAddresses -join ", ")
    }
}

function Get-SavedWifiProfiles {

    $currentWifi = Get-CurrentWifiInformation

    $profiles = netsh wlan show profiles |
        Select-String 'All User Profile|Wszystkie profile użytkowników' |
        ForEach-Object {
            ($_ -split ':',2)[1].Trim()
        }

    foreach ($profile in $profiles) {

        if ([string]::IsNullOrWhiteSpace($profile)) {
            continue
        }

        $details = netsh wlan show profile name="$profile" key=clear

        $passwordLine = $details |
            Select-String 'Key Content|Zawartość klucza'

        $securityLine = $details |
            Select-String 'Authentication|Uwierzytelnianie'

        $password = if ($passwordLine) {
            ($passwordLine -split ':',2)[1].Trim()
        }
        else {
            ""
        }

        $security = if ($securityLine) {
            ($securityLine -split ':',2)[1].Trim()
        }
        else {
            "Unknown"
        }

        $isConnected = $false

        if ($currentWifi) {
            $isConnected = $profile -eq $currentWifi.SSID
        }

        [PSCustomObject]@{
            Connected = if ($isConnected) { "✔" } else { "" }
            SSID      = $profile
            Password  = $password
            Security  = $security

            IPv4      = if ($isConnected) { $currentWifi.IPv4 } else { "" }
            Prefix    = if ($isConnected) { "/$($currentWifi.Prefix)" } else { "" }
            Gateway   = if ($isConnected) { $currentWifi.Gateway } else { "" }
            DNS       = if ($isConnected) { $currentWifi.DNS } else { "" }

            Signal    = if ($isConnected) { $currentWifi.Signal } else { "" }
            RadioType = if ($isConnected) { $currentWifi.RadioType } else { "" }
            Channel   = if ($isConnected) { $currentWifi.Channel } else { "" }
        }
    }
}

if ($Help -or $h) {
    Show-Help
    exit 0
}

if ($PSBoundParameters.Count -eq 0) {

    Show-Help

    Write-Host ""
    Write-Host "Scanning saved Wi-Fi profiles..." -ForegroundColor Yellow
    Write-Host ""
}

Get-SavedWifiProfiles |
    Sort-Object Connected -Descending |
    Format-Table `
        Connected,
        SSID,
        Security,
        Password,
        IPv4,
        Prefix,
        Gateway,
        Signal,
        Channel,
        RadioType `
        -AutoSize