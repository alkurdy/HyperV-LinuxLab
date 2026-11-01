BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Get-LabTargetVM" {
    It "Resolves VM by explicit name" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            param($Name)
            return [PSCustomObject]@{ Name = $Name; State = 'Running' }
        }

        $vms = & (Get-Module HyperV-LinuxLab) { Get-LabTargetVM -Name "test-node-01" }
        $vms | Should -Not -BeNullOrEmpty
        $vms[0].Name | Should -Be "test-node-01"
    }

    It "Resolves VMs from cluster JSON topology" {
        $jsonPath = Join-Path $TestDrive "test-cluster.json"
        @{
            ClusterName = "my-cluster"
            Nodes = @(
                @{ Name = "cp-01" },
                @{ Name = "worker-01" }
            )
        } | ConvertTo-Json | Set-Content -Path $jsonPath

        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            param($Name)
            return [PSCustomObject]@{ Name = $Name; State = 'Running' }
        }

        $vms = & (Get-Module HyperV-LinuxLab) { param($f) Get-LabTargetVM -Path $f } $jsonPath
        $vms.Count | Should -Be 2
        $vms[0].Name | Should -Be "my-cluster-cp-01"
        $vms[1].Name | Should -Be "my-cluster-worker-01"
    }
}
