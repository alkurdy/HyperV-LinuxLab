BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
    $script:dummyVmDir = Join-Path $TestDrive "test-vm-remove"
    New-Item -ItemType Directory -Path $script:dummyVmDir -Force | Out-Null
    $script:dummyDiff = Join-Path $script:dummyVmDir "diff.vhdx"
    New-Item -ItemType File -Path $script:dummyDiff -Force | Out-Null
}

Describe "Remove-LabVM" {
    BeforeEach {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            return [PSCustomObject]@{
                Name  = 'test-vm-remove'
                State = 'Running'
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Stop-VM' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMHardDiskDrive' -MockWith {
            return [PSCustomObject]@{
                Path = $script:dummyDiff
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Remove-VM' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Remove-Item' -MockWith { }
    }

    It "Stops running VM, deletes from Hyper-V, and cleans up directory" {
        Remove-LabVM -Name "test-vm-remove" -Force

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Stop-VM' -Times 1 -ParameterFilter {
            $Name -eq "test-vm-remove"
        }

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Remove-VM' -Times 1 -ParameterFilter {
            $Name -eq "test-vm-remove"
        }

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Remove-Item' -Times 1 -ParameterFilter {
            $Path -eq $script:dummyVmDir
        }
    }
}
