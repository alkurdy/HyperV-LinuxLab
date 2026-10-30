BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
    $script:mockBase = Join-Path $TestDrive "mock-base.vhdx"
    New-Item -ItemType File -Path $script:mockBase -Force | Out-Null
    $script:labPath = Join-Path $TestDrive "LabVMs"
}

Describe "New-LabVM" {
    BeforeEach {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-LabDefaultSwitch' -MockWith { return "Default Switch" }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'New-VHD' -MockWith {
            return [PSCustomObject]@{
                Path       = $Path
                ParentPath = $ParentPath
                VhdType    = 'Differencing'
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\New-VM' -MockWith {
            return [PSCustomObject]@{
                Name = $Name
                Id   = [guid]::NewGuid()
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Set-VMProcessor' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Set-VMFirmware' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Add-VMDvdDrive' -MockWith { }
    }

    It "Provisions Generation 2 VM with differencing disk" {
        $result = New-LabVM -Name "test-worker-01" `
            -BaseImage $script:mockBase `
            -MemoryGB 4 `
            -CPUCount 2 `
            -LabStoragePath $script:labPath

        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be "test-worker-01"
        $result.CPU | Should -Be 2
        $result.MemoryGB | Should -Be 4
        $result.BaseImage | Should -Be (Split-Path $script:mockBase -Leaf)

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' New-VHD -Times 1 -ParameterFilter {
            $ParentPath -eq $script:mockBase -and $Differencing -eq $true
        }

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\New-VM' -Times 1 -ParameterFilter {
            $Name -eq "test-worker-01" -and $Generation -eq 2
        }

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Set-VMFirmware' -Times 1 -ParameterFilter {
            $EnableSecureBoot -eq 'On' -and $SecureBootTemplate -eq 'MicrosoftUEFICertificateAuthority'
        }
    }
}
