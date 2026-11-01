function Get-LabVMMetadata {
    <#
    .SYNOPSIS
        Retrieves persisted metadata for a lab VM.
    .DESCRIPTION
        Reads the local 'metadata.json' file associated with a virtual machine.
        If missing or corrupted, parses the Hyper-V VM Notes field as a fallback.
    .PARAMETER VMName
        Name of the virtual machine.
    .PARAMETER LabStoragePath
        Path to lab VMs directory.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$VMName,

        [Parameter(Mandatory = $false)]
        [string]$LabStoragePath
    )

    if (-not $LabStoragePath) {
        $root = Get-LabStoragePath
        $LabStoragePath = Join-Path $root "LabVMs"
    }

    $vmDir = Join-Path $LabStoragePath $VMName
    $metaFile = Join-Path $vmDir "metadata.json"

    if (Test-Path $metaFile) {
        try {
            $data = Get-Content -Path $metaFile -Raw | ConvertFrom-Json
            return [PSCustomObject]@{
                Name       = $VMName
                Distro     = if ($data.Distro) { $data.Distro } else { "Unknown" }
                Username   = if ($data.Username) { $data.Username } else { "labadmin" }
                Password   = if ($data.Password) { $data.Password } else { "" }
                IPv4       = if ($data.IPv4) { $data.IPv4 } else { "" }
                SSH        = if ($data.SSH) { $data.SSH } else { "" }
                Profile    = if ($data.Profile) { $data.Profile } else { "None" }
                ParentBase = if ($data.ParentBase) { $data.ParentBase } else { "" }
                CreatedAt  = if ($data.CreatedAt) { $data.CreatedAt } else { "" }
                UpdatedAt  = if ($data.UpdatedAt) { $data.UpdatedAt } else { "" }
            }
        } catch {
            Write-Verbose "Failed to read metadata.json for '$VMName': $_"
        }
    }

    # Fallback to Hyper-V VM Notes
    $vm = Hyper-V\Get-VM -Name $VMName -ErrorAction SilentlyContinue
    $notes = if ($vm) { $vm.Notes } else { "" }

    $distro = if ($notes -match '(?m)^Distro:\s*(.+)$') { $matches[1].Trim() } else { "Unknown" }
    $user = if ($notes -match '(?m)^User:\s*(.+)$') { $matches[1].Trim() } else { "labadmin" }
    $pass = if ($notes -match '(?m)^Password:\s*(.+)$') { $matches[1].Trim() } else { "" }
    $ip = if ($notes -match '(?m)^IPv4:\s*(.+)$') { $matches[1].Trim() } else { "" }
    $ssh = if ($notes -match '(?m)^SSH:\s*(.+)$') { $matches[1].Trim() } else { "" }
    $profVal = if ($notes -match '(?m)^Profile:\s*(.+)$') { $matches[1].Trim() } else { "None" }

    return [PSCustomObject]@{
        Name       = $VMName
        Distro     = $distro
        Username   = $user
        Password   = $pass
        IPv4       = $ip
        SSH        = $ssh
        Profile    = $profVal
        ParentBase = ""
        CreatedAt  = ""
        UpdatedAt  = ""
    }
}
