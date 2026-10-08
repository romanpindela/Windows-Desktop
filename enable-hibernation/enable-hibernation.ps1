<#
================================================================================
  Nazwa skryptu : enable-hibernation.ps1
  Autor         : Roman Pindela
  Kontakt       : roman.pindela@gmail.com
  Wersja        : 1.1.1
  Data wydania  : 2026-10-08
  Licencja      : MIT
  Repozytorium  : https://github.com/roman/enable-hibernation

  OPIS:
    Skrypt umozliwia pelne zarzadzanie mechanizmem hibernacji oraz widocznoscia
    opcji hibernacji w menu zasilania menu Start (Windows 10/11 x64).
    Pozwala na wlaczenie (alokacja hiberfil.sys, wpis FlyoutMenuSettings)
    oraz wylaczenie (usuniecie pliku hiberfil.sys, ukrycie w menu Start).
    Uruchomienie bez parametrow wyswietla menu pomocy z informacja o wersji i autorze.

================================================================================
.SYNOPSIS
    Wlacza lub wylacza hibernacje w systemie oraz menu zasilania Start.
.PARAMETER EnableHibernation
    Wlacza plik hiberfil.sys oraz dodaje opcje Hibernacja do menu Start.
.PARAMETER DisableHibernation
    Wylacza plik hiberfil.sys, zwalnia miejsce na dysku i ukrywa opcje w menu Start.
.PARAMETER LogPath
    Sciezka do pliku tekstowego ze szczegolowym logiem dzialania skryptu.
    Domyslnie: C:\Logs\<yyyyMMdd_HHmmss>-<ComputerName>-<UserName>-Enable-Hibernation.txt
.PARAMETER Help
    Wyswietla szczegolowe menu pomocy i informacje o autorze.
.EXAMPLE
    .\enable-hibernation.ps1
.EXAMPLE
    .\enable-hibernation.ps1 -EnableHibernation
.EXAMPLE
    .\enable-hibernation.ps1 -DisableHibernation
.EXAMPLE
    .\enable-hibernation.ps1 -EnableHibernation -LogPath "C:\Logs\hibernation.txt"
.EXAMPLE
    .\enable-hibernation.ps1 -h
#>
[CmdletBinding(DefaultParameterSetName = "Default")]
param (
    [Parameter(ParameterSetName = "Enable")]
    [Alias("e", "Enable")]
    [switch]$EnableHibernation,

    [Parameter(ParameterSetName = "Disable")]
    [Alias("d", "Disable")]
    [switch]$DisableHibernation,

    [Parameter(ParameterSetName = "Enable")]
    [Parameter(ParameterSetName = "Disable")]
    [Alias("l", "Log")]
    [string]$LogPath,

    [Parameter(ParameterSetName = "Help")]
    [Parameter(ParameterSetName = "Default")]
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";

$SCRIPT_INFO = @{
    Name        = "Enable-Hibernation";
    Version     = "1.1.1";
    Author      = "Roman Pindela";
    Contact     = "roman.pindela@gmail.com";
    ReleaseDate = "2026-10-08";
};

$script:ActiveLogFile =$null;

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
            $cleanLine = "[$timePrefix]$Message`r`n";
            [System.IO.File]::AppendAllText($script:ActiveLogFile,$cleanLine, [System.Text.Encoding]::UTF8);
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
  Automatyczny konfigurator zasilania Windows umozliwiajacy wlaczenie lub
  wylaczenie pelnej hibernacji oraz kontrolujacy jej obecnosc w menu Start.

UZYCIE:
  .\enable-hibernation.ps1 -EnableHibernation [-LogPath <sciezka_do_logu.txt>]
  .\enable-hibernation.ps1 -DisableHibernation [-LogPath <sciezka_do_logu.txt>]
  .\enable-hibernation.ps1 -h | -Help

PARAMETRY:
  -EnableHibernation, -e  : Wlacza hibernacje w systemie oraz w menu Start.
  -DisableHibernation, -d : Wylacza hibernacje, usuwa hiberfil.sys i ukrywa w menu.
  -LogPath, -l, -Log      : [Opcjonalny] Sciezka do pliku logu tekstowego.
                            Domyslnie: C:\Logs\<Data_Godzina>-<Host>-<User>-Enable-Hibernation.txt
  -Help, -h               : Wyswietla to menu pomocy oraz informacje o autorze.

PRZYKLADY:
  .\enable-hibernation.ps1
  .\enable-hibernation.ps1 -h
  .\enable-hibernation.ps1 -EnableHibernation
  .\enable-hibernation.ps1 -DisableHibernation
  .\enable-hibernation.ps1 -e -LogPath "C:\Deploy\hibernation_setup.txt"
================================================================================
"@ -ForegroundColor Yellow;
}

# Jesli wywolano pomoc badz uruchomiono bez parametrow akcji
if ($Help -or (-not $EnableHibernation -and -not$DisableHibernation)) {
    Show-HelpGuide;
    return;
}

# Inicjalizacja sciezki logowania
if ([string]::IsNullOrWhiteSpace($LogPath)) {$defaultLogDir = "C:\Logs";
    $timeMarker = (Get-Date).ToString("yyyyMMdd_HHmmss");
    $compName   =$env:COMPUTERNAME;
    $userName   =$env:USERNAME;
    $scriptName =$SCRIPT_INFO.Name;
    $logFileName = "${timeMarker}-${compName}-${userName}-${scriptName}.txt";
    $LogPath = Join-Path ($defaultLogDir) ($logFileName);
}

$resolvedLogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath);
$logDirectory = [System.IO.Path]::GetDirectoryName($resolvedLogPath);
if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not [System.IO.Directory]::Exists($logDirectory)) {
    [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null;
}
$script:ActiveLogFile =$resolvedLogPath;

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent();
    $principal = New-Object Security.Principal.WindowsPrincipal($identity);
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
}

function Set-PowercfgHibernationState {
    param ([bool]$Enable)

    $stateWord = if ($Enable) { "on" } else { "off" };
    $stateDesc = if ($Enable) { "Aktywacja" } else { "Deaktywacja" };

    Write-Log "[1/3] $stateDesc podsystemu hibernacji (powercfg /hibernate$stateWord)..." Cyan;

    try {
        $pcfgParams = @{
            FilePath     = "$env:windir\System32\powercfg.exe"
            ArgumentList = "/hibernate $stateWord"
            NoNewWindow  = $true
            Wait         = $true
            PassThru     = $true
        };
        $proc = Start-Process @pcfgParams;

        if ($proc.ExitCode -eq 0) {
            if ($Enable) {
                Write-Log "    [+] Plik hiberfil.sys i obsluga ACPI zostaly pomyslnie wlaczone." Green;
            } else {
                Write-Log "    [+] Podsystem hibernacji wylaczony, plik hiberfil.sys zostal usuniety z dysku." Green;
            }
        }
        else {
            Write-Log "    [-] powercfg zakonczyl dzialanie z kodem bledu: $($proc.ExitCode)" Yellow;
        }
    }
    catch {
        Write-Log "    [-] Blad krytyczny podczas wywolywania powercfg: $_" Red;
        throw $_;
    }
}

function Set-StartMenuHibernateVisibility {
    param ([int]$TargetValue)

    Write-Log "[2/3] Konfiguracja wpisu rejestru Explorer FlyoutMenuSettings (Wartosc: $TargetValue)..." Cyan;

    $registryHivePath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings";
    $baseKey =$null;
    $subKey  =$null;

    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64);
        $subKey  =$baseKey.OpenSubKey($registryHivePath,$true);

        if ($null -eq$subKey) {
            Write-Log "    [*] Tworzenie brakujacego klucza FlyoutMenuSettings w rejestrze HKLM..." DarkGray;
            $subKey = $baseKey.CreateSubKey($registryHivePath);
        }

        $currentVal =$subKey.GetValue("ShowHibernateOption");
        if ($null -ne$currentVal -and [int]$currentVal -eq$TargetValue) {
            Write-Log "    [V] Pominieto: Opcja ShowHibernateOption posiada juz oczekiwana wartosc ($TargetValue)." Green;
        }
        else {
            $subKey.SetValue("ShowHibernateOption", $TargetValue, [Microsoft.Win32.RegistryValueKind]::DWord);
            Write-Log "    [+] Sukces: Zapisano ShowHibernateOption = $TargetValue (DWORD)." Green;
        }
    }
    catch {
        Write-Log "    [-] Blad modyfikacji rejestru Windows: $_" Red;
        throw $_;
    }
    finally {
        if ($null -ne $subKey)  {$subKey.Close(); }
        if ($null -ne $baseKey) {$baseKey.Close(); }
    }
}

function Show-HibernationStatusSummary {
    param ([bool]$TargetEnabled)

    Write-Log "[3/3] Weryfikacja stanu koncowego podsystemu zasilania..." Cyan;

    $regVal =$null;
    $baseKey =$null;
    $subKey  =$null;
    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64);
        $subKey  =$baseKey.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings");
        if ($null -ne$subKey) {
            $regVal =$subKey.GetValue("ShowHibernateOption");
        }
    }
    catch {}
    finally {
        if ($null -ne $subKey)  {$subKey.Close(); }
        if ($null -ne $baseKey) {$baseKey.Close(); }
    }

    $systemDrive =$env:SystemDrive;
    $hiberFilePath = Join-Path ($systemDrive) "hiberfil.sys";
    $hiberExists = [System.IO.File]::Exists($hiberFilePath);

    $stateText = if ($TargetEnabled) { "AKTYWNA (WIDOCZNA)" } else { "NIEAKTYWNA (UKRYTA)" };
    $stateColor = if ($TargetEnabled) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow };

    Write-Log "    ----------------------------------------------------------------" DarkGray;
    Write-Log "    Podsumowanie konfiguracji zasilania:" DarkCyan;
    Write-Log "      * Plik hiberfil.sys           : $(if ($hiberExists) { "Obecny ($hiberFilePath)" } else { "Brak pliku na dysku (przestrzen zwolniona)" })" Gray;
    Write-Log "      * Wpis rejestru Start Menu     : ShowHibernateOption = $regVal" Gray;
    Write-Log "      * Widocznosc w menu zasilania : $stateText" $stateColor;
    Write-Log "    ----------------------------------------------------------------" DarkGray;
}

# --- Glowny przeplyw programu ---

Clear-Host;

$actionName = "";
if ($EnableHibernation) {$actionName = "Wlaczanie hibernacji";
} else {
    $actionName = "Wylaczanie hibernacji";
}

Write-Log "================================================================================" Cyan;
Write-Log "  $($SCRIPT_INFO.Name) v$($SCRIPT_INFO.Version) -$actionName" Cyan;
Write-Log "  Autor: $($SCRIPT_INFO.Author) | Kontakt: $($SCRIPT_INFO.Contact)" Gray;
Write-Log "  Plik dziennika: $resolvedLogPath" DarkCyan;
Write-Log "================================================================================" Cyan;

if (-not (Test-IsAdmin)) {
    throw "Skrypt wymaga uprawnien administratora. Uruchom PowerShell jako Administrator.";
}

if ($EnableHibernation) {
    Set-PowercfgHibernationState -Enable $true;
    Set-StartMenuHibernateVisibility -TargetValue 1;
    Show-HibernationStatusSummary -TargetEnabled $true;
}
else {
    Set-PowercfgHibernationState -Enable $false;
    Set-StartMenuHibernateVisibility -TargetValue 0;
    Show-HibernationStatusSummary -TargetEnabled $false;
}

Write-Log "`n================================================================================" Green;
Write-Log "  [+] Procedura ($actionName) zostala zakonczona sukcesem." Green;
Write-Log "  [+] Raport z przebiegu zapisano w: $resolvedLogPath" Green;
Write-Log "================================================================================" Green;
Write-Log "Kontakt z autorem: $($SCRIPT_INFO.Contact)`n" Gray;