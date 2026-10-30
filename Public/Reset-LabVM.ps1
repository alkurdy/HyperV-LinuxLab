function Reset-LabVM {
    <#
    .SYNOPSIS
        Instantly resets a Linux lab VM to factory state in under 5 seconds.
    .DESCRIPTION
        Powers off the virtual machine, discards its child differencing VHDX, creates
        a brand-new empty differencing disk pointing to the golden base image, and boots
        the VM. This provides an instant rollback to a clean OS state without re-running installers.
    .PARAMETER Name
        Names of one or more VMs to reset. Accepts pipeline input.
    .PARAMETER Force
        Forces an immediate power off if the VM is running and bypasses confirmation prompts.
    .PARAMETER PassThru
        Returns the reset VM status object to the pipeline.
    .EXAMPLE
        Reset-LabVM -Name "linux-sandbox" -Force
    .EXAMPLE
        Get-LabVM -Name "k8s-*" | Reset-LabVM -Force
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string[]]$Name,

        [switch]$Force,

        [switch]$PassThru
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

            if ($Force -or $PSCmdlet.ShouldProcess($vmName, "Reset VM differencing disk to clean factory state")) {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                # 1. Power off VM
                if ($vm.State -eq 'Running') {
                    Write-Verbose "Stopping running VM '$vmName'..."
                    Hyper-V\Stop-VM -Name $vmName -TurnOff -Force:$Force | Out-Null
                }

                # 2. Inspect hard disk drives and identify differencing disk
                $hardDrive = Hyper-V\Get-VMHardDiskDrive -VMName $vmName | Select-Object -First 1
                if (-not $hardDrive -or -not (Test-Path $hardDrive.Path)) {
                    Write-Error "Could not locate virtual hard drive for '$vmName'."
                    continue
                }

                $diffPath = $hardDrive.Path
                if ($diffPath -match '\.avhdx$') {
                    Write-Verbose "Checkpoint chain detected ($diffPath). Collapsing snapshots..."
                    Hyper-V\Get-VMSnapshot -VMName $vmName -ErrorAction SilentlyContinue | Hyper-V\Remove-VMSnapshot | Out-Null
                    $hardDrive = Hyper-V\Get-VMHardDiskDrive -VMName $vmName | Select-Object -First 1
                    $diffPath = $hardDrive.Path
                }

                $vhdInfo = Hyper-V\Get-VHD -Path $diffPath
                $parentPath = $vhdInfo.ParentPath

                if (-not $parentPath -or -not (Test-Path $parentPath)) {
                    Write-Error "Virtual disk '$diffPath' does not have a valid parent base image."
                    continue
                }

                # 3. Discard Child Differencing Disk and recreate fresh
                Write-Verbose "Discarding child disk '$diffPath'..."
                Remove-Item -Path $diffPath -Force:$Force

                Write-Verbose "Spawning fresh differencing disk pointing to parent '$parentPath'..."
                New-VHD -ParentPath $parentPath -Path $diffPath -Differencing | Out-Null

                # 4. Boot VM fresh
                Write-Verbose "Powering on clean VM '$vmName'..."
                Hyper-V\Start-VM -Name $vmName | Out-Null

                $stopwatch.Stop()
                $elapsedSec = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
                Write-Information "[OK] VM '$vmName' successfully reset to factory state in ${elapsedSec}s." -InformationAction Continue

                if ($PassThru) {
                    [PSCustomObject]@{
                        Name          = $vmName
                        Status        = "Reset"
                        ResetDuration = "${elapsedSec}s"
                        ParentImage   = (Split-Path $parentPath -Leaf)
                        State         = "Running"
                    }
                }
            }
        }
    }
}
