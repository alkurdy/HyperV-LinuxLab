function Start-LabVM {
    <#
    .SYNOPSIS
        Powers on a Linux lab VM and optionally awaits network IP readiness.
    .DESCRIPTION
        Starts the Hyper-V virtual machine and polls the KVP integration service
        for an assigned IPv4 address.
    .PARAMETER Name
        Names of one or more VMs to start.
    .PARAMETER Wait
        Blocks until an IPv4 address is assigned to the guest.
    .PARAMETER TimeoutSeconds
        Maximum duration to wait for an IP address (default: 30s).
    .EXAMPLE
        Start-LabVM -Name "k8s-node01" -Wait
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string[]]$Name,

        [switch]$Wait,

        [int]$TimeoutSeconds = 30
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

            if ($PSCmdlet.ShouldProcess($vmName, "Start Hyper-V Virtual Machine")) {
                if ($vm.State -ne 'Running') {
                    Hyper-V\Start-VM -Name $vmName | Out-Null
                }

                $ip = ""
                if ($Wait) {
                    Write-Information "Waiting for VM '$vmName' to acquire an IP address..." -InformationAction Continue
                    $ip = Get-LabVMIPAddress -VMName $vmName -TimeoutSeconds $TimeoutSeconds
                    if ($ip) {
                        Write-Information @"

============================================================
 [OK] Linux Lab VM Ready!
------------------------------------------------------------
 Name    : $vmName
 Status  : Running
 IPv4    : $ip
 Connect : ssh labadmin@$ip
============================================================
"@ -InformationAction Continue
                    } else {
                        Write-Warning "VM '$vmName' started but did not report an IP within ${TimeoutSeconds}s."
                    }
                }

                [PSCustomObject]@{
                    Name  = $vmName
                    State = "Running"
                    IPv4  = $ip
                    SSH   = if ($ip) { "ssh labadmin@$ip" } else { "" }
                }
            }
        }
    }
}
