# install-applications (Windows Workstation Deployment)
Dokumentacja techniczna skryptu automatyzującego wdrażanie stacji roboczej Windows
## Informacje o projekcie
Parametr
Wartość
Nazwa projektu
install-applications (Windows Workstation Deployment)
Autor
Roman Pindela
Kontakt
roman.pindela@gmail.com
Wersja
1.3.0
Data wydania
02.10.2026
Licencja
MIT

## Główne możliwości
Brak hardkodowania: Lista aplikacji pobierana jest wyłącznie z zewnętrznego pliku JSON przekazanego jako parametr.
Architektura x64: Automatyczne pobieranie najnowszych 64-bitowych pakietów instalacyjnych bezpośrednio z oficjalnych repozytoriów i serwerów CDN.
Cicha instalacja (Unattended): Automatyczna akceptacja umów licencyjnych oraz instalacja w tle bez konieczności interakcji użytkownika.
Automatyczna samonaprawa winget: W przypadku wykrycia starszej wersji (< 1.7.0) lub braku narzędzia, skrypt automatycznie pobiera zależności (VCLibs, Microsoft.UI.Xaml) oraz aktualizuje winget za pośrednictwem modułu Microsoft.WinGet.Client.
Procedura awaryjna Office 365 (Fallback ODT): W razie niezgodności sumy kontrolnej (hash mismatch) w winget dla pakietu Microsoft Office, skrypt automatycznie pobiera instalator Office Deployment Tool (ODT), generuje plik konfiguracyjny XML i instaluje pakiet Office 365 w wersji 64-bitowej w polskiej wersji językowej (pl-PL).
Ochrona bufora konsoli: Specjalna funkcja logowania zapobiegająca rozjeżdżaniu się tekstu (schodkowaniu) w oknie konsoli PowerShell.
## Struktura katalogu wdrożeniowego
install-applications.ps1 — Główny skrypt instalacyjny PowerShell.
ApplicationList.json — Plik konfiguracyjny z listą aplikacji do zainstalowania.
README.md — Niniejsza dokumentacja techniczna.
## Wymagania systemowe
System operacyjny: Windows 10 / Windows 11 (architektura 64-bit).
Uprawnienia: Konsola PowerShell uruchomiona w trybie Administratora.
Połączenie sieciowe: Aktywne połączenie z Internetem umożliwiające pobieranie pakietów.
## Instrukcja uruchomienia
### 1. Zezwolenie na wykonywanie skryptów (jeśli jest zablokowane)

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
### 2. Wyświetlenie menu pomocy i danych autora

.\install-applications.ps1 -h
### 3. Uruchomienie pełnej instalacji pakietów
Uruchom konsolę PowerShell jako Administrator i przejdź do katalogu ze skryptem:
.\install-applications.ps1 -ConfigPath .\ApplicationList.json

(Dozwolona jest również forma skrócona: .\install-applications.ps1 .\ApplicationList.json)
## Struktura i przykład pliku konfiguracyjnego JSON
Plik JSON zawiera tablicę obiektów, gdzie każdy obiekt posiada pola Name (czytelna nazwa) oraz Id (oficjalny identyfikator w winget).
Przykład pełnej konfiguracji:
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
## Kody zakończenia i diagnostyka
Tabela wyjaśniająca kody zwracane przez instalatory i zachowanie skryptu:

Kod błędu / Status
Znaczenie
Działanie skryptu
0
Sukces
Aplikacja pobrana i zainstalowana pomyślnie.
-1978335189 (0x8A15002B)
Pakiet jest już zainstalowany
Pominięcie instalacji, przejście do kolejnego programu.
-1978335215 (0x8A150011)
Niezgodność hasha (Hash Mismatch)
Uruchomienie procedury awaryjnej (dla Office: ODT).
-1073741819 (0xC0000005)
Crash starej wersji winget
Automatyczna aktualizacja winget i zależności.
-1978335216 (0x8A150010)
Brak instalatora spełniającego filtry
Automatyczne usunięcie restrykcyjnych flag locale / arch.

## Kontakt i wsparcie
W razie problemów z wdrożeniem lub pytań technicznych:

Autor: Roman Pindela
Adres e-mail: roman.pindela@gmail.com

