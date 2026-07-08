<#
.SYNOPSIS
    Skrypt resetujący ustawienia klawiatury w Windows 11 do standardu Polski (Programisty)
    oraz wyłączający funkcje ułatwień dostępu (Klawisze trwałe itp.).
#>

Write-Host "Rozpoczynanie naprawy i przywracania domyślnych ustawień klawiatury..." -ForegroundColor Cyan

# 1. Ustawienie układu klawiatury na Polski (Programisty) jako jedyny/główny
Write-Host "-> Ustawianie układu klawiatury: Polski (programisty)..." -ForegroundColor Green
$LanguageList = New-WinUserLanguageList -Language "pl-PL"
$LanguageList[0].InputMethodTips.Clear()
$LanguageList[0].InputMethodTips.Add('0415:00000415') # Kod dla układu Polski (programisty)
Set-WinUserLanguageList -LanguageList $LanguageList -Force

# 2. Wyłączenie Klawiszy Trwałych (Sticky Keys) w rejestrze
Write-Host "-> Wyłączanie Klawiszy Trwałych i skrótów aktywujących..." -ForegroundColor Green
$AccessibilityPath = "HKCU:\Control Panel\Accessibility"

# Flags: 506 wyłącza Klawisze trwałe oraz zapobiega ich włączeniu przez 5-krotne wciśnięcie Shift
Set-ItemProperty -Path "$AccessibilityPath\StickyKeys" -Name "Flags" -Value "506"

# 3. Wyłączenie Klawiszy Filtrujących (Filter Keys) i Klawiszy Przełączających (Toggle Keys)
Write-Host "-> Wyłączanie Klawiszy Filtrujących i Przełączających..." -ForegroundColor Green
Set-ItemProperty -Path "$AccessibilityPath\Keyboard Response" -Name "Flags" -Value "122"
Set-ItemProperty -Path "$AccessibilityPath\ToggleKeys" -Name "Flags" -Value "58"

# 4. Przywrócenie domyślnej prędkości i opóźnienia powtarzania klawiszy
Write-Host "-> Przywracanie domyślnej prędkości wpisywania..." -ForegroundColor Green
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "KeyboardDelay" -Value "1"     # Standardowe opóźnienie
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "KeyboardSpeed" -Value "31"    # Maksymalna standardowa prędkość

# 5. Restart procesu Explorer w celu natychmiastowego zastosowania części ustawień
Write-Host "-> Odświeżanie interfejsu systemowego..." -ForegroundColor Green
Stop-Process -Name explorer -Force

Write-Host "`n[SUKCES] Ustawienia zostały przywrócone do normy!" -ForegroundColor Yellow
Write-Host "Zaleca się ponowne uruchomienie komputera (Restart), aby wszystkie zmiany w rejestrze weszły w życie." -ForegroundColor Cyan