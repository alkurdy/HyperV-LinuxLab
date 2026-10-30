function Test-LabPrerequisites {
    <#
    .SYNOPSIS
        Validates host environment readiness for Hyper-V Linux lab automation.
    .DESCRIPTION
        Checks administrator elevation, Hyper-V role status, virtual switch availability,
        disk free space, and outbound internet connectivity to cloud image repositories.
    .PARAMETER Detailed
        Displays full diagnostic properties for all tested subsystems.
    .EXAMPLE
        Test-LabPrerequisites
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed,

        [Parameter(Mandatory = $false)]
        [string]$TestHost = "cloud-images.ubuntu.com"
    )

    $checks = [ordered]@{}

    # 1. Administrator elevation
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $checks["AdministratorRights"] = $isAdmin

    # 2. Hyper-V module / role
    $hasHyperV = $null -ne (Get-Command 'Hyper-V\New-VM' -ErrorAction SilentlyContinue)
    $checks["HyperVModule"] = $hasHyperV

    # 3. Virtual switch
    $switches = Hyper-V\Get-VMSwitch -ErrorAction SilentlyContinue
    $checks["VirtualSwitchAvailable"] = ($null -ne $switches -and $switches.Count -gt 0)

    # 4. Storage free space (>= 10 GB on C:)
    $drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    $checks["StorageCapacity10GB"] = ($freeGB -ge 10.0)

    # 5. Outbound network connectivity
    $canConnect = Test-Connection -ComputerName $TestHost -Count 1 -Quiet -ErrorAction SilentlyContinue
    $checks["CloudImageNetworkAccess"] = $canConnect

    $allPassed = (-not ($checks.Values -contains $false))

    $result = [PSCustomObject]@{
        Status               = if ($allPassed) { "Ready" } else { "Failed" }
        AdministratorRights  = $checks["AdministratorRights"]
        HyperVModule         = $checks["HyperVModule"]
        VirtualSwitch        = $checks["VirtualSwitchAvailable"]
        FreeStorageGB        = $freeGB
        CloudImageAccess     = $checks["CloudImageNetworkAccess"]
        Recommendation       = if (-not $isAdmin) { "Re-launch PowerShell as Administrator." } `
                               elseif (-not $hasHyperV) { "Enable Hyper-V feature via Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" } `
                               elseif (-not $checks["VirtualSwitchAvailable"]) { "Create a virtual switch in Hyper-V Manager." } `
                               else { "Host is fully primed for Linux lab deployment." }
    }

    if ($Detailed) {
        return $result
    }

    if ($allPassed) {
        Write-Information "[OK] All prerequisites satisfied. Host is ready to deploy Hyper-V Linux labs." -InformationAction Continue
    } else {
        Write-Warning "Prerequisite checks failed: $($result.Recommendation)"
    }

    return $result
}
