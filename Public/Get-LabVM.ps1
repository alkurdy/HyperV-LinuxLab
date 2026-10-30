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
            $ip = ""
            $adapter = Hyper-V\Get-VMNetworkAdapter -VMName $vm.Name -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($adapter) {
                $validIPs = @($adapter.IPAddresses | Where-Object {
                    $_ -and $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' -and $_ -notlike '169.254*' -and $_ -ne '127.0.0.1'
                })
                if ($validIPs.Count -gt 0) {
                    $ip = $validIPs[0]
                }
            }

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

            [PSCustomObject]@{
                Name                = $vm.Name
                State               = $vm.State.ToString()
                IPv4                = $ip
                CPU                 = $vm.ProcessorCount
                MemoryMB            = [math]::Round($vm.MemoryAssigned / 1MB, 0)
                DifferencingDiskMB  = $diskSizeMB
                ParentBase          = $parentBase
                Uptime              = $vm.Uptime
            }
        }

        return $results
    }
}
