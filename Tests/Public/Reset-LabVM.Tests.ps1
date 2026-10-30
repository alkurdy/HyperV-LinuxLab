BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
    $script:mockBase = Join-Path $TestDrive "base.vhdx"
    $script:mockDiff = Join-Path $TestDrive "node-01-diff.vhdx"
    New-Item -ItemType File -Path $script:mockBase -Force | Out-Null
    New-Item -ItemType File -Path $script:mockDiff -Force | Out-Null
}

Describe "Reset-LabVM" {
    BeforeEach {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            return [PSCustomObject]@{
                Name  = 'node-01'
                State = 'Running'
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Stop-VM' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMHardDiskDrive' -MockWith {
            return [PSCustomObject]@{
                Path = $script:mockDiff
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VHD' -MockWith {
            return [PSCustomObject]@{
                Path       = $script:mockDiff
                ParentPath = $script:mockBase
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Remove-Item' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'New-VHD' -MockWith {
            return [PSCustomObject]@{
                Path       = $script:mockDiff
                ParentPath = $script:mockBase
                VhdType    = 'Differencing'
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Start-VM' -MockWith { }
    }

    It "Discards differencing disk and spawns fresh differencing disk pointing to parent" {
        $result = Reset-LabVM -Name "node-01" -Force -PassThru

        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be "node-01"
        $result.Status | Should -Be "Reset"
        $result.ParentImage | Should -Be (Split-Path $script:mockBase -Leaf)

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Stop-VM' -Times 1 -ParameterFilter {
            $Name -eq "node-01"
        }

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Remove-Item' -Times 1 -ParameterFilter {
            $Path -eq $script:mockDiff
        }

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'New-VHD' -Times 1 -ParameterFilter {
            $ParentPath -eq $script:mockBase -and $Path -eq $script:mockDiff -and $Differencing -eq $true
        }

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Start-VM' -Times 1 -ParameterFilter {
            $Name -eq "node-01"
        }
    }
}
