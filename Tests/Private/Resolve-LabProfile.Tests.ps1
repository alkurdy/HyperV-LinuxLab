BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Resolve-LabProfile" {
    It "Returns default custom profile when profile name is omitted" {
        $p = & (Get-Module HyperV-LinuxLab) { Resolve-LabProfile }
        $p.Name | Should -Be "Custom"
        $p.Packages | Should -BeNullOrEmpty
    }

    It "Resolves built-in profile by name" {
        $p = & (Get-Module HyperV-LinuxLab) { Resolve-LabProfile -Profile "Minimal" }
        $p.Name | Should -Be "Minimal"
        $p.Packages | Should -Contain "curl"
    }

    It "Resolves custom profile from valid JSON file path" {
        $jsonFile = Join-Path $TestDrive "my-custom-profile.json"
        @{
            Name        = "CustomDev"
            Description = "Custom environment"
            Packages    = @("neovim", "zsh")
            RunCommands = @("echo ready")
        } | ConvertTo-Json | Set-Content -Path $jsonFile

        $p = & (Get-Module HyperV-LinuxLab) { param($f) Resolve-LabProfile -Profile $f } $jsonFile
        $p.Name | Should -Be "CustomDev"
        $p.Packages | Should -Contain "neovim"
    }

    It "Throws actionable error when profile JSON file is corrupted" {
        $corruptFile = Join-Path $TestDrive "corrupt-profile.json"
        Set-Content -Path $corruptFile -Value "{ invalid json [,,] }"

        { & (Get-Module HyperV-LinuxLab) { param($f) Resolve-LabProfile -Profile $f } $corruptFile } |
            Should -Throw -ExpectedMessage "*Failed to parse profile JSON file*"
    }

    It "Throws helpful error with available profiles when profile is not found" {
        { & (Get-Module HyperV-LinuxLab) { Resolve-LabProfile -Profile "NonExistentProfileXYZ" } } |
            Should -Throw -ExpectedMessage "*Available built-in profiles*"
    }
}
