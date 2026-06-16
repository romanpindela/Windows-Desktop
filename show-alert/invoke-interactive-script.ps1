<#
.SYNOPSIS
    Executes a local PowerShell script interactively on a remote machine's desktop.
.DESCRIPTION
    Bypasses Windows Session 0 isolation (WinRM restriction) by dynamically
    copying the script to the remote machine and triggering it via a temporary 
    Scheduled Task in the context of the currently logged-on user.
.PARAMETER ComputerName
    The target remote computer hostname or IP address.
.PARAMETER ScriptPath
    The path to the local .ps1 script file that you want to execute interactively.
.PARAMETER Credential
    Optional PSCredential object. If not provided, you will be prompted.
.PARAMETER ArgumentList
    Optional array of arguments to pass to the remote script.
.NOTES
    Author: Roman Pindela
    Version: 1.0.1
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$ComputerName,

    [Parameter(Mandatory=$false)]
    [string]$ScriptPath,

    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory=$false)]
    [object[]]$ArgumentList,

    [Alias("h", "Help")]
    [switch]$ShowHelp
)

$ScriptVersion = "1.0.1"

function Show-Help {
    Write-Host ""
    Write-Host "INVOKE-INTERACTIVESCRIPT v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Execute local .ps1 scripts interactively on a remote desktop"
    Write-Host ""
    Write-Host "DESCRIPTION"
    Write-Host "    Bypasses Windows Session 0 isolation by copying the script to the"
    Write-Host "    remote machine and triggering it via a temporary Scheduled Task"
    Write-Host "    assigned to the built-in Users group. This ensures the GUI is"
    Write-Host "    displayed to the currently active user."
    Write-Host ""
    Write-Host "USAGE"
    Write-Host "    .\invoke-interactive-script.ps1 -ComputerName <String> -ScriptPath <String>"
    Write-Host ""
    Write-Host "PARAMETERS"
    Write-Host "    -ComputerName  Hostname or IP address of the target computer."
    Write-Host "    -ScriptPath    Path to the local .ps1 script to execute interactively."
    Write-Host "    -Credential    Optional pre-defined network credentials."
    Write-Host "    -ArgumentList  Optional array of arguments to pass to the remote script."
    Write-Host "    -h, -Help      Display this structured help screen."
    Write-Host ""
    Write-Host "EXAMPLES"
    Write-Host "    .\invoke-interactive-script.ps1 -ComputerName '10.10.1.96' -ScriptPath '.\show-alert.ps1' -ArgumentList '-Message `"Hello`"'"
    Write-Host ""
}

if ($ShowHelp -or [string]::IsNullOrWhiteSpace($ComputerName) -or [string]::IsNullOrWhiteSpace($ScriptPath)) {
    Show-Help
    exit
}

if (-not (Test-Path -Path $ScriptPath -PathType Leaf)) {
    Write-Error "Error: The local script file '$ScriptPath' was not found."
    exit
}

try {
    Write-Host ""
    Write-Host "Invoke-InteractiveScript v$ScriptVersion" -ForegroundColor Green
    Write-Host "Target: $ComputerName"
    
    if (-not $Credential) { 
        $Credential = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message "Enter credentials for $ComputerName" 
    }

    # 1. Read local script
    Write-Host "Reading local script content..." -ForegroundColor Yellow
    $ScriptContent = Get-Content -Path $ScriptPath -Raw
    
    # Convert array of arguments to a single string for powershell.exe arguments
    $ArgsString = ""
    if ($ArgumentList) {
        $ArgsString = $ArgumentList -join " "
    }

    Write-Host "Deploying interactive payload via Scheduled Tasks..." -ForegroundColor Yellow

    # 2. Remote Execution Block
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop -ArgumentList $ScriptContent, $ArgsString -ScriptBlock {
        param($ScriptCode, $ArgsStr)
        
        # Check who is currently looking at the screen
        $LoggedOnUser = (Get-CimInstance Win32_ComputerSystem).UserName
        
        if ([string]::IsNullOrWhiteSpace($LoggedOnUser)) {
            throw "No user is currently logged on to the interactive session. Cannot display GUI."
        }

        Write-Host "  > Interactive session found for user: $LoggedOnUser" -ForegroundColor Cyan

        # Save script to a public temp location so the logged-on user can read it
        $TempFile = Join-Path $env:PUBLIC "interactive_payload_$(Get-Random).ps1"
        Set-Content -Path $TempFile -Value $ScriptCode -Force

        # Build the exact command to run and encode it to bypass Task Scheduler quote stripping
        $CommandToRun = "& `"$TempFile`" $ArgsStr"
        $EncodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($CommandToRun))

        # Configure the scheduled task
        $TaskName = "InteractiveDeploy_$(Get-Random)"
        $PSArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $EncodedCommand"
        
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $PSArgs
        
        # Rozwiązanie zlokalizowanej nazwy grupy 'Użytkownicy' za pomocą SID (S-1-5-32-545)
        # Pozwala to na uruchomienie zadania na pulpicie bez znajomości hasła zalogowanego użytkownika
        $UsersGroup = (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')).Translate([System.Security.Principal.NTAccount]).Value
        $Principal = New-ScheduledTaskPrincipal -GroupId $UsersGroup
        
        Write-Host "  > Registering and triggering temporary task..." -ForegroundColor DarkGray
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Principal $Principal -Force | Out-Null
        
        Start-ScheduledTask -TaskName $TaskName
        
        Write-Host "  > Waiting for the user to close the window..." -ForegroundColor Cyan
        
        # Wait until the task finishes (user clicks Close)
        while ((Get-ScheduledTask -TaskName $TaskName).State -eq 'Running') {
            Start-Sleep -Seconds 2
        }
        
        Write-Host "  > Cleaning up task..." -ForegroundColor DarkGray
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        
        Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
        
        Write-Host "Successfully projected GUI to $LoggedOnUser's desktop!" -ForegroundColor Green
    }

} catch {
    Write-Error "Execution failed. Reason: $($_.Exception.Message)"
}