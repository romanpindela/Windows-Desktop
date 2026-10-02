<#
================================================================================
  Nazwa skryptu : Install-Applications.ps1
  Autor         : Roman Pindela
  Kontakt       : roman.pindela@gmail.com
  Wersja        : 1.4.0
  Data wydania  : 2026-10-02
  Licencja      : MIT
  Repozytorium  : https://github.com/roman/install-applications

  OPIS:
    Skrypt automatyzuje instalacje i konfiguracje oprogramowania stacji roboczej
    w srodowisku Windows (architektura x64) w oparciu o menedzer pakietow winget
    oraz plik konfiguracyjny JSON. Zawiera graficzny pasek postepu, numeracje
    pakietow, automatyczna samonaprawe winget oraz fallback ODT dla Office 365.

  HISTORIA ZMIAN:
    v1.0.0 (2026-10-02) - Pierwsza wersja: integracja z winget i wczytywanie JSON.
    v1.1.0 (2026-10-02) - Dodano obsluge przelacznika -h / -Help i walidacje parametrow.
    v1.2.0 (2026-10-02) - Dodano automatyczna aktualizacje winget przez Microsoft.WinGet.Client.
    v1.3.0 (2026-10-02) - Dodano procedure awaryjna ODT dla Office 365, metadane oraz dokumentacje.
    v1.3.2 (2026-10-02) - Naprawiono separatory sciezki w parametrach -Path.
    v1.4.0 (2026-10-02) - Dodano pasek postepu Write-Progress, numeracje zadan [X/Y] oraz zwiekszono czytelnosc.
================================================================================
.SYNOPSIS
    Automatycznie pobiera i instaluje aplikacje z pliku JSON przy uzyciu winget.
.PARAMETER ConfigPath
    Sciezka do pliku JSON z lista programow.
.PARAMETER Help
    Wyswietla szczegolowe menu pomocy i informacje o autorze.
.EXAMPLE
    .\Install-Applications.ps1 -h
.EXAMPLE
    .\Install-Applications.ps1 -ConfigPath .\ApplicationList.json
#>
[CmdletBinding(DefaultParameterSetName = "Install")]
param (
    [Parameter(ParameterSetName = "Install", Position = 0)]
    [Alias("c", "Path")]
    [ValidateScript({
        if (Test-Path $_ -PathType Leaf) { $true }
        else { throw "Plik nie istnieje pod podana sciezka: $_" }
    })]
    [string]$ConfigPath,

    [Parameter(ParameterSetName = "Help")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Globalne metadane skryptu
$SCRIPT_INFO = @{
    Name        = "Install-Applications"
    Version     = "1.4.0"
    Author      = "Roman"
    Contact     = "roman@example.com"
    ReleaseDate = "2026-10-02"
}

function Write-Log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    [Console]::CursorLeft = 0
    Write-Host "$Message" -ForegroundColor $Color
}

function Show-HelpGuide {
    [Console]::CursorLeft = 0
    Write-Host @"
================================================================================
  $($SCRIPT_INFO.Name) - v$($SCRIPT_INFO.Version)
  Autor: $($SCRIPT_INFO.Author) | Kontakt: $($SCRIPT_INFO.Contact)
================================================================================
OPIS:
  Automatyczny instalator stacji roboczej Windows x64 korzystajacy z menedzera
  pakietow winget i listy aplikacji w formacie JSON.

UZYCIE:
  .\Install-Applications.ps1 -ConfigPath <sciezka_do_pliku.json>
  .\Install-Applications.ps1 -h | -Help

PARAMETRY:
  -ConfigPath, -c, -Path : [Wymagany] Sciezka do pliku JSON z konfiguracja pakietow.
  -Help, -h              : Wyswietla to menu pomocy oraz dane autora.

PRZYKLADY:
  .\Install-Applications.ps1 -h
  .\Install-Applications.ps1 -ConfigPath .\ApplicationList.json
  .\Install-Applications.ps1 .\ApplicationList.json
================================================================================
"@ -ForegroundColor Yellow
}

if ($Help -or [string]::IsNullOrWhiteSpace($ConfigPath)) {
    Show-HelpGuide
    return
}

function Test-IsAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-WingetPrerequisites {
    [CmdletBinding()]
    param (
        [string]$MinimumVersion = "1.7.0"
    )

    $needsUpdate = $false
    $wingetCmd = Get-Command -Name "winget.exe" -ErrorAction SilentlyContinue

    if (-not $wingetCmd) {
        Write-Log "[!] Narzedzie winget nie jest zainstalowane." Yellow
        $needsUpdate = $true
    }
    else {
        try {
            $rawVer = (& winget.exe --version 2>$null | Out-String).Trim().TrimStart('v')
            $parsedParts = $rawVer.Split('-')[0].Split('.')
            while ($parsedParts.Count -lt 2) { $parsedParts += "0" }
            $installedVer = [version]($parsedParts -join '.')

            Write-Log "[i] Wykryto wersje winget: $rawVer" Gray

            if ($installedVer -lt [version]$MinimumVersion) {
                Write-Log "[!] Wersja winget ($rawVer) wymaga aktualizacji (min. $MinimumVersion)..." Yellow
                $needsUpdate = $true
            }
        }
        catch {
            Write-Log "[!] Blad odczytu wersji winget. Wymuszanie naprawy..." Yellow
            $needsUpdate = $true
        }
    }

    if (-not $needsUpdate) {
        Write-Log "[+] Srodowisko winget jest gotowe do pracy." Green
        return
    }

    Write-Log "[*] Instalowanie aktualizacji winget wraz ze wszystkimi zaleznosciami..." Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-Log "    -> Przygotowywanie dostawcy NuGet..." Gray
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        }

        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

        if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) {
            Write-Log "    -> Pobieranie modulu Microsoft.WinGet.Client..." Gray
            Install-Module -Name Microsoft.WinGet.Client -Force -AllowClobber | Out-Null
        }

        Import-Module -Name Microsoft.WinGet.Client -Force

        Write-Log "    -> Pobieranie frameworkow i instalowanie winget..." Gray
        Repair-WinGetPackageManager -Latest -Force

        $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        $userPath    = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
        $env:Path    = "$machinePath;$userPath"

        Write-Log "[+] Winget zostal pomyslnie zaktualizowany i naprawiony." Green
    }
    catch {
        throw "Nie udalo sie automatycznie zaktualizowac winget: $_"
    }
}

function Install-OfficeFallback {
    [CmdletBinding()]
    param ()

    Write-Log "    [!] Uruchamianie procedury awaryjnej (Office Deployment Tool - PL x64)..." Yellow

    $tempDir = Join-Path -Path $env:TEMP -ChildPath "OfficeInstall"
    if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }

    $setupExe = Join-Path -Path $tempDir -ChildPath "setup.exe"
    $configXml = Join-Path -Path $tempDir -ChildPath "configuration.xml"
    $directSetupUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe"

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
"@

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Write-Log "        -> Generowanie konfiguracji instalatora ODT (64-bit, pl-PL)..." Gray
        Set-Content -Path $configXml -Value $xmlContent -Encoding UTF8

        Write-Log "        -> Pobieranie instalatora Click-to-Run..." Gray
        Invoke-WebRequest -Uri $directSetupUrl -OutFile $setupExe -UseBasicParsing

        Write-Log "        -> Pobieranie i cicha instalacja pakietu Office 365 w tle..." Cyan
        $process = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configXml`"" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Log "    [+] Sukces: Microsoft 365 Apps zostal zainstalowany w jezyku polskim." Green
        }
        else {
            Write-Log "    [-] Instalator Office zakonczyl dzialanie z kodem: $($process.ExitCode)" Yellow
        }
    }
    catch {
        Write-Log "    [-] Blad podczas instalacji Office w trybie awaryjnym: $_" Red
    }
    finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-AppPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$App,

        [Parameter(Mandatory = $true)]
        [int]$CurrentIndex,

        [Parameter(Mandatory = $true)]
        [int]$TotalCount
    )

    $prefix = "[$CurrentIndex/$TotalCount]"
    Write-Log "`n$prefix Pobieranie i instalacja: $($App.Name) (ID: $($App.Id))..." Cyan

    $installArgs = @(
        "install",
        "--exact",
        "--id", $App.Id,
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )

    try {
        $process = Start-Process -FilePath "winget.exe" -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
        
        switch ($process.ExitCode) {
            0 {
                Write-Log "    [+] Sukces: $($App.Name) zostal pomyslnie zainstalowany." Green
            }
            -1978335189 { # 0x8A15002B: ERROR_ALREADY_INSTALLED
                Write-Log "    [!] Pominieto: $($App.Name) jest juz zainstalowany w najnowszej wersji." Yellow
            }
            -1978335215 { # 0x8A150011: ERROR_INSTALLER_HASH_MISMATCH
                Write-Log "    [-] Wykryto niezgodnosc sumy kontrolnej w winget dla $($App.Name)." Yellow
                if ($App.Id -eq "Microsoft.Office") {
                    Install-OfficeFallback
                }
                else {
                    Write-Log "    [-] Kod bledu instalatora $($App.Name): $($process.ExitCode)" Yellow
                }
            }
            default {
                Write-Log "    [-] Kod bledu instalatora $($App.Name): $($process.ExitCode)" Yellow
            }
        }
    }
    catch {
        Write-Log "    Blad krytyczny podczas instalacji $($App.Name):$_" Red
    }
}

# --- Glowny przeplyw programu ---

Clear-Host
Write-Log "================================================================================" Cyan
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) - Inicjalizacja srodowiska" Cyan
Write-Log "  Autor: $($SCRIPT_INFO.Author) | Kontakt: $($SCRIPT_INFO.Contact)" Gray
Write-Log "================================================================================" Cyan

if (-not (Test-IsAdmin)) {
    throw "Skrypt wymaga uprawnien administratora. Uruchom PowerShell jako Administrator."
}

# 1. Sprawdzenie i przygotowanie winget
Assert-WingetPrerequisites -MinimumVersion "1.7.0"

# 2. Wczytanie konfiguracji z pliku JSON
try {
    Write-Log "[i] Wczytywanie konfiguracji z: $ConfigPath" Gray
    $applications = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
    throw "Blad podczas odczytu lub parsowania pliku JSON: $_"
}

if ($null -eq $applications -or$applications.Count -eq 0) {
    Write-Log "Wskazany plik JSON jest pusty. Zamykanie skryptu." Yellow
    return
}

$totalApps =$applications.Count
Write-Log "`nZnaleziono $totalApps pozycji do weryfikacji i instalacji." DarkCyan
Write-Log "Rozpoczynanie procesu instalacji...`n" DarkCyan

# 3. Przetwarzanie pakietow w petli z paskiem postepu
$currentIndex = 0

foreach ($app in $applications) {$currentIndex++
    
    if (-not ($app.PSObject.Properties['Id'] -and$app.PSObject.Properties['Name'])) {
        Write-Log "Pominieto niepoprawny wpis JSON (wymagane pola: 'Id', 'Name')." Yellow
        continue
    }

    # Obliczenie procentu ukonczenia i wyswietlenie natywnego paska postepu
    $percentComplete = [math]::Round((($currentIndex - 1) /$totalApps) * 100)
    Write-Progress -Activity "Instalacja oprogramowania stacji roboczej" `
                   -Status "Przetwarzanie ($currentIndex z $totalApps): $($app.Name)" `
                   -PercentComplete $percentComplete

    Install-AppPackage -App $app -CurrentIndex $currentIndex -TotalCount $totalApps
}

# Zakonczenie paska postepu
Write-Progress -Activity "Instalacja oprogramowania stacji roboczej" -Completed

Write-Log "`n================================================================================" Green
Write-Log "  [+] Zakonczono sprawdzanie i instalacje wszystkich pakietow ($totalApps/$totalApps)." Green
Write-Log "================================================================================" Green
Write-Log "Kontakt z autorem: $($SCRIPT_INFO.Contact)`n" Gray