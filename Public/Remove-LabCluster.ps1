function Remove-LabCluster {
    <#
    .SYNOPSIS
        Tears down all virtual machines and differencing disks belonging to a cluster JSON definition.
    .DESCRIPTION
        Reads a cluster JSON file and removes every declared VM, unlinking and deleting
        differencing VHDX storage and cloud-init assets.
    .PARAMETER Path
        Path to the cluster JSON topology file.
    .PARAMETER Force
        Bypasses confirmation prompts.
    .EXAMPLE
        Remove-LabCluster -Path .\examples\k8s-3node-cluster.json -Force
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [switch]$Force
    )

    begin {
        Assert-Administrator
    }

    process {
        if (-not (Test-Path $Path)) {
            throw "Cluster topology file '$Path' was not found."
        }

        $cluster = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $nodeNames = @()
        foreach ($n in $cluster.Nodes) {
            $fullNodeName = if ($cluster.ClusterName -and -not $n.Name.StartsWith($cluster.ClusterName)) {
                "$($cluster.ClusterName)-$($n.Name)"
            } else {
                $n.Name
            }
            $nodeNames += $fullNodeName
        }

        if ($Force -or $PSCmdlet.ShouldProcess($cluster.ClusterName, "Tear down $($nodeNames.Count) cluster nodes")) {
            Write-Information "--- Tearing Down Cluster '$($cluster.ClusterName)' ---" -InformationAction Continue

            foreach ($name in $nodeNames) {
                Remove-LabVM -Name $name -Force:$Force
            }

            Write-Information "[OK] Cluster '$($cluster.ClusterName)' teardown complete." -InformationAction Continue
        }
    }
}
