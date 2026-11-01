BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
    $script:dummyDiff = Join-Path $TestDrive "node-01.vhdx"
    New-Item -ItemType File -Path $script:dummyDiff -Force | Out-Null
}

Describe "Get-LabVM" {
    BeforeEach {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            return @(
                [PSCustomObject]@{
                    Name           = 'node-01'
                    State          = 'Running'
                    ProcessorCount = 2
                    MemoryAssigned = 2147483648
                    Uptime         = [timespan]::FromMinutes(42)
                }
            )
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMNetworkAdapter' -MockWith {
            return [PSCustomObject]@{
                IPAddresses = @('192.168.1.150', 'fe80::1')
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMHardDiskDrive' -MockWith {
            return [PSCustomObject]@{
                Path = $script:dummyDiff
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VHD' -MockWith {
            return [PSCustomObject]@{
                ParentPath = 'C:\Base\Ubuntu2404.vhdx'
            }
        }
    }

    It "Discovers running VM metrics and IP address" {
        $result = Get-LabVM -Name "node-01"
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be "node-01"
        $result.State | Should -Be "Running"
        $result.IPv4 | Should -Be "192.168.1.150"
        $result.CPU | Should -Be 2
        $result.MemoryMB | Should -Be 2048
        $result.ParentBase | Should -Be "Ubuntu2404.vhdx"
        $result.Distro | Should -Not -BeNullOrEmpty
        $result.Username | Should -Be "labadmin"
        $result.SSH | Should -Be "ssh labadmin@192.168.1.150"
    }

    It "Accepts VM names from pipeline" {
        $result = "node-01" | Get-LabVM
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be "node-01"
    }

    It "Surfaces saved credentials and distro from metadata" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-LabVMMetadata' -MockWith {
            [PSCustomObject]@{
                Name     = 'node-01'
                Distro   = 'AlmaLinux9'
                Username = 'clouduser'
                Password = 'CustomPass123'
                IPv4     = '192.168.1.150'
                SSH      = 'ssh clouduser@192.168.1.150'
                Profile  = 'SecurityLab'
            }
        }

        $res = Get-LabVM -Name "node-01"
        $res.Distro | Should -Be "AlmaLinux9"
        $res.Username | Should -Be "clouduser"
        $res.Password | Should -Be "CustomPass123"
        $res.SSH | Should -Be "ssh clouduser@192.168.1.150"
    }
}
