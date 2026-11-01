function Set-LabVMMetadata {
    <#
    .SYNOPSIS
        Persists and updates local metadata and Hyper-V VM Notes for a lab VM.
    .DESCRIPTION
        Saves VM configuration, credentials, distro information, and connection telemetry
        to a local 'metadata.json' file in the VM directory, and writes a human-readable
        summary to the Hyper-V VM's native Notes field for GUI inspection.
    .PARAMETER VMName
        Name of the virtual machine.
    .PARAMETER Distro
        Linux distribution identifier (e.g., Ubuntu2404, Debian12, AlmaLinux9).
    .PARAMETER Username
        Default sudo username configured inside the guest.
    .PARAMETER Password
        Plaintext passphrase/password.
    .PARAMETER IPv4
        Assigned guest IPv4 address.
    .PARAMETER SSH
        Ready-to-use SSH connection command.
    .PARAMETER Profile
        Toolchain profile applied to the VM.
    .PARAMETER ParentBase
        Parent base image filename.
    .PARAMETER LabStoragePath
        Path to lab VMs directory.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $false)]
        [string]$Distro,

        [Parameter(Mandatory = $false)]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [string]$Password,

        [Parameter(Mandatory = $false)]
        [string]$IPv4,

        [Parameter(Mandatory = $false)]
        [string]$SSH,

        [Parameter(Mandatory = $false)]
        [string]$Profile,

        [Parameter(Mandatory = $false)]
        [string]$ParentBase,

        [Parameter(Mandatory = $false)]
        [string]$LabStoragePath
    )

    if (-not $LabStoragePath) {
        $root = Get-LabStoragePath
        $LabStoragePath = Join-Path $root "LabVMs"
    }

    $vmDir = Join-Path $LabStoragePath $VMName
    $metaFile = Join-Path $vmDir "metadata.json"

    # Load existing metadata if present to merge updates
    $existing = if (Test-Path $metaFile) {
        try {
            Get-Content -Path $metaFile -Raw | ConvertFrom-Json
        } catch {
            $null
        }
    } else {
        $null
    }

    $resolvedDistro = if ($Distro) {
        $Distro
    } elseif ($existing -and $existing.Distro) {
        $existing.Distro
    } else {
        "Unknown"
    }

    $resolvedUser = if ($Username) {
        $Username
    } elseif ($existing -and $existing.Username) {
        $existing.Username
    } else {
        "labadmin"
    }

    $resolvedPass = if ($Password) {
        $Password
    } elseif ($existing -and $existing.Password) {
        $existing.Password
    } else {
        ""
    }

    $resolvedIP = if ($IPv4) {
        $IPv4
    } elseif ($existing -and $existing.IPv4) {
        $existing.IPv4
    } else {
        ""
    }

    $resolvedSSH = if ($SSH) {
        $SSH
    } elseif ($resolvedIP) {
        "ssh $resolvedUser@$resolvedIP"
    } elseif ($existing -and $existing.SSH) {
        $existing.SSH
    } else {
        ""
    }

    $resolvedProfile = if ($Profile) {
        $Profile
    } elseif ($existing -and $existing.Profile) {
        $existing.Profile
    } else {
        "None"
    }

    $resolvedBase = if ($ParentBase) {
        $ParentBase
    } elseif ($existing -and $existing.ParentBase) {
        $existing.ParentBase
    } else {
        ""
    }

    $createdTime = if ($existing -and $existing.CreatedAt) {
        $existing.CreatedAt
    } else {
        (Get-Date).ToString("o")
    }

    $metaObj = [ordered]@{
        Name       = $VMName
        Distro     = $resolvedDistro
        Username   = $resolvedUser
        Password   = $resolvedPass
        IPv4       = $resolvedIP
        SSH        = $resolvedSSH
        Profile    = $resolvedProfile
        ParentBase = $resolvedBase
        CreatedAt  = $createdTime
        UpdatedAt  = (Get-Date).ToString("o")
    }

    if (Test-Path $vmDir) {
        $metaObj | ConvertTo-Json -Depth 4 | Set-Content -Path $metaFile -Encoding UTF8 -Force
    }

    # Sync to native Hyper-V VM Notes
    $notesLines = @(
        "Distro: $resolvedDistro",
        "User: $resolvedUser"
    )
    if ($resolvedPass) { $notesLines += "Password: $resolvedPass" }
    if ($resolvedIP) { $notesLines += "IPv4: $resolvedIP" }
    if ($resolvedSSH) { $notesLines += "SSH: $resolvedSSH" }
    if ($resolvedProfile -and $resolvedProfile -ne "None") { $notesLines += "Profile: $resolvedProfile" }

    $notes = $notesLines -join "`n"
    Hyper-V\Set-VM -Name $VMName -Notes $notes -ErrorAction SilentlyContinue

    return [PSCustomObject]$metaObj
}
