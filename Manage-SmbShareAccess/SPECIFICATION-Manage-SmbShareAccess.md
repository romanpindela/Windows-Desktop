# Specyfikacja Techniczna: manage-smb-share-access

## 1. Metadane i Lokalizacja

* **Repozytorium:** `Windows-Desktop`
* **Ścieżka bazowa repozytorium:** `c:\GitHub\Windows Desktop\`
* **Katalog projektu:** `Manage-SmbShareAccess\`
* **Główny plik skryptu:** `manage-smb-share-access.ps1`
* **Wersja:** `2.0.0`
* **Typ operacji:** Kompleksowe zarządzanie cyklem życia zasobów sieciowych SMB, konfiguracją zaawansowaną oraz uprawnieniami zasobów i systemu plików (NTFS / ACL).

---

## 2. Cel i Zakres Funkcjonalny

Skrypt stanowi kompleksowe narzędzie administracyjne do obsługi współdzielonych folderów i zasobów sieciowych w systemie Windows. Integruje pełny cykl życia zasobu oraz spójne zarządzanie uprawnieniami na dwóch poziomach:
1. **Uprawnienia udziału SMB (Share Permissions):** Zarządzane przez moduł `SmbShare` (`Grant-SmbShareAccess`, `Revoke-SmbShareAccess`, `Block-SmbShareAccess`, `Get-SmbShareAccess`).
2. **Uprawnienia systemu plików (NTFS Permissions / ACL):** Zarządzane na poziomie katalogu wskazanego przez udział za pomocą mechanizmów .NET (`System.Security.AccessControl.DirectorySecurity`, `FileSystemAccessRule`).

### Główne możliwości:
* **Inwentaryzacja i listowanie zasobów (`-Action List`):** Enumerate shares, obsługa udziałów ukrytych (`-IncludeHidden`), ścieżki, status ABE i szyfrowania.
* **Audyt i inspekcja uprawnień (`-Action Show`):** Prezentacja uprawnień SMB, uprawnień katalogu NTFS oraz matrycy analizy spójności (Consistency Check).
* **Tworzenie i włączanie zasobów (`-Action Create`):** Zakładanie udziału na istniejącym lub nowo tworzonym katalogu, obsługa Access-Based Enumeration (`-EnableABE`), szyfrowania SMB 3.0+ (`-EncryptData`), trybów pamięci podręcznej (`-CachingMode`) oraz limitu połączeń.
* **Wyłączanie i usuwanie udostępniania (`-Action Remove`):** Bezpieczne usuwanie udziału SMB z zachowaniem nienaruszonego katalogu fizycznego na dysku.
* **Zarządzanie uprawnieniami (`-Action Grant`, `Revoke`, `Deny`):** Dodawanie, odbieranie i blokowanie tożsamości z synchronizacją z NTFS (`-ApplyToNtfs`).
* **Weryfikacja spójności:** Wykrywanie wąskich gardeł (np. SMB FullControl vs NTFS Read).
* **Obsługa symulacji zmian (`-WhatIf` / `-Confirm`):** Wsparcie dla `SupportsShouldProcess`.
* **Wielojęzyczność:** Pełne wsparcie dla polskich i angielskich wersji Windows (SID-based checks).

---

## 3. Wymagania Systemowe i Uprawnienia

* **System operacyjny:** Windows 10 / Windows 11 (edycje Pro, Enterprise, Education) lub Windows Server 2019+.
* **Wersja PowerShell:** Windows PowerShell 5.1 lub PowerShell 7+.
* **Wymagane moduły:**
  * `SmbShare` (wbudowany w Windows).
  * `Microsoft.PowerShell.Security`.
* **Uprawnienia:** Wymagane uprawnienia administratora lokalnego (weryfikacja SID `BuiltInAdministratorsSid` z automatyczną elewacją UAC).

---

## 4. Parametry Wejściowe Skryptu

| Parametr | Typ | Wymagany dla akcji | Domyślna wartość | Opis |
| :--- | :--- | :--- | :---: | :--- |
| `-Action` | `[string]` | **Wszystkie** | — | `List`, `Show`, `Create`, `Remove`, `Grant`, `Revoke`, `Deny`. |
| `-ShareName` | `[string]` | `Show`, `Create`, `Remove`, `Grant`, `Revoke`, `Deny` | — | Nazwa udziału sieciowego SMB. |
| `-Path` | `[string]` | `Create` | — | Fizyczna ścieżka do katalogu na dysku. |
| `-AccountName` | `[string[]]` | `Grant`, `Revoke`, `Deny` | — | Nazwa użytkownika lub grupy (np. `DOMENA\user`, `BUILTIN\Users`). |
| `-AccessRight` | `[string]` | `Grant`, `Deny` | `Read` | Poziom uprawnień: `Read`, `Change`, `FullControl`. |
| `-ApplyToNtfs` | `[switch]` | `Grant`, `Revoke`, `Deny` | `$true` | Czy synchronizować uprawnienia z systemem plików NTFS. |
| `-Description` | `[string]` | `Create` | — | Opis / komentarz dla udziału. |
| `-EnableABE` | `[switch]` | `Create` | `$false` | Włączenie Access-Based Enumeration. |
| `-EncryptData` | `[switch]` | `Create` | `$false` | Wymuszenie szyfrowania danych SMB. |
| `-CachingMode` | `[string]` | `Create` | `Manual` | Tryb pamięci podręcznej (`None`, `Manual`, `Programs`, `Documents`, `BranchCache`). |
| `-ConcurrentUserLimit` | `[int]` | `Create` | `0` | Limit jednoczesnych połączeń (0 = bez limitu). |
| `-IncludeHidden` | `[switch]` | `List` | `$false` | Uwzględnienie zasobów administracyjnych/ukrytych (`$`). |
| `-LogPath` | `[string]` | Wszystkie | `C:\Logs\` | Ścieżka docelowa dla plików logów. |
| `-WhatIf` | `[switch]` | Modyfikacje | — | Standardowy przełącznik symulacji akcji. |
| `-Confirm` | `[switch]` | Modyfikacje | — | Monit o potwierdzenie krytycznych zmian. |

---

## 5. Mapowanie Uprawnień (SMB vs NTFS)

| Poziom (`-AccessRight`) | SMB AccessRight | NTFS FileSystemRights | Dziedziczenie NTFS |
| :--- | :--- | :--- | :--- |
| `Read` | `Read` | `ReadAndExecute, Synchronize` | `ContainerInherit, ObjectInherit` |
| `Change` | `Change` | `Modify, Synchronize` | `ContainerInherit, ObjectInherit` |
| `FullControl` | `Full` | `FullControl` | `ContainerInherit, ObjectInherit` |

---

## 6. Struktura Katalogów i Plików

```plaintext
c:\GitHub\Windows Desktop\Manage-SmbShareAccess\
│
├── SPECIFICATION-Manage-SmbShareAccess.md   # Niniejsza specyfikacja
├── manage-smb-share-access.ps1              # Główny skrypt wykonawczy
├── README.md                                # Instrukcja wdrożenia i przykłady użycia
└── Tests\
    └── manage-smb-share-access.Tests.ps1    # Testy Pester (weryfikacja składni, parametrów, mapowań)
```
