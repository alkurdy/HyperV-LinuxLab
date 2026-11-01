BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Install-LabHyperV" {
    BeforeEach {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-CimInstance' -MockWith {
            param($ClassName)
            if ($ClassName -eq 'Win32_OperatingSystem') {
                return [PSCustomObject]@{ Caption = 'Microsoft Windows 11 Pro' }
            }
            if ($ClassName -eq 'Win32_ComputerSystem') {
                return [PSCustomObject]@{ HypervisorPresent = $true }
            }
            if ($ClassName -eq 'Win32_Processor') {
                return @([PSCustomObject]@{ VirtualizationFirmwareEnabled = $true })
            }
            return $null
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-Process' -MockWith { return $null }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Test-Path' -MockWith { return $false }
    }

    It "Reports already active when Hyper-V feature, tools, and service are running" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-WindowsOptionalFeature' -MockWith {
            return [PSCustomObject]@{ State = 'Enabled' }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-Command' -MockWith {
            return [PSCustomObject]@{ Name = 'Hyper-V\New-VM' }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-Service' -MockWith {
            return [PSCustomObject]@{ Name = 'vmms'; Status = 'Running' }
        }

        $result = Install-LabHyperV
        $result.Status | Should -Be "Ready"
        $result.HypervisorRunning | Should -Be $true
        $result.RestartNeeded | Should -Be $false
    }

    It "Detects pending reboot when Hyper-V feature is enabled but service not active" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-WindowsOptionalFeature' -MockWith {
            return [PSCustomObject]@{ State = 'Enabled' }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-Command' -MockWith { return $null }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-Service' -MockWith { return $null }

        $result = Install-LabHyperV
        $result.Status | Should -Be "RebootRequired"
        $result.RestartNeeded | Should -Be $true
    }

    It "Throws when hardware virtualization is disabled and Force is omitted" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-CimInstance' -MockWith {
            param($ClassName)
            if ($ClassName -eq 'Win32_OperatingSystem') {
                return [PSCustomObject]@{ Caption = 'Microsoft Windows 11 Enterprise' }
            }
            if ($ClassName -eq 'Win32_ComputerSystem') {
                return [PSCustomObject]@{ HypervisorPresent = $false }
            }
            if ($ClassName -eq 'Win32_Processor') {
                return @([PSCustomObject]@{ VirtualizationFirmwareEnabled = $false })
            }
            return $null
        }

        { Install-LabHyperV } | Should -Throw -ExpectedMessage "*Hardware virtualization (Intel VT-x or AMD-V) is disabled in BIOS/UEFI*"
    }

    It "Enables Hyper-V optional feature and reports reboot required" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-WindowsOptionalFeature' -MockWith {
            return [PSCustomObject]@{ State = 'Disabled' }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Enable-WindowsOptionalFeature' -MockWith {
            return [PSCustomObject]@{
                RestartNeeded = $true
                State         = 'Enabled'
            }
        }

        $result = Install-LabHyperV
        $result.Status | Should -Be "RebootRequired"
        $result.RestartNeeded | Should -Be $true
        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' -CommandName 'Enable-WindowsOptionalFeature' -Times 1
    }

    It "Restarts computer when -Restart switch is passed and restart is needed" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-WindowsOptionalFeature' -MockWith {
            return [PSCustomObject]@{ State = 'Disabled' }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Enable-WindowsOptionalFeature' -MockWith {
            return [PSCustomObject]@{
                RestartNeeded = $true
                State         = 'Enabled'
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Restart-Computer' -MockWith { }

        $result = Install-LabHyperV -Restart -Force
        $result.Status | Should -Be "RebootRequired"
        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' -CommandName 'Restart-Computer' -Times 1
    }

    It "Blocks on Windows Home edition" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Get-CimInstance' -MockWith {
            param($ClassName)
            if ($ClassName -eq 'Win32_OperatingSystem') {
                return [PSCustomObject]@{ Caption = 'Windows 11 Home Edition' }
            }
            return $null
        }

        { Install-LabHyperV } | Should -Throw -ExpectedMessage "*Windows Home edition does not support Hyper-V*"
    }
}
