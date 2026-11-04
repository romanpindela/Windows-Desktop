# Specyfikacja Techniczna: Manage-SmbShareAccess

## 1. Metadane i Lokalizacja

* **Repozytorium:** `Windows-Desktop`
* **Ścieżka bazowa repozytorium:** `c:\Dane\rpindela\GitHub\Windows-Desktop\`
* **Katalog projektu:** `Manage-SmbShareAccess\`
* **Główny plik skryptu:** `Set-SmbShareAccessRule.ps1`
* **Typ operacji:** Zarządzanie uprawnieniami zasobów sieciowych SMB oraz uprawnieniami systemu plików (NTFS / ACL).

---

## 2. Cel i Zakres Funkcjonalny

Skrypt automatyzuje proces zarządzania dostępem do współdzielonych folderów w systemie Windows. Realizuje spójne nadawanie i odbieranie uprawnień na dwóch niezależnych poziomach:
1. **Uprawnienia udziału SMB (Share Permissions):** Zarządzane przez moduł `SmbShare` (`Grant-SmbShareAccess`, `Revoke-SmbShareAccess`, `Block-SmbShareAccess`).
2. **Uprawnienia systemu plików (NTFS Permissions / ACL):** Zarządzane na poziomie katalogu wskazanego przez udział za pomocą mechanizmów .NET (`System.Security.AccessControl.DirectorySecurity`, `FileSystemAccessRule`).

### Główne możliwości:
* Dodawanie tożsamości (użytkownik lokalny, domowy lub grupa) z określonym poziomem dostępu do Share i NTFS.
* Usuwanie tożsamości z uprawnień udziału SMB oraz opcjonalnie z list kontroli dostępu NTFS.
* Weryfikacja spójności (ostrzeżenie, gdy poziom uprawnień NTFS jest bardziej restrykcyjny niż uprawnienia SMB lub odwrotnie).
* Obsługa symulacji zmian (`-WhatIf` / `SupportsShouldProcess`).
* Raportowanie stanu przed i po modyfikacji.

---

## 3. Wymagania Systemowe i Uprawnienia

* **System operacyjny:** Windows 10 / Windows 11 (edycje Pro, Enterprise, Education).
* **Wersja PowerShell:** Windows PowerShell 5.1 lub PowerShell 7+.
* **Wymagane moduły:**
  * `SmbShare` (wbudowany w Windows).
  * `Microsoft.PowerShell.Security`.
* **Uprawnienia:** Wymagane uprawnienia administratora lokalnego (skrypt weryfikuje kontekst administracyjny tokenu za pomocą `WindowsPrincipal` i wykonuje automatyczną elewację UAC, jeśli uruchomiono go w zwykłym procesie).

---

## 4. Parametry Wejściowe Skryptu

| Parametr | Typ | Wymagany | Domyślna wartość | Opis |
| :--- | :--- | :---: | :---: | :--- |
| `-ShareName` | `[string]` | **Tak** | — | Nazwa udziału sieciowego SMB. |
| `-AccountName` | `[string[]]` | **Tak** | — | Nazwa użytkownika lub grupy (np. `CONTOSO\j.kowalski`, `BUILTIN\Users`, `.\LokalnyUser`). |
| `-Action` | `[string]` | **Tak** | — | Akcja: `Grant`, `Revoke`, `Deny`. Dozwolone wartości w `ValidateSet`. |
| `-AccessRight` | `[string]` | Nie | `Read` | Poziom uprawnień: `Read`, `Change` (Modify), `FullControl`. |
| `-ApplyToNtfs` | `[switch]` | Nie | `$true` | Czy synchronizować uprawnienia z systemem plików NTFS. |
| `-LogPath` | `[string]` | Nie | `C:\Logs\` | Ścieżka docelowa dla plików logów. |
| `-WhatIf` | `[switch]` | Nie | — | Standardowy przełącznik symulacji akcji. |
| `-Confirm` | `[switch]` | Nie | — | Monit o potwierdzenie krytycznych zmian. |

---

## 5. Mapowanie Uprawnień (SMB vs NTFS)

| Poziom (`-AccessRight`) | SMB AccessRight | NTFS FileSystemRights | Dziedziczenie NTFS |
| :--- | :--- | :--- | :--- |
| `Read` | `Read` | `ReadAndExecute, Synchronize` | `ContainerInherit, ObjectInherit` |
| `Change` | `Change` | `Modify, Synchronize` | `ContainerInherit, ObjectInherit` |
| `FullControl` | `Full` | `FullControl` | `ContainerInherit, ObjectInherit` |

---

## 6. Architektura Logowania i Obsługi Błędów

### 6.1. System Logowania
* Logowanie do pliku w lokalizacji: `C:\Logs\Manage-SmbShareAccess_yyyyMMdd.log`.
* Jeśli folder `C:\Logs\` nie istnieje, skrypt tworzy go automatycznie.
* Każdy wpis w formacie: `[yyyy-MM-dd HH:mm:ss] [POZIOM] [Funkcja/Krok] Treść komunikatu`.
* Poziomy logowania: `INFO`, `WARN`, `ERROR`, `DEBUG`.
* Równoległe wyjście na konsolę za pomocą `Write-Host` z odpowiednimi kolorami (zielony, żółty, czerwony, cyjan).

### 6.2. Obsługa Błędów (Error Handling)
* Główny blok `try/catch` otaczający operacje manipulacji ACL i SMB.
* Weryfikacja istnienia udziału (`Get-SmbShare -Name $ShareName -ErrorAction Stop`).
* Walidacja konta w systemie (`[System.Security.Principal.NTAccount]` z próbą translacji do SID).
* Zabezpieczenie przed uszkodzeniem dziedziczenia ACL (skrypt zachowuje istniejące flagi dziedziczenia).

---

## 7. Struktura Katalogów i Plików

```plaintext
c:\Dane\rpindela\GitHub\Windows-Desktop\Manage-SmbShareAccess\
│
├── SPECIFICATION-Manage-SmbShareAccess.md   # Niniejsza specyfikacja
├── Set-SmbShareAccessRule.ps1               # Główny skrypt wykonawczy
├── README.md                                # Instrukcja wdrożenia i przykłady użycia
└── Tests\
    └── Set-SmbShareAccessRule.Tests.ps1     # Testy Pester (weryfikacja parametrów i mocki)
```

---

## 8. Przykłady Użycia

### Przykład 1: Nadanie uprawnień do odczytu dla użytkownika domenowego (SMB + NTFS)
```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "RaportyFinansowe" -AccountName "DOMENA\k.nowak" -Action Grant -AccessRight Read
```

### Przykład 2: Nadanie uprawnień modyfikacji dla grupy lokalnej
```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "Projekty" -AccountName "EdytorzyProjektow" -Action Grant -AccessRight Change
```

### Przykład 3: Odebranie uprawnień z udziału i systemu plików
```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -Action Revoke
```

### Przykład 4: Symulacja zmian z parametrem `-WhatIf`
```powershell
.\Set-SmbShareAccessRule.ps1 -ShareName "Dane" -AccountName "DOMENA\b.kowalski" -Action Revoke -WhatIf
```