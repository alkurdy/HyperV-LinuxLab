function Restore-LabVM {
    <#
    .SYNOPSIS
        Restores one or more Hyper-V lab virtual machines to their last or specified checkpoint.
    .DESCRIPTION
        Reverts the virtual machine to a previous state in seconds without wiping the VM
        back to the golden base image. If no snapshot name is specified, the most recent
        checkpoint is automatically restored.
    .PARAMETER Name
        Name of one or more lab VMs to restore (supports pipeline input).
    .PARAMETER SnapshotName
        Optional name of a specific checkpoint to restore. Defaults to the most recent checkpoint.
    .PARAMETER Force
        Bypasses confirmation prompts.
    .EXAMPLE
        Restore-LabVM -Name "node-01"
    .EXAMPLE
        Restore-LabVM -Name "node-01" -SnapshotName "pre-docker-install" -Force
    .EXAMPLE
        Get-LabVM -Name "k8s-*" | Restore-LabVM -Force
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string[]]$Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SnapshotName,

        [switch]$Force
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

            # Find target snapshot
            $allSnaps = @(Hyper-V\Get-VMSnapshot -VMName $vmName -ErrorAction SilentlyContinue)
            $targetSnap = if ($SnapshotName) {
                $allSnaps | Where-Object { $_.Name -eq $SnapshotName } | Select-Object -First 1
            } else {
                $allSnaps | Sort-Object CreationTime -Descending | Select-Object -First 1
            }

            if (-not $targetSnap) {
                $err = if ($SnapshotName) {
                    "Checkpoint '$SnapshotName' not found for VM '$vmName'."
                } else {
                    "No checkpoints found for VM '$vmName'. Use Checkpoint-LabVM before restoring."
                }
                Write-Error $err
                continue
            }

            if ($Force -or $PSCmdlet.ShouldProcess($vmName, "Restore to checkpoint '$($targetSnap.Name)'")) {
                Write-Verbose "Restoring VM '$vmName' to checkpoint '$($targetSnap.Name)'..."
                Hyper-V\Restore-VMSnapshot -VMName $vmName -Name $targetSnap.Name -Confirm:$false

                Write-Information "[OK] VM '$vmName' reverted to checkpoint '$($targetSnap.Name)'." -InformationAction Continue

                [PSCustomObject]@{
                    VMName               = $vmName
                    RestoredSnapshot     = $targetSnap.Name
                    SnapshotCreationTime = $targetSnap.CreationTime
                    RestoredAt           = Get-Date
                    State                = (Hyper-V\Get-VM -Name $vmName -ErrorAction SilentlyContinue).State.ToString()
                }
            }
        }
    }
}
