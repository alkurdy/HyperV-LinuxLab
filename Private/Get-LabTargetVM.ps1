function Get-LabTargetVM {
    <#
    .SYNOPSIS
        Resolves a collection of Hyper-V Linux lab virtual machines.
    .DESCRIPTION
        Selects target virtual machines based on cluster topology JSON, explicit name
        filters (including wildcards), or auto-discovering lab VMs located within the
        configured lab storage directory or bearing differencing disks.
    .PARAMETER Name
        Optional name filter or list of VM names.
    .PARAMETER Path
        Optional path to a cluster JSON topology file.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string[]]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Path
    )

    $targetNames = @()

    if ($Path) {
        if (-not (Test-Path $Path)) {
            throw "Cluster topology file '$Path' was not found."
        }
        $cluster = Get-Content -Path $Path -Raw | ConvertFrom-Json
        foreach ($node in $cluster.Nodes) {
            $targetNames += (Get-LabClusterNodeName -ClusterName $cluster.ClusterName -NodeName $node.Name)
        }
    } elseif ($Name -and $Name.Count -gt 0) {
        $hasWildcardOnly = ($Name.Count -eq 1 -and $Name[0] -eq '*')
        if (-not $hasWildcardOnly) {
            $targetNames = $Name
        }
    }

    if ($targetNames.Count -gt 0) {
        $vms = foreach ($n in $targetNames) {
            $found = Hyper-V\Get-VM -Name $n -ErrorAction SilentlyContinue
            if ($found) {
                # Ensure each found item matches target filter
                $found | Where-Object { $_.Name -like $n }
            }
        }
        $seen = @{}
        $resultList = @()
        foreach ($item in $vms) {
            if ($item -and -not $seen.ContainsKey($item.Name)) {
                $seen[$item.Name] = $true
                $resultList += $item
            }
        }
        return @($resultList)
    }

    # Auto-detect lab VMs located in lab storage or using differencing disks
    $cfg = Get-LabConfiguration
    $labRoot = $cfg.StoragePath
    $labVMPath = $cfg.LabVMPath
    $baseImagesPath = $cfg.BaseImagePath

    $allVMs = Hyper-V\Get-VM -ErrorAction SilentlyContinue
    $labVMs = foreach ($vm in $allVMs) {
        $isLab = $false

        if ($vm.Path -and ($vm.Path.StartsWith($labVMPath, [System.StringComparison]::OrdinalIgnoreCase) -or
            $vm.Path.StartsWith($labRoot, [System.StringComparison]::OrdinalIgnoreCase))) {
            $isLab = $true
        } else {
            $hdd = Hyper-V\Get-VMHardDiskDrive -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hdd -and $hdd.Path) {
                if ($hdd.Path.StartsWith($labVMPath, [System.StringComparison]::OrdinalIgnoreCase) -or
                    $hdd.Path.StartsWith($labRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $isLab = $true
                } else {
                    $vhd = Hyper-V\Get-VHD -Path $hdd.Path -ErrorAction SilentlyContinue
                    if ($vhd -and $vhd.ParentPath -and $vhd.ParentPath.StartsWith($baseImagesPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $isLab = $true
                    }
                }
            }

            if (-not $isLab) {
                $dvd = Hyper-V\Get-VMDvdDrive -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($dvd -and $dvd.Path -and (Split-Path $dvd.Path -Leaf) -like "*cidata.iso") {
                    $isLab = $true
                }
            }
        }

        if ($isLab) {
            $vm
        }
    }

    return @($labVMs)
}
