# Specyfikacja Zadania: Audit-EndpointPersistence

## 1. Metadane Zadania
- **Cel:** Przygotowanie skryptu PowerShell do audytu i detekcji mechanizmów utrzymania obecności (Persistence / ASEP - Auto-Start Execution Points) na stacjach roboczych Windows.
- **Katalog docelowy:** `c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-EndpointPersistence\`
- **Nazwa pliku skryptu:** `Audit-EndpointPersistence.ps1`
- **Typ narzędzia:** Audyt / Detekcja zagrożeń / Threat Hunting / Hardening
- **Wymagane środowisko:** Windows 10, Windows 11, Windows Server (Windows PowerShell 5.1 oraz PowerShell 7+)
- **Uprawnienia:** Wymagane podniesione uprawnienia administratora (`Run as Administrator`) z automatyczną elewacją.

---

## 2. Architektura i Konwencje Standardu

### 2.1. Zgodność ze standardami produkcyjnymi
1. **Nagłówek pomocy (`Get-Help`):**
   - Kompletny blok CBH (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`, `.NOTES`).
2. **Atrybuty zaawansowane:**
   - `[CmdletBinding()]` z pełną deklaracją typów dla każdego parametru.
3. **Wymóg elewacji (UAC Self-Elevation):**
   - Weryfikacja tożsamości WindowsPrincipal dla SID administratora (`S-1-5-32-544`).
   - W przypadku braku elewacji: automatyczne wznowienie procesu z argumentem `-Verb RunAs` i przekazaniem parametrów wejściowych.
4. **Logowanie zdarzeń (`Write-Log`):**
   - Zapis do `C:\Logs\Audit-EndpointPersistence_yyyyMMdd_HHmmss.log`.
   - Rotacja/tworzenie katalogu docelowego w przypadku braku.
   - Format wpisu: `[yyyy-MM-dd HH:mm:ss] [SEVERITY] Komunikat`.
5. **Pasek postępu (`Write-Progress`):**
   - Wielopoziomowe śledzenie etapów skanowania poszczególnych wektorów ASEP.
6. **Obsługa błędów:**
   - Precyzyjne bloki `try { ... } catch { ... }` zabezpieczające przed brakiem dostępu do kluczy rejestru (HKCU innych użytkowników, chronione klucze HKLM) i zablokowanymi plikami.

---

## 3. Zakres Detekcji i Logika Analityczna

Skrypt weryfikuje cztery kluczowe wektory utrzymania obecności (Persistence):

### 3.1. Harmonogram Zadań (Scheduled Tasks)
- **Kryteria audytu:**
  - Zadania skonfigurowane do uruchamiania w kontekście `NT AUTHORITY\SYSTEM` (SID `S-1-5-18`) lub lokalnej grupy `Administrators` (SID `S-1-5-32-544`).
  - Akcje zadań wskazujące na pliki wykonywalne/skrypty (`.exe`, `.bat`, `.cmd`, `.vbs`, `.ps1`, `.dll`) zlokalizowane w folderach podwyższonego ryzyka:
    - `%TEMP%` / `%TMP%` (np. `C:\Windows\Temp`, `C:\Users\*\AppData\Local\Temp`)
    - `%APPDATA%` / `%LOCALAPPDATA%`
    - `C:\Users\Public\`
    - Katalogi z prawami zapisu dla zwykłych użytkowników.
- **Ocena ryzyka:** `High` lub `Critical`.

### 3.2. Rejestr Autostartu (ASEP Registry Keys)
- **Badane gałęzie rejestru:**
  - `HKLM:\Software\Microsoft\Windows\CurrentVersion\Run` oraz `RunOnce`
  - `HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run` oraz `RunOnce`
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run` oraz `RunOnce`
  - `HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders` i `User Shell Folders`
  - `HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components`
- **Kryteria oceny ryzyka:**
  - Wskazanie na ścieżki w profilach użytkowników, katalogach tymczasowych lub `Public` -> `High`.
  - Odwołania do parserów skryptów (`powershell.exe -enc`, `wscript.exe`, `cscript.exe`, `mshta.exe`, `rundll32.exe`) z parametrami sieciowymi lub ukrytymi -> `Critical`.
  - Poprawne binaria w `C:\Program Files\` z podpisem cyfrowym -> `Low`.

### 3.3. Foldery Startup (Autostart w Eksploratorze)
- **Lokalizacje:**
  - Globalny: `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup`
  - Bieżący użytkownik: `$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup`
  - Opcjonalnie: skanowanie profili w `C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`
- **Kryteria audytu:**
  - Wykrycie skrótów `.lnk`, plików `.url`, skryptów lub binariów.
  - Odczyt właściwości celu skrótu (`TargetPath`, `Arguments`) i analiza docelowej ścieżki.

### 3.4. Usługi Windows (Windows Services)
- **Unquoted Service Paths:**
  - Wyszukiwanie usług typu `Own Process` / `Share Process`, których ścieżka binarna zawiera spacje, nie jest ujęta w cudzysłowy i nie wskazuje na chronione podkatalogi `C:\Windows\System32\`.
- **Niestandardowe binaria:**
  - Usługi uruchamiane z katalogów innych niż `%SystemRoot%` i `%ProgramFiles%`.
  - Usługi wskazujące na pliki w profilach użytkowników lub dyskach wymiennych -> `Critical`.

---

## 4. Model Oceny Ryzyka (Risk Engine)

| Poziom Ryzyka | Warunki Kwalifikacji |
|---|---|
| **Critical** | Wykonywanie kodu z `C:\Users\Public`, `%TEMP%` lub `AppData` w kontekście `SYSTEM`; niespójna ścieżka usługi (Unquoted) z możliwością wstrzyknięcia pliku; zakodowane wywołania PowerShell/MSHTA w rejestrze autostartu. |
| **High** | Wpisy `Run`/`RunOnce` wskazujące na `%AppData%`; zadania zaplanowane admina uruchamiające niepodpisane skrypty; pliki wykonywalne w folderze Startup użytkownika. |
| **Medium** | Unquoted Service Path zlokalizowany wewnątrz `Program Files` (wymagający praw admina do zapisu); zadania harmonogramu z brakującym plikiem binarnym (osierocone wpisy). |
| **Low** | Standardowe aplikacje autostartu zainstalowane w `C:\Program Files\` lub `C:\Program Files (x86)\` posiadające poprawne podpisy cyfrowe. |

---

## 5. Parametry Wejściowe Skryptu

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ReportPath = "C:\Logs\Audit-EndpointPersistence_Report.html",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath = "C:\Logs\Audit-EndpointPersistence.log",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Low", "Medium", "High", "Critical")]
    [string]$MinimumRiskLevel = "Low",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAllProfiles,

    [Parameter(Mandatory = $false)]
    [switch]$OpenReport
)
```

---

## 6. Struktura Obiektu Wyjściowego (`PSCustomObject`)

Każdy zidentyfikowany punkt autostartu/utrzymania obecności zwraca ujednolicony obiekt:

```powershell
[PSCustomObject]@{
    Category        = "ScheduledTask" # ScheduledTask | RegistryRun | StartupFolder | WindowsService
    Name            = "UpdateCheckHelper"
    PathOrCommand   = "C:\Users\Public\update.exe /silent"
    ResolvedBinary  = "C:\Users\Public\update.exe"
    AccountContext  = "NT AUTHORITY\SYSTEM"
    RiskLevel       = "Critical"     # Low | Medium | High | Critical
    DetectionReason = "SYSTEM context executing binary from C:\Users\Public"
    IsSigned        = $false
    Signer          = $null
    FileExists      = $true
}
```

---

## 7. Wymagania Dotyczące Raportu HTML

1. **Stylistyka:**
   - Nowoczesny, responsywny dashboard (CSS Flexbox/Grid, font systemowy Segoe UI, ciemny motyw nagłówków lub profesjonalny motyw cyber-audit).
2. **Karty metryk (Executive Summary):**
   - Łączna liczba zbadanych punktów ASEP.
   - Liczniki z podziałem na ryzyka: `Critical` (czerwony), `High` (pomarańczowy), `Medium` (żółty), `Low` (zielony/szary).
3. **Tabele szczegółowe:**
   - Kolorystyczne wyróżnienie wierszy na podstawie `RiskLevel`.
   - Możliwość szybkiego sortowania i filtrowania (czysty CSS/Vanilla JS bez zależności zewnętrznych).
4. **Sekcja rekomendacji:**
   - Automatycznie generowane zalecenia remediacji w oparciu o znalezione podatności (np. naprawa cudzysłowów w rejestrze usług, usunięcie podejrzanych zadań w Harmonogramie).

---

## 8. Struktura Plików w Projekcie

```
c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-EndpointPersistence\
├── Audit-EndpointPersistence.ps1       # Główny skrypt audytujący
├── SPECIFICATION-Audit-EndpointPersistence.md # Niniejsza specyfikacja
└── README.md                           # Dokumentacja uruchomieniowa i przykłady
```

---

## 9. Plan Wdrożenia i Kolejne Kroki
1. **Zatwierdzenie specyfikacji:** Weryfikacja reguł heurystycznych detekcji ryzyka.
2. **Implementacja modułów detekcyjnych:**
   - Moduł `Get-ScheduledTaskPersistence`
   - Moduł `Get-RegistryPersistence`
   - Moduł `Get-StartupFolderPersistence`
   - Moduł `Get-UnquotedServicePersistence`
3. **Generator raportu HTML:** Opracowanie wbudowanego szablonu HTML/CSS generowanego bez modułów zewnętrznych.
4. **Testy stacyjne:** Walidacja na maszynie z typowymi aplikacjami autostartu oraz syntetycznymi próbkami podatności (np. celowo stworzone unquoted service path w środowisku testowym).