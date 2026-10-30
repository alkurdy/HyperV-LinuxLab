function Checkpoint-LabVM {
    <#
    .SYNOPSIS
        Creates a checkpoint (snapshot) of one or more Hyper-V lab virtual machines.
    .DESCRIPTION
        Takes an instant snapshot of the VM's differencing state, enabling fast rollbacks
        during testing without discarding installed packages or configuration changes.
    .PARAMETER Name
        Name of one or more lab VMs to checkpoint (supports pipeline input).
    .PARAMETER SnapshotName
        Optional descriptive name for the checkpoint. If omitted, a timestamped name is generated.
    .EXAMPLE
        Checkpoint-LabVM -Name "node-01" -SnapshotName "pre-docker-install"
    .EXAMPLE
        Get-LabVM -Name "k8s-*" | Checkpoint-LabVM -SnapshotName "pre-kubeadm-init"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string[]]$Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SnapshotName
    )

    begin {
        Assert-Administrator
    }

    process {
        foreach ($vmName in $Name) {
            $vm = Hyper-V\Get-VM -Name $vmName -ErrorAction SilentlyContinue
            if (-not $vm) {
                Write-Warning "Virtual machine '$vmName' was not found in Hyper-V."
                continue
            }

            $targetName = if ($SnapshotName) {
                $SnapshotName
            } else {
                "checkpoint-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            }

            if ($PSCmdlet.ShouldProcess($vmName, "Create checkpoint '$targetName'")) {
                Write-Verbose "Creating checkpoint '$targetName' for VM '$vmName'..."
                $snap = Hyper-V\Checkpoint-VM -Name $vmName -SnapshotName $targetName -Passthru

                Write-Information "[OK] Checkpoint '$targetName' created for VM '$vmName'." -InformationAction Continue

                [PSCustomObject]@{
                    VMName       = $vmName
                    SnapshotName = $targetName
                    CreationTime = if ($snap) { $snap.CreationTime } else { Get-Date }
                    ParentName   = if ($snap) { $snap.ParentSnapshotName } else { "" }
                }
            }
        }
    }
}
