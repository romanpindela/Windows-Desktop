<#
.SYNOPSIS
    Manages the automatic upgrade from Windows 10 to Windows 11.
.DESCRIPTION
    By default, modifies local registry policies to pin the target release version 
    to Windows 10 (22H2), preventing automatic Windows 11 installation.
    Use the -Disable switch to remove the block and allow the upgrade.
.PARAMETER Disable
    Switch parameter. If specified, unblocks the Windows 11 upgrade path.
.NOTES
    Author: Roman Pindela
    Version: 1.0.0
#>

[CmdletBinding()]
param (
    [switch]$Disable
)

$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

try {
    if ($Disable) {
        Write-Verbose "Rozpoczęto proces odblokowywania aktualizacji do Windows 11..."
        
        Remove-ItemProperty -Path $registryPath -Name "TargetReleaseVersion" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $registryPath -Name "ProductVersion" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $registryPath -Name "TargetReleaseVersionInfo" -ErrorAction SilentlyContinue
        
        Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        
        Write-Host "Blokada usunięta. Windows 11 może zostać pobrany." -ForegroundColor Yellow
    }
    else {
        Write-Verbose "Rozpoczęto proces blokowania aktualizacji do Windows 11..."
        
        if (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }

        Set-ItemProperty -Path $registryPath -Name "TargetReleaseVersion" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $registryPath -Name "ProductVersion" -Value "Windows 10" -Type String -Force
        Set-ItemProperty -Path $registryPath -Name "TargetReleaseVersionInfo" -Value "22H2" -Type String -Force

        Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        
        Write-Host "Gotowe! Aktualizacja do Windows 11 została zablokowana. Twój system pozostanie na Windows 10 (22H2)." -ForegroundColor Green
    }
}
catch {
    Write-Error "Wystąpił błąd podczas modyfikacji rejestru lub restartu usługi: $_"
}