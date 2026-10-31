BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
    $script:dummyClusterJson = Join-Path $TestDrive "cluster-test.json"
    @{
        ClusterName = "k8s-test"
        Nodes = @(
            @{ Name = "cp-01"; Role = "ControlPlane" },
            @{ Name = "worker-01"; Role = "Worker" }
        )
    } | ConvertTo-Json | Set-Content -Path $script:dummyClusterJson
}

Describe "Start-Lab and Stop-Lab" {
    Context "Start-Lab" {
        BeforeEach {
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
                param($Name)
                $vms = @(
                    [PSCustomObject]@{
                        Name                 = 'k8s-test-cp-01'
                        State                = 'Off'
                        Path                 = 'C:\HyperV-LinuxLab\LabVMs\k8s-test-cp-01'
                        AutomaticStartAction = 'Nothing'
                        AutomaticStartDelay  = 0
                        AutomaticStopAction  = 'Save'
                    },
                    [PSCustomObject]@{
                        Name                 = 'k8s-test-worker-01'
                        State                = 'Running'
                        Path                 = 'C:\HyperV-LinuxLab\LabVMs\k8s-test-worker-01'
                        AutomaticStartAction = 'Nothing'
                        AutomaticStartDelay  = 0
                        AutomaticStopAction  = 'Save'
                    }
                )
                if ($Name) {
                    return @($vms | Where-Object { $_.Name -like $Name })
                }
                return $vms
            }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Start-VM' -MockWith { }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMNetworkAdapter' -MockWith {
                return [PSCustomObject]@{
                    IPAddresses = @('192.168.1.150')
                }
            }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-LabVMIPAddress' -MockWith {
                return "192.168.1.150"
            }
        }

        It "Starts targeted VMs and outputs standardized telemetry" {
            $results = Start-Lab -Name "k8s-test-cp-01"
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -Be 1
            $results[0].Name | Should -Be "k8s-test-cp-01"
            $results[0].State | Should -Be "Running"

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Start-VM' -Times 1 -ParameterFilter {
                $Name -eq "k8s-test-cp-01"
            }
        }

        It "Starts cluster nodes declared in a topology JSON file with -Wait" {
            $results = Start-Lab -Path $script:dummyClusterJson -Wait -TimeoutSeconds 5
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -Be 2
            $results[0].Name | Should -Be "k8s-test-cp-01"
            $results[0].IPv4 | Should -Be "192.168.1.150"
            $results[0].SSH | Should -Be "ssh labadmin@192.168.1.150"
        }

        It "Gracefully warns when no lab VMs are found" {
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith { return @() }
            $results = Start-Lab -Name "non-existent"
            $results.Count | Should -Be 0
        }
    }

    Context "Stop-Lab" {
        BeforeEach {
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
                param($Name)
                $vms = @(
                    [PSCustomObject]@{
                        Name  = 'k8s-test-cp-01'
                        State = 'Running'
                        Path  = 'C:\HyperV-LinuxLab\LabVMs\k8s-test-cp-01'
                    },
                    [PSCustomObject]@{
                        Name  = 'k8s-test-worker-01'
                        State = 'Running'
                        Path  = 'C:\HyperV-LinuxLab\LabVMs\k8s-test-worker-01'
                    }
                )
                if ($Name) {
                    return @($vms | Where-Object { $_.Name -like $Name })
                }
                return $vms
            }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Stop-VM' -MockWith { }
        }

        It "Gracefully stops all targeted running lab VMs" {
            $results = Stop-Lab -Name "k8s-test-cp-01"
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -Be 1
            $results[0].Name | Should -Be "k8s-test-cp-01"
            $results[0].State | Should -Be "Off"

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Stop-VM' -Times 1 -ParameterFilter {
                $Name -eq "k8s-test-cp-01"
            }
        }

        It "Stops cluster nodes with -Force parameter" {
            $results = Stop-Lab -Path $script:dummyClusterJson -Force
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -Be 2
            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Stop-VM' -Times 2
        }

        It "Gracefully warns when stopping if no lab VMs exist" {
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith { return @() }
            $results = Stop-Lab -Name "non-existent"
            $results.Count | Should -Be 0
        }
    }
}
