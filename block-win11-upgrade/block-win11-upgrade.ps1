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
    [Alias("h","help")]
    [switch]$ShowHelp,

    [switch]$Enable,
    [switch]$Disable
)

$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

if ($ShowHelp -or $PSBoundParameters.Count -eq 0) {
    Write-Host "block-win11-upgrade.ps1 - Prevent automatic Windows 10 to Windows 11 upgrade" -ForegroundColor Cyan
    Write-Host "";
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\block-win11-upgrade.ps1 -Enable     # Block automatic Windows 11 upgrade" -ForegroundColor Gray
    Write-Host "  .\block-win11-upgrade.ps1 -Disable    # Restore default upgrade behavior" -ForegroundColor Gray
    Write-Host "  .\block-win11-upgrade.ps1 -Help       # Show this help message" -ForegroundColor Gray
    Write-Host "";
    Write-Host "Author: Roman Pindela" -ForegroundColor White
    Write-Host "Description: Modifies Windows Update policy to keep the system on Windows 10 (22H2) and prevent an automatic upgrade to Windows 11." -ForegroundColor Gray
    Write-Host "";
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\block-win11-upgrade.ps1 -Enable" -ForegroundColor Gray
    Write-Host "  .\block-win11-upgrade.ps1 -Disable" -ForegroundColor Gray
    Write-Host "  .\block-win11-upgrade.ps1 -h" -ForegroundColor Gray
    return
}

try {
    if ($Disable) {
        Write-Verbose "Started the process of unblocking the Windows 11 upgrade..."
        
        Remove-ItemProperty -Path $registryPath -Name "TargetReleaseVersion" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $registryPath -Name "ProductVersion" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $registryPath -Name "TargetReleaseVersionInfo" -ErrorAction SilentlyContinue
        
        Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        
        Write-Host "Block removed. Windows 11 can now be downloaded." -ForegroundColor Yellow
    }
    elseif ($Enable) {
        Write-Verbose "Started the process of blocking the Windows 11 upgrade..."
        
        if (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }

        Set-ItemProperty -Path $registryPath -Name "TargetReleaseVersion" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $registryPath -Name "ProductVersion" -Value "Windows 10" -Type String -Force
        Set-ItemProperty -Path $registryPath -Name "TargetReleaseVersionInfo" -Value "22H2" -Type String -Force

        Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        
        Write-Host "Done! The Windows 11 upgrade has been blocked. Your system will remain on Windows 10 (22H2)." -ForegroundColor Green
    }
    else {
        Write-Error "Invalid parameters. Use -Enable to apply the block or -Disable to remove it. Use -Help for usage information."
    }
}
catch {
    Write-Error "An error occurred while modifying the registry or restarting the service: $_"
}