BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
    $script:clusterJson = Join-Path $PSScriptRoot "..\..\examples\k8s-3node-cluster.json"
    $script:multiDistroJson = Join-Path $PSScriptRoot "..\..\examples\multi-distro-cluster.json"
}

Describe "Cluster Topology Deployment" {
    Context "Test-LabCluster" {
        It "Validates the k8s-3node-cluster.json topology" {
            $result = Test-LabCluster -Path $script:clusterJson
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "Valid"
            $result.ClusterName | Should -Be "k8s-lab"
            $result.NodeCount | Should -Be 3
            $result.TotalMemoryGB | Should -Be 8
            $result.TotalCPU | Should -Be 6
            $result.Errors.Count | Should -Be 0
        }

        It "Validates the multi-distro-cluster.json topology" {
            $result = Test-LabCluster -Path $script:multiDistroJson
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "Valid"
            $result.ClusterName | Should -Be "polyglot-lab"
            $result.NodeCount | Should -Be 3
            $result.Errors.Count | Should -Be 0
        }
    }

    Context "New-LabCluster and Remove-LabCluster" {
        BeforeEach {
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'New-LabBaseImage' -MockWith {
                return [PSCustomObject]@{
                    Distro = $Distro
                    Path   = "C:\Base\$Distro.vhdx"
                }
            }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'New-LabVM' -MockWith {
                return [PSCustomObject]@{
                    Name   = $Name
                    Distro = if ($Distro) { $Distro } else { 'Ubuntu2404' }
                    State  = 'Running'
                    IPv4   = '192.168.1.101'
                    SSH    = "ssh labadmin@192.168.1.101"
                }
            }
            Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Remove-LabVM' -MockWith { }
        }

        It "Provisions all nodes declared in cluster.json" {
            $deployed = New-LabCluster -Path $script:clusterJson
            $deployed.Count | Should -Be 3
            $deployed[0].Name | Should -Be "k8s-lab-cp-01"
            $deployed[1].Name | Should -Be "k8s-lab-worker-01"
            $deployed[2].Name | Should -Be "k8s-lab-worker-02"

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'New-LabVM' -Times 3
        }

        It "Provisions heterogeneous multi-distro cluster nodes" {
            $deployed = New-LabCluster -Path $script:multiDistroJson
            $deployed.Count | Should -Be 3
            $deployed[0].Name | Should -Be "polyglot-lab-u24-node"
            $deployed[1].Name | Should -Be "polyglot-lab-deb12-node"
            $deployed[2].Name | Should -Be "polyglot-lab-alma9-node"

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'New-LabVM' -Times 3
        }

        It "Tears down all nodes declared in cluster.json" {
            Remove-LabCluster -Path $script:clusterJson -Force

            Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Remove-LabVM' -Times 3
        }
    }
}
