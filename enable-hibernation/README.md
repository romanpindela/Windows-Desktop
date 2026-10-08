# enable-hibernation (Windows Power Management Configuration)
  
Dokumentacja techniczna skryptu automatyzującego zarządzanie podsystemem hibernacji oraz widocznością przycisku hibernacji w menu zasilania Start w systemach Windows.
  
## Informacje o projekcie
  
| Parametr | Wartość |
| :--- | :--- |
| **Nazwa projektu** | enable-hibernation (Windows Power Management Configuration) |
| **Autor** | Roman Pindela |
| **Kontakt** | roman.pindela@gmail.com |
| **Wersja** | 1.1.1 |
| **Data wydania** | 08.10.2026 |
| **Licencja** | MIT |
| **Repozytorium** | [GitHub - roman/enable-hibernation](https://github.com/roman/enable-hibernation) |
  
---
  
## Główne możliwości
  
* **Tryb interaktywnej pomocy przy starcie:** Uruchomienie skryptu bez parametrów lub z przełącznikiem `-h` / `-Help` natychmiast wyświetla informacje o wersji, autorze, składni oraz przykłady użycia.
* **Dwukierunkowe zarządzanie stanem:**
  * `-EnableHibernation`: tworzy plik `hiberfil.sys`, aktywuje mechanizm ACPI oraz dodaje przycisk do menu Start.
  * `-DisableHibernation`: usuwa plik `hiberfil.sys` (zwalniając gigabajty na dysku systemowym) oraz ukrywa przycisk w menu Start.
* **Pełna idempotencja:** Skrypt weryfikuje aktualną wartość `ShowHibernateOption` w rejestrze; jeśli żądany stan jest już ustawiony, modyfikacja jest bezpiecznie pomijana.
* **Zaawansowane logowanie do pliku tekstowego:** Każde wykonanie tworzy szczegółowy plik dziennika z dokładnymi znacznikami czasu `[RRRR-MM-DD GG:MM:SS]`.
  * Ścieżka domyślna: `C:\Logs\<DataIGodzina>-<Komputer>-<Użytkownik>-Enable-Hibernation.txt`.
  * Automatyczne tworzenie brakującego katalogu docelowego.
  * Możliwość zdefiniowania własnej ścieżki za pomocą parametru `-LogPath`.
* **Modyfikacja i audyt rejestru przez .NET Registry API:** Bezpośrednie operacje za pośrednictwem klasy `[Microsoft.Win32.RegistryKey]` na gałęzi `HKLM` (64-bit view) w ścieżce `SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings`.
* **Weryfikacja stanu końcowego:** Automatyczny audyt obecności pliku `hiberfil.sys` na dysku systemowym oraz poprawności flagi DWORD w rejestrze.
  
---
  
## Struktura katalogu
  
```shell
enable-hibernation/
├── assets/
│   ├── Standard_run.jpg          # Widok uruchomienia pomocy / standardowy
│   ├── enable_hibernation.jpg     # Zrzut ekranu z włączenia hibernacji
│   └── disable_hibernation.jpg    # Zrzut ekranu z wyłączenia hibernacji
├── enable-hibernation.ps1        # Główny skrypt konfiguracyjny PowerShell
└── README.md                     # Niniejsza dokumentacja techniczna
```
  
## Wymagania systemowe
  
- **System operacyjny:** Windows 10 / Windows 11 (architektura 64-bit).
- **Uprawnienia:** Konsola PowerShell uruchomiona z uprawnieniami Administratora (niezbędna do manipulacji plikiem `hiberfil.sys` oraz gałęzią HKLM).
  
## Instrukcja uruchomienia
  
### 1. Zezwolenie na wykonywanie skryptów (jeśli jest zablokowane)
```shell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
  
### 2. Wyświetlenie menu pomocy i danych autora
```shell
.\enable-hibernation.ps1
# (lub: .\enable-hibernation.ps1 -h)
```
  
### 3. Włączenie hibernacji i dodanie do menu Start
```shell
.\enable-hibernation.ps1 -EnableHibernation
# (lub: .\enable-hibernation.ps1 -e)
```
  
### 4. Wyłączenie hibernacji i zwolnienie miejsca na dysku
```shell
.\enable-hibernation.ps1 -DisableHibernation
# (lub: .\enable-hibernation.ps1 -d)
```
  
### 5. Uruchomienie z własną ścieżką do logu
```shell
.\enable-hibernation.ps1 -EnableHibernation -LogPath "C:\Deploy\hibernation.txt"
```
  
## Screenshots
  
### Standard Run / Pomoc
![Standard Run / Pomoc](assets/Standard_run.jpg)
  
### Włączenie hibernacji (-EnableHibernation)
![Włączenie hibernacji](assets/enable_hibernation.jpg)
  
### Wyłączenie hibernacji (-DisableHibernation)
![Wyłączenie hibernacji](assets/disable_hibernation.jpg)
  
## Kody zakończenia i diagnostyka
  
| Kod błędu / Status | Znaczenie techniczne | Działanie skryptu |
| :--- | :--- | :--- |
| **0** | Sukces wykonania | Zadana operacja (włączenie/wyłączenie) zakończona powodzeniem. |
| **Brak uprawnień admina** | Uruchomienie bez podwyższonych uprawnień UAC | Rzucenie wyjątku i natychmiastowe zatrzymanie wykonania (throw). |
| **Błąd powercfg** | Kod zakończenia powercfg.exe inny niż 0 | Odnotowanie ostrzeżenia w konsoli i pliku logu. |
  
## Kontakt i wsparcie
  
W razie problemów z wdrożeniem lub pytań technicznych:
- **Autor:** Roman Pindela
- **Adres e-mail:** roman.pindela@gmail.com
- **Licencja:** MIT License