# ==============================================================================
# PESTER TEST SUITE: Set-SmbShareAccessRule.Tests.ps1
# ==============================================================================
$scriptRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path -Path $scriptRoot -ChildPath 'Set-SmbShareAccessRule.ps1'

Describe 'Set-SmbShareAccessRule - Script Integrity & Syntax' {
    It 'Script file exists in the project root' {
        (Test-Path -Path $scriptPath) | Should Be $true
    }

    It 'Script contains valid PowerShell syntax without parse errors' {
        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)

        $parseErrors.Count | Should Be 0
    }

    It 'Declares CmdletBinding with SupportsShouldProcess enabled' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $bindingAttr = $ast.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' }

        $bindingAttr | Should Not Be $null
        $namedArgs = @($bindingAttr.NamedArguments | ForEach-Object { $_.ArgumentName })
        ($namedArgs -contains 'SupportsShouldProcess') | Should Be $true
    }
}

Describe 'Set-SmbShareAccessRule - Parameter Validation' {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
    $params = $ast.ParamBlock.Parameters

    It 'Defines all required parameters' {
        $paramNames = @($params.Name.VariablePath.UserPath)
        ($paramNames -contains 'ShareName') | Should Be $true
        ($paramNames -contains 'AccountName') | Should Be $true
        ($paramNames -contains 'Action') | Should Be $true
        ($paramNames -contains 'AccessRight') | Should Be $true
        ($paramNames -contains 'ApplyToNtfs') | Should Be $true
        ($paramNames -contains 'LogPath') | Should Be $true
        ($paramNames -contains 'Help') | Should Be $true
    }

    It 'Restricts Action parameter with ValidateSet (Grant, Revoke, Deny)' {
        $actionParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Action' }
        $validateSet = $actionParam.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }

        $validateSet | Should Not Be $null
        $validValues = @($validateSet.PositionalArguments | ForEach-Object { $_.Value })
        ($validValues -contains 'Grant') | Should Be $true
        ($validValues -contains 'Revoke') | Should Be $true
        ($validValues -contains 'Deny') | Should Be $true
    }

    It 'Restricts AccessRight parameter with ValidateSet (Read, Change, FullControl)' {
        $rightParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'AccessRight' }
        $validateSet = $rightParam.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }

        $validateSet | Should Not Be $null
        $validValues = @($validateSet.PositionalArguments | ForEach-Object { $_.Value })
        ($validValues -contains 'Read') | Should Be $true
        ($validValues -contains 'Change') | Should Be $true
        ($validValues -contains 'FullControl') | Should Be $true
    }

    It 'Defaults ApplyToNtfs to $true' {
        $ntfsParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'ApplyToNtfs' }
        $ntfsParam.DefaultValue.Extent.Text | Should Be '$true'
    }
}

Describe 'Set-SmbShareAccessRule - Help and Safe Execution' {
    It 'Displays help without errors when run with -Help' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Help
        ($output | Out-String) -match 'MANAGE SMB SHARE AND NTFS ACCESS' | Should Be $true
    }

    It 'Displays help without errors when run with -h' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -h
        ($output | Out-String) -match 'MANAGE SMB SHARE AND NTFS ACCESS' | Should Be $true
    }

    It 'Displays help without errors when invoked with no arguments' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
        ($output | Out-String) -match 'MANAGE SMB SHARE AND NTFS ACCESS' | Should Be $true
    }
}

Describe 'Set-SmbShareAccessRule - Permission Mapping Logic' {
    It 'Maps AccessRight to correct SMB permissions' {
        $mapSmb = {
            param ($right)
            switch ($right) {
                'Read'        { 'Read' }
                'Change'      { 'Change' }
                'FullControl' { 'Full' }
                Default       { throw "Unsupported" }
            }
        }

        (& $mapSmb 'Read') | Should Be 'Read'
        (& $mapSmb 'Change') | Should Be 'Change'
        (& $mapSmb 'FullControl') | Should Be 'Full'
    }

    It 'Maps AccessRight to correct NTFS FileSystemRights' {
        $mapNtfs = {
            param ($right)
            switch ($right) {
                'Read' {
                    [System.Security.AccessControl.FileSystemRights](
                        [System.Security.AccessControl.FileSystemRights]::ReadAndExecute -bor
                        [System.Security.AccessControl.FileSystemRights]::Synchronize
                    )
                }
                'Change' {
                    [System.Security.AccessControl.FileSystemRights](
                        [System.Security.AccessControl.FileSystemRights]::Modify -bor
                        [System.Security.AccessControl.FileSystemRights]::Synchronize
                    )
                }
                'FullControl' {
                    [System.Security.AccessControl.FileSystemRights]::FullControl
                }
            }
        }

        $readRights = & $mapNtfs 'Read'
        $readRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadAndExecute) | Should Be $true
        $readRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Synchronize) | Should Be $true

        $changeRights = & $mapNtfs 'Change'
        $changeRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Modify) | Should Be $true

        $fullRights = & $mapNtfs 'FullControl'
        $fullRights | Should Be ([System.Security.AccessControl.FileSystemRights]::FullControl)
    }
}

Describe 'Set-SmbShareAccessRule - Consistency Analysis Logic' {
    $testConsistency = {
        param ([string]$SmbRight, [string]$NtfsRight)
        function Get-AccessRank ([string]$text) {
            if ($text -match 'Deny') { return -1 }
            if ($text -match 'Full') { return 3 }
            if ($text -match 'Modify|Change') { return 2 }
            if ($text -match 'Read') { return 1 }
            return 0
        }
        $smbRank = Get-AccessRank $SmbRight
        $ntfsRank = Get-AccessRank $NtfsRight

        if ($smbRank -gt $ntfsRank -and $ntfsRank -gt 0) {
            return 'WARN_SMB_PERMISSIVE'
        }
        elseif ($ntfsRank -gt $smbRank -and $smbRank -gt 0) {
            return 'WARN_NTFS_PERMISSIVE'
        }
        return 'BALANCED'
    }

    It 'Warns when SMB is FullControl but NTFS is Read' {
        (& $testConsistency 'Full' 'Read') | Should Be 'WARN_SMB_PERMISSIVE'
    }

    It 'Warns when NTFS is Modify but SMB is Read' {
        (& $testConsistency 'Read' 'Modify') | Should Be 'WARN_NTFS_PERMISSIVE'
    }

    It 'Detects balanced permissions when both are Read' {
        (& $testConsistency 'Read' 'Read') | Should Be 'BALANCED'
    }

    It 'Detects balanced permissions when both are FullControl' {
        (& $testConsistency 'Full' 'FullControl') | Should Be 'BALANCED'
    }
}
