function Get-LabVM {
    <#
    .SYNOPSIS
        Retrieves status, IP address, and disk usage for Hyper-V Linux lab VMs.
    .DESCRIPTION
        Returns runtime telemetry for lab VMs, discovering guest IPv4 addresses via
        Hyper-V KVP data exchange and calculating host differencing disk consumption.
    .PARAMETER Name
        Optional name filter (supports wildcards, e.g., 'k8s-*').
    .EXAMPLE
        Get-LabVM
    .EXAMPLE
        Get-LabVM -Name "node-*" | Format-Table Name, State, IPv4, DifferencingDiskMB
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Name = @("*")
    )

    process {
        $vms = foreach ($n in $Name) {
            Hyper-V\Get-VM -Name $n -ErrorAction SilentlyContinue
        }

        $results = foreach ($vm in $vms) {
            $ip = Get-LabVMIPAddress -VMName $vm.Name -TimeoutSeconds 0

            $diskSizeMB = 0.0
            $parentBase = ""
            $hdd = Hyper-V\Get-VMHardDiskDrive -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hdd -and (Test-Path $hdd.Path)) {
                $item = Get-Item $hdd.Path
                $diskSizeMB = [math]::Round($item.Length / 1MB, 2)
                $vhd = Hyper-V\Get-VHD -Path $hdd.Path -ErrorAction SilentlyContinue
                if ($vhd -and $vhd.ParentPath) {
                    $parentBase = Split-Path $vhd.ParentPath -Leaf
                }
            }

            # Retrieve local metadata
            $meta = Get-LabVMMetadata -VMName $vm.Name

            # Infer distro if metadata is Unknown but ParentBase is known
            $distro = if ($meta.Distro -and $meta.Distro -ne "Unknown") {
                $meta.Distro
            } elseif ($parentBase -match "ubuntu-24") {
                "Ubuntu2404"
            } elseif ($parentBase -match "ubuntu-22") {
                "Ubuntu2204"
            } elseif ($parentBase -match "debian-12") {
                "Debian12"
            } elseif ($parentBase -match "AlmaLinux-9") {
                "AlmaLinux9"
            } else {
                "Custom"
            }

            # Update cached IP in metadata if newly discovered
            $effectiveIP = if ($ip) { $ip } else { $meta.IPv4 }
            if ($ip -and $ip -ne $meta.IPv4) {
                Set-LabVMMetadata -VMName $vm.Name -IPv4 $ip -Distro $distro | Out-Null
            }

            $user = if ($meta.Username) { $meta.Username } else { "labadmin" }
            $sshCmd = if ($effectiveIP) {
                "ssh $user@$effectiveIP"
            } else {
                ""
            }

            [PSCustomObject]@{
                Name                = $vm.Name
                Distro              = $distro
                State               = $vm.State.ToString()
                IPv4                = $effectiveIP
                Username            = $user
                Password            = $meta.Password
                SSH                 = $sshCmd
                CPU                 = $vm.ProcessorCount
                MemoryMB            = [math]::Round($vm.MemoryAssigned / 1MB, 0)
                DifferencingDiskMB  = $diskSizeMB
                ParentBase          = if ($parentBase) { $parentBase } else { $meta.ParentBase }
                Profile             = $meta.Profile
                Uptime              = $vm.Uptime
            }
        }

        return $results
    }
}
