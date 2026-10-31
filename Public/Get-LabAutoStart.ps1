function Get-LabAutoStart {
    <#
    .SYNOPSIS
        Queries computer startup configuration for Hyper-V Linux lab virtual machines.
    .DESCRIPTION
        Inspects native Hyper-V AutomaticStartAction settings on lab virtual machines
        and reports the presence and state of the 'HyperV-LinuxLab-AutoStart' Scheduled Task.
    .PARAMETER Name
        Optional names or wildcard patterns of specific lab VMs to query.
    .PARAMETER Path
        Optional path to a cluster topology JSON file defining target nodes.
    .EXAMPLE
        Get-LabAutoStart
    .EXAMPLE
        Get-LabAutoStart -Name "k8s-*"
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'ByPath', Position = 0)]
        [string]$Path
    )

    process {
        $targetVMs = Get-LabTargetVM -Name $Name -Path $Path
        $results = @()

        foreach ($vm in $targetVMs) {
            $results += [PSCustomObject]@{
                Target               = $vm.Name
                Type                 = "HyperV-VM"
                AutomaticStartAction = $vm.AutomaticStartAction.ToString()
                DelaySeconds         = $vm.AutomaticStartDelay
                AutomaticStopAction  = $vm.AutomaticStopAction.ToString()
                Status               = if ($vm.AutomaticStartAction -eq 'Start') { "Enabled" } else { "Disabled" }
            }
        }

        # Query Scheduled Task status
        $taskName = "HyperV-LinuxLab-AutoStart"
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            $triggerDesc = if ($task.Triggers) {
                ($task.Triggers | ForEach-Object { $_.CimClass.CimClassName -replace '^MSFT_Task' -replace 'Trigger$' }) -join ", "
            } else {
                "Unknown"
            }

            $results += [PSCustomObject]@{
                Target               = $taskName
                Type                 = "ScheduledTask"
                AutomaticStartAction = $triggerDesc
                DelaySeconds         = 0
                AutomaticStopAction  = "N/A"
                Status               = $task.State.ToString()
            }
        }

        $tableOutput = ($results | Format-Table Target, Type, AutomaticStartAction, DelaySeconds, Status | Out-String).Trim()

        Write-Information @"

============================================================
 [LAB AUTO-START STATUS] Hyper-V Linux Lab
------------------------------------------------------------
$tableOutput
============================================================
"@ -InformationAction Continue

        return $results
    }
}
