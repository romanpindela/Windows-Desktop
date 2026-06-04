<#
.SYNOPSIS
    Captures a local screenshot of the primary display.
.DESCRIPTION
    Captures the primary screen using .NET Graphics and saves it as a PNG file.
    Designed for local execution or via Task Scheduler.
.PARAMETER OutputDirectory
    The directory where the screenshot will be saved. Defaults to 'C:\temp'.
.EXAMPLE
    .\Invoke-LocalScreenshot.ps1 -OutputDirectory "C:\Screenshots"
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.1.0
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory = "C:\temp",

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

function Show-Help {
    Write-Host "`n=== Invoke-LocalScreenshot ===" -ForegroundColor Cyan
    Write-Host "Description: Captures primary screen to a PNG file."
    Write-Host "Author: Roman Pindela (roman.pindela@gmail.com)"
    Write-Host "Version: 1.1.0"
    Write-Host "`nUsage:"
    Write-Host "  .\Invoke-LocalScreenshot.ps1 -OutputDirectory 'C:\Path\To\Save'"
    Write-Host "`nOptions:"
    Write-Host "  -h, -Help    Show this help message"
}

if ($ShowHelp) { Show-Help; exit }

try {
    # Validate directory
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    # Add Assemblies
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Capture Logic
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

    $timestamp = Get-Date -Format "yyyy.MM.dd_HH.mm.ss"
    $path = Join-Path $OutputDirectory "screenshot-$timestamp.png"

    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $graphics.Dispose()
    $bitmap.Dispose()

    Write-Host "Success: Screenshot saved to $path" -ForegroundColor Green
} catch {
    Write-Error "Failed to capture screenshot: $($_.Exception.Message)"
}