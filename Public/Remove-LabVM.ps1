function Remove-LabVM {
    <#
    .SYNOPSIS
        Tears down a Linux lab VM and deletes its child differencing assets.
    .DESCRIPTION
        Powers off the VM, removes its definition from Hyper-V, and deletes the associated
        differencing VHDX and Cloud-Init ISO files from host storage. Leaves parent base images intact.
    .PARAMETER Name
        Names of one or more VMs to remove. Accepts pipeline input.
    .PARAMETER Force
        Forces removal without interactive confirmation prompts.
    .EXAMPLE
        Remove-LabVM -Name "linux-sandbox" -Force
    .EXAMPLE
        Get-LabVM -Name "k8s-*" | Remove-LabVM -Force
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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
                Write-Warning "Virtual machine '$vmName' was not found in Hyper-V."
                continue
            }

            if ($Force -or $PSCmdlet.ShouldProcess($vmName, "Remove VM and delete differencing storage")) {
                if ($vm.State -eq 'Running') {
                    Write-Verbose "Stopping running VM '$vmName'..."
                    Hyper-V\Stop-VM -Name $vmName -TurnOff -Force:$Force | Out-Null
                }

                # Locate virtual disk and configuration files
                $pathsToDelete = @()
                $hdd = Hyper-V\Get-VMHardDiskDrive -VMName $vmName -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($hdd -and (Test-Path $hdd.Path)) {
                    $pathsToDelete += (Split-Path $hdd.Path -Parent)
                }

                # Remove VM from Hyper-V
                Write-Verbose "Removing VM '$vmName' from Hyper-V..."
                Hyper-V\Remove-VM -Name $vmName -Force:$Force | Out-Null

                # Clean up VM directory on disk
                foreach ($p in $pathsToDelete) {
                    if (Test-Path $p) {
                        Write-Verbose "Cleaning up VM folder '$p'..."
                        Remove-Item -Path $p -Recurse -Force:$Force -ErrorAction SilentlyContinue
                    }
                }

                Write-Information "[OK] Removed VM '$vmName' and deleted local differencing storage." -InformationAction Continue
            }
        }
    }
}
