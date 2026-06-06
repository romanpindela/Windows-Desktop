<#
.SYNOPSIS
    Displays saved Wi-Fi profiles, passwords and network configuration.

.DESCRIPTION
    Retrieves all saved Wi-Fi profiles from Windows,
    including passwords, security types and current
    network configuration of active Wi-Fi adapters.

.AUTHOR
    Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela

.VERSION
    1.0.0
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
    Write-Host "Displays saved Wi-Fi profiles, passwords and network settings."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "    .\get-wifi-profiles.ps1"
    Write-Host "    .\get-wifi-profiles.ps1 -Help"
    Write-Host "    .\get-wifi-profiles.ps1 -h"
    Write-Host ""
    Write-Host "Author : Roman Pindela"
    Write-Host "Version: 1.0.0"
    Write-Host "GitHub : https://github.com/romanpindela"
    Write-Host ""
}

function get-wifi-profiles {
    $profilesOutput = netsh wlan show profiles

    $profiles = $profilesOutput |
        Select-String "All User Profile|Wszystkie profile użytkowników" |
        ForEach-Object {
            ($_ -split ":")[1].Trim()
        }

    foreach ($profile in $profiles) {

        if ([string]::IsNullOrWhiteSpace($profile)) {
            continue
        }

        $profileDetails = netsh wlan show profile name="$profile" key=clear

        $passwordLine = $profileDetails |
            Select-String "Key Content|Zawartość klucza"

        $securityLine = $profileDetails |
            Select-String "Authentication|Uwierzytelnianie"

        $password = if ($passwordLine) {
            ($passwordLine -split ":")[1].Trim()
        }
        else {
            ""
        }

        $security = if ($securityLine) {
            ($securityLine -split ":")[1].Trim()
        }
        else {
            "Unknown"
        }

        $wifiAdapter = Get-NetAdapter |
            Where-Object {
                $_.Status -eq "Up" -and $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11"
            } |
            Select-Object -First 1

        $ipv4 = ""
        $prefix = ""
        $gateway = ""
        $dns = ""

        if ($wifiAdapter) {

            $ipInfo = Get-NetIPAddress `
                -InterfaceIndex $wifiAdapter.ifIndex `
                -AddressFamily IPv4 `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1

            $gwInfo = Get-NetRoute `
                -InterfaceIndex $wifiAdapter.ifIndex `
                -DestinationPrefix "0.0.0.0/0" `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1

            $dnsInfo = Get-DnsClientServerAddress `
                -InterfaceIndex $wifiAdapter.ifIndex `
                -AddressFamily IPv4 `
                -ErrorAction SilentlyContinue

            if ($ipInfo) {
                $ipv4 = $ipInfo.IPAddress
                $prefix = "/$($ipInfo.PrefixLength)"
            }

            if ($gwInfo) {
                $gateway = $gwInfo.NextHop
            }

            if ($dnsInfo) {
                $dns = $dnsInfo.ServerAddresses -join ", "
            }
        }

        [PSCustomObject]@{
            SSID     = $profile
            Password = $password
            Security = $security
            IPv4     = $ipv4
            Prefix   = $prefix
            Gateway  = $gateway
            DNS      = $dns
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
    Write-Host "Running profile scan..." -ForegroundColor Yellow
}

get-wifi-profiles | Format-Table -AutoSize