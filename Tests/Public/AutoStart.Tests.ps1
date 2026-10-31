BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Lab Auto-Start Management" {
    BeforeEach {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            param($Name)
            $vms = @(
                [PSCustomObject]@{
                    Name                 = 'lab-node-01'
                    State                = 'Running'
                    Path                 = 'C:\HyperV-LinuxLab\LabVMs\lab-node-01'
                    AutomaticStartAction = 'Start'
                    AutomaticStartDelay  = 15
                    AutomaticStopAction  = 'ShutDown'
                }
            )
            if ($Name) {
                return @($vms | Where-Object { $_.Name -like $Name })
            }
            return $vms
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Set-VM' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Register-ScheduledTask' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Unregister-ScheduledTask' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-ScheduledTask' -MockWith {
            return [PSCustomObject]@{
                TaskName = 'HyperV-LinuxLab-AutoStart'
                State    = 'Ready'
                Triggers = @([PSCustomObject]@{ CimClass = [PSCustomObject]@{ CimClassName = 'MSFT_TaskBootTrigger' } })
            }
        }
    }

    Context "Enable-LabAutoStart" {
        It "Enables native Hyper-V auto-start action with delay" {
            $results = Enable-LabAutoStart -Name "lab-node-01" -Mode HyperV -DelaySeconds 20
            $results | Should -Not -BeNullOrEmpty
            $results[0].Target | Should -Be "lab-node-01"
            $results[0].Type | Should -Be "HyperV-VM"
            $results[0].AutomaticStartAction | Should -Be "Start"
            $results[0].DelaySeconds | Should -Be 20

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Set-VM' -Times 1 -ParameterFilter {
                $Name -eq "lab-node-01" -and $AutomaticStartAction -eq 'Start' -and $AutomaticStartDelay -eq 20
            }
        }

        It "Registers Windows Scheduled Task in ScheduledTask mode" {
            $results = Enable-LabAutoStart -Mode ScheduledTask -Trigger AtStartup
            $results | Should -Not -BeNullOrEmpty
            $results[0].Target | Should -Be "HyperV-LinuxLab-AutoStart"
            $results[0].Type | Should -Be "ScheduledTask"
            $results[0].Status | Should -Be "Registered"

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Register-ScheduledTask' -Times 1
        }
    }

    Context "Disable-LabAutoStart" {
        It "Disables native Hyper-V auto-start" {
            $results = Disable-LabAutoStart -Name "lab-node-01" -Mode HyperV
            $results | Should -Not -BeNullOrEmpty
            $results[0].Target | Should -Be "lab-node-01"
            $results[0].AutomaticStartAction | Should -Be "Nothing"

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Set-VM' -Times 1 -ParameterFilter {
                $Name -eq "lab-node-01" -and $AutomaticStartAction -eq 'Nothing'
            }
        }

        It "Unregisters Scheduled Task in Both mode" {
            $results = Disable-LabAutoStart -Name "lab-node-01" -Mode Both
            $results.Count | Should -Be 2
            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Unregister-ScheduledTask' -Times 1
        }
    }

    Context "Get-LabAutoStart" {
        It "Reports auto-start status for VMs and Scheduled Task" {
            $results = Get-LabAutoStart -Name "lab-node-01"
            $results.Count | Should -Be 2
            $vmReport = $results | Where-Object { $_.Type -eq "HyperV-VM" }
            $vmReport.Target | Should -Be "lab-node-01"
            $vmReport.AutomaticStartAction | Should -Be "Start"
            $vmReport.Status | Should -Be "Enabled"

            $taskReport = $results | Where-Object { $_.Type -eq "ScheduledTask" }
            $taskReport.Target | Should -Be "HyperV-LinuxLab-AutoStart"
            $taskReport.Status | Should -Be "Ready"
        }
    }
}
