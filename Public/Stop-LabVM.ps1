function Stop-LabVM {
    <#
    .SYNOPSIS
        Shuts down or powers off a running Hyper-V Linux lab VM.
    .DESCRIPTION
        Gracefully requests guest shutdown or forces immediate power-off.
    .PARAMETER Name
        Names of one or more VMs to stop.
    .PARAMETER Force
        Forces immediate turn-off rather than graceful guest OS shutdown.
    .EXAMPLE
        Stop-LabVM -Name "linux-sandbox" -Force
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string[]]$Name,

        [switch]$Force
    )

    begin {
        Assert-Administrator
    }

    process {
        foreach ($vmName in $Name) {
            $vm = Hyper-V\Get-VM -Name $vmName -ErrorAction SilentlyContinue
            if (-not $vm) {
                Write-Warning "VM '$vmName' not found."
                continue
            }

            if ($PSCmdlet.ShouldProcess($vmName, "Stop Hyper-V Virtual Machine")) {
                if ($vm.State -eq 'Running') {
                    if ($Force) {
                        Hyper-V\Stop-VM -Name $vmName -TurnOff -Force | Out-Null
                    } else {
                        Hyper-V\Stop-VM -Name $vmName | Out-Null
                    }
                }

                [PSCustomObject]@{
                    Name  = $vmName
                    State = "Off"
                }
            }
        }
    }
}
