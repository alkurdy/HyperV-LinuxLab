function New-LabCluster {
    <#
    .SYNOPSIS
        Provisions a multi-node lab cluster from a declarative JSON topology file.
    .DESCRIPTION
        Reads a cluster JSON topology specification, validates capacity, provisions
        child differencing VMs sharing a single golden base image, applies profiles,
        and discovers guest network addresses.
    .PARAMETER Path
        Path to the cluster JSON topology file.
    .PARAMETER Force
        Proceeds with deployment even if prerequisite warnings exist.
    .EXAMPLE
        New-LabCluster -Path .\examples\k8s-3node-cluster.json
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject[]])]
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

        # 1. Validate Topology
        Write-Verbose "Validating cluster topology at '$Path'..."
        $testResult = Test-LabCluster -Path $Path
        if ($testResult.Status -ne "Valid" -and -not $Force) {
            $msg = ($testResult.Errors -join "; ")
            throw "Cluster topology validation failed: $msg. Use -Force to override."
        }

        $cluster = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $baseDistro = if ($cluster.BaseImage) { $cluster.BaseImage } else { "Ubuntu2404" }
        $switchName = $cluster.SwitchName

        if ($PSCmdlet.ShouldProcess($cluster.ClusterName, "Deploy cluster with $($cluster.Nodes.Count) nodes")) {
            # 2. Ensure base image is cached
            Write-Information "--- Ensuring Base Image '$baseDistro' is Cached ---" -InformationAction Continue
            $base = New-LabBaseImage -Distro $baseDistro

            Write-Information "--- Deploying Cluster '$($cluster.ClusterName)' ($($cluster.Nodes.Count) nodes) ---" -InformationAction Continue

            $deployed = @()
            foreach ($n in $cluster.Nodes) {
                $fullNodeName = if ($cluster.ClusterName -and -not $n.Name.StartsWith($cluster.ClusterName)) {
                    "$($cluster.ClusterName)-$($n.Name)"
                } else {
                    $n.Name
                }

                $ram = if ($n.MemoryGB) { [int]$n.MemoryGB } else { 2 }
                $cpu = if ($n.CPU) { [int]$n.CPU } else { 2 }

                Write-Information "Provisioning node '$fullNodeName' (RAM: ${ram}GB, CPU: $cpu, Profile: $($n.Profile))..." -InformationAction Continue

                $vmParams = @{
                    Name      = $fullNodeName
                    BaseImage = $base.Path
                    MemoryGB  = $ram
                    CPUCount  = $cpu
                    Start     = $true
                }
                if ($n.Profile) { $vmParams["Profile"] = $n.Profile }
                if ($switchName) { $vmParams["SwitchName"] = $switchName }
                if ($n.Packages) { $vmParams["Packages"] = @($n.Packages) }

                $vm = New-LabVM @vmParams
                $deployed += [PSCustomObject]@{
                    Name     = $fullNodeName
                    Role     = if ($n.Role) { $n.Role } else { "Worker" }
                    State    = $vm.State
                    IPv4     = $vm.IPv4
                    SSH      = $vm.SSH
                    CPU      = $cpu
                    MemoryGB = $ram
                    Profile  = if ($n.Profile) { $n.Profile } else { "None" }
                }
            }

            # Summary Table
            Write-Information @"

============================================================
 [CLUSTER READY] $($cluster.ClusterName) ($($deployed.Count) Nodes)
------------------------------------------------------------
$($deployed | Format-Table Name, Role, IPv4, CPU, MemoryGB, Profile | Out-String)
 SSH Access:
$(($deployed | Where-Object { $_.IPv4 } | ForEach-Object { "   $($_.Name): $($_.SSH)" }) -join "`n")
============================================================
"@ -InformationAction Continue

            return $deployed
        }
    }
}
