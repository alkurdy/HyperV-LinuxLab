BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Assert-Administrator" {
    It "Does not throw when process is elevated" {
        # Running in an elevated session
        { & (Get-Module HyperV-LinuxLab) { Assert-Administrator } } | Should -Not -Throw
    }
}
