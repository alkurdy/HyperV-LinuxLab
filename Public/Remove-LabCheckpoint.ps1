function Remove-LabCheckpoint {
    <#
    .SYNOPSIS
        Deletes one or more checkpoints from a Hyper-V lab VM.
    .DESCRIPTION
        Cleans up snapshots to merge differencing deltas back into the active child disk
        or purge old checkpoints.
    .PARAMETER Name
        Name of one or more lab VMs (supports pipeline input).
    .PARAMETER SnapshotName
        Name of the specific checkpoint to remove.
    .PARAMETER All
        Removes all checkpoints associated with the VM.
    .PARAMETER Force
        Bypasses confirmation prompts.
    .EXAMPLE
        Remove-LabCheckpoint -Name "node-01" -SnapshotName "pre-docker-install"
    .EXAMPLE
        Remove-LabCheckpoint -Name "node-01" -All -Force
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string[]]$Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SnapshotName,

        [switch]$All,

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

            $snaps = if ($All) {
                Hyper-V\Get-VMSnapshot -VMName $vmName -ErrorAction SilentlyContinue
            } elseif ($SnapshotName) {
                Hyper-V\Get-VMSnapshot -VMName $vmName -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $SnapshotName }
            } else {
                Write-Error "Specify either -SnapshotName <Name> or -All to remove checkpoints for '$vmName'."
                continue
            }

            if (-not $snaps) {
                Write-Warning "No matching checkpoints found on VM '$vmName'."
                continue
            }

            foreach ($s in $snaps) {
                if ($Force -or $PSCmdlet.ShouldProcess($vmName, "Remove checkpoint '$($s.Name)'")) {
                    Write-Verbose "Deleting checkpoint '$($s.Name)' on VM '$vmName'..."
                    Hyper-V\Remove-VMSnapshot -VMName $vmName -Name $s.Name

                    Write-Information "[OK] Checkpoint '$($s.Name)' removed from VM '$vmName'." -InformationAction Continue
                }
            }
        }
    }
}
