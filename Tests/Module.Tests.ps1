BeforeAll {
    $script:rootPath     = Split-Path $PSScriptRoot -Parent
    $script:manifestPath = Join-Path $script:rootPath "HyperV-LinuxLab.psd1"
}

Describe "Module Manifest and Health" {
    It "Passes Test-ModuleManifest" {
        $manifest = Test-ModuleManifest -Path $script:manifestPath
        $manifest | Should -Not -BeNullOrEmpty
        $manifest.Name | Should -Be "HyperV-LinuxLab"
    }

    It "Exports all 14 expected public cmdlets" {
        $manifest = Import-PowerShellDataFile -Path $script:manifestPath
        $expectedCmdlets = @(
            'Checkpoint-LabVM',
            'Get-LabBaseImage',
            'Get-LabCheckpoint',
            'Get-LabVM',
            'New-LabBaseImage',
            'New-LabCloudInitISO',
            'New-LabVM',
            'Remove-LabCheckpoint',
            'Remove-LabVM',
            'Reset-LabVM',
            'Restore-LabVM',
            'Start-LabVM',
            'Stop-LabVM',
            'Test-LabPrerequisites'
        )

        foreach ($cmdlet in $expectedCmdlets) {
            $manifest.FunctionsToExport | Should -Contain $cmdlet
        }
    }

    It "Passes PSScriptAnalyzer with zero errors or warnings on module code" {
        $moduleDirs = @(
            (Join-Path $script:rootPath "Public"),
            (Join-Path $script:rootPath "Private")
        )
        $issues = @()
        foreach ($dir in $moduleDirs) {
            $issues += Invoke-ScriptAnalyzer -Path $dir -Recurse -Severity Error,Warning
        }
        $issues.Count | Should -Be 0
    }
}
