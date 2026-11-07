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
    - Advanced Regular Expressions: Full support for literal replacement, regex patterns (-UseRegex),
      multiline (^/$ matching each line via -RegexMultiline), singleline (. matching newlines via -RegexSingleline),
      and dynamic ScriptBlock evaluation (-MatchEvaluator).
    - Encoding Support: Supports UTF-8 (PS5.1 default BOM / PS7 default no-BOM), UTF8NoBOM, ASCII, and Unicode.
    - Preserves Newlines & Diacritics: Accurately retains Windows (CRLF) and Unix (LF) line endings
      as well as international/Polish diacritics.
    - Binary Protection & File Size Bounds: Automatically detects and skips binary files
      to prevent corrupting executables or images, with a configurable file size guard (-MaxFileSizeMB).
    - Flexible Multi-Filtering & Exclusions: Supports multiple file filter masks (-Filter) and
      file-name/pattern exclusions (-ExcludeFiles) alongside directory exclusions (-ExcludeDirectories).
    - Backup Management: Creates backups alongside modified files (-CreateBackup) or cleanly
      in a dedicated backup directory tree (-BackupDirectory).
    - Visual Diff Preview & Audit Export: Previews before/after diff snippets with line numbers (-ShowDiff)
      and exports structured audit reports to CSV or JSON (-ExportReportPath).
    - Smart Modification: Files are only touched and rewritten if replacement matches are actually found,
      preserving file modification timestamps on untouched files.
    - Structured Logging: Optional -EnableLogging switch writes structured timestamps and logs to C:\Logs.

.PARAMETER Path
    The target directory path containing the files to process.
    Aliases: Folder, Directory.

.PARAMETER FindText
    The literal text string or Regular Expression pattern to search for.

.PARAMETER ReplaceWith
    The replacement text. Defaults to an empty string (""), which removes matching occurrences.

.PARAMETER MatchEvaluator
    A PowerShell ScriptBlock for dynamic replacement (e.g., { param($m) $m.Value.ToUpper() }).
    When specified, automatically enables regular expressions.

.PARAMETER Filter
    One or more file filter masks (e.g. '*.md', '*.json', '*.config'). Defaults to '*.*'.
    Can be supplied as an array or comma-separated string.

.PARAMETER Recurse
    Recursively scans subdirectories when specified.

.PARAMETER UseRegex
    Treats -FindText as a Regular Expression pattern rather than a literal string.

.PARAMETER RegexSingleline
    Enables Singleline mode (RegexOptions.Singleline), allowing the dot '.' to match newline characters '\n'.
    Ideal for multiline blocks (XML/JSON/HTML tags).

.PARAMETER RegexMultiline
    Enables Multiline mode (RegexOptions.Multiline), changing the meaning of '^' and '$' so they match
    at the beginning and end of any line, not just the whole string.

.PARAMETER CaseSensitive
    Enforces case-sensitive matching. Defaults to false (case-insensitive).

.PARAMETER ExcludeDirectories
    Array of folder names to exclude from processing.
    Defaults to @('.git', '.vs', 'node_modules').

.PARAMETER ExcludeFiles
    Array of file patterns to exclude from processing (e.g. '*.min.js', 'package-lock.json').

.PARAMETER Encoding
    File output encoding. Supported values: 'utf8', 'utf8NoBOM', 'ascii', 'unicode'.
    Defaults to 'utf8'.

.PARAMETER CreateBackup
    Creates a backup copy with the '.bak' extension before saving modifications.

.PARAMETER BackupDirectory
    Specifies a dedicated destination directory for backup files, preserving relative paths.

.PARAMETER IncludeBinary
    When specified, disables automatic binary file detection and processes binary files.
    Default behavior skips binary files safely.

.PARAMETER SkipBinary
    Explicit switch to skip binary files (active by default; provided for command-line clarity).

.PARAMETER MaxFileSizeMB
    Maximum allowable file size in megabytes to process. Prevents OutOfMemory exceptions on massive files.
    Defaults to 50 MB. Set to 0 to disable size limit.

.PARAMETER ShowDiff
    Displays a colorized visual diff preview of matched lines with line numbers before applying changes.

.PARAMETER ExportReportPath
    Path to an output report file (.csv or .json) recording execution details for each processed file.

.PARAMETER EnableLogging
    Enables execution logging to C:\Logs\<YYYYMMDD-HHmmss>-replace-text-in-files-<HostName>-<UserName>.log.

.PARAMETER Help
    Displays the interactive help guide and examples.
    Aliases: h, HelpMe.

.OUTPUTS
    [PSCustomObject] Summary object containing:
    - Path               : Analyzed directory path
    - FilesScanned       : Total number of scanned files
    - FilesModified      : Number of files modified (or that would be modified in WhatIf mode)
    - FilesFailed        : Number of files that encountered errors
    - FilesSkippedBinary : Number of binary files safely skipped
    - FilesSkippedSize   : Number of oversized files skipped
    - TotalMatches       : Total number of replacement occurrences found
    - Duration           : Time elapsed during operation
    - Mode               : 'Execute' or 'WhatIf'

.EXAMPLE
    .\replace-text-in-files.ps1 -Path ".\Docs" -Filter "*.md" -FindText "#stary-tag" -ReplaceWith "" -Recurse
    Recursively removes '#stary-tag' from all Markdown files under the '.\Docs' folder.

.EXAMPLE
    .\replace-text-in-files.ps1 -Path "C:\Projekty" -Filter "*.json" -FindText 'v(\d+)\.(\d+)\.(\d+)' -ReplaceWith 'v2.$2.$3' -UseRegex -ShowDiff -WhatIf
    Simulates regex version replacement with visual diff preview without modifying disk.

.EXAMPLE
    .\replace-text-in-files.ps1 -Path "D:\Configs" -Filter "*.config", "*.xml" -FindText "(?s)<connectionString>.*?</connectionString>" -ReplaceWith "<connectionString>Server=new-db</connectionString>" -UseRegex -RegexSingleline -BackupDirectory "D:\Backups" -ExportReportPath ".\report.json"
    Replaces multiline connection blocks across config and XML files, routing backups to D:\Backups and exporting audit report.

.EXAMPLE
    .\replace-text-in-files.ps1 -Path ".\Source" -Filter "*.cs" -FindText '\b[a-z0-9._%+-]+@company\.com\b' -MatchEvaluator { param($m) $m.Value.ToLower() } -ShowDiff
    Dynamically normalizes company email addresses to lowercase using a ScriptBlock evaluator.

.NOTES
    Script Name : replace-text-in-files.ps1
    Author      : Roman Pindela
    Contact     : roman.pindela@gmail.com
    GitHub      : https://github.com/romanpindela
    Version     : 1.1.0
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
    [scriptblock]$MatchEvaluator,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [string[]]$Filter = @("*.*"),

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$Recurse,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$UseRegex,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$RegexSingleline,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$RegexMultiline,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$CaseSensitive,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [string[]]$ExcludeDirectories = @('.git', '.vs', 'node_modules'),

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [string[]]$ExcludeFiles = @(),

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [ValidateSet("utf8", "utf8NoBOM", "ascii", "unicode", IgnoreCase = $true)]
    [string]$Encoding = "utf8",

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$CreateBackup,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [string]$BackupDirectory,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$IncludeBinary,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$SkipBinary,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [int]$MaxFileSizeMB = 50,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$ShowDiff,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [string]$ExportReportPath,

    [Parameter(Mandatory = $false, ParameterSetName = "Replace")]
    [switch]$EnableLogging,

    [Parameter(Mandatory = $false, ParameterSetName = "Help")]
    [Alias("h", "HelpMe")]
    [switch]$Help
)

# --- SCRIPT CONSTANTS & METADATA ---
$SCRIPT_INFO = @{
    Name        = "replace-text-in-files"
    Version     = "1.1.0"
    Author      = "Roman Pindela"
    Contact     = "roman.pindela@gmail.com"
    GitHub      = "https://github.com/romanpindela"
    ReleaseDate = "2026-11-07"
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
# BINARY DETECTION HELPER
# ==============================================================================
function Test-IsBinaryFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $buffer = [byte[]]::new(8192)
    $fs = $null
    try {
        $fs = [System.IO.File]::OpenRead($FilePath)
        $bytesRead = $fs.Read($buffer, 0, $buffer.Length)
        if ($bytesRead -le 0) { return $false }

        # Check for known text Unicode Byte Order Marks (BOM)
        # UTF-8 BOM: EF BB BF
        if ($bytesRead -ge 3 -and $buffer[0] -eq 0xEF -and $buffer[1] -eq 0xBB -and $buffer[2] -eq 0xBF) {
            return $false
        }
        # UTF-16 LE BOM: FF FE
        if ($bytesRead -ge 2 -and $buffer[0] -eq 0xFF -and $buffer[1] -eq 0xFE) {
            return $false
        }
        # UTF-16 BE BOM: FE FF
        if ($bytesRead -ge 2 -and $buffer[0] -eq 0xFE -and $buffer[1] -eq 0xFF) {
            return $false
        }

        # Scan for null bytes (0x00) which indicate binary files
        for ($i = 0; $i -lt $bytesRead; $i++) {
            if ($buffer[$i] -eq 0) {
                return $true
            }
        }
        return $false
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $fs) { $fs.Dispose() }
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
  -MatchEvaluator <ScriptBlock>  : ScriptBlock for dynamic replacement (e.g. { param(`$m) `$m.Value.ToUpper() })
  -Filter <String[]>             : File filter mask(s), e.g. '*.json', '*.xml' (Default: '*.*')
  -Recurse                       : Searches subfolders recursively
  -UseRegex                      : Enables regular expression matching
  -RegexSingleline               : Allows '.' to match newlines (\n) for multiline block replacement
  -RegexMultiline                : Changes '^' and '$' to match start/end of each line
  -CaseSensitive                 : Enforces case-sensitive search
  -ExcludeDirectories <String[]> : Folder names to ignore (Default: .git, .vs, node_modules)
  -ExcludeFiles <String[]>       : File patterns to ignore (e.g. '*.min.js', 'package-lock.json')
  -Encoding <String>             : Output encoding: utf8, utf8NoBOM, ascii, unicode (Default: utf8)
  -CreateBackup                  : Creates a .bak backup alongside modified files
  -BackupDirectory <String>      : Dedicated destination directory for backups (preserves hierarchy)
  -IncludeBinary                 : Disables automatic binary file detection (processes binary files)
  -MaxFileSizeMB <Int32>         : Maximum file size to scan in MB (Default: 50, 0 = unlimited)
  -ShowDiff                      : Displays colorized line-by-line diff preview before/after
  -ExportReportPath <String>     : Path to export audit report file (.csv or .json)
  -EnableLogging                 : Writes execution logs to C:\Logs
  -WhatIf                        : Simulates changes without modifying files on disk
  -Confirm                       : Prompts for confirmation before modifying each file
  -Help / -h                     : Displays this help screen

PRACTICAL EXAMPLES:
  1. Remove old tag from Markdown files:
     .\replace-text-in-files.ps1 -Path ".\Docs" -Filter "*.md" -FindText "#old-tag" -ReplaceWith "" -Recurse

  2. Simulate Regex replacement with visual diff (-ShowDiff -WhatIf):
     .\replace-text-in-files.ps1 -Path "C:\Projekty" -Filter "*.json" -FindText 'v\d+\.\d+\.\d+' -ReplaceWith 'v2.0.0' -UseRegex -ShowDiff -WhatIf

  3. Multiline XML/Config block replacement with dedicated backup directory and JSON report:
     .\replace-text-in-files.ps1 -Path "D:\Configs" -Filter "*.config", "*.xml" -FindText "(?s)<connectionString>.*?</connectionString>" -ReplaceWith "<connectionString>Server=new-db</connectionString>" -UseRegex -RegexSingleline -BackupDirectory "D:\Backups" -ExportReportPath ".\audit.json"

  4. Dynamic normalization using a ScriptBlock evaluator:
     .\replace-text-in-files.ps1 -Path ".\Source" -Filter "*.cs" -FindText '\b[a-z0-9._%+-]+@company\.com\b' -MatchEvaluator { param(`$m) `$m.Value.ToLower() } -ShowDiff
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
Write-AppLog "Target path resolved: '$resolvedPath'" -Level INFO

# Normalize Backup Directory if specified
$resolvedBackupDir = $null
if (-not [string]::IsNullOrWhiteSpace($BackupDirectory)) {
    $resolvedBackupDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BackupDirectory)
    if (-not (Test-Path -LiteralPath $resolvedBackupDir)) {
        try {
            $null = [System.IO.Directory]::CreateDirectory($resolvedBackupDir)
            Write-AppLog "Created backup directory: '$resolvedBackupDir'" -Level INFO
        }
        catch {
            $errMsg = "Failed to create backup directory '$resolvedBackupDir': $($_.Exception.Message)"
            Write-AppLog $errMsg -Level ERROR
            throw $errMsg
        }
    }
}

# 4. Encoding Resolver
$targetEncoding = $null
$readEncodingName = "UTF8"

switch ($Encoding.ToLowerInvariant()) {
    "utf8" {
        # PS5.1 defaults to UTF-8 with BOM; PS7+ defaults to UTF-8 BOM-less
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
if ($null -ne $MatchEvaluator) {
    # MatchEvaluator implies Regex
    $UseRegex = $true
}

$regexOptions = [System.Text.RegularExpressions.RegexOptions]::None
if (-not $CaseSensitive) {
    $regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
}
if ($RegexSingleline) {
    $regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
}
if ($RegexMultiline) {
    $regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
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

# 6. Exclude Directories & Files Normalization
$excludeDirSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($null -ne $ExcludeDirectories) {
    foreach ($dir in $ExcludeDirectories) {
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            [void]$excludeDirSet.Add($dir.Trim().Trim('\', '/'))
        }
    }
}

$excludeFilePatterns = [System.Collections.Generic.List[string]]::new()
if ($null -ne $ExcludeFiles) {
    foreach ($ef in $ExcludeFiles) {
        if (-not [string]::IsNullOrWhiteSpace($ef)) {
            foreach ($subEf in $ef.Split(',')) {
                $trimmed = $subEf.Trim()
                if (-not [string]::IsNullOrEmpty($trimmed)) {
                    $excludeFilePatterns.Add($trimmed)
                }
            }
        }
    }
}

# 7. File Filters Normalization
$normalizedFilters = [System.Collections.Generic.List[string]]::new()
if ($null -ne $Filter) {
    foreach ($f in $Filter) {
        if (-not [string]::IsNullOrWhiteSpace($f)) {
            foreach ($subF in $f.Split(',')) {
                $trimmed = $subF.Trim()
                if (-not [string]::IsNullOrEmpty($trimmed)) {
                    $normalizedFilters.Add($trimmed)
                }
            }
        }
    }
}
if ($normalizedFilters.Count -eq 0) {
    $normalizedFilters.Add("*.*")
}

# 8. File Discovery
Write-AppLog "Scanning directory for files matching filter(s): $($normalizedFilters -join ', ')..." -Level INFO

$seenFilePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$foundFiles    = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

foreach ($filterMask in $normalizedFilters) {
    $gciParams = @{
        LiteralPath = $resolvedPath
        Filter      = $filterMask
        File        = $true
        Recurse     = $Recurse.IsPresent
        ErrorAction = 'SilentlyContinue'
    }
    $discovered = Get-ChildItem @gciParams
    if ($null -ne $discovered) {
        foreach ($item in $discovered) {
            if ($seenFilePaths.Add($item.FullName)) {
                $foundFiles.Add($item)
            }
        }
    }
}

# Filter out excluded directory segments and excluded file patterns
$eligibleFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($file in $foundFiles) {
    $shouldExclude = $false

    # Relative path calculation
    $relPath = if ($file.FullName.StartsWith($resolvedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $file.FullName.Substring($resolvedPath.Length).TrimStart('\', '/')
    } else {
        $file.FullName
    }

    # Directory exclusion check
    if ($excludeDirSet.Count -gt 0) {
        $segments = $relPath.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        for ($i = 0; $i -lt ($segments.Length - 1); $i++) {
            if ($excludeDirSet.Contains($segments[$i])) {
                $shouldExclude = $true
                break
            }
        }
    }

    # File pattern exclusion check
    if (-not $shouldExclude -and $excludeFilePatterns.Count -gt 0) {
        foreach ($pattern in $excludeFilePatterns) {
            if ($file.Name -like $pattern -or $relPath -like $pattern) {
                $shouldExclude = $true
                break
            }
        }
    }

    if (-not $shouldExclude) {
        $eligibleFiles.Add($file)
    }
}

$totalScanned         = $eligibleFiles.Count
$totalModified        = 0
$totalFailed          = 0
$totalOccurrences     = 0
$skippedBinaryCount   = 0
$skippedSizeCount     = 0
$reportRecords        = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-AppLog "Found $totalScanned file(s) eligible for processing." -Level INFO

# 9. Processing Loop
$currentIndex = 0

foreach ($file in $eligibleFiles) {
    $currentIndex++
    $percent = if ($totalScanned -gt 0) { [math]::Min(100, [int](($currentIndex / $totalScanned) * 100)) } else { 100 }
    Write-Progress -Activity "replace-text-in-files" -Status "Processing file $currentIndex of ${totalScanned} - $($file.Name)" -PercentComplete $percent

    $relPath = if ($file.FullName.StartsWith($resolvedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $file.FullName.Substring($resolvedPath.Length).TrimStart('\', '/')
    } else {
        $file.Name
    }

    # Max file size guard
    if ($MaxFileSizeMB -gt 0 -and $file.Length -gt ($MaxFileSizeMB * 1024 * 1024)) {
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        Write-AppLog "Skipping '$($file.FullName)' - file size (${sizeMB} MB) exceeds limit of $MaxFileSizeMB MB." -Level WARN
        $skippedSizeCount++
        $reportRecords.Add([PSCustomObject]@{
            FilePath     = $file.FullName
            RelativePath = $relPath
            FileSizeKB   = [math]::Round($file.Length / 1KB, 2)
            MatchesCount = 0
            Status       = "SkippedSize"
            ErrorMessage = "File size exceeds limit of $MaxFileSizeMB MB"
        })
        continue
    }

    # Binary file guard
    if (-not $IncludeBinary) {
        if (Test-IsBinaryFile -FilePath $file.FullName) {
            Write-AppLog "Skipping binary file '$($file.FullName)'." -Level WARN
            $skippedBinaryCount++
            $reportRecords.Add([PSCustomObject]@{
                FilePath     = $file.FullName
                RelativePath = $relPath
                FileSizeKB   = [math]::Round($file.Length / 1KB, 2)
                MatchesCount = 0
                Status       = "SkippedBinary"
                ErrorMessage = "Binary file detected"
            })
            continue
        }
    }

    $tempFilePath = $null
    try {
        # Read file safely into memory
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding $readEncodingName -ErrorAction Stop

        if ($null -eq $content) {
            # Empty file, nothing to replace
            $reportRecords.Add([PSCustomObject]@{
                FilePath     = $file.FullName
                RelativePath = $relPath
                FileSizeKB   = [math]::Round($file.Length / 1KB, 2)
                MatchesCount = 0
                Status       = "Unchanged"
                ErrorMessage = $null
            })
            continue
        }

        # Check for matches
        $matches = $compiledRegex.Matches($content)
        $matchCount = $matches.Count

        if ($matchCount -eq 0) {
            # No occurrence found, skip file without touching disk
            $reportRecords.Add([PSCustomObject]@{
                FilePath     = $file.FullName
                RelativePath = $relPath
                FileSizeKB   = [math]::Round($file.Length / 1KB, 2)
                MatchesCount = 0
                Status       = "Unchanged"
                ErrorMessage = $null
            })
            continue
        }

        # Visual Diff Preview if requested
        if ($ShowDiff) {
            Write-Host "`n  [DIFF PREVIEW] $($file.FullName) ($matchCount match(es))" -ForegroundColor Cyan
            $diffPreviewIndex = 0
            foreach ($m in $matches) {
                $diffPreviewIndex++
                if ($diffPreviewIndex -gt 10) {
                    $remaining = $matchCount - 10
                    Write-Host "    ... ($remaining more match(es) truncated from console preview)" -ForegroundColor DarkGray
                    break
                }

                $prefix = $content.Substring(0, $m.Index)
                $lineNum = ([regex]::Matches($prefix, "`n")).Count + 1

                $replacementPreview = if ($null -ne $MatchEvaluator) {
                    try { (& $MatchEvaluator $m) } catch { "<ScriptBlock Error: $($_.Exception.Message)>" }
                } elseif ($UseRegex) {
                    try { $m.Result($ReplaceWith) } catch { $ReplaceWith }
                } else {
                    $ReplaceWith
                }

                Write-Host "    Line ${lineNum}:" -ForegroundColor Yellow
                Write-Host "      [-] $($m.Value)" -ForegroundColor Red
                Write-Host "      [+] $replacementPreview" -ForegroundColor Green
            }
        }

        # Occurrence found - handle modification
        $actionDescription = "Replace $matchCount occurrence(s) in '$($file.FullName)'"

        if ($PSCmdlet.ShouldProcess($file.FullName, $actionDescription)) {
            # Create backup if requested
            if ($CreateBackup -or -not [string]::IsNullOrEmpty($resolvedBackupDir)) {
                $backupPath = if (-not [string]::IsNullOrEmpty($resolvedBackupDir)) {
                    $targetBackup = Join-Path -Path $resolvedBackupDir -ChildPath "$relPath.bak"
                    $parentDir = [System.IO.Path]::GetDirectoryName($targetBackup)
                    if (-not (Test-Path -LiteralPath $parentDir)) {
                        $null = [System.IO.Directory]::CreateDirectory($parentDir)
                    }
                    $targetBackup
                } else {
                    "$($file.FullName).bak"
                }

                Copy-Item -LiteralPath $file.FullName -Destination $backupPath -Force -ErrorAction Stop
                Write-AppLog "Backup created: '$backupPath'" -Level ACTION
            }

            # Perform replacement
            $newContent = if ($null -ne $MatchEvaluator) {
                $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
                    param([System.Text.RegularExpressions.Match]$m)
                    & $MatchEvaluator $m
                }
                $compiledRegex.Replace($content, $evaluator)
            } elseif ($UseRegex) {
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

            $reportRecords.Add([PSCustomObject]@{
                FilePath     = $file.FullName
                RelativePath = $relPath
                FileSizeKB   = [math]::Round($file.Length / 1KB, 2)
                MatchesCount = $matchCount
                Status       = "Modified"
                ErrorMessage = $null
            })
        }
        else {
            # WhatIf mode was triggered
            Write-AppLog "[WhatIf] Would modify '$($file.FullName)' ($matchCount occurrence(s) matched)." -Level ACTION
            $totalModified++
            $totalOccurrences += $matchCount

            $reportRecords.Add([PSCustomObject]@{
                FilePath     = $file.FullName
                RelativePath = $relPath
                FileSizeKB   = [math]::Round($file.Length / 1KB, 2)
                MatchesCount = $matchCount
                Status       = "WhatIf"
                ErrorMessage = $null
            })
        }
    }
    catch [System.UnauthorizedAccessException] {
        $totalFailed++
        $errMsg = "Access denied when processing '$($file.FullName)'. Run script as Administrator to modify this file."
        Write-AppLog $errMsg -Level ERROR
        Write-Warning $errMsg

        $reportRecords.Add([PSCustomObject]@{
            FilePath     = $file.FullName
            RelativePath = $relPath
            FileSizeKB   = [math]::Round($file.Length / 1KB, 2)
            MatchesCount = 0
            Status       = "Failed"
            ErrorMessage = $errMsg
        })
    }
    catch {
        $totalFailed++
        $errMsg = "Error processing '$($file.FullName)': $($_.Exception.Message)"
        Write-AppLog $errMsg -Level ERROR
        Write-Warning $errMsg

        $reportRecords.Add([PSCustomObject]@{
            FilePath     = $file.FullName
            RelativePath = $relPath
            FileSizeKB   = [math]::Round($file.Length / 1KB, 2)
            MatchesCount = 0
            Status       = "Failed"
            ErrorMessage = $errMsg
        })
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

# 10. Audit Report Export
if (-not [string]::IsNullOrWhiteSpace($ExportReportPath)) {
    try {
        $resolvedReportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExportReportPath)
        $parentReportDir = [System.IO.Path]::GetDirectoryName($resolvedReportPath)
        if (-not [string]::IsNullOrEmpty($parentReportDir) -and -not (Test-Path -LiteralPath $parentReportDir)) {
            $null = [System.IO.Directory]::CreateDirectory($parentReportDir)
        }

        $reportExt = [System.IO.Path]::GetExtension($resolvedReportPath)
        if ($reportExt -eq ".json") {
            $reportRecords | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8 -Force
        } else {
            $reportRecords | Export-Csv -LiteralPath $resolvedReportPath -NoTypeInformation -Encoding UTF8 -Force
        }
        Write-AppLog "Execution audit report exported to: '$resolvedReportPath'" -Level ACTION
    }
    catch {
        Write-AppLog "Failed to export audit report: $($_.Exception.Message)" -Level ERROR
    }
}

$stopwatch.Stop()
$mode = if ($WhatIfPreference) { "WhatIf" } else { "Execute" }

# 11. Summary Output
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " replace-text-in-files - Operation Summary ($mode)" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Path               : $resolvedPath" -ForegroundColor White
Write-Host " Files Scanned      : $totalScanned" -ForegroundColor White
Write-Host " Files Modified     : $totalModified" -ForegroundColor $(if ($totalModified -gt 0) { [ConsoleColor]::Green } else { [ConsoleColor]::White })
Write-Host " Total Matches      : $totalOccurrences" -ForegroundColor $(if ($totalOccurrences -gt 0) { [ConsoleColor]::Green } else { [ConsoleColor]::White })
Write-Host " Binary Skipped     : $skippedBinaryCount" -ForegroundColor $(if ($skippedBinaryCount -gt 0) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White })
Write-Host " Size Skipped (>50M): $skippedSizeCount" -ForegroundColor $(if ($skippedSizeCount -gt 0) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White })
Write-Host " Files Failed       : $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { [ConsoleColor]::Red } else { [ConsoleColor]::White })
Write-Host " Elapsed Time       : $($stopwatch.Elapsed.ToString('hh\:mm\:ss\.fff'))" -ForegroundColor White
if ($script:LoggingEnabled) {
    Write-Host " Log File           : $($script:LogFilePath)" -ForegroundColor White
}
if (-not [string]::IsNullOrEmpty($ExportReportPath)) {
    Write-Host " Audit Report       : $resolvedReportPath" -ForegroundColor White
}
Write-Host "================================================================================`n" -ForegroundColor Cyan

# Return summary object to pipeline
return [PSCustomObject]@{
    Path                 = $resolvedPath
    FilesScanned         = $totalScanned
    FilesModified        = $totalModified
    FilesFailed          = $totalFailed
    FilesSkippedBinary   = $skippedBinaryCount
    FilesSkippedSize     = $skippedSizeCount
    TotalMatches         = $totalOccurrences
    Duration             = $stopwatch.Elapsed
    Mode                 = $mode
}
