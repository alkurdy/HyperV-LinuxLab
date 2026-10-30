function Test-LabCluster {
    <#
    .SYNOPSIS
        Validates a declarative cluster JSON topology configuration before provisioning.
    .DESCRIPTION
        Checks schema validity, node parameters, profile availability, and ensures host
        RAM and disk storage capacity can satisfy the entire cluster topology.
    .PARAMETER Path
        Path to the cluster JSON topology file.
    .EXAMPLE
        Test-LabCluster -Path .\examples\k8s-3node-cluster.json
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Cluster specification file '$Path' was not found."
    }

    $errors = @()
    $cluster = try {
        Get-Content -Path $Path -Raw | ConvertFrom-Json
    } catch {
        $errors += "Failed to parse JSON: $_"
        $null
    }

    if (-not $cluster) {
        return [PSCustomObject]@{
            Status   = "Invalid"
            Path     = (Resolve-Path $Path).Path
            Errors   = $errors
            Capacity = $null
        }
    }

    if (-not $cluster.ClusterName) {
        $errors += "Missing required root property 'ClusterName'."
    }

    if (-not $cluster.Nodes -or $cluster.Nodes.Count -eq 0) {
        $errors += "Cluster specification must contain at least one node in 'Nodes' array."
    }

    $totalRAM = 0
    $totalCPU = 0
    $nodeNames = @()

    foreach ($n in $cluster.Nodes) {
        if (-not $n.Name) {
            $errors += "A node is missing the required 'Name' property."
            continue
        }

        $fullNodeName = if ($cluster.ClusterName -and -not $n.Name.StartsWith($cluster.ClusterName)) {
            "$($cluster.ClusterName)-$($n.Name)"
        } else {
            $n.Name
        }

        if ($nodeNames -contains $fullNodeName) {
            $errors += "Duplicate node name detected: '$fullNodeName'."
        }
        $nodeNames += $fullNodeName

        $ram = if ($n.MemoryGB) { [int]$n.MemoryGB } else { 2 }
        $cpu = if ($n.CPU) { [int]$n.CPU } else { 2 }
        $totalRAM += $ram
        $totalCPU += $cpu

        # Check profile resolution if profile specified
        if ($n.Profile) {
            try {
                $null = Resolve-LabProfile -Profile $n.Profile
            } catch {
                $errors += "Node '$($n.Name)' specifies invalid profile '$($n.Profile)': $_"
            }
        }
    }

    # Host capacity checks
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $hostRamGB = if ($cs -and $cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { 0.0 }
    if ($hostRamGB -gt 0 -and $totalRAM -gt ($hostRamGB * 0.85)) {
        $errors += "Cluster requires ${totalRAM} GB RAM, which exceeds 85% of host physical RAM (${hostRamGB} GB)."
    }

    $drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    $freeStorageGB = if ($drive) { [math]::Round($drive.Free / 1GB, 2) } else { 0.0 }
    $minStorageRequired = 10 + ($cluster.Nodes.Count * 2)
    if ($freeStorageGB -lt $minStorageRequired) {
        $errors += "Cluster requires at least ${minStorageRequired} GB free disk space. Volume C: only has ${freeStorageGB} GB free."
    }

    $isValid = ($errors.Count -eq 0)

    return [PSCustomObject]@{
        Status        = if ($isValid) { "Valid" } else { "Invalid" }
        ClusterName   = $cluster.ClusterName
        NodeCount     = $cluster.Nodes.Count
        TotalMemoryGB = $totalRAM
        TotalCPU      = $totalCPU
        HostFreeRAMGB = $hostRamGB
        HostFreeDisk  = $freeStorageGB
        Errors        = $errors
    }
}
