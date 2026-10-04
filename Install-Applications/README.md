# install-applications (Windows Workstation Deployment)
Dokumentacja techniczna skryptu automatyzującego wdrażanie stacji roboczej Windows.

## Informacje o projekcie

| Parametr | Wartość |
| :--- | :--- |
| **Nazwa projektu** | install-applications (Windows Workstation Deployment) |
| **Autor** | Roman Pindela |
| **Kontakt** | roman.pindela@gmail.com |
| **Wersja** | 1.5.0 |
| **Data wydania** | 04.10.2026 |
| **Licencja** | MIT |

---

## Główne możliwości

* **Brak hardkodowania:** Lista aplikacji pobierana jest wyłącznie z zewnętrznego pliku JSON przekazanego jako parametr.
* **Architektura x64:** Automatyczne pobieranie najnowszych 64-bitowych pakietów instalacyjnych bezpośrednio z oficjalnych repozytoriów i serwerów CDN.
* **Cicha instalacja (Unattended):** Automatyczna akceptacja umów licencyjnych oraz instalacja w tle bez konieczności interakcji użytkownika.
* **Automatyczna samonaprawa winget:** W przypadku wykrycia starszej wersji (< 1.7.0) lub braku narzędzia, skrypt automatycznie pobiera zależności (VCLibs, Microsoft.UI.Xaml) oraz aktualizuje winget za pośrednictwem modułu `Microsoft.WinGet.Client`.
* **Procedura awaryjna Office 365 (Fallback ODT):** W razie niezgodności sumy kontrolnej (*hash mismatch*) w winget dla pakietu Microsoft Office, skrypt automatycznie pobiera instalator Office Deployment Tool (ODT), generuje konfigurację XML i instaluje pakiet Office 365 (64-bit, pl-PL).
* **Automatyczna instalacja User-Context (Non-Admin Fallback):** Programy odrzucające uruchomienie z uprawnieniami administratora (kod `0x8A150056`, np. Spotify) są automatycznie delegowane do uruchomienia w kontekście zalogowanego użytkownika (`--scope user`) przy użyciu tymczasowego zadania Harmonogramu Zadań z obniżonym poziomem tokena (`RunLevel Limited`).
* **Wizualizacja postępu:** Czytelny pasek postępu `Write-Progress` oraz numeracja przetwarzanych elementów `[X/Y]`.
* **Ochrona bufora konsoli:** Dedykowana funkcja logowania zapobiegająca rozjeżdżaniu się tekstu (schodkowaniu) w oknie konsoli PowerShell.

---

## Struktura katalogu wdrożeniowego

* `Install-Applications.ps1` — Główny skrypt instalacyjny PowerShell.
* `ApplicationList.json` — Plik konfiguracyjny z listą aplikacji do zainstalowania.
* `README.md` — Niniejsza dokumentacja techniczna.

---

## Wymagania systemowe

* **System operacyjny:** Windows 10 / Windows 11 (architektura 64-bit).
* **Uprawnienia:** Konsola PowerShell uruchomiona w trybie Administratora (wymagana do instalacji systemowych i rejestracji fallbacków).
* **Połączenie sieciowe:** Aktywne połączenie z Internetem umożliwiające pobieranie pakietów.

---

## Instrukcja uruchomienia

### 1. Zezwolenie na wykonywanie skryptów (jeśli jest zablokowane)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

```

### 2. Wyświetlenie menu pomocy i danych autora

```powershell
.\Install-Applications.ps1 -h

```

### 3. Uruchomienie pełnej instalacji pakietów

Uruchom konsolę PowerShell jako Administrator i przejdź do katalogu ze skryptem:

```powershell
.\Install-Applications.ps1 -ConfigPath .\ApplicationList.json

```

*(Dozwolona jest również forma skrócona: `.\Install-Applications.ps1 .\ApplicationList.json`)*

---

## Struktura i przykład pliku konfiguracyjnego JSON

Plik JSON zawiera tablicę obiektów, gdzie każdy obiekt posiada pola `Name` (czytelna nazwa) oraz `Id` (oficjalny identyfikator w winget).

Przykład pełnej konfiguracji:

```json
[
  { "Name": "7-Zip", "Id": "7zip.7zip" },
  { "Name": "Adobe Acrobat Reader DC (PL)", "Id": "Adobe.Acrobat.Reader.64-bit" },
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

## Kody zakończenia i diagnostyka

| Kod błędu / Status | Znaczenie | Działanie skryptu |
| --- | --- | --- |
| **0** | Sukces | Aplikacja pobrana i zainstalowana pomyślnie. |
| **-1978335189 (0x8A15002B)** | Pakiet jest już zainstalowany | Pominięcie instalacji, przejście do kolejnego programu. |
| **-1978335146 (0x8A150056)** | Blokada kontekstu Administratora | Automatyczna instalacja w profilu użytkownika za pomocą izolowanego zadania `ScheduledTask` (`--scope user`). |
| **-1978335215 (0x8A150011)** | Niezgodność hasha (*Hash Mismatch*) | Uruchomienie procedury awaryjnej (dla Office: ODT). |
| **-1073741819 (0xC0000005)** | Crash starej wersji winget | Automatyczna aktualizacja winget i zależności. |
| **-1978335216 (0x8A150010)** | Brak instalatora spełniającego filtry | Pominięcie restrykcyjnych flag locale / arch. |

---

## Kontakt i wsparcie

W razie problemów z wdrożeniem lub pytań technicznych:

* **Autor:** Roman Pindela
* **Adres e-mail:** roman.pindela@gmail.com

```

```