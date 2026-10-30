BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Start-LabVM and Stop-LabVM" {
    Context "Start-LabVM" {
        BeforeEach {
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
                return [PSCustomObject]@{
                    Name  = 'node-start'
                    State = 'Off'
                }
            }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Start-VM' -MockWith { }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-LabVMIPAddress' -MockWith {
                return "192.168.1.188"
            }
        }

        It "Starts VM and discovers IP address when -Wait is specified" {
            $result = Start-LabVM -Name "node-start" -Wait -TimeoutSeconds 10
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "node-start"
            $result.State | Should -Be "Running"
            $result.IPv4 | Should -Be "192.168.1.188"

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Start-VM' -Times 1 -ParameterFilter {
                $Name -eq "node-start"
            }
        }
    }

    Context "Stop-LabVM" {
        BeforeEach {
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
                return [PSCustomObject]@{
                    Name  = 'node-stop'
                    State = 'Running'
                }
            }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Stop-VM' -MockWith { }
        }

        It "Shuts down running VM" {
            $result = Stop-LabVM -Name "node-stop"
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "node-stop"
            $result.State | Should -Be "Off"

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Stop-VM' -Times 1 -ParameterFilter {
                $Name -eq "node-stop"
            }
        }
    }
}
