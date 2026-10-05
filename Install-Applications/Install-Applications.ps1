<#
================================================================================
  Nazwa skryptu : Install-Applications.ps1
  Autor         : Roman Pindela
  Kontakt       : roman.pindela@gmail.com
  Wersja        : 1.9.9
  Data wydania  : 2026-10-04
  Licencja      : MIT
  Repozytorium  : https://github.com/roman/install-applications

  OPIS:
    Skrypt automatyzuje instalacje i konfiguracje oprogramowania stacji roboczej
    w srodowisku Windows (architektura x64) w oparciu o winget oraz plik JSON.
    Wykorzystuje natywne API .NET Registry do precyzyjnego audytu i odczytu
    metadanych zainstalowanych aplikacji (DisplayName, DisplayVersion,
    InstallDate, InstallLocation). Pomija programy obecne juz w systemie,
    wspiera instalacje profilu uzytkownika (non-admin fallback dla np. Spotify).
    Procedura awaryjna ODT dla pakietu Office 365 uruchamiana jest WYLACZNIE
    wtedy, gdy uzytkownik jawnie przekaże przelacznik -Fallback.
    Posiada modul rejestrowania pelnego przebiegu instalacji do pliku logu.

================================================================================
.SYNOPSIS
    Automatycznie pobiera, audytuje i instaluje aplikacje z pliku JSON przy uzyciu winget.
.PARAMETER ConfigPath
    Sciezka do pliku JSON z lista programow do zainstalowania.
.PARAMETER LogPath
    Sciezka do logu instalacji lub raportu zainstalowanych aplikacji.
    W trybie raportu pusta wartosc (-l "") zapisuje raport pod domyslna nazwa
    zakonczona sufiksem -installedApplications.txt.
    W trybie -VerifyInstalledApps parametr -l zapisuje raport. Pusta wartosc
    (-l "") wybiera domyslna nazwe z sufiksem -installedApplications.
.PARAMETER Fallback
    Zezwala na uzycie procedury awaryjnej ODT dla pakietu Office w przypadku
    bledu instalatora winget (np. niezgodnosci sumy kontrolnej). Domyslnie wylaczone.
.PARAMETER VerifyInstalledApps
    Wyswietla zainstalowane programy pogrupowane wedlug producenta.
.PARAMETER Help
    Wyswietla szczegolowe menu pomocy i informacje o autorze.
.EXAMPLE
    .\Install-Applications.ps1 -ConfigPath .\ApplicationList-Roman.json
.EXAMPLE
    .\Install-Applications.ps1 -ConfigPath .\ApplicationList.json -Fallback
.EXAMPLE
    .\Install-Applications.ps1 -h
#>
[CmdletBinding(DefaultParameterSetName = "Install")]
param (
    [Parameter(ParameterSetName = "Install", Position = 0)]
    [Alias("c", "Path")]
    [ValidateScript({
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_);
        if ([System.IO.File]::Exists($resolved)) { $true }
        else { throw "Plik konfiguracji nie istnieje pod podana sciezka: $_" }
    })]
    [string]$ConfigPath,

    [Parameter(ParameterSetName = "Install", Position = 1)]
    [Parameter(ParameterSetName = "Verify")]
    [Alias("l", "Log")]
    [string]$LogPath,

    [Parameter(ParameterSetName = "Install")]
    [Alias("fo", "FallbackOffice")]
    [switch]$Fallback,

    [Parameter(ParameterSetName = "Verify")]
    [Alias("v")]
    [switch]$VerifyInstalledApps,

    [Parameter(ParameterSetName = "Help")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";

$SCRIPT_INFO = @{
    Name        = "Install-Applications";
    Version     = "1.9.9";
    Author      = "Roman Pindela";
    Contact     = "roman.pindela@gmail.com";
    ReleaseDate = "2026-10-04";
};

# Globalna zmienna przechowujaca sciezke aktywnego pliku dziennika
$script:ActiveLogFile = $null;

function Write-Log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    [Console]::CursorLeft = 0;
    Write-Host "$Message" -ForegroundColor $Color;

    if (-not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
        try {
            $timePrefix = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss");
            $cleanLine = "[$timePrefix] $Message`r`n";
            [System.IO.File]::AppendAllText($script:ActiveLogFile, $cleanLine, [System.Text.Encoding]::UTF8);
        }
        catch {}
    }
}

function Show-HelpGuide {
    [Console]::CursorLeft = 0;
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Autor: $($SCRIPT_INFO.Author) | Kontakt: $($SCRIPT_INFO.Contact)
================================================================================
OPIS:
  Automatyczny instalator stacji roboczej Windows x64 z pelnym audytem rejestru
  oraz rejestrowaniem dzialan do pliku dziennika.

UZYCIE:
  .\Install-Applications.ps1 -ConfigPath <sciezka_do_pliku.json> [-LogPath <sciezka_do_logu.txt>] [-Fallback]
    .\Install-Applications.ps1 -VerifyInstalledApps [-LogPath <sciezka_do_raportu.txt>]
    .\Install-Applications.ps1 -v [-l ""]
  .\Install-Applications.ps1 -h | -Help

PARAMETRY:
  -ConfigPath, -c, -Path : [Wymagany] Sciezka do pliku JSON z konfiguracja pakietow.
    -LogPath, -l, -Log     : [Opcjonalny] Sciezka pliku logu instalacji. Z -v zapisuje
                                                     raport; -v -l "" wybiera domyslna nazwe zakonczona
                                                     -installedApplications.txt.
  -Fallback, -fo         : [Opcjonalny] Wlacza procedure awaryjna ODT dla pakietu Office
                           w razie bledu sumy kontrolnej w winget. Bez tej flagi
                           procedura awaryjna nie zostanie uruchomiona.
    -VerifyInstalledApps, -v : Wyswietla programy pogrupowane wedlug producenta,
                                                            posortowane wedlug daty instalacji.
  -Help, -h              : Wyswietla to menu pomocy oraz informacje o autorze.

PRZYKLADY:
  .\Install-Applications.ps1 -h
  .\Install-Applications.ps1 -ConfigPath .\ApplicationList-Roman.json
  .\Install-Applications.ps1 -c .\ApplicationList.json -Fallback
    .\Install-Applications.ps1 -v
    .\Install-Applications.ps1 -v -l ""
    .\Install-Applications.ps1 -v -l "C:\Reports\InstalledApps.txt"
  .\Install-Applications.ps1 .\ApplicationList.json -LogPath "C:\Deploy\log.txt"
================================================================================
"@ -ForegroundColor Yellow;
}

if ($Help -or ([string]::IsNullOrWhiteSpace($ConfigPath) -and -not $VerifyInstalledApps)) {
    Show-HelpGuide;
    return;
}

# Inicjalizacja domyslnej sciezki logowania, jesli nie zostala wskazana
if (-not $VerifyInstalledApps) {
    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $defaultLogDir = "C:\Logs";
        $timeMarker = (Get-Date).ToString("yyyyMMdd_HHmmss");
        $compName   = $env:COMPUTERNAME;
        $userName   = $env:USERNAME;
        $scriptName = $SCRIPT_INFO.Name;
        $logFileName = "${timeMarker}-${compName}-${userName}-${scriptName}.txt";
        $LogPath = Join-Path ($defaultLogDir) ($logFileName);
    }

    $resolvedLogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath);
    $logDirectory = [System.IO.Path]::GetDirectoryName($resolvedLogPath);
    if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not [System.IO.Directory]::Exists($logDirectory)) {
        [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null;
    }
    $script:ActiveLogFile = $resolvedLogPath;
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent();
    $principal = New-Object Security.Principal.WindowsPrincipal($identity);
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
}

function Assert-WingetPrerequisites {
    param ([string]$MinimumVersion = "1.7.0")

    $wingetCmd = Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue;
    $needsUpdate = $false;

    if (-not $wingetCmd) {
        Write-Log "[!] Narzedzie winget nie jest zainstalowane." Yellow;
        $needsUpdate = $true;
    }
    else {
        try {
            $rawVer = (& winget.exe --version 2>$null | Out-String).Trim().TrimStart('v');
            $parsedParts = $rawVer.Split('-')[0].Split('.');
            while ($parsedParts.Count -lt 2) { $parsedParts += "0"; }
            $installedVer = [version]($parsedParts -join '.');

            Write-Log "[i] Wykryto wersje winget: $rawVer" Gray;

            if ($installedVer -lt [version]$MinimumVersion) {
                Write-Log "[!] Wersja winget ($rawVer) wymaga aktualizacji (min. $MinimumVersion)..." Yellow;
                $needsUpdate = $true;
            }
        }
        catch {
            $needsUpdate = $true;
        }
    }

    if (-not $needsUpdate) {
        Write-Log "[+] Srodowisko winget jest gotowe do pracy." Green;
        return;
    }

    Write-Log "[*] Instalowanie aktualizacji winget wraz z zaleznosciami..." Cyan;
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

    try {
        if (-not (Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.201 -Force | Out-Null;
        }
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted;
        if (-not (Get-Module -ListAvailable -Name "Microsoft.WinGet.Client")) {
            Install-Module -Name "Microsoft.WinGet.Client" -Force -AllowClobber | Out-Null;
        }
        Import-Module -Name "Microsoft.WinGet.Client" -Force;
        Repair-WinGetPackageManager -Latest -Force;

        $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine);
        $userPath    = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User);
        $env:Path    = "$machinePath;$userPath";

        Write-Log "[+] Winget zostal pomyslnie zaktualizowany." Green;
    }
    catch {
        throw "Nie udalo sie zaktualizowac winget: $_";
    }
}

function Install-OfficeFallback {
    Write-Log "    [!] Uruchamianie procedury awaryjnej (Office Deployment Tool - PL x64)..." Yellow;

    $tempDir = Join-Path ($env:TEMP) "OfficeInstall";
    if (-not [System.IO.Directory]::Exists($tempDir)) {
        [System.IO.Directory]::CreateDirectory($tempDir) | Out-Null;
    }

    $setupExe = Join-Path ($tempDir) "setup.exe";
    $configXml = Join-Path ($tempDir) "configuration.xml";
    $directSetupUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe";

    $xmlContent = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="pl-pl" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
</Configuration>
"@;

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
        [System.IO.File]::WriteAllText($configXml, $xmlContent, [System.Text.Encoding]::UTF8);

        $webParams = @{
            Uri             = $directSetupUrl
            OutFile         = $setupExe
            UseBasicParsing = $true
        };
        Invoke-WebRequest @webParams;

        $officeProcParams = @{
            FilePath         = "setup.exe"
            WorkingDirectory = $tempDir
            ArgumentList     = "/configure `"$configXml`""
            Wait             = $true
            PassThru         = $true
        };
        $process = Start-Process @officeProcParams;

        if ($process.ExitCode -eq 0) {
            Write-Log "    [+] Sukces: Microsoft 365 Apps zostal zainstalowany." Green;
        }
        else {
            Write-Log "    [-] Instalator Office zakonczyl dzialanie z kodem: $($process.ExitCode)" Yellow;
        }
    }
    catch {
        Write-Log "    [-] Blad podczas instalacji Office w trybie awaryjnym: $_" Red;
    }
    finally {
        if ([System.IO.Directory]::Exists($tempDir)) {
            try { [System.IO.Directory]::Delete($tempDir, $true); } catch {}
        }
    }
}

# --- Silnik inwentaryzacji i dopasowywania aplikacji (.NET Registry API) ---

function Get-WindowsInstalledApplications {
    [CmdletBinding()]
    param ()

    $installedList = [System.Collections.Generic.List[PSCustomObject]]::new();

    $hives = @(
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry32; Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" },
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser;  View = [Microsoft.Win32.RegistryView]::Default;    Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" }
    );

    foreach ($target in $hives) {
        $baseKey = $null;
        $subKey  = $null;
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($target.Hive, $target.View);
            $subKey  = $baseKey.OpenSubKey($target.Path);

            if ($subKey) {
                foreach ($keyName in $subKey.GetSubKeyNames()) {
                    $appKey = $null;
                    try {
                        $appKey = $subKey.OpenSubKey($keyName);
                        if ($appKey) {
                            $rawDisplayName = $appKey.GetValue("DisplayName");
                            $displayName = if ($null -ne $rawDisplayName) { [string]$rawDisplayName } else { "" };

                            if (-not [string]::IsNullOrWhiteSpace($displayName)) {
                                $rawVer  = $appKey.GetValue("DisplayVersion");
                                $rawDate = $appKey.GetValue("InstallDate");
                                $rawLoc  = $appKey.GetValue("InstallLocation");
                                $rawIcon = $appKey.GetValue("DisplayIcon");
                                $rawPublisher = $appKey.GetValue("Publisher");
                                $rawSize = $appKey.GetValue("EstimatedSize");
                                # Formatowanie daty instalacji YYYYMMDD -> YYYY-MM-DD
                                $formattedDate = "Brak wpisu daty w rejestrze";
                                $installDateSort = $null;
                                if ($null -ne $rawDate) {
                                    $dStr = [string]$rawDate;
                                    if ($dStr -match '^\d{8}$') {
                                        $formattedDate = "$($dStr.Substring(0,4))-$($dStr.Substring(4,2))-$($dStr.Substring(6,2))";
                                        try { $installDateSort = [datetime]::ParseExact($dStr, "yyyyMMdd", [Globalization.CultureInfo]::InvariantCulture); } catch {}
                                    } elseif (-not [string]::IsNullOrWhiteSpace($dStr)) {
                                        $formattedDate = $dStr;
                                        $parsedDate = [datetime]::MinValue;
                                        if ([datetime]::TryParse($dStr, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                                            $installDateSort = $parsedDate;
                                        }
                                    }
                                }

                                $sizeMB = $null;
                                if ($null -ne $rawSize) {
                                    $sizeKB = 0.0;
                                    if ([double]::TryParse([string]$rawSize, [ref]$sizeKB) -and $sizeKB -gt 0) {
                                        $sizeMB = [math]::Round(($sizeKB / 1024), 2);
                                    }
                                }

                                # Okreslanie sciezki instalacji
                                $location = "";
                                if ($null -ne $rawLoc -and -not [string]::IsNullOrWhiteSpace([string]$rawLoc)) {
                                    $location = [string]$rawLoc;
                                } elseif ($null -ne $rawIcon -and -not [string]::IsNullOrWhiteSpace([string]$rawIcon)) {
                                    $iconClean = ([string]$rawIcon -split ',')[0].Trim(' "');
                                    if ([System.IO.File]::Exists($iconClean)) {
                                        $location = [System.IO.Path]::GetDirectoryName($iconClean);
                                    }
                                }

                                if (-not $location) {
                                    $location = "Katalog domyslny systemu / profilu";
                                }

                                $installedList.Add([PSCustomObject]@{
                                    KeyName         = $keyName;
                                    DisplayName     = $displayName;
                                    DisplayVersion  = if ($null -ne $rawVer) { [string]$rawVer } else { "Brak danych o wersji" };
                                    Publisher       = if ($null -ne $rawPublisher -and -not [string]::IsNullOrWhiteSpace([string]$rawPublisher)) { [string]$rawPublisher } else { "Nieznany producent" };
                                    InstallDate     = $formattedDate;
                                    InstallDateSort = $installDateSort;
                                    SizeMB          = $sizeMB;
                                    Architecture    = if ($target.View -eq [Microsoft.Win32.RegistryView]::Registry32) { "32-bit" } else { "64-bit" };
                                    Scope           = if ($target.Hive -eq [Microsoft.Win32.RegistryHive]::CurrentUser) { "Użytkownik" } else { "Komputer" };
                                    InstallLocation = $location;
                                });
                            }
                        }
                    }
                    catch {}
                    finally {
                        if ($appKey) { $appKey.Close(); }
                    }
                }
            }
        }
        catch {}
        finally {
            if ($subKey)  { $subKey.Close(); }
            if ($baseKey) { $baseKey.Close(); }
        }
    }

    return $installedList;
}

function Find-InstalledApp {
    param (
        [string]$TargetName,
        [string]$TargetId,
        $SystemInventory
    )

    $cleanTargetName = ($TargetName -replace '\s*\([^)]*\)', '').Trim();

    # 1. Przeszukiwanie pamieci inwentarza rejestru
    foreach ($item in $SystemInventory) {
        if (-not [string]::IsNullOrWhiteSpace($TargetId) -and $item.KeyName -eq $TargetId) {
            return $item;
        }

        if ($item.DisplayName -eq $TargetName) {
            return $item;
        }

        if ($item.DisplayName -like "$cleanTargetName*" -or ($cleanTargetName.Length -ge 4 -and $item.DisplayName -like "*$cleanTargetName*")) {
            return $item;
        }
    }

    # 2. Awaryjny odczyt winget list dla aplikacji bez wpisu ARP
    if (-not [string]::IsNullOrWhiteSpace($TargetId)) {
        try {
            $wOut = (& winget.exe list --exact --id $TargetId --accept-source-agreements 2>$null | Out-String).Trim();
            if ($wOut -and $wOut -notmatch "Nie znaleziono" -and $wOut -notmatch "No installed") {
                $lines = $wOut -split "[\r\n]+" | Where-Object {
                    $_ -match [regex]::Escape($TargetId) -and
                    $_ -notmatch '^-{3,}' -and
                    $_ -notmatch '^Name\s+Id\s+Version' -and
                    $_ -notmatch '^Nazwa\s+Identyfikator'
                };
                if ($lines.Count -gt 0) {
                    $row = ($lines[0] -replace '\s{2,}', '|').Trim();
                    $cols = $row -split '\|';
                    $wName = if ($cols.Count -ge 1) { $cols[0].Trim() } else { $TargetName };
                    $wVer  = if ($cols.Count -ge 3) { $cols[2].Trim() } elseif ($cols.Count -ge 2) { $cols[1].Trim() } else { "Biezaca (winget)" };

                    return [PSCustomObject]@{
                        KeyName         = $TargetId;
                        DisplayName     = $wName;
                        DisplayVersion  = $wVer;
                        InstallDate     = "Zainstalowano przez winget";
                        InstallLocation = "Standardowy folder aplikacji";
                    };
                }
            }
        }
        catch {}
    }

    return $null;
}

function Show-AppMetadata {
    param (
        [PSCustomObject]$Info,
        [string]$Header = "Informacje o zainstalowanym pakiecie:"
    )
    Write-Log "    ----------------------------------------------------------------" DarkGray;
    Write-Log "    $Header" DarkCyan;
    Write-Log "      * Nazwa aplikacji  : $($Info.DisplayName)" Gray;
    Write-Log "      * Wersja programu  : $($Info.DisplayVersion)" Gray;
    Write-Log "      * Data instalacji  : $($Info.InstallDate)" Gray;
    Write-Log "      * Lokalizacja      : $($Info.InstallLocation)" Gray;
    Write-Log "    ----------------------------------------------------------------" DarkGray;
}

function Invoke-UserContextInstall {
    param (
        [string]$AppId,
        [string]$AppName
    )
    Write-Log "    [!] Pakiet $AppName wymaga instalacji w profilu uzytkownika." Yellow;
    Write-Log "        -> Uruchamianie zadania w kontekscie zalogowanego uzytkownika..." Cyan;

    $loggedUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName;
    if (-not $loggedUser) { $loggedUser = [Environment]::UserName; }

    $taskName = "WinGet_UserInstall_" + ($AppId -replace '[^a-zA-Z0-9]', '_');
    $userArgs = "install --exact --id $AppId --scope user --silent --accept-package-agreements --accept-source-agreements";

    $actionParams = @{
        Execute  = "winget.exe"
        Argument = $userArgs
    };
    $action = New-ScheduledTaskAction @actionParams;

    $principalParams = @{
        UserId    = $loggedUser
        LogonType = "Interactive"
        RunLevel  = "Limited"
    };
    $principal = New-Object Microsoft.PowerShell.Commands.ScheduledTaskPrincipal @principalParams;

    $regParams = @{
        TaskName  = $taskName
        Action    = $action
        Principal = $principal
        Force     = $true
    };
    Register-ScheduledTask @regParams | Out-Null;

    $taskParams = @{ TaskName = $taskName };
    Start-ScheduledTask @taskParams;

    do {
        Start-Sleep -Seconds 2;
        $taskState = (Get-ScheduledTask @taskParams).State;
    } while ($taskState -eq 'Running')

    $taskInfo = Get-ScheduledTaskInfo @taskParams;
    Unregister-ScheduledTask @taskParams -Confirm:$false;

    return $taskInfo.LastTaskResult;
}

function Install-AppPackage {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$App,

        [Parameter(Mandatory = $true)]
        [int]$CurrentIndex,

        [Parameter(Mandatory = $true)]
        [int]$TotalCount,

        [Parameter(Mandatory = $true)]
        $SystemInventory,

        [Parameter(Mandatory = $false)]
        [switch]$EnableOfficeFallback
    )

    $prefix = "[$CurrentIndex/$TotalCount]";
    Write-Log "`n$prefix Sprawdzanie i przygotowanie: $($App.Name) (ID: $($App.Id))..." Cyan;

    # 1. Sprawdzenie obecnosci w zindeksowanym inwentarzu rejestru
    $match = Find-InstalledApp ($App.Name) ($App.Id) ($SystemInventory);
    if ($null -ne$match) {
        Write-Log "    [V] Pominieto: Aplikacja jest juz zainstalowana w systemie." Green;
        Show-AppMetadata ($match) ("Wykryte parametry zainstalowanej aplikacji:");
        return;
    }

    Write-Log "    [-] Brak aplikacji w systemie. Rozpoczynanie pobierania i instalacji..." Yellow;

    # 2. Standardowa instalacja winget
    $installArgs = @(
        "install",
        "--exact",
        "--id", $App.Id,
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements"
    );

    try {
        $procParams = @{
            FilePath     = "winget.exe"
            ArgumentList = $installArgs
            NoNewWindow  = $true
            Wait         = $true
            PassThru     = $true
        };
        $process = Start-Process @procParams;

        if ($process.ExitCode -eq -1978335146) {$userResult = Invoke-UserContextInstall ($App.Id) ($App.Name);
            if ($userResult -eq 0 -or$userResult -eq -1978335189) {
                Write-Log "    [+] Pomyslnie zakonczono instalacje w profilu uzytkownika." Green;
            } else {
                Write-Log "    [-] Instalator uzytkownika zwrocil kod: $userResult" Yellow;
            }
        }
        elseif ($process.ExitCode -eq 0 -or$process.ExitCode -eq -1978335189) {
            Write-Log "    [+] Sukces: Proces instalacji $($App.Name) zakonczony pomyslnie." Green;
        }
        elseif ($process.ExitCode -eq -1978335215) {
            Write-Log "    [-] Wykryto niezgodnosc sumy kontrolnej w winget dla $($App.Name)." Yellow;
            if ($App.Id -eq "Microsoft.Office" -or $App.Id -like "*Office*") {
                if ($EnableOfficeFallback) {
                    Write-Log "    [!] Flaga -Fallback aktywna. Uruchamianie procedury awaryjnej ODT..." Cyan;
                    Install-OfficeFallback;
                } else {
                    Write-Log "    [!] Procedura awaryjna ODT jest wylaczona (brak parametru -Fallback). Instalacja pakietu Office zostala przerwana." Yellow;
                }
            }
        }
        else {
            Write-Log "    [-] Kod zakonczenia instalatora $($App.Name): $($process.ExitCode)" Yellow;
        }

        # 3. Odswiezenie i wyswietlenie metadanych bezposrednio po udanej instalacji
        $refreshedInventory = Get-WindowsInstalledApplications;
        $postMatch = Find-InstalledApp ($App.Name) ($App.Id) ($refreshedInventory);
        if ($null -ne$postMatch) {
            Show-AppMetadata ($postMatch) ("Szczegoly nowo zainstalowanej aplikacji:");
        } else {
            Write-Log "    [i] Stan rejestracji pakietu sprawdzony." Gray;
        }
    }
    catch {
        Write-Log "    Blad krytyczny podczas instalacji $($App.Name):$_" Red;
    }
}

# --- Glowny przeplyw programu ---

if ($VerifyInstalledApps) {
    $systemInventory = Get-WindowsInstalledApplications;
    if ($systemInventory.Count -eq 0) {
        Write-Host "Nie znaleziono zainstalowanych aplikacji w sprawdzonych galeziach rejestru." -ForegroundColor Yellow;
        return;
    }

    $reportLines = [System.Collections.Generic.List[string]]::new();
    $reportLines.Add("Zainstalowane programy: $($systemInventory.Count)");
    foreach ($publisherGroup in ($systemInventory | Group-Object -Property Publisher | Sort-Object -Property Name)) {
        $reportLines.Add("");
        $reportLines.Add("=== $($publisherGroup.Name) ===");
        $summaryTable = $publisherGroup.Group |
            Sort-Object -Property InstallDateSort -Descending |
            Format-Table `
                @{Label = "Program"; Expression = { $_.DisplayName }; Width = 46}, `
                @{Label = "Wersja"; Expression = { $_.DisplayVersion }; Width = 28}, `
                @{Label = "Instalacja"; Expression = { if ($_.InstallDateSort) { $_.InstallDateSort.ToString("yyyy-MM-dd") } elseif ($_.InstallDate -eq "Brak wpisu daty w rejestrze") { "Brak danych" } else { $_.InstallDate } }; Width = 12} `
            -Wrap -AutoSize | Out-String -Width 120;
        $reportLines.Add($summaryTable.TrimEnd());

        $locationTable = $publisherGroup.Group |
            Sort-Object -Property InstallDateSort -Descending |
            Format-Table `
                @{Label = "Program"; Expression = { $_.DisplayName }; Width = 36}, `
                @{Label = "Arch / zakres / MB"; Expression = { "$($_.Architecture) / $($_.Scope) / $(if ($null -ne $_.SizeMB) { "$($_.SizeMB) MB" } else { 'n/d' })" }; Width = 26}, `
                @{Label = "Lokalizacja instalacji"; Expression = { $_.InstallLocation }; Width = 56} `
            -Wrap -AutoSize | Out-String -Width 120;
        $reportLines.Add($locationTable.TrimEnd());
    }

    $reportText = $reportLines -join [Environment]::NewLine;
    Write-Host $reportText;

    if ($PSBoundParameters.ContainsKey("LogPath")) {
        if ([string]::IsNullOrWhiteSpace($LogPath)) {
            $defaultLogDir = "C:\Logs";
            $timeMarker = (Get-Date).ToString("yyyyMMdd_HHmmss");
            $compName = $env:COMPUTERNAME;
            $userName = $env:USERNAME;
            $reportFileName = "${timeMarker}-${compName}-${userName}-$($SCRIPT_INFO.Name)-installedApplications.txt";
            $resolvedReportPath = Join-Path $defaultLogDir $reportFileName;
        } else {
            $resolvedReportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath);
        }

        $reportDirectory = [System.IO.Path]::GetDirectoryName($resolvedReportPath);
        if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not [System.IO.Directory]::Exists($reportDirectory)) {
            [System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null;
        }
        [System.IO.File]::WriteAllText($resolvedReportPath, $reportText + [Environment]::NewLine, [System.Text.Encoding]::UTF8);
        Write-Host "`nRaport zapisano w: $resolvedReportPath" -ForegroundColor Cyan;
    }
    return;
}

Clear-Host;
Write-Log "================================================================================" Cyan;
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - Inicjalizacja srodowiska" Cyan;
Write-Log "  Autor: $($SCRIPT_INFO.Author) | Kontakt: $($SCRIPT_INFO.Contact)" Gray;
Write-Log "  Plik dziennika: $resolvedLogPath" DarkCyan;
Write-Log "  Fallback ODT  : $(if ($Fallback) { 'WLACZONY' } else { 'WYLACZONY (domyslnie)' })" $(if ($Fallback) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray });
Write-Log "================================================================================" Cyan;

if (-not (Test-IsAdmin)) {
    throw "Skrypt wymaga uprawnien administratora. Uruchom PowerShell jako Administrator.";
}

# 1. Weryfikacja srodowiska winget
Assert-WingetPrerequisites "1.7.0";

# 2. Wczytanie konfiguracji z pliku JSON
try {
    Write-Log "[i] Wczytywanie konfiguracji z: $ConfigPath" Gray;
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ConfigPath);
    $jsonRaw = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8);
    $applications =$jsonRaw | ConvertFrom-Json;
}
catch {
    throw "Blad podczas odczytu lub parsowania pliku JSON: $_";
}

if ($null -eq $applications -or$applications.Count -eq 0) {
    Write-Log "Wskazany plik JSON jest pusty. Zamykanie skryptu." Yellow;
    return;
}

# 3. Skanowanie rejestru Windows w pamieci RAM (.NET API)
Write-Log "[*] Skanowanie zainstalowanego oprogramowania (.NET Registry API)..." Gray;
$systemInventory = Get-WindowsInstalledApplications;
Write-Log "[+] Zindeksowano $($systemInventory.Count) zainstalowanych wpisow w rejestrze." Green;

$totalApps = [int]$applications.Count;
Write-Log "`nZnaleziono $totalApps pozycji do weryfikacji i instalacji." DarkCyan;
Write-Log "Rozpoczynanie procesu instalacji...`n" DarkCyan;

# 4. Przetwarzanie pakietow w petli
$currentIndex = 0;

foreach ($app in $applications) {$currentIndex++;

    if (-not ($app.PSObject.Properties['Id'] -and$app.PSObject.Properties['Name'])) {
        Write-Log "Pominieto niepoprawny wpis JSON (wymagane pola: 'Id', 'Name')." Yellow;
        continue;
    }

    $percentComplete = [math]::Round(((($currentIndex - 1) / $totalApps) * 100));$progParams = @{
        Activity        = "Instalacja oprogramowania stacji roboczej"
        Status          = "Przetwarzanie ($currentIndex z$totalApps): $($app.Name)"
        PercentComplete = $percentComplete
    };
    Write-Progress @progParams;

    $callArgs = @{
        App                  = $app
        CurrentIndex         = [int]$currentIndex
        TotalCount           = [int]$totalApps
        SystemInventory      = $systemInventory
        EnableOfficeFallback = $Fallback
    };
    Install-AppPackage @callArgs;
}

Write-Progress -Activity "Instalacja oprogramowania stacji roboczej" -Completed;

Write-Log "`n================================================================================" Green;
Write-Log "  [+] Zakonczono sprawdzanie wszystkich pakietow ($totalApps/$totalApps)." Green;
Write-Log "  [+] Raport z przebiegu zapisano w: $resolvedLogPath" Green;
Write-Log "================================================================================" Green;
Write-Log "Kontakt z autorem: $($SCRIPT_INFO.Contact)`n" Gray;