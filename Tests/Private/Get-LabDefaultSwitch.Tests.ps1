BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Get-LabDefaultSwitch" {
    It "Returns preferred switch if found" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMSwitch' -MockWith {
            param($Name)
            if ($Name -eq 'CustomSwitch') {
                return [PSCustomObject]@{ Name = 'CustomSwitch' }
            }
            return $null
        }

        $sw = & (Get-Module HyperV-LinuxLab) { Get-LabDefaultSwitch -PreferredSwitch "CustomSwitch" }
        $sw | Should -Be "CustomSwitch"
    }

    It "Throws when specified preferred switch does not exist" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMSwitch' -MockWith { return $null }

        { & (Get-Module HyperV-LinuxLab) { Get-LabDefaultSwitch -PreferredSwitch "NonExistentSwitch" } } |
            Should -Throw -ExpectedMessage "*was not found on this host*"
    }

    It "Resolves Default Switch when no preference specified" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMSwitch' -MockWith {
            param($Name)
            if ($Name -eq 'Default Switch') {
                return [PSCustomObject]@{ Name = 'Default Switch' }
            }
            return $null
        }

        $sw = & (Get-Module HyperV-LinuxLab) { Get-LabDefaultSwitch }
        $sw | Should -Be "Default Switch"
    }
}
