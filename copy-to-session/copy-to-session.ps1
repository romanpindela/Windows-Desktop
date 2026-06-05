<#
.SYNOPSIS
    Smartly copies files, multiple files, or entire directories from the local computer to a remote session securely.
.DESCRIPTION
    This script establishes a secure PSSession using provided credentials, copies the specified
    local paths to a remote destination, and cleanly closes the session afterward.
    Intelligent Copying: 
    - If a file or multiple files are provided, they are copied directly into the target remote directory.
    - If a folder is provided, the folder itself and all its contents are copied recursively into the target remote directory.
.PARAMETER ComputerName
    The hostname or IP address of the remote computer.
.PARAMETER LocalPath
    Array of local file or directory paths to copy. Accepts comma-separated values.
.PARAMETER RemotePath
    The destination base directory path on the remote computer.
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.1.0
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$ComputerName,

    [Parameter(Mandatory=$false)]
    [string[]]$LocalPath,

    [Parameter(Mandatory=$false)]
    [string]$RemotePath,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

function Show-ScriptHelp {
    Write-Host "`n=== SCRIPT: copy-to-session ===" -ForegroundColor Cyan
    Write-Host "Description: Intelligently copies files or whole folders to a remote server using PSSession."
    Write-Host "Author: Roman Pindela (roman.pindela@gmail.com) | https://github.com/romanpindela"
    Write-Host "Version: 1.1.0"
    Write-Host "`nUsage Examples:"
    Write-Host "  # Copying a single file:"
    Write-Host "  .\copy-to-session.ps1 -ComputerName 'SRV1' -LocalPath 'C:\temp\data.txt' -RemotePath 'C:\remote_temp\'"
    Write-Host "  `n  # Copying multiple files at once:"
    Write-Host "  .\copy-to-session.ps1 -ComputerName 'SRV1' -LocalPath 'C:\temp\a.txt', 'C:\temp\b.txt' -RemotePath 'C:\remote_temp\'"
    Write-Host "  `n  # Copying an entire directory with its contents:"
    Write-Host "  .\copy-to-session.ps1 -ComputerName 'SRV1' -LocalPath 'C:\LocalFolder' -RemotePath 'C:\remote_temp\'"
    Write-Host "`n  .\copy-to-session.ps1 -h`n"
}

if ($ShowHelp -or [string]::IsNullOrWhiteSpace($ComputerName) -or -not $LocalPath -or [string]::IsNullOrWhiteSpace($RemotePath)) {
    Show-ScriptHelp
    exit
}

try {
    # Validate local paths
    foreach ($path in $LocalPath) {
        if (-not (Test-Path $path)) {
            throw "Error: Local path '$path' does not exist."
        }
    }

    Write-Host "Requesting credentials for $ComputerName..."
    $credential = Get-Credential -Message "Enter credentials to connect to $ComputerName"

    Write-Host "Establishing PSSession..."
    $session = New-PSSession -ComputerName $ComputerName -Credential $credential -ErrorAction Stop

    # Ensure remote base directory exists (critical for intelligent file/folder sorting)
    Write-Host "Verifying remote destination directory..."
    Invoke-Command -Session $session -ScriptBlock {
        param($rPath)
        if (-not (Test-Path $rPath)) {
            Write-Host "Creating remote directory: $rPath"
            New-Item -ItemType Directory -Path $rPath -Force | Out-Null
        }
    } -ArgumentList $RemotePath

    Write-Host "Intelligently copying items to session..."
    Copy-Item -Path $LocalPath -Destination $RemotePath -ToSession $session -Recurse -Force -ErrorAction Stop

    Write-Host "Copy operation completed successfully." -ForegroundColor Green

} catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
} finally {
    if ($session) {
        Write-Host "Closing PSSession..."
        Remove-PSSession -Session $session
    }
}