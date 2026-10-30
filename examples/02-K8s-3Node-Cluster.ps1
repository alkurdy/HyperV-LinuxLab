<#
.SYNOPSIS
    Provisions a 3-node Kubernetes lab topology (1 control-plane, 2 workers) in seconds.
.DESCRIPTION
    Automates multi-node topology standup using Hyper-V differencing disks sharing
    a single Ubuntu base image. Demonstrates batch reset and cleanup.
#>

[CmdletBinding()]
param(
    [string]$ClusterPrefix = "k8s",
    [int]$MasterMemoryGB = 4,
    [int]$WorkerMemoryGB = 2
)

Import-Module HyperV-LinuxLab -Force

# Verify host prerequisites
$prereqs = Test-LabPrerequisites
if ($prereqs.Status -ne "Ready") {
    throw "Host prerequisites failed."
}

# Ensure base image exists
$base = New-LabBaseImage -Distro "Ubuntu2404"

# Define cluster nodes
$nodes = @(
    @{ Name = "$ClusterPrefix-cp-01";   Role = "ControlPlane"; RAM = $MasterMemoryGB; CPU = 2 },
    @{ Name = "$ClusterPrefix-node-01"; Role = "Worker";       RAM = $WorkerMemoryGB; CPU = 2 },
    @{ Name = "$ClusterPrefix-node-02"; Role = "Worker";       RAM = $WorkerMemoryGB; CPU = 2 }
)

Write-Information "--- Standing Up 3-Node Kubernetes Lab ---" -InformationAction Continue

$deployed = @()
foreach ($n in $nodes) {
    Write-Information "Provisioning $($n.Role) node '$($n.Name)'..." -InformationAction Continue
    $vm = New-LabVM -Name $n.Name `
        -BaseImage $base.Path `
        -MemoryGB $n.RAM `
        -CPUCount $n.CPU `
        -Packages @("curl", "git", "iptables", "socat", "conntrack") `
        -Start

    $deployed += $vm
}

# Display cluster summary
Write-Information "--- Cluster Nodes Provisioned ---" -InformationAction Continue
Get-LabVM -Name "$ClusterPrefix-*" | Format-Table Name, State, IPv4, CPU, MemoryMB, DifferencingDiskMB

# Demonstration commands:
# Batch Reset all 3 nodes simultaneously:
# Get-LabVM -Name "$ClusterPrefix-*" | Reset-LabVM -Force

# Complete Teardown:
# Get-LabVM -Name "$ClusterPrefix-*" | Remove-LabVM -Force
