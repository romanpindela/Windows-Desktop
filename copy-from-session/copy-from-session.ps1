<#
.SYNOPSIS
    Smartly retrieves files, multiple files, or entire directories from a remote computer securely.
.DESCRIPTION
    This script establishes a secure PSSession using provided credentials, retrieves the specified
    remote paths, copies them to the local machine, and cleanly closes the session afterward.
    Intelligent Copying:
    - If a file or multiple files are provided, they are copied directly into the target local directory.
    - If a folder is provided, the folder itself and all its contents are copied recursively into the target local directory.
.PARAMETER ComputerName
    The hostname or IP address of the remote computer.
.PARAMETER RemotePath
    Array of remote file or directory paths to copy. Accepts comma-separated values.
.PARAMETER LocalPath
    The destination base directory path on the local computer.
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
    [string[]]$RemotePath,

    [Parameter(Mandatory=$false)]
    [string]$LocalPath,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

function Show-ScriptHelp {
    Write-Host "`n=== SCRIPT: Copy-FromSession ===" -ForegroundColor Cyan
    Write-Host "Description: Intelligently retrieves files or whole folders from a remote server using PSSession."
    Write-Host "Author: Roman Pindela (roman.pindela@gmail.com) | https://github.com/romanpindela"
    Write-Host "Version: 1.1.0"
    Write-Host "`nUsage Examples:"
    Write-Host "  # Retrieving a single file:"
    Write-Host "  .\Copy-FromSession.ps1 -ComputerName 'SRV1' -RemotePath 'C:\remote_temp\data.txt' -LocalPath 'C:\local_temp\'"
    Write-Host "  `n  # Retrieving multiple files at once:"
    Write-Host "  .\Copy-FromSession.ps1 -ComputerName 'SRV1' -RemotePath 'C:\remote_temp\a.txt', 'C:\remote_temp\b.txt' -LocalPath 'C:\local_temp\'"
    Write-Host "  `n  # Retrieving an entire directory with its contents:"
    Write-Host "  .\Copy-FromSession.ps1 -ComputerName 'SRV1' -RemotePath 'C:\RemoteFolder' -LocalPath 'C:\local_temp\'"
    Write-Host "`n  .\Copy-FromSession.ps1 -h`n"
}

if ($ShowHelp -or [string]::IsNullOrWhiteSpace($ComputerName) -or -not $RemotePath -or [string]::IsNullOrWhiteSpace($LocalPath)) {
    Show-ScriptHelp
    exit
}

try {
    # Validate local destination path format
    if (-not ([System.IO.Path]::IsPathRooted($LocalPath))) {
        throw "Error: LocalPath must be an absolute path (e.g. C:\Folder)."
    }

    Write-Host "Requesting credentials for $ComputerName..."
    $credential = Get-Credential -Message "Enter credentials to connect to $ComputerName"

    Write-Host "Establishing PSSession..."
    $session = New-PSSession -ComputerName $ComputerName -Credential $credential -ErrorAction Stop

    # Verify remote source paths exist before attempting copy
    Write-Host "Verifying remote source paths..."
    Invoke-Command -Session $session -ScriptBlock {
        param($paths)
        foreach ($p in $paths) {
            if (-not (Test-Path $p)) {
                throw "Error: Remote path '$p' does not exist on the target server."
            }
        }
    } -ArgumentList (,$RemotePath)

    # Ensure local base directory exists (critical for intelligent file/folder sorting)
    Write-Host "Verifying local destination directory..."
    if (-not (Test-Path $LocalPath)) {
        Write-Host "Creating local directory: $LocalPath"
        New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
    }

    Write-Host "Intelligently retrieving items from session..."
    Copy-Item -Path $RemotePath -Destination $LocalPath -FromSession $session -Recurse -Force -ErrorAction Stop

    Write-Host "Retrieval operation completed successfully." -ForegroundColor Green

} catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
} finally {
    if ($session) {
        Write-Host "Closing PSSession..."
        Remove-PSSession -Session $session
    }
}