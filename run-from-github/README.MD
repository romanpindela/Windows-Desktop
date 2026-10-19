# PowerShell Script Launcher (Run from GitHub)

**Version: 1.1.0**

[![PowerShell Compatibility](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.0%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%28Desktop%20%2F%20Server%29-lightgrey.svg)](https://www.microsoft.com/windows)
[![Privileges](https://img.shields.io/badge/Privileges-Administrator-red.svg)](https://docs.microsoft.com/en-us/windows/security/identity-protection/user-account-control/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Niezawodny launcher PowerShell typu **Copy-Paste** zaprojektowany do automatycznego pobierania i uruchamiania dowolnego skryptu bezpośrednio z repozytorium GitHub po wklejeniu bloku poleceń do konsoli PowerShell uruchomionej jako **Administrator**.

---

## 📋 Spis treści

- [Opis działania](#-opis-działania)
- [Porównanie 3 wariantów polityki wykonywania (ExecutionPolicy)](#-porównanie-3-wariantów-polityki-wykonywania-executionpolicy)
- [Gotowe bloki do skopiowania](#-gotowe-bloki-do-skopiowania)
  - [Wariant 1: Dla danej maszyny (LocalMachine)](#wariant-1-dla-danej-maszyny-localmachine)
  - [Wariant 2: Dla danego użytkownika (CurrentUser)](#wariant-2-dla-danego-użytkownika-currentuser)
  - [Wariant 3: Dla danej sesji (Process)](#wariant-3-dla-danej-sesji-process)
- [Co robi każda część bloku kodu?](#-co-robi-każda-część-bloku-kodu)
- [Wymagania techniczne](#-wymagania-techniczne)
- [Autor](#-autor)

---

## 🔍 Opis działania

Głównym celem tego rozwiązania jest umożliwienie natychmiastowego uruchomienia skryptu z GitHuba na nowej maszynie lub podczas sesji serwisowej bez konieczności ręcznego tworzenia plików czy pobierania repozytorium przez przeglądarkę.

Każdy z poniższych bloków poleceń realizuje pełny cykl operacyjny w ramach jednego wklejenia do konsoli:
1. **Weryfikacja uprawnień Administratora:** Sprawdza, czy konsola została uruchomiona z podwyższonymi uprawnieniami (językowo niezależny mechanizm SID).
2. **Odblokowanie PowerShell (`Set-ExecutionPolicy`):** Odblokowuje możliwość uruchamiania skryptów w wybranym zakresie (`LocalMachine`, `CurrentUser` lub `Process`).
3. **Przygotowanie katalogu docelowego (`C:\PowerShell`):** Sprawdza obecność folderu i tworzy go automatycznie, jeśli nie istnieje.
4. **Konfiguracja TLS 1.2 i obsługa linku GitHub:** Wymusza protokół TLS 1.2 oraz automatycznie przekształca standardowe adresy URL widoku GitHuba (`/blob/`) na bezpośrednie łącza do czystej zawartości (`raw.githubusercontent.com`).
5. **Pobranie skryptu:** Pobiera plik docelowy za pomocą `Invoke-WebRequest`.
6. **Odblokowanie pliku (`Unblock-File`):** Usuwa zabezpieczenie Windows Mark of the Web (MotW / `Zone.Identifier`).
7. **Uruchomienie skryptu:** Wykonuje pobrany skrypt w bieżącym oknie i prezentuje wyniki.

---

## 📊 Porównanie 3 wariantów polityki wykonywania (ExecutionPolicy)

| Wariant | Zakres (`-Scope`) | Poziom rejestru | Trwałość | Kiedy stosować? |
| :--- | :--- | :--- | :--- | :--- |
| **1. Maszyna** | `LocalMachine` | `HKLM:\SOFTWARE\Microsoft\PowerShell...` | **Trwała** (dla całego systemu) | Stacje robocze, serwery administratorskie, instalacje bazowe, gdy każdy użytkownik komputera ma mieć odblokowany PowerShell. |
| **2. Użytkownik** | `CurrentUser` | `HKCU:\SOFTWARE\Microsoft\PowerShell...` | **Trwała** (dla profilu użytkownika) | Maszyny współdzielone, gdy chcesz odblokować wykonywanie skryptów tylko dla konta administratora/użytkownika bez zmiany ustawień innych profili. |
| **3. Sesja** | `Process` | Brak (tylko pamięć procesu) | **Tymczasowa** (znika po zamknięciu okna) | Jednorazowe wdrożenia, diagnostyka, audyty bezpieczeństwa i środowiska o zaostrzonych regułach, gdzie nie wolno modyfikować rejestru na stałe. |

---

## 🚀 Gotowe bloki do skopiowania

> [!IMPORTANT]
> Przed wklejeniem kodu upewnij się, że otworzyłeś konsolę **PowerShell jako Administrator** (`Uruchom jako administrator` / `Run as Administrator`).
> Zmienną `$UrlToDownload` możesz zmienić na dowolny skrypt z GitHuba.

---

### Wariant 1: Dla danej maszyny (LocalMachine)

Odblokowuje możliwość wykonywania skryptów globalnie dla całej maszyny (wszystkich użytkowników).

#### Pełny blok skryptu (czytelny i gotowy do wklejenia):

```powershell
# ==============================================================================
# WARIANT 1: DLA DANEJ MASZYNY (Scope: LocalMachine)
# ==============================================================================
# 1. Konfiguracja adresu skryptu i katalogu docelowego
$UrlToDownload   = "https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"
$DestinationPath = "C:\PowerShell"

# 2. Weryfikacja uprawnień Administratora (językowo niezależny test SID)
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
if (-not $principal.IsInRole($adminSid)) {
    Write-Error "Wymagane są uprawnienia Administratora! Uruchom konsolę PowerShell jako Administrator."
    return
}

# 3. Odblokowanie wykonywania skryptów dla całej maszyny
Write-Host "Ustawianie ExecutionPolicy na RemoteSigned dla LocalMachine..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# 4. Sprawdzenie i utworzenie folderu docelowego
if (-not (Test-Path -LiteralPath $DestinationPath)) {
    Write-Host "Tworzenie katalogu: $DestinationPath..." -ForegroundColor Yellow
    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
}

# 5. Konfiguracja TLS 1.2 i konwersja adresu GitHub na Raw URL
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($UrlToDownload -like "*github.com/*/blob/*") {
    $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
} else {
    $rawUrl = $UrlToDownload
}

$fileName        = Split-Path -Path $rawUrl.Split('?')[0] -Leaf
$destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

# 6. Pobranie skryptu z GitHuba
Write-Host "Pobieranie '$fileName' do '$DestinationPath'..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

# 7. Odblokowanie pliku (usunięcie blokady Mark-of-the-Web) i uruchomienie
if (Test-Path -LiteralPath $destinationFile) {
    Unblock-File -LiteralPath $destinationFile
    Write-Host "[OK] Skrypt odblokowany pomyślnie." -ForegroundColor Green
    Write-Host "`n--- Uruchamianie pobranego skryptu: $fileName ---`n" -ForegroundColor Yellow
    & $destinationFile
    Write-Host "`n--- Zakończono wykonywanie: $fileName ---" -ForegroundColor Yellow
} else {
    Write-Error "Błąd: Nie znaleziono pobranego pliku pod ścieżką: $destinationFile"
}
```

#### Wersja jednolinijkowa (One-Liner do szybkiego uruchomienia):

```powershell
& { $u="https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"; $p="C:\PowerShell"; if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){throw "Wymagany Administrator!"}; Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force; if(-not(Test-Path $p)){New-Item -Path $p -ItemType Directory -Force|Out-Null}; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=if($u -like "*github.com/*/blob/*"){$u -replace "github.com","raw.githubusercontent.com" -replace "/blob/","/"}else{$u}; $f=Join-Path $p (Split-Path $r.Split('?')[0] -Leaf); Invoke-WebRequest -Uri $r -OutFile $f -UseBasicParsing; Unblock-File -LiteralPath $f; & $f }
```

---

### Wariant 2: Dla danego użytkownika (CurrentUser)

Odblokowuje możliwość wykonywania skryptów tylko dla konta bieżącego użytkownika (konfiguracja trwała w `HKCU`).

#### Pełny blok skryptu (czytelny i gotowy do wklejenia):

```powershell
# ==============================================================================
# WARIANT 2: DLA DANEGO UŻYTKOWNIKA (Scope: CurrentUser)
# ==============================================================================
# 1. Konfiguracja adresu skryptu i katalogu docelowego
$UrlToDownload   = "https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"
$DestinationPath = "C:\PowerShell"

# 2. Weryfikacja uprawnień Administratora (językowo niezależny test SID)
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
if (-not $principal.IsInRole($adminSid)) {
    Write-Error "Wymagane są uprawnienia Administratora! Uruchom konsolę PowerShell jako Administrator."
    return
}

# 3. Odblokowanie wykonywania skryptów dla bieżącego użytkownika
Write-Host "Ustawianie ExecutionPolicy na RemoteSigned dla CurrentUser..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 4. Sprawdzenie i utworzenie folderu docelowego
if (-not (Test-Path -LiteralPath $DestinationPath)) {
    Write-Host "Tworzenie katalogu: $DestinationPath..." -ForegroundColor Yellow
    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
}

# 5. Konfiguracja TLS 1.2 i konwersja adresu GitHub na Raw URL
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($UrlToDownload -like "*github.com/*/blob/*") {
    $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
} else {
    $rawUrl = $UrlToDownload
}

$fileName        = Split-Path -Path $rawUrl.Split('?')[0] -Leaf
$destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

# 6. Pobranie skryptu z GitHuba
Write-Host "Pobieranie '$fileName' do '$DestinationPath'..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

# 7. Odblokowanie pliku (usunięcie blokady Mark-of-the-Web) i uruchomienie
if (Test-Path -LiteralPath $destinationFile) {
    Unblock-File -LiteralPath $destinationFile
    Write-Host "[OK] Skrypt odblokowany pomyślnie." -ForegroundColor Green
    Write-Host "`n--- Uruchamianie pobranego skryptu: $fileName ---`n" -ForegroundColor Yellow
    & $destinationFile
    Write-Host "`n--- Zakończono wykonywanie: $fileName ---" -ForegroundColor Yellow
} else {
    Write-Error "Błąd: Nie znaleziono pobranego pliku pod ścieżką: $destinationFile"
}
```

#### Wersja jednolinijkowa (One-Liner do szybkiego uruchomienia):

```powershell
& { $u="https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"; $p="C:\PowerShell"; if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){throw "Wymagany Administrator!"}; Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; if(-not(Test-Path $p)){New-Item -Path $p -ItemType Directory -Force|Out-Null}; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=if($u -like "*github.com/*/blob/*"){$u -replace "github.com","raw.githubusercontent.com" -replace "/blob/","/"}else{$u}; $f=Join-Path $p (Split-Path $r.Split('?')[0] -Leaf); Invoke-WebRequest -Uri $r -OutFile $f -UseBasicParsing; Unblock-File -LiteralPath $f; & $f }
```

---

### Wariant 3: Dla danej sesji (Process)

Odblokowuje możliwość wykonywania poleceń **wyłącznie w otwartym procesie PowerShell**. Nie modyfikuje rejestru Windows i automatycznie wygasa po zamknięciu okna konsoli.

#### Pełny blok skryptu (czytelny i gotowy do wklejenia):

```powershell
# ==============================================================================
# WARIANT 3: DLA DANEJ SESJI (Scope: Process)
# ==============================================================================
# 1. Konfiguracja adresu skryptu i katalogu docelowego
$UrlToDownload   = "https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"
$DestinationPath = "C:\PowerShell"

# 2. Weryfikacja uprawnień Administratora (językowo niezależny test SID)
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
if (-not $principal.IsInRole($adminSid)) {
    Write-Error "Wymagane są uprawnienia Administratora! Uruchom konsolę PowerShell jako Administrator."
    return
}

# 3. Odblokowanie wykonywania skryptów tylko na czas bieżącej sesji / procesu
Write-Host "Ustawianie ExecutionPolicy na Bypass dla bieżącej sesji (Process)..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# 4. Sprawdzenie i utworzenie folderu docelowego
if (-not (Test-Path -LiteralPath $DestinationPath)) {
    Write-Host "Tworzenie katalogu: $DestinationPath..." -ForegroundColor Yellow
    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
}

# 5. Konfiguracja TLS 1.2 i konwersja adresu GitHub na Raw URL
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($UrlToDownload -like "*github.com/*/blob/*") {
    $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
} else {
    $rawUrl = $UrlToDownload
}

$fileName        = Split-Path -Path $rawUrl.Split('?')[0] -Leaf
$destinationFile = Join-Path -Path $DestinationPath -ChildPath $fileName

# 6. Pobranie skryptu z GitHuba
Write-Host "Pobieranie '$fileName' do '$DestinationPath'..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing

# 7. Odblokowanie pliku (usunięcie blokady Mark-of-the-Web) i uruchomienie
if (Test-Path -LiteralPath $destinationFile) {
    Unblock-File -LiteralPath $destinationFile
    Write-Host "[OK] Skrypt odblokowany pomyślnie." -ForegroundColor Green
    Write-Host "`n--- Uruchamianie pobranego skryptu: $fileName ---`n" -ForegroundColor Yellow
    & $destinationFile
    Write-Host "`n--- Zakończono wykonywanie: $fileName ---`n" -ForegroundColor Yellow
} else {
    Write-Error "Błąd: Nie znaleziono pobranego pliku pod ścieżką: $destinationFile"
}
```

#### Wersja jednolinijkowa (One-Liner do szybkiego uruchomienia):

```powershell
& { $u="https://github.com/romanpindela/Windows-Desktop/blob/main/get-wifi-profiles/get-wifi-profiles.ps1"; $p="C:\PowerShell"; if(-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){throw "Wymagany Administrator!"}; Set-ExecutionPolicy Bypass -Scope Process -Force; if(-not(Test-Path $p)){New-Item -Path $p -ItemType Directory -Force|Out-Null}; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=if($u -like "*github.com/*/blob/*"){$u -replace "github.com","raw.githubusercontent.com" -replace "/blob/","/"}else{$u}; $f=Join-Path $p (Split-Path $r.Split('?')[0] -Leaf); Invoke-WebRequest -Uri $r -OutFile $f -UseBasicParsing; Unblock-File -LiteralPath $f; & $f }
```

---

## 🔧 Co robi każda część bloku kodu?

1. **Weryfikacja konta Administratora:**
   ```powershell
   $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
   $principal = New-Object Security.Principal.WindowsPrincipal($identity)
   $adminSid  = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltInAdministratorsSid, $null)
   $principal.IsInRole($adminSid)
   ```
   *Dlaczego tak:* Użycie dobrze znanego identyfikatora SID `S-1-5-32-544` gwarantuje 100% niezawodności na polskich (`Administratorzy`) i angielskich (`Administrators`) wersjach systemu Windows.

2. **Odblokowanie polityki wykonywania:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   ```
   *Dlaczego tak:* Domyślna polityka w Windows to często `Restricted`. Odblokowanie odpowiedniego zakresu pozwala na uruchomienie skryptu bez konieczności interaktywnego potwierdzania monitów (`-Force`).

3. **Utworzenie folderu docelowego (`C:\PowerShell`):**
   ```powershell
   if (-not (Test-Path -LiteralPath $DestinationPath)) {
       New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
   }
   ```
   *Dlaczego tak:* Bezpieczna lokalizacja `C:\PowerShell` zapobiega zaśmiecaniu profilu użytkownika lub katalogów tymczasowych, a parametr `-Force` gwarantuje brak błędów w przypadku, gdy folder już istnieje.

4. **Konwersja adresu URL i TLS 1.2:**
   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   if ($UrlToDownload -like "*github.com/*/blob/*") {
       $rawUrl = $UrlToDownload -replace "github.com", "raw.githubusercontent.com" -replace "/blob/", "/"
   }
   ```
   *Dlaczego tak:* Windows PowerShell 5.1 domyślnie używa starszych protokołów SSL3/TLS 1.0, z którymi GitHub odmawia połączenia. Wymuszenie TLS 1.2 jest niezbędne. Zamiana adresu pozwala wkleić dowolny zwykły link z przeglądarki GitHub bez szukania przycisku "Raw".

5. **Pobranie pliku:**
   ```powershell
   Invoke-WebRequest -Uri $rawUrl -OutFile $destinationFile -UseBasicParsing
   ```
   *Dlaczego tak:* Flaga `-UseBasicParsing` zapobiega problemom w środowiskach Server Core oraz tam, gdzie silnik Internet Explorer nie był wstępnie konfigurowany.

6. **Odblokowanie pliku (`Unblock-File`):**
   ```powershell
   Unblock-File -LiteralPath $destinationFile
   ```
   *Dlaczego tak:* Pliki pobrane z sieci są oznaczane strumieniem NTFS `Zone.Identifier` (Mark of the Web), co może blokować ich uruchomienie nawet przy `RemoteSigned`. Polecenie natychmiast usuwa to ograniczenie.

7. **Uruchomienie skryptu:**
   ```powershell
   & $destinationFile
   ```
   *Dlaczego tak:* Operator wywołania `&` uruchamia pobrany skrypt w bieżącym kontekście konsoli z pełnym przekazywaniem strumieni wyjściowych.

---

## 💻 Wymagania techniczne

* **System operacyjny:** Windows 10, Windows 11, Windows Server 2016 / 2019 / 2022 / 2025+
* **Wersja PowerShell:** Windows PowerShell 5.1 lub PowerShell 7+
* **Uprawnienia:** Konsola uruchomiona jako Administrator (**Run as Administrator**)
* **Połączenie sieciowe:** Dostęp do `github.com` oraz `raw.githubusercontent.com` (HTTPS / port 443)

---

## 👤 Autor

* **Roman Pindela**
* **E-mail:** `roman.pindela@gmail.com`
* **GitHub:** [https://github.com/romanpindela](https://github.com/romanpindela)
* **Repozytorium:** [Windows-Desktop](https://github.com/romanpindela/Windows-Desktop)