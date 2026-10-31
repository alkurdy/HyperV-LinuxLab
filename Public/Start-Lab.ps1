function Start-Lab {
    <#
    .SYNOPSIS
        Powers on all Linux lab virtual machines or a specific cluster topology.
    .DESCRIPTION
        Discovers and powers on Hyper-V Linux lab virtual machines, with optional
        support for waiting for guest IPv4 network address acquisition and standardized
        connection telemetry.
    .PARAMETER Name
        Optional names or wildcard patterns of specific lab VMs to start.
    .PARAMETER Path
        Path to a cluster topology JSON file defining the target nodes.
    .PARAMETER Wait
        Blocks execution until each VM acquires an IPv4 address via Hyper-V KVP data exchange.
    .PARAMETER TimeoutSeconds
        Maximum duration in seconds to wait for network IP assignment per VM (default: 45s).
    .EXAMPLE
        Start-Lab
    .EXAMPLE
        Start-Lab -Wait
    .EXAMPLE
        Start-Lab -Path .\examples\k8s-3node-cluster.json -Wait
    .EXAMPLE
        Start-Lab -Name "k8s-*" -Wait
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true, Position = 0)]
        [string]$Path,

        [switch]$Wait,

        [int]$TimeoutSeconds = 45
    )

    begin {
        Assert-Administrator
    }

    process {
        $targetVMs = Get-LabTargetVM -Name $Name -Path $Path
        if (-not $targetVMs -or $targetVMs.Count -eq 0) {
            Write-Warning "No Hyper-V Linux lab virtual machines were found."
            return @()
        }

        $nodeCount = $targetVMs.Count
        Write-Information "--- Starting Hyper-V Linux Lab ($nodeCount node$(if ($nodeCount -ne 1) { 's' })) ---" -InformationAction Continue

        $results = @()
        foreach ($vm in $targetVMs) {
            $vmName = $vm.Name

            if ($PSCmdlet.ShouldProcess($vmName, "Start Hyper-V Virtual Machine")) {
                if ($vm.State -ne 'Running') {
                    Hyper-V\Start-VM -Name $vmName | Out-Null
                    Write-Information "[OK] VM '$vmName' powered on." -InformationAction Continue
                } else {
                    Write-Information "[OK] VM '$vmName' is already running." -InformationAction Continue
                }

                $ip = ""
                if ($Wait) {
                    Write-Information "Waiting for VM '$vmName' to acquire an IP address..." -InformationAction Continue
                    $ip = Get-LabVMIPAddress -VMName $vmName -TimeoutSeconds $TimeoutSeconds
                    if (-not $ip) {
                        Write-Warning "VM '$vmName' started but did not report an IP within ${TimeoutSeconds}s."
                    }
                } else {
                    # Attempt quick non-blocking discovery of existing IP
                    $adapter = Hyper-V\Get-VMNetworkAdapter -VMName $vmName -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($adapter) {
                        $validIPs = @($adapter.IPAddresses | Where-Object {
                            $_ -and $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' -and $_ -notlike '169.254*' -and $_ -ne '127.0.0.1'
                        })
                        if ($validIPs.Count -gt 0) {
                            $ip = $validIPs[0]
                        }
                    }
                }

                $results += [PSCustomObject]@{
                    Name  = $vmName
                    State = "Running"
                    IPv4  = $ip
                    SSH   = if ($ip) { "ssh labadmin@$ip" } else { "" }
                }
            }
        }

        # Standardized Terminal Summary Box
        $sshEntries = $results | Where-Object { $_.IPv4 }
        $sshListing = if ($sshEntries.Count -gt 0) {
            "`n SSH Access:`n" + (($sshEntries | ForEach-Object { "   $($_.Name): $($_.SSH)" }) -join "`n")
        } else {
            ""
        }

        $tableOutput = ($results | Format-Table Name, State, IPv4, SSH | Out-String).Trim()

        Write-Information @"

============================================================
 [LAB READY] Hyper-V Linux Lab ($($results.Count) Nodes)
------------------------------------------------------------
$tableOutput$sshListing
============================================================
"@ -InformationAction Continue

        return $results
    }
}
