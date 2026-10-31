function Stop-Lab {
    <#
    .SYNOPSIS
        Stops all running Linux lab virtual machines or a specific cluster topology.
    .DESCRIPTION
        Gracefully requests guest operating system shutdown or forces immediate power-off
        for all active Hyper-V Linux lab virtual machines.
    .PARAMETER Name
        Optional names or wildcard patterns of specific lab VMs to stop.
    .PARAMETER Path
        Path to a cluster topology JSON file defining the target nodes.
    .PARAMETER Force
        Forces an immediate power-off (TurnOff) rather than graceful OS shutdown.
    .PARAMETER Wait
        Blocks execution until each virtual machine transitions to the 'Off' state.
    .PARAMETER TimeoutSeconds
        Maximum duration in seconds to wait for shutdown (default: 60s).
    .EXAMPLE
        Stop-Lab
    .EXAMPLE
        Stop-Lab -Force
    .EXAMPLE
        Stop-Lab -Path .\examples\k8s-3node-cluster.json -Wait
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true, Position = 0)]
        [string]$Path,

        [switch]$Force,

        [switch]$Wait,

        [int]$TimeoutSeconds = 60
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
        Write-Information "--- Stopping Hyper-V Linux Lab ($nodeCount node$(if ($nodeCount -ne 1) { 's' })) ---" -InformationAction Continue

        $results = @()
        foreach ($vm in $targetVMs) {
            $vmName = $vm.Name

            if ($PSCmdlet.ShouldProcess($vmName, "Stop Hyper-V Virtual Machine")) {
                if ($vm.State -eq 'Running') {
                    if ($Force) {
                        Hyper-V\Stop-VM -Name $vmName -TurnOff -Force | Out-Null
                    } else {
                        Hyper-V\Stop-VM -Name $vmName | Out-Null
                    }

                    if ($Wait) {
                        Write-Information "Waiting for VM '$vmName' to power off..." -InformationAction Continue
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
                            $current = Hyper-V\Get-VM -Name $vmName -ErrorAction SilentlyContinue
                            if (-not $current -or $current.State -eq 'Off') {
                                break
                            }
                            Start-Sleep -Milliseconds 1000
                        }
                    }

                    Write-Information "[OK] VM '$vmName' stopped." -InformationAction Continue
                } else {
                    Write-Information "[OK] VM '$vmName' is already off." -InformationAction Continue
                }

                $results += [PSCustomObject]@{
                    Name  = $vmName
                    State = "Off"
                }
            }
        }

        # Standardized Terminal Summary Box
        $tableOutput = ($results | Format-Table Name, State | Out-String).Trim()

        Write-Information @"

============================================================
 [OK] Hyper-V Linux Lab Stopped ($($results.Count) Nodes)
------------------------------------------------------------
$tableOutput
============================================================
"@ -InformationAction Continue

        return $results
    }
}
