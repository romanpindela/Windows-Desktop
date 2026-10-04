# install-applications (Windows Workstation Deployment)
Dokumentacja techniczna skryptu automatyzującego audyt, pobieranie, instalację oraz bezobsługowe wdrażanie stacji roboczej Windows.
---
## Informacje o projekcie

| Parametr | Wartość |
| --- | --- |
| **Nazwa projektu** | install-applications (Windows Workstation Deployment) |
| **Autor** | Roman Pindela |
| **Kontakt** | roman.pindela@gmail.com |
| **Wersja** | 1.9.6 |
| **Data wydania** | 04.10.2026 |
| **Licencja** | MIT |
| **Repozytorium** | [GitHub - roman/install-applications](https://github.com/roman/install-applications) |
---
## Główne możliwości
* **Brak hardkodowania:** Lista aplikacji pobierana jest wyłącznie z zewnętrznego pliku JSON przekazanego jako parametr w linii poleceń.
* **Architektura x64:** Automatyczne pobieranie najnowszych 64-bitowych pakietów instalacyjnych bezpośrednio z oficjalnych repozytoriów dostawców i serwerów CDN.
* **Cicha instalacja (Unattended):** Automatyczna akceptacja umów licencyjnych oraz instalacja w tle bez konieczności interakcji użytkownika.
* **Audyt rejestru przez .NET Registry API:** Jednorazowa, błyskawiczna inwentaryzacja oprogramowania w pamięci RAM za pośrednictwem natywnej klasy `[Microsoft.Win32.RegistryKey]`. Skrypt skanuje gałęzie:
  * `HKLM` 64-bit (`SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`)
  * `HKLM` 32-bit / WOW6432Node (`SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`)
  * `HKCU` profil zalogowanego użytkownika (`SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`)
  Rozwiązanie to eliminuje błędy uprawnień oraz zawieszanie się pętli PowerShell na kluczach zawierających znaki specjalne i identyfikatory GUID (`{...}`).
* **Inteligentne dopasowywanie (Smart Matching):** Skrypt oczyszcza nazwy pakietów z nawiasów (usuwa m.in. `(PL)`, `(x64)`, sufiksy wersji) i porównuje trzon programu, dzięki czemu wpisy takie jak `"Adobe Acrobat Reader DC (PL)"` lub `"7-Zip"` z pliku JSON bezbłędnie łączą się z wpisami w rejestrze Windows.
* **Precyzyjne metadane aplikacji:** Dla każdego zweryfikowanego programu skrypt wyświetla w czytelnej ramce logu:
  * Pełną nazwę rejestrową (`DisplayName`)
  * Dokładną wersję programu (`DisplayVersion`)
  * Datę instalacji (`InstallDate` sformatowaną do czytelnej postaci `YYYY-MM-DD`)
  * Ścieżkę instalacji na dysku (`InstallLocation` / `DisplayIcon`)
* **Pełna idempotencja (Skip Already Installed):** Programy wykryte w systemie są natychmiast pomijane wraz z prezentacją ich metadanych, co zapobiega zbędnemu obciążaniu łącza i powtórnym próbom instalacji.
* **Automatyczna instalacja User-Context (Non-Admin Fallback):** Pakiety odrzucające podniesione uprawnienia administratora (kod błędu `0x8A150056` / `-1978335146`, np. Spotify) są automatycznie delegowane do uruchomienia w kontekście zalogowanego użytkownika (`--scope user`) przy użyciu izolowanego zadania `ScheduledTask` z uprawnieniami `RunLevel Limited`.
* **Procedura awaryjna Office 365 (ODT Fallback):** W razie niezgodności sumy kontrolnej (*hash mismatch*, kod `0x8A150011` / `-1978335215`) w repozytorium `winget`, skrypt automatycznie pobiera instalator Office Deployment Tool (ODT), generuje w locie konfigurację XML i instaluje pakiet Microsoft 365 Apps w polskiej wersji językowej (`pl-PL`, 64-bit).
* **Automatyczna samonaprawa winget:** Weryfikacja minimalnej wersji menedżera pakietów (>= 1.7.0). W razie potrzeby skrypt pobiera brakujące zależności (VCLibs, Microsoft.UI.Xaml) oraz aktualizuje i naprawia narzędzie winget za pośrednictwem modułu `Microsoft.WinGet.Client`.
* **Wizualizacja postępu i ochrona bufora:** Pasek postępu `Write-Progress`, numeracja zadań `[X/Y]` oraz dedykowana funkcja logowania zapobiegająca schodkowaniu tekstu w konsoli.
* **Odporność na błędy parsowania:** Skrypt działa w trybie `Set-StrictMode -Version Latest`, wykorzystuje bezpieczny Hashtable Splatting parametrów oraz odczytuje pliki konfiguracyjne natywną metodą `[System.IO.File]::ReadAllText`.
---
## Struktura katalogu wdrożeniowego

```shell
install-applications/
├── Install-Applications.ps1       # Główny skrypt instalacyjny PowerShell
├── ApplicationList-Roman.json     # Dedykowana lista aplikacji roboczych
├── ApplicationList.json           # Domyślny szablon konfiguracji pakietów
└── README.md                      # Niniejsza dokumentacja techniczna
```
---
## Wymagania systemowe
* **System operacyjny:** Windows 10 / Windows 11 (architektura 64-bit).
* **Uprawnienia:** Konsola PowerShell uruchomiona z uprawnieniami Administratora (niezbędna do instalacji globalnych i rejestracji zadań fallback).
* **Połączenie sieciowe:** Dostęp do sieci Internet (oficjalne serwery CDN producentów oraz repozytorium WinGet).
---
## Instrukcja uruchomienia
### 1. Zezwolenie na wykonywanie skryptów (jeśli jest zablokowane)

```shell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
### 2. Wyświetlenie menu pomocy i danych autora
```shell
.\Install-Applications.ps1 -h
```
### 3. Uruchomienie instalacji pakietów
```shell
.\Install-Applications.ps1 -ConfigPath .\ApplicationList-Roman.json
```
*(Dopuszczalna jest również składnia skrócona: `.\Install-Applications.ps1 .\ApplicationList-Roman.json`)*
---
## Struktura i przykład pliku konfiguracyjnego JSON
Plik JSON zawiera tablicę obiektów, gdzie każdy obiekt posiada pola `Name` (czytelna nazwa) oraz `Id` (identyfikator pakietu w winget):

```json
[
  { "Name": "7-Zip", "Id": "7zip.7zip" },
  { "Name": "Adobe Acrobat Reader DC (PL)", "Id": "Adobe.Acrobat.Reader.64-bit" },
  { "Name": "Sublime Text 4", "Id": "SublimeHQ.SublimeText.4" },
  { "Name": "Total Commander", "Id": "Ghisler.TotalCommander" },
  { "Name": "Visual Studio Code", "Id": "Microsoft.VisualStudioCode" },
  { "Name": "Google Drive", "Id": "Google.GoogleDrive" },
  { "Name": "Microsoft OneDrive", "Id": "Microsoft.OneDrive" },
  { "Name": "Microsoft 365 Apps (Office)", "Id": "Microsoft.Office" },
  { "Name": "Google Chrome", "Id": "Google.Chrome" },
  { "Name": "IrfanView", "Id": "IrfanSkiljan.IrfanView" },
  { "Name": "VLC Media Player", "Id": "VideoLAN.VLC" },
  { "Name": "Spotify", "Id": "Spotify.Spotify" },
  { "Name": "Microsoft Teams", "Id": "Microsoft.Teams" },
  { "Name": "Mozilla Firefox", "Id": "Mozilla.Firefox" },
  { "Name": "Opera Stable", "Id": "Opera.Opera" },
  { "Name": "Brave Browser", "Id": "Brave.Brave" },
  { "Name": "Microsoft PowerToys", "Id": "Microsoft.PowerToys" },
  { "Name": "TeamViewer", "Id": "TeamViewer.TeamViewer" },
  { "Name": "Git for Windows", "Id": "Git.Git" },
  { "Name": "Notepad++", "Id": "Notepad++.Notepad++" },
  { "Name": "Windows Terminal", "Id": "Microsoft.WindowsTerminal" }
]
```
---
## Przykładowy widok konsoli podczas pracy


```shell
================================================================================
  Install-Applications v1.9.6 - Inicjalizacja srodowiska
  Autor: Roman Pindela | Kontakt: roman.pindela@gmail.com
================================================================================
[i] Wykryto wersje winget: 1.29.380
[+] Srodowisko winget jest gotowe do pracy.
[i] Wczytywanie konfiguracji z: .\ApplicationList-Roman.json
[*] Skanowanie zainstalowanego oprogramowania (.NET Registry API)...
[+] Zindeksowano 41 zainstalowanych wpisow w rejestrze.

Znaleziono 26 pozycji do weryfikacji i instalacji.
Rozpoczynanie procesu instalacji...

[1/26] Sprawdzanie i przygotowanie: 7-Zip (ID: 7zip.7zip)...
    [V] Pominieto: Aplikacja jest juz zainstalowana w systemie.
    ----------------------------------------------------------------
    Wykryte parametry zainstalowanej aplikacji:
      * Nazwa aplikacji  : 7-Zip 24.08 (x64)
      * Wersja programu  : 24.08.00.0
      * Data instalacji  : 2026-10-02
      * Lokalizacja      : C:\Program Files\7-Zip
    ----------------------------------------------------------------

[2/26] Sprawdzanie i przygotowanie: Spotify (ID: Spotify.Spotify)...
    [-] Brak aplikacji w systemie. Rozpoczynanie pobierania i instalacji...
    [!] Pakiet Spotify wymaga instalacji w profilu uzytkownika.
        -> Uruchamianie zadania w kontekscie zalogowanego uzytkownika...
    [+] Pomyslnie zakonczono instalacje w profilu uzytkownika.
    ----------------------------------------------------------------
    Szczegoly nowo zainstalowanej aplikacji:
      * Nazwa aplikacji  : Spotify
      * Wersja programu  : 1.2.50.335
      * Data instalacji  : 2026-10-04
      * Lokalizacja      : C:\Users\rpindela\AppData\Roaming\Spotify
    ----------------------------------------------------------------
```
---
## Kody zakończenia i diagnostyka

| Kod błędu / Status | Znaczenie techniczne | Działanie skryptu |
| --- | --- | --- |
| **0** | Sukces instalatora | Pobranie i prezentacja metadanych nowo zainstalowanego pakietu. |
| **-1978335189 (0x8A15002B)** | Pakiet jest już zarejestrowany w systemie | Pobranie wpisu z inwentarza rejestru, wyświetlenie metadanych i pominięcie instalacji. |
| **-1978335146 (0x8A150056)** | Blokada uruchomienia w kontekście administratora | Automatyczna instalacja w profilu użytkownika za pomocą izolowanego zadania ScheduledTask (--scope user). |
| **-1978335215 (0x8A150011)** | Niezgodność hasha (*Hash Mismatch*) | Uruchomienie procedury awaryjnej (dla pakietu Office: automatyczne wdrożenie ODT). |
| **-1073741819 (0xC0000005)** | Błąd krytyczny starszej wersji winget | Automatyczna naprawa i aktualizacja pakietów przez Microsoft.WinGet.Client. |
---
## Kontakt i wsparcie
W razie problemów z wdrożeniem lub pytań technicznych:
* **Autor:** Roman Pindela
* **Adres e-mail:** roman.pindela@gmail.com
* **Licencja:** MIT License
