# ==============================================================================
# SETTINGS - Paste the full GitHub link below and specify whether to execute it
# ==============================================================================
$GitHubUrl = "https://github.com/romanpindela/Windows-Desktop/blob/main/deploy-platnik-zus/deploy-zus-platnik.ps1"
$TargetFolder = "C:\PowerShell"
$RunAfterDownload = $true  # Set to $false if you only want to download without executing
# ==============================================================================

# Force TLS 1.2 security protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Automatically convert standard GitHub URL to RAW format
if ($GitHubUrl -like "*github.com/*/blob/*") {
    $rawUrl = $GitHubUrl -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
} else {
    $rawUrl = $GitHubUrl
}

# Extract file name from the URL
$fileName = Split-Path -Path $rawUrl -Leaf
$destinationFile = Join-Path -Path $TargetFolder -ChildPath $fileName

# Check and create target folder if it does not exist
if (-not (Test-Path -Path $TargetFolder)) {
    Write-Host "Creating directory: $TargetFolder..." -ForegroundColor Yellow
    New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
}

# Remove existing file prior to downloading to ensure a clean overwrite
if (Test-Path -Path $destinationFile) {
    Write-Host "Existing file found. Overwriting '$fileName'..." -ForegroundColor Yellow
    Remove-Item -Path $destinationFile -Force -ErrorAction SilentlyContinue
}

# Download, unblock, and execute
try {
    Write-Host "Downloading latest version of '$fileName'..." -ForegroundColor Cyan
    
    # Download file (OutFile automatically overwrites, but -UseBasicParsing ensures speed)
    Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

    if (Test-Path -Path $destinationFile) {
        Write-Host "[OK] File successfully saved/overwritten at: $destinationFile" -ForegroundColor Green

        # Unblock the file (removes web mark-of-the-web block)
        Unblock-File -Path $destinationFile
        Write-Host "[OK] File unblocked (Unblock-File)." -ForegroundColor Gray

        # Execute script
        if ($RunAfterDownload) {
            Write-Host "`n--- Executing script: $fileName ---`n" -ForegroundColor Yellow
            & $destinationFile
        }
    }
} catch {
    Write-Host "`n[ERROR] An error occurred while downloading/overwriting: $_" -ForegroundColor Red
}