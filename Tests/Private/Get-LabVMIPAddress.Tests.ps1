BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Get-LabVMIPAddress" {
    It "Returns empty string immediately if VM is not found or not running" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith { return $null }
        $ip = & (Get-Module HyperV-LinuxLab) { Get-LabVMIPAddress -VMName "nonexistent-vm" -TimeoutSeconds 0 }
        $ip | Should -Be ""
    }

    It "Discovers valid IPv4 address from adapter" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            [PSCustomObject]@{
                Name  = "test-vm"
                State = "Running"
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMNetworkAdapter' -MockWith {
            return @(
                [PSCustomObject]@{
                    IPAddresses = @("169.254.1.1", "192.168.1.155", "fe80::1")
                }
            )
        }

        $ip = & (Get-Module HyperV-LinuxLab) { Get-LabVMIPAddress -VMName "test-vm" -TimeoutSeconds 0 }
        $ip | Should -Be "192.168.1.155"
    }

    It "Filters out link-local and loopback addresses" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            [PSCustomObject]@{
                Name  = "test-vm"
                State = "Running"
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMNetworkAdapter' -MockWith {
            return @(
                [PSCustomObject]@{
                    IPAddresses = @("169.254.10.20", "127.0.0.1")
                }
            )
        }

        $ip = & (Get-Module HyperV-LinuxLab) { Get-LabVMIPAddress -VMName "test-vm" -TimeoutSeconds 0 }
        $ip | Should -Be ""
    }
}
