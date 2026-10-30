function Get-LabVMIPAddress {
    <#
    .SYNOPSIS
        Queries the assigned IPv4 address of a running Hyper-V Linux VM.
    .DESCRIPTION
        Inspects Hyper-V Integration Services network adapter data exchange to resolve
        the guest's assigned IPv4 address.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $vm = Hyper-V\Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if (-not $vm -or $vm.State -ne 'Running') {
            return ""
        }

        $adapters = Hyper-V\Get-VMNetworkAdapter -VMName $VMName -ErrorAction SilentlyContinue
        foreach ($adapter in $adapters) {
            $ips = @($adapter.IPAddresses | Where-Object {
                $_ -and $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' -and $_ -notlike '169.254*' -and $_ -ne '127.0.0.1'
            })
            if ($ips.Count -gt 0) {
                return $ips[0]
            }
        }

        Start-Sleep -Milliseconds 1500
    }

    return ""
}
