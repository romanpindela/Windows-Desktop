# Specyfikacja Architektoniczna Zadania: Audit-BitLockerAndTpmStatus

Dokument stanowi ustrukturyzowaną dyrektywę wdrożeniową dla agenta **Antigravity**. Wszystkie komponenty muszą zostać zrealizowane zgodnie z poniższymi standardami, architekturą i regułami środowiska.

---

## 1. Metadane i Ścieżki

- **Repozytorium docelowe:** `c:\Dane\rpindela\GitHub\Windows-Desktop\`
- **Katalog roboczy:** `c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-BitLockerAndTpmStatus\`
- **Plik skryptu:** `Audit-BitLockerAndTpmStatus.ps1`
- **Plik dokumentacji:** `README.md`
- **Ścieżka logów wykonawczych:** `C:\Logs\Audit-BitLockerAndTpmStatus_yyyyMMdd_HHmmss.log`
- **Ścieżka domyślnego raportu HTML:** `C:\Logs\Audit-BitLockerAndTpmStatus_yyyyMMdd_HHmmss.html`

---

## 2. Cel Biznesowy i Kontekst Zgodności

Skrypt realizuje kompleksowy audyt kryptograficzny stacji roboczych Windows 10/11 pod kątem wymagań:
- **Dyrektywy NIS2** (zarządzanie ryzykiem łańcucha dostaw i ochrona stacji końcowych),
- **Polityk zero-trust i ochrony danych at-rest** (zabezpieczenie nośników przed kradzieżą i nieautoryzowanym odczytem offline),
- **Wymagań audytowych Active Directory / Microsoft Entra ID** (weryfikacja escrow kluczy odzyskiwania BitLocker).

---

## 3. Zakres Audytu i Architektura Logiki

Skrypt musi działać w architekturze modułowej, agregując wyniki w obiekt `[PSCustomObject]` przed ich prezentacją i eksportem.

### 3.1. Sprzętowa warstwa zaufania (Hardware Root of Trust)
1. **Moduł TPM (`Get-Tpm` / WMI `root\CIMv2\Security\MicrosoftTpm`):**
   - Obecność fizycznego lub fTPM.
   - Wersja specyfikacji (wymagana TPM 2.0).
   - Właściwości: `TpmPresent`, `TpmReady`, `TpmEnabled`, `TpmActivated`.
   - Producent modułu i wersja firmware producenta.
2. **Bezpieczny rozruch (Secure Boot):**
   - Wywołanie `Confirm-SecureBootUEFI` z obsługą błędów (środowiska Legacy BIOS vs UEFI).
   - Sprawdzenie flagi trybu UEFI (`$env:firmware_type` lub `Get-ComputerInfo`).

### 3.2. Szyfrowanie wolumenów (BitLocker)
1. **Analiza wolumenów (`Get-BitLockerVolume`):**
   - Identyfikacja wszystkich wolumenów logicznych (OS Drive, Fixed Data Drives, ewentualne Removable Drives).
   - `VolumeStatus`: weryfikacja czy wolumen jest w pełni zaszyfrowany (`FullyEncrypted`).
   - `EncryptionPercentage`: wymagane równe 100%.
   - `EncryptionMethod`: detekcja algorytmu (rekomendowany standard: `XtsAes128`, `XtsAes256`).
   - `ProtectionStatus`: `On` vs `Off`.
2. **Kluczowe protektory (Key Protectors):**
   - Wykrycie obecności protektorów: `Tpm`, `TpmPin`, `RecoveryPassword`, `NumericalPassword`.
   - Flaga ostrzegawcza w przypadku braku protektora TPM lub braku hasła odzyskiwania.

### 3.3. Weryfikacja Escrow (Kopia zapasowa kluczy)
1. **Detekcja typu dołączenia stacji (`dsregcmd /status`):**
   - Identyfikacja: `AzureAdJoined`, `DomainJoined`, `EnterpriseJoined`.
2. **Weryfikacja wysłania klucza do chmury / AD:**
   - Sprawdzenie logów zdarzeń Windows:
     - Microsoft-Windows-BitLocker/BitLocker Management (`EventID 845` – pomyślna archiwizacja w AD/Entra ID, `EventID 846` – błąd escrow).
   - Wyznaczenie jednoznacznego statusu escrow: `SUCCESS_ENTRA`, `SUCCESS_AD`, `FAILED_NO_ESCROW`, `STANDALONE_NOT_APPLICABLE`.

---

## 4. Wymagania Techniczne i Standardy Jakościowe

### 4.1. Środowisko i Elewacja
- **Kompatybilność:** Windows PowerShell 5.1 oraz PowerShell 7+ (Dual Engine).
- **Elewacja UAC:** Weryfikacja tożsamości administracyjnej po SID `S-1-5-32-544`:
  ```powershell
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
      throw "Skrypt wymaga uprawnień administratora (UAC Elevation)."
  }
  ```
- **Obsługa błędów:** `[CmdletBinding()]` z pełną deklaracją bloków `try/catch` dla każdego podsystemu (TPM, UEFI, BitLocker, EventLog).

### 4.2. Interfejs Użytkownika i Konsola
- Dynamiczny pasek postępu `Write-Progress` dla każdego etapu:
  1. *Sprawdzanie stanu TPM i UEFI...*
  2. *Audyt wolumenów BitLocker...*
  3. *Weryfikacja historii zdarzeń escrow kluczy...*
  4. *Generowanie raportu HTML i podsumowania konsolowego...*
- Wynik w konsoli w formie czytelnej tabeli ze znacznikami statusu:
  - `[PASS]` – kolor zielony (`Green`)
  - `[FAIL]` – kolor czerwony (`Red`)
  - `[WARN]` – kolor żółty (`Yellow`)

### 4.3. Moduł Logowania (`C:\Logs\`)
- Dedykowana, wewnętrzna funkcja `Write-LogEntry`:
  - Tworzenie folderu `C:\Logs\` w przypadku jego braku.
  - Format wpisu: `yyyy-MM-dd HH:mm:ss.fff [INFO|WARN|ERROR] Treść komunikatu`.
  - Kodowanie: UTF-8.
  - Wykluczenie ujawniania pełnych kluczy odzyskiwania w logu (zapis wyłącznie KeyProtector ID).

### 4.4. Raport HTML
- Nowoczesny, estetyczny raport HTML (Dark/Clean UI, self-contained CSS).
- Sekcje raportu:
  1. **Podsumowanie maszyny:** Hostname, OS, architektura, data skanowania, globalny status zgodności (NIS2 Ready / Non-Compliant).
  2. **Tabela TPM & Secure Boot:** Wersja specyfikacji, status gotowości, tryb rozruchu.
  3. **Tabela Wolumenów BitLocker:** Dysk, stan szyfrowania, %, metoda, typy protektorów, status escrow.

---

## 5. Parametry Skryptu (`param`)

| Parametr | Typ | Domyślna wartość | Opis |
| :--- | :--- | :--- | :--- |
| `PathHtmlReport` | `[string]` | `C:\Logs\Audit-BitLockerAndTpmStatus_<timestamp>.html` | Ścieżka wygenerowania raportu HTML. |
| `OpenReport` | `[switch]` | `$false` | Automatyczne otwarcie wygenerowanego raportu HTML w domyślnej przeglądarce. |
| `EnforceAes256` | `[switch]` | `$false` | Flaga audytowa: traktuj metody inne niż `XtsAes256` lub `Aes256` jako `FAIL` zamiast `PASS/WARN`. |
| `PassThru` | `[switch]` | `$false` | Zwraca końcowy obiekt audytu do potoku PowerShell (`PSCustomObject`). |

---

## 6. Lista Zadań dla Agenta Antigravity

1. **Utworzenie struktury:**
   - Zainicjowanie katalogu `c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-BitLockerAndTpmStatus\`.
2. **Implementacja `Audit-BitLockerAndTpmStatus.ps1`:**
   - Dodanie standardowego nagłówka Help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`).
   - Implementacja sprawdzania uprawnień administracyjnych (SID `S-1-5-32-544`).
   - Implementacja mechanizmu `Write-LogEntry` z zapisem do `C:\Logs\`.
   - Moduły audytowe: TPM, Secure Boot, BitLocker, Escrow EventLog.
   - Budowa szablonu HTML z responsywną tabelą CSS.
   - Kolorowy rendering w konsoli (PASS / WARN / FAIL).
3. **Przygotowanie dokumentacji `README.md`:**
   - Wymagania wstępne, uprawnienia, opis parametrów, przykłady użycia CLI, opis kryteriów oceny NIS2.
