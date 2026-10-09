<#
.SYNOPSIS
    Script resetting keyboard settings in Windows 11 to Polish (Programmers) layout
    and disabling accessibility ease-of-access shortcuts (Sticky Keys, etc.).
#>

Write-Host "Starting repair and restoration of default keyboard settings..." -ForegroundColor Cyan

# 1. Set keyboard layout to Polish (Programmers) as the primary/only layout
Write-Host "-> Setting keyboard layout: Polish (Programmers)..." -ForegroundColor Green
$LanguageList = New-WinUserLanguageList -Language "pl-PL"
$LanguageList[0].InputMethodTips.Clear()
$LanguageList[0].InputMethodTips.Add('0415:00000415') # Identifier for Polish (Programmers) layout
Set-WinUserLanguageList -LanguageList $LanguageList -Force

# 2. Disable Sticky Keys in the registry
Write-Host "-> Disabling Sticky Keys and activation shortcuts..." -ForegroundColor Green
$AccessibilityPath = "HKCU:\Control Panel\Accessibility"

# Flags: 506 disables Sticky Keys and prevents activation via 5x Shift keypress
Set-ItemProperty -Path "$AccessibilityPath\StickyKeys" -Name "Flags" -Value "506"

# 3. Disable Filter Keys and Toggle Keys
Write-Host "-> Disabling Filter Keys and Toggle Keys..." -ForegroundColor Green
Set-ItemProperty -Path "$AccessibilityPath\Keyboard Response" -Name "Flags" -Value "122"
Set-ItemProperty -Path "$AccessibilityPath\ToggleKeys" -Name "Flags" -Value "58"

# 4. Restore default keyboard repeat rate and delay
Write-Host "-> Restoring default typing rate and delay..." -ForegroundColor Green
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "KeyboardDelay" -Value "1"     # Standard delay
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "KeyboardSpeed" -Value "31"    # Maximum standard speed

# 5. Restart Explorer process to immediately apply UI changes
Write-Host "-> Refreshing system shell interface..." -ForegroundColor Green
Stop-Process -Name explorer -Force

Write-Host "`n[SUCCESS] Settings have been restored to default!" -ForegroundColor Yellow
Write-Host "A system restart is recommended for all registry changes to take full effect." -ForegroundColor Cyan