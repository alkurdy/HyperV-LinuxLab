BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Assert-LabDiskSpace" {
    It "Returns true when free disk space exceeds requirement" {
        $ok = & (Get-Module HyperV-LinuxLab) { Assert-LabDiskSpace -Path "C:\HyperV-LinuxLab" -RequiredGB 0.01 }
        $ok | Should -Be $true
    }

    It "Throws when disk space is insufficient and Force is omitted" {
        { & (Get-Module HyperV-LinuxLab) { Assert-LabDiskSpace -Path "C:\HyperV-LinuxLab" -RequiredGB 999999.0 } } |
            Should -Throw -ExpectedMessage "*insufficient space*"
    }

    It "Returns false without throwing when Force is passed" {
        $result = & (Get-Module HyperV-LinuxLab) { Assert-LabDiskSpace -Path "C:\HyperV-LinuxLab" -RequiredGB 999999.0 -Force }
        $result | Should -Be $false
    }
}
