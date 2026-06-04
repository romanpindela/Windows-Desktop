<#
.SYNOPSIS
    A utility script to create Directory Junction points in Windows.
.DESCRIPTION
    This script automates the creation of Junction points using native PowerShell commands.
.PARAMETER JunctionPath
    The path where the new junction (link) should be created.
.PARAMETER TargetPath
    The existing directory path that the junction will point to.
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.1.1
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$JunctionPath,

    [Parameter(Mandatory=$false)]
    [string]$TargetPath,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

function Show-ScriptHelp {
    Write-Host "`n=== HELP: New-JunctionPoint ===" -ForegroundColor Cyan
    Write-Host "Description: Creates a Directory Junction point (link) pointing to a target folder."
    Write-Host "Author: Roman Pindela (roman.pindela@gmail.com)"
    Write-Host "Web: https://github.com/romanpindela"
    Write-Host "Version: 1.1.1"
    Write-Host "`nUsage Examples:"
    Write-Host "  .\make-junction-point.ps1 -JunctionPath 'C:\MyLink' -TargetPath 'D:\Data\Folder'"
    Write-Host "  .\make-junction-point.ps1 -h"
}

# 1. Automatyczny Help przy braku parametrów lub fladze -h
if ($ShowHelp -or ([string]::IsNullOrWhiteSpace($JunctionPath) -and [string]::IsNullOrWhiteSpace($TargetPath))) {
    Show-ScriptHelp
    exit
}

try {
    # 2. Ochrona przed pustym inputem
    if ([string]::IsNullOrWhiteSpace($JunctionPath) -or [string]::IsNullOrWhiteSpace($TargetPath)) {
        throw "Error: Both JunctionPath and TargetPath must be provided."
    }

    # 3. Weryfikacja ścieżek bezwzględnych
    if (-not ([System.IO.Path]::IsPathRooted($JunctionPath)) -or -not ([System.IO.Path]::IsPathRooted($TargetPath))) {
         throw "Error: Please provide absolute (full) paths for security."
    }

    # 4. Sprawdzenie czy cel istnieje i jest katalogiem
    if (-not (Test-Path -Path $TargetPath -PathType Container)) {
        throw "Error: The target directory '$TargetPath' does not exist."
    }

    # 5. Ochrona przed nadpisaniem istniejących danych
    if (Test-Path -Path $JunctionPath) {
        throw "Error: The path '$JunctionPath' already exists."
    }

    # Tworzenie Junction Point
    New-Item -Path $JunctionPath -ItemType Junction -Value $TargetPath | Out-Null

    Write-Host "Success: Junction created successfully!" -ForegroundColor Green
    Write-Host "Link: $JunctionPath -> $TargetPath"
}
catch {
    Write-Error "Failed to create junction point. Details: $($_.Exception.Message)"
}