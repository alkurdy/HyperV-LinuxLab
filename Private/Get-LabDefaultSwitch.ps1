function Get-LabDefaultSwitch {
    <#
    .SYNOPSIS
        Resolves the active Hyper-V Virtual Switch for lab VMs.
    .DESCRIPTION
        Attempts to locate 'Default Switch', or falls back to the first available
        Internal or External virtual switch on the host.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PreferredSwitch
    )

    if ($PreferredSwitch) {
        $sw = Hyper-V\Get-VMSwitch -Name $PreferredSwitch -ErrorAction SilentlyContinue
        if ($sw) {
            return $sw.Name
        }
        throw "Specified Hyper-V Virtual Switch '$PreferredSwitch' was not found on this host."
    }

    # Attempt to locate Windows 10/11 'Default Switch'
    $defaultSw = Hyper-V\Get-VMSwitch -Name "Default Switch" -ErrorAction SilentlyContinue
    if ($defaultSw) {
        return $defaultSw.Name
    }

    # Fall back to any active switch
    $anySw = Hyper-V\Get-VMSwitch -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($anySw) {
        return $anySw.Name
    }

    throw "No Hyper-V Virtual Switches found. Create an Internal or External switch in Hyper-V Manager."
}
