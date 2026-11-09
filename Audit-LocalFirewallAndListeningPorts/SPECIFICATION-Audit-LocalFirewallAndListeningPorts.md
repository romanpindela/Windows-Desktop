# Specyfikacja Techniczna Zadania: Audit-LocalFirewallAndListeningPorts

## 1. Informacje podstawowe i metadane

| Parametr | Wartość |
| :--- | :--- |
| **Repozytorium** | `Windows-Desktop` |
| **Ścieżka projektu** | `c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-LocalFirewallAndListeningPorts\` |
| **Główny plik skryptu** | `Audit-LocalFirewallAndListeningPorts.ps1` |
| **Plik specyfikacji** | `SPECIFICATION-Audit-LocalFirewallAndListeningPorts.md` |
| **Plik dokumentacji** | `README.md` |
| **Wersja PowerShell** | PowerShell 5.1 oraz PowerShell 7+ (Dual-compatibility) |
| **Wymagane uprawnienia** | Administrator (`Run as Administrator` – automatyczna elewacja po SID `S-1-5-32-544`) |
| **Obsługa logowania** | Tak (`C:\Logs\Audit-LocalFirewallAndListeningPorts.log`) |
| **Wsparcie dla pipeline** | Tak (`[PSCustomObject]` zwracany na standardowy strumień wyjściowy) |
| **Generowanie raportu** | Tak (Samodzielny raport HTML z osadzonym CSS) |

---

## 2. Cel i kontekst biznesowo-techniczny

Skrypt służy do audytu bezpieczeństwa i ewaluacji powierzchni ataku na poziomie pojedynczego endpointu Windows (stacja robocza lub serwer). Umożliwia administratorowi oraz zespołowi SecOps szybką identyfikację:
1. Nieaktywnych lub osłabionych profili wbudowanej zapory Windows Defender Firewall.
2. Aktywnych usług sieciowych (porty TCP/UDP w stanie nasłuchu) wraz z identyfikacją binarek, ich podpisów cyfrowych i integralności.
3. Potencjalnie niebezpiecznych reguł zapory zezwalających na nieograniczony dostęp z dowolnego źródła (`RemoteAddress = Any / * / 0.0.0.0/0`) do krytycznych portów administracyjnych i współdzielenia plików.

---

## 3. Zakres techniczny i logika działania

### 3.1. Elewacja uprawnień (Self-Elevation)
- Na samym początku wykonywania skryptu weryfikowany jest token administracyjny za pomocą `[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()`.
- Weryfikacja oparta o SID wbudowanej grupy administratorów: `[Security.Principal.WindowsBuiltInRole]::Administrator` (`S-1-5-32-544`).
- W przypadku braku uprawnień następuje automatyczny restart procesu PowerShell z parametrem `-Verb RunAs`, z zachowaniem przekazanych parametrów `$PSBoundParameters`.

### 3.2. Audyt profili zapory sieciowej (Firewall Profiles)
- Pobranie stanu wszystkich profili (`Domain`, `Private`, `Public`) za pośrednictwem polecenia `Get-NetFirewallProfile`.
- Weryfikacja:
  - `Enabled` (`True` / `False`). Flaga `FAIL` jeśli którykolwiek profil jest wyłączony.
  - `DefaultInboundAction` (Oczekiwane: `Block` / `BlockAllInbound`). Flaga `WARN` jeśli ustawiono `Allow`.
  - `DefaultOutboundAction` (Typowo: `Allow`).
  - Stan rejestrowania logów zdarzeń zapory (`LogAllowed`, `LogBlocked`, `LogFileName`).

### 3.3. Audyt portów nasłuchujących i powiązanie z procesami
- Pobranie aktywnych gniazd TCP w stanie `Listen` (`Get-NetTCPConnection -State Listen`).
- Pobranie aktywnych endpointów UDP (`Get-NetUDPEndpoint`).
- Pobranie list procesów (`Get-Process`) z mapowaniem:
  - `OwningProcess` / `Id` $\to$ `ProcessName`, `Path`, `CommandLine` (jeśli dostępne via WMI/CIM), `StartTime`.
  - Weryfikacja podpisu cyfrowego pliku wykonywalnego (`Get-AuthenticodeSignature`):
    - Status podpisu (`Valid`, `NotSigned`, `HashMismatch`, `UntrustedRoot` itp.).
    - Wystawca certyfikatu (`SignerCertificate.Subject`).
- Identyfikacja procesów-widm (port nasłuchuje, ale proces już nie istnieje lub PID = 0/System).

### 3.4. Detekcja reguł wysokiego ryzyka (High-Risk Inbound Rules)
- Pobranie włączonych reguł przychodzących (`Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow`).
- Połączenie z filtrami portów i adresów (`Get-NetFirewallPortFilter`, `Get-NetFirewallAddressFilter`).
- Definicja portów wysokiego ryzyka (konfigurowalna w parametrach, domyślnie):
  - **3389** (RDP)
  - **5985, 5986** (WinRM HTTP/HTTPS)
  - **445, 139** (SMB / NetBIOS)
  - **22** (SSH)
  - **21, 23** (FTP / Telnet)
- Kryteria wykrycia naruszenia baseline'u (`IsCriticalExposure = $true`):
  - `Action` = `Allow`
  - `Direction` = `Inbound`
  - `Enabled` = `True`
  - `LocalPort` zawiera co najmniej jeden port z listy wysokiego ryzyka.
  - `RemoteAddress` to `Any`, `*`, `Internet`, `0.0.0.0/0`, `::/0` lub zawiera brak ograniczeń subnetowych.

---

## 4. Architektura parametrów skryptu

```powershell
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogDirectory = 'C:\Logs',

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "C:\Logs\Firewall-Audit-Report-$((Get-Date).ToString('yyyyMMdd-HHmmss')).html",

    [Parameter(Mandatory = $false)]
    [int[]]$HighRiskPorts = @(21, 22, 23, 139, 445, 3389, 5985, 5986),

    [Parameter(Mandatory = $false)]
    [switch]$NoHtmlReport,

    [Parameter(Mandatory = $false)]
    [switch]$ShowReportInBrowser,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)
```

---

## 5. Standard logowania i obsługi błędów

### 5.1. Funkcja `Write-CustomLog`
- Format wpisu: `[yyyy-MM-dd HH:mm:ss.fff] [SEVERITY] [ThreadId] Treść komunikatu`
- Poziomy: `DEBUG`, `INFO`, `WARN`, `ERROR`, `CRITICAL`
- Automatyczne tworzenie katalogu docelowego (`Test-Path` $\to$ `New-Item -ItemType Directory`).
- Równoległy zapis do pliku logu (`Out-File -Append -Encoding utf8`) oraz prezentacja w konsoli z użyciem kolorowania składni (`Write-Host` / `Write-Verbose` w zależności od przełącznika `$Quiet`).

### 5.2. Obsługa błędów (Try-Catch & ErrorAction)
- Wszystkie operacje WMI/CIM, parsowanie reguł zapory i odpytywanie procesów muszą być objęte blokami `try { ... } catch { ... }`.
- Błędy dostępu do chronionych procesów systemowych (np. PID 4 / System, csrss.exe) nie mogą przerywać pętli zbierania danych (graceful degradation: status `Access Denied / Protected System Process`).

---

## 6. Struktura raportu HTML

Raport HTML musi stanowić w 100% niezależny, pojedynczy plik z wbudowanym arkuszem stylów CSS (Self-contained, brak zewnętrznych zależności CDN):
1. **Header & Summary Cards:**
   - Hostname, Data skanu, System operacyjny, Użytkownik uruchamiający.
   - Status profili: Wszystkie aktywne (Zielony) / Co najmniej jeden wyłączony (Czerwony).
   - Licznik reguł wysokiego ryzyka (Alert badge: Czerwony jeśli $>0$).
   - Liczba otwartych portów nasłuchujących (Podział na podpisane i niepodpisane binarki).
2. **Sekcja 1: Stan profili zapory** (Tabela: Profil, Stan, Domyślny ruch przychodzący/wychodzący, Ścieżka logu).
3. **Sekcja 2: Reguły podwyższonego ryzyka (Baseline Violations)**:
   - Podświetlenie na czerwono reguł `Any -> HighRiskPort`.
   - Pola: Nazwa reguły, Profil, Protokół, Port lokalny, Zdalny adres, Akcja.
4. **Sekcja 3: Aktywne usługi i porty nasłuchujące (Listening Ports Inventory)**:
   - Pola: Protokół, Adres lokalny, Port, PID, Nazwa procesu, Ścieżka, Status podpisu Authenticode, Wydawca podpisu.
   - Wiersze z binarkami o statusie `NotSigned` lub `HashMismatch` oznaczone kolorem ostrzegawczym (pomarańczowy/żółty).

---

## 7. Model danych wyjściowych (Pipeline Object)

Skrypt generuje na standardowy strumień wyjściowy ustrukturyzowany obiekt:

```powershell
[PSCustomObject]@{
    ComputerName       = $env:COMPUTERNAME
    AuditTimestamp     = (Get-Date)
    FirewallProfiles   = $profileResults      # Kolekcja obiektów profili
    HighRiskRulesCount = $criticalRules.Count
    HighRiskRules      = $criticalRules       # Kolekcja naruszeń reguł
    ListeningEndpoints = $listeningInventory # Szczegółowe mapowanie port-proces-podpis
    SummaryStatus      = ($criticalRules.Count -eq 0 -and $profilesOk) ? 'PASS' : 'FAIL'
}
```

---

## 8. Plan wdrożenia i weryfikacji (Checklist)

- [ ] Utworzenie struktury folderu `c:\Dane\rpindela\GitHub\Windows-Desktop\Audit-LocalFirewallAndListeningPorts\`.
- [ ] Zapisanie niniejszej specyfikacji technicznej jako `SPECIFICATION-Audit-LocalFirewallAndListeningPorts.md`.
- [ ] Implementacja kodu głównego `Audit-LocalFirewallAndListeningPorts.ps1` zgodnie z regułami:
  - Brak aliasów (`Get-Process`, nie `ps`; `Where-Object`, nie `?`).
  - Pełne nazwy parametrów.
  - Obsługa bloków `Begin`, `Process`, `End`.
  - Pasek postępu `Write-Progress` podczas analizy sygnatur plików i reguł zapory.
- [ ] Utworzenie dokumentacji `README.md` z opisem użycia, przykładami i zrzutem widoku raportu.
- [ ] Test wykonania z uprawnieniami standardowymi (weryfikacja UAC auto-elevation).
- [ ] Test wykonania w środowisku PowerShell 5.1 (Windows 10/11 / Server 2016-2025) oraz PowerShell 7.x.
- [ ] Walidacja generowanego pliku HTML pod kątem responsywności i poprawności stylów offline.
