<#
.SYNOPSIS
    Displays a graphical warning message to the user.
.DESCRIPTION
    The script generates a pop-up warning window with a red background. 
    It uses Windows Forms and DWM API for full native styling.
.NOTES
    Author: Roman Pindela
    Email: roman.pindela@gmail.com
    GitHub: https://github.com/romanpindela
    Version: 1.0.0
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$Message = "Please contact the administrator.`n`nRoman Pindela.",

    [Parameter(Mandatory=$false)]
    [string]$Title = "WARNING",

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

function Show-ScriptHelp {
    Write-Host "`n=== SCRIPT: Show-Alert ===" -ForegroundColor Cyan
    Write-Host "Description: Displays a warning message (Windows Forms) in the operating system."
    Write-Host "Author: Roman Pindela (roman.pindela@gmail.com) | https://github.com/romanpindela"
    Write-Host "Version: 1.0.0"
    Write-Host "`nUsage Examples:"
    Write-Host "  .\show-alert.ps1"
    Write-Host "  .\show-alert.ps1 -Message 'A system error occurred. Please log out.' -Title 'FAILURE'"
    Write-Host "  .\show-alert.ps1 -h`n"
}

if ($ShowHelp) {
    Show-ScriptHelp
    exit
}

try {
    Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, System.Drawing

    # Create the form (window)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(500,250)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::Red
    $form.ForeColor = [System.Drawing.Color]::White
    $form.FormBorderStyle = "FixedDialog" 
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # Block closing via Alt+F4 (requires using the button)
    $script:allowClose = $false
    $form.add_FormClosing({
        if (-not $script:allowClose) {
            $_.Cancel = $true
        }
    })

    # Prevent focus loss (disables clicking on the taskbar and other applications)
    $form.add_Deactivate({
        if (-not $script:allowClose) {
            $form.BringToFront(); $form.Focus()
        }
    })

    $form.ControlBox = $false # Hides the system X in the corner of the window, forcing the user to click "Close"
    $form.TopMost = $true

    # Force a red title bar (DWM API for Windows 10/11)
    if (-not ("DwmWatermark" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DwmWatermark {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@ -ErrorAction Stop
    }

    # Global keyboard hook
    if (-not ("BlockKeys" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
public class BlockKeys {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT {
        public uint vkCode; public uint scanCode; public uint flags; public uint time; public IntPtr dwExtraInfo;
    }

    public static void SetHook() {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            _hookID = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }
    public static void RemoveHook() { UnhookWindowsHookEx(_hookID); }
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            KBDLLHOOKSTRUCT objKeyInfo = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            bool alt = (objKeyInfo.flags & 32) == 32;
            bool ctrl = (GetAsyncKeyState(0x11) & 0x8000) != 0;
            if (objKeyInfo.vkCode == 0x5B || objKeyInfo.vkCode == 0x5C) return (IntPtr)1; // Windows Key (LWin, RWin)
            if (alt && (objKeyInfo.vkCode == 0x09 || objKeyInfo.vkCode == 0x1B || objKeyInfo.vkCode == 0x73)) return (IntPtr)1; // Alt+Tab, Alt+Esc, Alt+F4
            if (ctrl && objKeyInfo.vkCode == 0x1B) return (IntPtr)1; // Ctrl+Esc
            if (objKeyInfo.vkCode == 0x70) return (IntPtr)1; // F1
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }
}
"@ -ErrorAction Stop
    }

    $form.add_HandleCreated({
        $color = 0x0000FF # BGR format (Red)
        [DwmWatermark]::DwmSetWindowAttribute($this.Handle, 35, [ref]$color, 4) 
    })

    # Create a text label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.Location = New-Object System.Drawing.Point(20,20) 
    $label.Size = New-Object System.Drawing.Size(440,110)
    $label.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    # Create the "Close" button
    $button = New-Object System.Windows.Forms.Button
    $button.Text = "Close"
    $button.Size = New-Object System.Drawing.Size(120,40)
    $button.Location = New-Object System.Drawing.Point(180,150)
    $button.BackColor = [System.Drawing.Color]::White
    $button.ForeColor = [System.Drawing.Color]::Black
    $button.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.add_Click({ $script:allowClose = $true; $form.Close() })

    # Add controls to the window
    $form.Controls.Add($label)
    $form.Controls.Add($button)

    # Activate global keyboard block (Hook)
    [BlockKeys]::SetHook()

    # Display the window on the screen with a background
    $overlay = New-Object System.Windows.Forms.Form
    $overlay.FormBorderStyle = "None"
    $overlay.BackColor = "Black"
    $overlay.Opacity = 0.7
    $overlay.ShowInTaskbar = $false
    $overlay.StartPosition = "Manual"
    $overlay.Bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $overlay.TopMost = $true
    $overlay.add_Click({ [System.Media.SystemSounds]::Beep.Play() })
    
    $overlay.add_FormClosing({
        if (-not $script:allowClose) {
            $_.Cancel = $true
        }
    })
    
    # Force focus for the black background as well
    $overlay.add_Deactivate({
        if (-not $script:allowClose) {
            $overlay.BringToFront(); $form.BringToFront(); $form.Focus()
        }
    })

    $overlay.Show()
    
    $form.ShowDialog($overlay) | Out-Null
    $script:allowClose = $true
    $overlay.Close()

    # Deactivate keyboard block after proper closure
    [BlockKeys]::RemoveHook()

} catch {
    Write-Error "Error while displaying the message. Details: $($_.Exception.Message)"
    # Emergency removal of the block in case of C# code crash
    try { [BlockKeys]::RemoveHook() } catch {}
}