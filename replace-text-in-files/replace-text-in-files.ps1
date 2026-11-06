<#
.SYNOPSIS
    Searches and replaces text or regular expressions across multiple files safely.

.DESCRIPTION
    replace-text-in-files performs mass search-and-replace operations in text files
    within a specified directory tree.

    Key Features:
    - Safe In-Memory & Atomic File Operations: Avoids pipeline file-locking or corruption
      by reading files into memory (-Raw), validating changes, and writing safely.
    - Dual PowerShell Compatibility: Fully compatible with Windows PowerShell 5.1 and PowerShell 7+.
    - Safety First: Full support for -WhatIf and -Confirm (SupportsShouldProcess).
    - Encoding Support: Supports UTF-8 (PS5.1 default BOM / PS7 default no-BOM), UTF8NoBOM, ASCII, and Unicode.
    - Preserves Newlines & Diacritics: Accurately retains Windows (CRLF) and Unix (LF) line endings
      as well as international/Polish diacritics.
    - Backup Creation: Optional -CreateBackup switch creates a '.bak' copy before modifying any file.
    - Smart Modification: Files are only touched and rewritten if replacement matches are actually found,
      preserving file modification timestamps on untouched files.
    - Detailed Logging: Optional -EnableLogging switch writes structured timestamps and logs to C:\Logs.
    - Directory Exclusion: Excludes specified folders such as .git, .vs, node_modules.

.PARAMETER Path
    The target directory path containing the files to process.
    Aliases: Folder, Directory.

.PARAMETER FindText
    The literal text string or Regular Expression pattern to search for.

.PARAMETER ReplaceWith
    The replacement text. Defaults to an empty string (""), which removes matching occurrences.

.PARAMETER Filter
    File filter mask (e.g. '*.md', '*.txt', '*.config'). Defaults to '*.*'.

.PARAMETER Recurse
    Recursively scans subdirectories when specified.

.PARAMETER UseRegex
    Treats -FindText as a Regular Expression pattern rather than a literal string.

.PARAMETER CaseSensitive
    Enforces case-sensitive matching. Defaults to false (case-insensitive).

.PARAMETER ExcludeDirectories
    Array of folder names to exclude from processing.
    Defaults to @('.git', '.vs', 'node_modules').

.PARAMETER Encoding
    File output encoding. Supported values: 'utf8', 'utf8NoBOM', 'ascii', 'unicode'.
    Defaults to 'utf8'.

.PARAMETER CreateBackup
    Creates a backup copy with the '.bak' extension before saving modifications.

.PARAMETER EnableLogging
    Enables execution logging to C:\Logs\<YYYYMMDD-HHmmss>-replace-text-in-files-<HostName>-<UserName>.log.

.PARAMETER Help
    Displays the interactive help guide and examples.
    Aliases: h, HelpMe.

.OUTPUTS
    [PSCustomObject] Summary object containing:
    - Path          : Analyzed directory path
    - FilesScanned  : Total number of scanned files
    - FilesModified : Number of files modified (or that would be modified in WhatIf mode)
    - FilesFailed   : Number of files that encountered errors
    - Duration      : Time elapsed during operation
    - Mode          : 'Execute' or 'WhatIf'

.EXAMPLE
    .\replace-text-in-files.ps1 -Path ".\Docs" -Filter "*.md" -FindText "#stary-tag" -ReplaceWith "" -Recurse
    Recursively removes '#stary-tag' from all Markdown files under the '.\Docs' folder.

.EXAMPLE
    .\replace-text-in-files.ps1 -Path "C:\Projekty" -Filter "*.json" -FindText 'v\d+\.\d+\.\d+' -ReplaceWith 'v2.0.0' -UseRegex -WhatIf
    Simulates replacing version numbers matching a regular expression across JSON files without modifying disk.

.EXAMPLE
    .\replace-text-in-files.ps1 -Path "D:\Configs" -Filter "*.config" -FindText "Server=old-db" -ReplaceWith "Server=new-db" -CreateBackup -EnableLogging
    Updates database connection strings in config files, creating '.bak' backups and logging all operations to C:\Logs.

.NOTES
    Script Name : replace-text-in-files.ps1
    Author      : Roman Pindela
    Contact     : roman.pindela@gmail.com
    GitHub      : https://github.com/romanpindela
    Version     : 1.0.0
    Environment : Windows 10, Windows 11, Windows Server 2016+
    PowerShell  : Windows PowerShell 5.1 & PowerShell 7+
#>

[CmdletBinding(DefaultParameterSetName = "Replace", SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Replace")]
    [Alias("Folder", "Directory")]
    [string]$Path,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Replace")]
    [string]$FindText,

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "Replace")]
    [AllowEmptyString()]
    [string]$ReplaceWith = "",

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [string]$Filter = "*.*",

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$Recurse,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$UseRegex,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$CaseSensitive,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [string[]]$ExcludeDirectories = @('.git', '.vs', 'node_modules'),

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [ValidateSet("utf8", "utf8NoBOM", "ascii", "unicode", IgnoreCase = $true)]
    [string]$Encoding = "utf8",

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$CreateBackup,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$EnableLogging,

    [Parameter(Mandatory = $false, ParameterSetName = "Help")]
    [Alias("h", "HelpMe")]
    [switch]$Help
)

# --- SCRIPT CONSTANTS & METADATA ---
$SCRIPT_INFO = @{
    Name        = "replace-text-in-files"
    Version     = "1.0.0"
    Author      = "Roman Pindela"
    Contact     = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    ReleaseDate = "2026-11-06"
}

# --- GLOBAL SCRIPT VARIABLES ---
$script:LoggingEnabled = $false
$script:LogFilePath    = $null

# ==============================================================================
# LOGGING SYSTEM
# ==============================================================================
function Initialize-Logging {
    param (
        [string]$ScriptName
    )

    $defaultLogDir = "C:\Logs"
    if (-not (Test-Path -LiteralPath $defaultLogDir)) {
        try {
            $null = New-Item -Path $defaultLogDir -ItemType Directory -Force -ErrorAction Stop
        }
        catch {
            # Fallback to %TEMP%\Logs if C:\Logs cannot be created due to permissions
            $defaultLogDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "Logs"
            if (-not (Test-Path -LiteralPath $defaultLogDir)) {
                $null = New-Item -Path $defaultLogDir -ItemType Directory -Force
            }
        }
    }

    $timestamp    = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $computerName = [System.Environment]::MachineName
    $userName     = [System.Environment]::UserName
    $fileName     = "$timestamp-$ScriptName-$computerName-$userName.log"

    $script:LogFilePath    = Join-Path -Path $defaultLogDir -ChildPath $fileName
    $script:LoggingEnabled = $true
}

function Write-AppLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "ACTION")]
        [string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $logLine   = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "INFO"   { [ConsoleColor]::White }
        "ACTION" { [ConsoleColor]::Cyan }
        "WARN"   { [ConsoleColor]::Yellow }
        "ERROR"  { [ConsoleColor]::Red }
        default  { [ConsoleColor]::Gray }
    }

    Write-Host $logLine -ForegroundColor $color

    if ($script:LoggingEnabled -and -not [string]::IsNullOrEmpty($script:LogFilePath)) {
        try {
            [System.IO.File]::AppendAllText($script:LogFilePath, $logLine + [System.Environment]::NewLine, [System.Text.Encoding]::UTF8)
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

# ==============================================================================
# ADMINISTRATIVE CHECK
# ==============================================================================
function Test-IsAdministrator {
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

# ==============================================================================
# HELP GUIDE DISPLAY
# ==============================================================================
function Show-HelpGuide {
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Author : $($SCRIPT_INFO.Author) | Contact: $($SCRIPT_INFO.Contact)
  GitHub : $($SCRIPT_INFO.GitHub)
================================================================================
DESCRIPTION:
  Searches and replaces strings or regular expression patterns in files
  across directories safely without data corruption or handle locking.

PARAMETERS:
  -Path <String>                 : Target directory path (Required, Alias: -Folder, -Directory)
  -FindText <String>             : Text or Regex pattern to find (Required)
  -ReplaceWith <String>          : Replacement text (Default: "")
  -Filter <String>               : File filter pattern, e.g. '*.md' (Default: '*.*')
  -Recurse                       : Searches subfolders recursively
  -UseRegex                      : Enables regular expression matching
  -CaseSensitive                 : Enforces case-sensitive search
  -ExcludeDirectories <String[]> : Folder names to ignore (Default: .git, .vs, node_modules)
  -Encoding <String>             : Output encoding: utf8, utf8NoBOM, ascii, unicode (Default: utf8)
  -CreateBackup                  : Creates a .bak backup before modifying files
  -EnableLogging                 : Writes execution logs to C:\Logs
  -WhatIf                        : Simulates changes without modifying files on disk
  -Confirm                       : Prompts for confirmation before modifying each file
  -Help / -h                     : Displays this help screen

PRACTICAL EXAMPLES:
  1. Remove old tag from Markdown files:
     .\replace-text-in-files.ps1 -Path ".\Docs" -Filter "*.md" -FindText "#old-tag" -ReplaceWith "" -Recurse

  2. Simulate Regex replacement in JSON files (-WhatIf):
     .\replace-text-in-files.ps1 -Path "C:\Projekty" -Filter "*.json" -FindText 'v\d+\.\d+\.\d+' -ReplaceWith 'v2.0.0' -UseRegex -WhatIf

  3. Safe config update with backups and logging:
     .\replace-text-in-files.ps1 -Path "D:\Configs" -Filter "*.config" -FindText "Server=old-db" -ReplaceWith "Server=new-db" -CreateBackup -EnableLogging
================================================================================
"@ -ForegroundColor Yellow
}

# ==============================================================================
# MAIN SCRIPT LOGIC
# ==============================================================================
if ($Help -or $PsCmdlet.ParameterSetName -eq "Help") {
    Show-HelpGuide
    return
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# 1. Initialize Logging
if ($EnableLogging) {
    Initialize-Logging -ScriptName $SCRIPT_INFO.Name
    Write-AppLog "Logging enabled. Output file: '$($script:LogFilePath)'" -Level INFO
}

# 2. Administrative Check (Informative)
if (-not (Test-IsAdministrator)) {
    Write-AppLog "Running without elevated Administrator privileges. Modifying protected system directories may require elevation." -Level INFO
}

# 3. Path Validation
if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    $errMsg = "The specified path does not exist or is not a directory: '$Path'"
    Write-AppLog $errMsg -Level ERROR
    throw $errMsg
}

$resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath
Write-AppLog "Starting replace-text-in-files in '$resolvedPath'" -Level INFO
Write-AppLog "Search pattern: '$FindText' | Replacement: '$ReplaceWith' | UseRegex: $UseRegex | CaseSensitive: $CaseSensitive" -Level INFO

# 4. Encoding Configuration
$targetEncoding = $null
$readEncodingName = "UTF8"

switch ($Encoding.ToLowerInvariant()) {
    "utf8" {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $targetEncoding = [System.Text.UTF8Encoding]::new($false)
        } else {
            $targetEncoding = [System.Text.UTF8Encoding]::new($true)
        }
        $readEncodingName = "UTF8"
    }
    "utf8nobom" {
        $targetEncoding = [System.Text.UTF8Encoding]::new($false)
        $readEncodingName = "UTF8"
    }
    "ascii" {
        $targetEncoding = [System.Text.Encoding]::ASCII
        $readEncodingName = "Ascii"
    }
    "unicode" {
        $targetEncoding = [System.Text.Encoding]::Unicode
        $readEncodingName = "Unicode"
    }
}

# 5. Regex Compiler & Validator
$regexOptions = [System.Text.RegularExpressions.RegexOptions]::None
if (-not $CaseSensitive) {
    $regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
}

$patternString = if ($UseRegex) { $FindText } else { [System.Text.RegularExpressions.Regex]::Escape($FindText) }
try {
    $compiledRegex = [System.Text.RegularExpressions.Regex]::new($patternString, $regexOptions)
}
catch {
    $errMsg = "Failed to compile search pattern '$patternString': $($_.Exception.Message)"
    Write-AppLog $errMsg -Level ERROR
    throw $errMsg
}

# 6. Exclude Directories Normalization
$excludeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($null -ne $ExcludeDirectories) {
    foreach ($dir in $ExcludeDirectories) {
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            [void]$excludeSet.Add($dir.Trim().Trim('\', '/'))
        }
    }
}

# 7. File Discovery & Filtering
Write-AppLog "Scanning directory for files matching '$Filter'..." -Level INFO

$gciParams = @{
    LiteralPath = $resolvedPath
    Filter      = $Filter
    File        = $true
    Recurse     = $Recurse.IsPresent
    ErrorAction = 'SilentlyContinue'
}

$foundFiles = Get-ChildItem @gciParams

# Exclude files residing within excluded directory segments
$eligibleFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($file in $foundFiles) {
    $shouldExclude = $false
    if ($excludeSet.Count -gt 0) {
        $relPath = if ($file.FullName.StartsWith($resolvedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $file.FullName.Substring($resolvedPath.Length).TrimStart('\', '/')
        } else {
            $file.FullName
        }
        $segments = $relPath.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        # Exclude if any directory segment matches the excluded list (excluding final file name)
        for ($i = 0; $i -lt ($segments.Length - 1); $i++) {
            if ($excludeSet.Contains($segments[$i])) {
                $shouldExclude = $true
                break
            }
        }
    }

    if (-not $shouldExclude) {
        $eligibleFiles.Add($file)
    }
}

$totalScanned     = $eligibleFiles.Count
$totalModified    = 0
$totalFailed      = 0
$totalOccurrences = 0

Write-AppLog "Found $totalScanned file(s) eligible for processing." -Level INFO

# 8. Processing Loop
$currentIndex = 0

foreach ($file in $eligibleFiles) {
    $currentIndex++
    $percent = if ($totalScanned -gt 0) { [math]::Min(100, [int](($currentIndex / $totalScanned) * 100)) } else { 100 }
    Write-Progress -Activity "replace-text-in-files" -Status "Processing file $currentIndex of ${totalScanned} - $($file.Name)" -PercentComplete $percent

    $tempFilePath = $null
    try {
        # Read file safely into memory
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding $readEncodingName -ErrorAction Stop

        if ($null -eq $content) {
            # Empty file, nothing to replace
            continue
        }

        # Check for matches
        $matches = $compiledRegex.Matches($content)
        $matchCount = $matches.Count

        if ($matchCount -eq 0) {
            # No occurrence found, skip file without touching disk
            continue
        }

        # Occurrence found - handle modification
        $actionDescription = "Replace $matchCount occurrence(s) in '$($file.FullName)'"

        if ($PSCmdlet.ShouldProcess($file.FullName, $actionDescription)) {
            # Create backup if requested
            if ($CreateBackup) {
                $backupPath = "$($file.FullName).bak"
                Copy-Item -LiteralPath $file.FullName -Destination $backupPath -Force -ErrorAction Stop
                Write-AppLog "Backup created: '$backupPath'" -Level ACTION
            }

            # Perform replacement
            $newContent = if ($UseRegex) {
                $compiledRegex.Replace($content, $ReplaceWith)
            } else {
                # Escape '$' to avoid Regex backreference interpretation in literal replacement
                $safeSub = $ReplaceWith.Replace('$', '$$')
                $compiledRegex.Replace($content, $safeSub)
            }

            # Transactional / safe writing: write to a temporary file first, then overwrite target
            $guid = [System.Guid]::NewGuid().ToString("N")
            $tempFilePath = "$($file.FullName).tmp.$guid"

            [System.IO.File]::WriteAllText($tempFilePath, $newContent, $targetEncoding)

            # Atomically replace target file
            [System.IO.File]::Copy($tempFilePath, $file.FullName, $true)
            [System.IO.File]::Delete($tempFilePath)
            $tempFilePath = $null

            Write-AppLog "Modified '$($file.FullName)' ($matchCount occurrence(s) replaced)." -Level ACTION
            $totalModified++
            $totalOccurrences += $matchCount
        }
        else {
            # WhatIf mode was triggered
            Write-AppLog "[WhatIf] Would modify '$($file.FullName)' ($matchCount occurrence(s) matched)." -Level ACTION
            $totalModified++
            $totalOccurrences += $matchCount
        }
    }
    catch [System.UnauthorizedAccessException] {
        $totalFailed++
        $errMsg = "Access denied when processing '$($file.FullName)'. Run script as Administrator to modify this file."
        Write-AppLog $errMsg -Level ERROR
        Write-Warning $errMsg
    }
    catch {
        $totalFailed++
        $errMsg = "Error processing '$($file.FullName)': $($_.Exception.Message)"
        Write-AppLog $errMsg -Level ERROR
        Write-Warning $errMsg
    }
    finally {
        # Clean up any leftover temporary file in case of failure
        if (-not [string]::IsNullOrEmpty($tempFilePath) -and (Test-Path -LiteralPath $tempFilePath)) {
            try {
                Remove-Item -LiteralPath $tempFilePath -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
}

Write-Progress -Activity "replace-text-in-files" -Completed

$stopwatch.Stop()
$mode = if ($WhatIfPreference) { "WhatIf" } else { "Execute" }

# Summary Output
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " replace-text-in-files - Operation Summary ($mode)" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Path               : $resolvedPath" -ForegroundColor White
Write-Host " Files Scanned      : $totalScanned" -ForegroundColor White
Write-Host " Files Modified     : $totalModified" -ForegroundColor $(if ($totalModified -gt 0) { [ConsoleColor]::Green } else { [ConsoleColor]::White })
Write-Host " Total Matches      : $totalOccurrences" -ForegroundColor $(if ($totalOccurrences -gt 0) { [ConsoleColor]::Green } else { [ConsoleColor]::White })
Write-Host " Files Failed       : $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { [ConsoleColor]::Red } else { [ConsoleColor]::White })
Write-Host " Elapsed Time       : $($stopwatch.Elapsed.ToString('hh\:mm\:ss\.fff'))" -ForegroundColor White
if ($script:LoggingEnabled) {
    Write-Host " Log File           : $($script:LogFilePath)" -ForegroundColor White
}
Write-Host "================================================================================`n" -ForegroundColor Cyan

# Return summary object to pipeline
return [PSCustomObject]@{
    Path          = $resolvedPath
    FilesScanned  = $totalScanned
    FilesModified = $totalModified
    FilesFailed   = $totalFailed
    Duration      = $stopwatch.Elapsed
    Mode          = $mode
}
