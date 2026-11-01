function Get-LabVMIPAddress {
    <#
    .SYNOPSIS
        Queries the assigned IPv4 address of a running Hyper-V Linux VM.
    .DESCRIPTION
        Inspects Hyper-V Integration Services network adapter data exchange to resolve
        the guest's assigned IPv4 address. Supports instantaneous single-pass checks
        (TimeoutSeconds = 0) or polling with a configurable timeout.
    .PARAMETER VMName
        Name of the virtual machine.
    .PARAMETER TimeoutSeconds
        Maximum duration to wait for an IP address. Default is 30s. Specify 0 for non-blocking single-pass check.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    do {
        $vm = Hyper-V\Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if (-not $vm -or $vm.State -ne 'Running') {
            return ""
        }

        $adapters = Hyper-V\Get-VMNetworkAdapter -VMName $VMName -ErrorAction SilentlyContinue
        if ($adapters) {
            foreach ($adapter in $adapters) {
                if ($adapter.IPAddresses) {
                    $ips = @($adapter.IPAddresses | Where-Object {
                        $_ -and $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' -and $_ -notlike '169.254*' -and $_ -ne '127.0.0.1'
                    })
                    if ($ips.Count -gt 0) {
                        return $ips[0]
                    }
                }
            }
        }

        if ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            Start-Sleep -Milliseconds 1500
        }
    } while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds)

    return ""
}
