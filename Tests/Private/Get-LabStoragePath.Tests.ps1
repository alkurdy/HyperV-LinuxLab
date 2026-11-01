BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Get-LabStoragePath" {
    It "Returns explicit path when specified" {
        $p = & (Get-Module HyperV-LinuxLab) { Get-LabStoragePath -ExplicitPath "D:\CustomLab" }
        $p | Should -Be "D:\CustomLab"
    }

    It "Returns default path or persistent config path when omitted" {
        $p = & (Get-Module HyperV-LinuxLab) { Get-LabStoragePath }
        $p | Should -Not -BeNullOrEmpty
    }
}
