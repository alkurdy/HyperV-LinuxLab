BeforeAll {
    $script:privatePath = Join-Path $PSScriptRoot "..\..\Private\Get-LabClusterNodeName.ps1"
    . $script:privatePath
}

Describe "Get-LabClusterNodeName" {
    It "Prefixes node name with cluster name when not already present" {
        $name = Get-LabClusterNodeName -ClusterName "k8s-lab" -NodeName "cp-01"
        $name | Should -Be "k8s-lab-cp-01"
    }

    It "Preserves node name if it already starts with cluster name" {
        $name = Get-LabClusterNodeName -ClusterName "k8s-lab" -NodeName "k8s-lab-cp-01"
        $name | Should -Be "k8s-lab-cp-01"
    }

    It "Returns node name unchanged if cluster name is empty" {
        $name = Get-LabClusterNodeName -ClusterName "" -NodeName "worker-01"
        $name | Should -Be "worker-01"
    }
}
