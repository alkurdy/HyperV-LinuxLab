function Disable-LabAutoStart {
    <#
    .SYNOPSIS
        Disables automatic computer startup for Hyper-V Linux lab virtual machines.
    .DESCRIPTION
        Reverts Hyper-V VM AutomaticStartAction back to 'Nothing' and/or unregisters
        the 'HyperV-LinuxLab-AutoStart' Windows Scheduled Task.
    .PARAMETER Name
        Names or wildcard patterns of specific lab VMs to configure.
    .PARAMETER Path
        Path to a cluster topology JSON file defining target nodes.
    .PARAMETER Mode
        Auto-start mechanism to disable: 'HyperV' (default), 'ScheduledTask', or 'Both'.
    .EXAMPLE
        Disable-LabAutoStart
    .EXAMPLE
        Disable-LabAutoStart -Mode Both
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true, Position = 0)]
        [string]$Path,

        [ValidateSet('HyperV', 'ScheduledTask', 'Both')]
        [string]$Mode = 'HyperV'
    )

    begin {
        Assert-Administrator
    }

    process {
        $targetVMs = @(Get-LabTargetVM -Name $Name -Path $Path)
        if ($targetVMs.Count -eq 0 -and $Mode -ne 'ScheduledTask') {
            Write-Warning "No Hyper-V Linux lab virtual machines were found."
            return @()
        }

        Write-Information "--- Disabling Lab Auto-Start (Mode: $Mode) ---" -InformationAction Continue

        $results = @()

        # 1. Native Hyper-V AutomaticStartAction
        if ($Mode -in @('HyperV', 'Both')) {
            foreach ($vm in $targetVMs) {
                $vmName = $vm.Name
                if ($PSCmdlet.ShouldProcess($vmName, "Set AutomaticStartAction to 'Nothing'")) {
                    Hyper-V\Set-VM -Name $vmName -AutomaticStartAction Nothing | Out-Null

                    Write-Information "[OK] VM '$vmName' AutomaticStartAction reset to Nothing." -InformationAction Continue

                    $results += [PSCustomObject]@{
                        Target               = $vmName
                        Type                 = "HyperV-VM"
                        AutomaticStartAction = "Nothing"
                        Status               = "Disabled"
                    }
                }
            }
        }

        # 2. Windows Scheduled Task
        if ($Mode -in @('ScheduledTask', 'Both')) {
            $taskName = "HyperV-LinuxLab-AutoStart"
            if ($PSCmdlet.ShouldProcess($taskName, "Unregister Scheduled Task '$taskName'")) {
                $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                if ($existing) {
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                    Write-Information "[OK] Unregistered Scheduled Task '$taskName'." -InformationAction Continue
                    $status = "Unregistered"
                } else {
                    Write-Information "[OK] Scheduled Task '$taskName' not registered." -InformationAction Continue
                    $status = "NotPresent"
                }

                $results += [PSCustomObject]@{
                    Target               = $taskName
                    Type                 = "ScheduledTask"
                    AutomaticStartAction = "None"
                    Status               = $status
                }
            }
        }

        # Standardized Terminal Summary Box
        $tableOutput = ($results | Format-Table Target, Type, AutomaticStartAction, Status | Out-String).Trim()

        Write-Information @"

============================================================
 [OK] Lab Auto-Start Disabled (Mode: $Mode)
------------------------------------------------------------
$tableOutput
============================================================
"@ -InformationAction Continue

        return $results
    }
}
