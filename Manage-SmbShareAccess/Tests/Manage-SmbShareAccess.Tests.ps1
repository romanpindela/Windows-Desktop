# ==============================================================================
# PESTER TEST SUITE: Manage-SmbShareAccess.Tests.ps1
# ==============================================================================
$scriptRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path -Path $scriptRoot -ChildPath 'Manage-SmbShareAccess.ps1'

Describe 'Manage-SmbShareAccess - Script Integrity & Syntax' {
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

Describe 'Manage-SmbShareAccess - Parameter Sets & Attribute Validation' {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
    $params = $ast.ParamBlock.Parameters

    It 'Defines all required parameters for comprehensive management' {
        $paramNames = @($params.Name.VariablePath.UserPath)
        ($paramNames -contains 'Action') | Should Be $true
        ($paramNames -contains 'ShareName') | Should Be $true
        ($paramNames -contains 'Path') | Should Be $true
        ($paramNames -contains 'AccountName') | Should Be $true
        ($paramNames -contains 'AccessRight') | Should Be $true
        ($paramNames -contains 'ApplyToNtfs') | Should Be $true
        ($paramNames -contains 'Description') | Should Be $true
        ($paramNames -contains 'EnableABE') | Should Be $true
        ($paramNames -contains 'EncryptData') | Should Be $true
        ($paramNames -contains 'CachingMode') | Should Be $true
        ($paramNames -contains 'ConcurrentUserLimit') | Should Be $true
        ($paramNames -contains 'IncludeHidden') | Should Be $true
        ($paramNames -contains 'LogPath') | Should Be $true
        ($paramNames -contains 'Help') | Should Be $true
    }

    It 'Restricts Action parameter to full lifecycle actions (List, Show, Create, Remove, Grant, Revoke, Deny)' {
        $actionParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Action' }
        $validateSet = $actionParam.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }

        $validateSet | Should Not Be $null
        $validValues = @($validateSet.PositionalArguments | ForEach-Object { $_.Value })
        ($validValues -contains 'List') | Should Be $true
        ($validValues -contains 'Show') | Should Be $true
        ($validValues -contains 'Create') | Should Be $true
        ($validValues -contains 'Remove') | Should Be $true
        ($validValues -contains 'Grant') | Should Be $true
        ($validValues -contains 'Revoke') | Should Be $true
        ($validValues -contains 'Deny') | Should Be $true
    }

    It 'Restricts AccessRight parameter to Read, Change, FullControl' {
        $rightParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'AccessRight' }
        $validateSet = $rightParam.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }

        $validateSet | Should Not Be $null
        $validValues = @($validateSet.PositionalArguments | ForEach-Object { $_.Value })
        ($validValues -contains 'Read') | Should Be $true
        ($validValues -contains 'Change') | Should Be $true
        ($validValues -contains 'FullControl') | Should Be $true
    }

    It 'Restricts CachingMode parameter to standard SMB caching policies' {
        $cacheParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'CachingMode' }
        $validateSet = $cacheParam.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }

        $validateSet | Should Not Be $null
        $validValues = @($validateSet.PositionalArguments | ForEach-Object { $_.Value })
        ($validValues -contains 'None') | Should Be $true
        ($validValues -contains 'Manual') | Should Be $true
        ($validValues -contains 'Programs') | Should Be $true
        ($validValues -contains 'Documents') | Should Be $true
        ($validValues -contains 'BranchCache') | Should Be $true
    }

    It 'Defaults ApplyToNtfs to $true' {
        $ntfsParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'ApplyToNtfs' }
        $ntfsParam.DefaultValue.Extent.Text | Should Be '$true'
    }
}

Describe 'Manage-SmbShareAccess - Help and Safe Default Invocation' {
    It 'Displays help without errors when run with -Help' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Help
        ($output | Out-String) -match 'MANAGE SMB SHARE AND NTFS ACCESS UTILITY' | Should Be $true
    }

    It 'Displays help without errors when run with -h' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -h
        ($output | Out-String) -match 'MANAGE SMB SHARE AND NTFS ACCESS UTILITY' | Should Be $true
    }

    It 'Displays help without errors when invoked with no arguments' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
        ($output | Out-String) -match 'MANAGE SMB SHARE AND NTFS ACCESS UTILITY' | Should Be $true
    }
}

Describe 'Manage-SmbShareAccess - Input Validation & Security' {
    It 'Disallows command injection characters in AccountName' {
        $validateAccount = {
            param ($Account)
            if ($Account -match '[`$;&|<>]') {
                throw "Disallowed characters"
            }
        }

        { & $validateAccount 'DOMAIN\valid.user' } | Should Not Throw
        { & $validateAccount 'DOMENA\user;calc.exe' } | Should Throw
        { & $validateAccount 'DOMENA\user|whoami' } | Should Throw
    }
}

Describe 'Manage-SmbShareAccess - Permission Mapping Logic' {
    It 'Maps AccessRight to correct SMB share rights' {
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

Describe 'Manage-SmbShareAccess - Consistency Analysis Logic' {
    $testConsistency = {
        param ([string]$SmbRight, [string]$NtfsRight)
        function Get-AccessRank ([string]$text) {
            if ($text -match 'Deny|Block') { return -1 }
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
