BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Lab Configuration and Multi-Volume Support" {
    It "Returns active configuration with Get-LabConfiguration" {
        $cfg = Get-LabConfiguration
        $cfg | Should -Not -BeNullOrEmpty
        $cfg.StoragePath | Should -Not -BeNullOrEmpty
        $cfg.BaseImagePath | Should -Match "BaseImages"
        $cfg.LabVMPath | Should -Match "LabVMs"
        $cfg.CloudInitPath | Should -Match "CloudInit"
    }

    It "Discovers multiple storage volumes in Test-LabPrerequisites" {
        $prereqs = Test-LabPrerequisites -Detailed
        $prereqs | Should -Not -BeNullOrEmpty
        $prereqs.PSObject.Properties.Name | Should -Contain "DiscoveredVolumes"
        $prereqs.PSObject.Properties.Name | Should -Contain "RecommendedDrive"
        $prereqs.PSObject.Properties.Name | Should -Contain "TargetStoragePath"
        $prereqs.DiscoveredVolumes.Count | Should -BeGreaterThan 0
    }

    Context "Storage Scream Test" {
        It "Passes when free space is sufficient" {
            InModuleScope 'HyperV-LinuxLab' {
                $passed = Assert-LabDiskSpace -Path "C:\HyperV-LinuxLab" -RequiredGB 1.0
                $passed | Should -BeTrue
            }
        }

        It "Triggers scream test and throws when free space is insufficient" {
            InModuleScope 'HyperV-LinuxLab' {
                { Assert-LabDiskSpace -Path "C:\HyperV-LinuxLab" -RequiredGB 999999.0 } |
                    Should -Throw "*storage scream test*"
            }
        }

        It "Does not throw when -Force is passed even if deficit exists" {
            InModuleScope 'HyperV-LinuxLab' {
                $result = Assert-LabDiskSpace -Path "C:\HyperV-LinuxLab" -RequiredGB 999999.0 -Force
                $result | Should -BeFalse
            }
        }
    }
}
