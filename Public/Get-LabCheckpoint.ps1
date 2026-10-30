function Get-LabCheckpoint {
    <#
    .SYNOPSIS
        Retrieves checkpoints (snapshots) associated with one or more Hyper-V lab VMs.
    .DESCRIPTION
        Queries and lists existing checkpoints, creation timestamps, and parent relationships
        for lab VMs.
    .PARAMETER Name
        Name of one or more lab VMs to query (supports pipeline input).
    .PARAMETER SnapshotName
        Optional filter for snapshot names (supports wildcards, e.g. 'pre-*').
    .EXAMPLE
        Get-LabCheckpoint -Name "node-01"
    .EXAMPLE
        Get-LabVM | Get-LabCheckpoint | Format-Table VMName, Name, CreationTime
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string[]]$Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SnapshotName = "*"
    )

    process {
        foreach ($vmName in $Name) {
            $vm = Hyper-V\Get-VM -Name $vmName -ErrorAction SilentlyContinue
            if (-not $vm) {
                Write-Warning "Virtual machine '$vmName' was not found in Hyper-V."
                continue
            }

            $snaps = Hyper-V\Get-VMSnapshot -VMName $vmName -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like $SnapshotName } |
                Sort-Object CreationTime -Descending

            foreach ($s in $snaps) {
                [PSCustomObject]@{
                    VMName             = $vmName
                    Name               = $s.Name
                    CreationTime       = $s.CreationTime
                    ParentSnapshotName = $s.ParentSnapshotName
                    SnapshotType       = $s.SnapshotType.ToString()
                }
            }
        }
    }
}
