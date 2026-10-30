function Test-LabPrerequisites {
    <#
    .SYNOPSIS
        Validates host environment readiness for Hyper-V Linux lab automation.
    .DESCRIPTION
        Checks administrator elevation, Windows Edition compatibility (Pro/Enterprise/Server vs Home),
        Hyper-V role/module status, virtual switch availability, host physical RAM, target volume free space,
        and outbound internet connectivity to Ubuntu cloud image repositories.
    .PARAMETER StoragePath
        Path to evaluate available disk capacity for base VHDX and virtual disks. Default is 'C:\'.
    .PARAMETER MinimumFreeStorageGB
        Minimum free storage required in gigabytes. Default is 20 GB.
    .PARAMETER MinimumMemoryGB
        Minimum physical host RAM required in gigabytes. Default is 8 GB.
    .PARAMETER Detailed
        Displays full diagnostic properties for all tested subsystems.
    .PARAMETER TestHost
        Remote host used to test outbound network connectivity. Default is 'cloud-images.ubuntu.com'.
    .EXAMPLE
        Test-LabPrerequisites
    .EXAMPLE
        Test-LabPrerequisites -StoragePath "D:\" -MinimumFreeStorageGB 50 -Detailed
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$StoragePath = "C:\",

        [Parameter(Mandatory = $false)]
        [int]$MinimumFreeStorageGB = 20,

        [Parameter(Mandatory = $false)]
        [int]$MinimumMemoryGB = 8,

        [Parameter(Mandatory = $false)]
        [int]$MinimumCPUCount = 4,

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

    # 2. Windows Edition compatibility (Hyper-V requires Pro, Enterprise, Education, or Server)
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $regEdition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).EditionID
    $caption = if ($os) { $os.Caption } else { "Unknown" }
    $isHomeEdition = ($caption -match '\bHome\b') -or ($regEdition -match '^Core')
    $hyperVSupported = (-not $isHomeEdition)
    $checks["WindowsEditionSupported"] = $hyperVSupported

    # 3. Hyper-V module / role installed
    $hasHyperV = $null -ne (Get-Command 'Hyper-V\New-VM' -ErrorAction SilentlyContinue)
    $checks["HyperVModule"] = $hasHyperV

    # 4. Virtual switch availability
    $switches = Hyper-V\Get-VMSwitch -ErrorAction SilentlyContinue
    $checks["VirtualSwitchAvailable"] = ($null -ne $switches -and $switches.Count -gt 0)

    # 5. Host CPU Core capacity
    $processors = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $totalCores = 0
    foreach ($p in $processors) {
        $totalCores += $p.NumberOfLogicalProcessors
    }
    $cpuSufficient = ($totalCores -ge $MinimumCPUCount)
    $checks["CPUCoresSufficient"] = $cpuSufficient

    # 6. Host RAM capacity (minimum required for lab virtualization)
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $totalRamGB = if ($cs -and $cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { 0.0 }
    $ramSufficient = ($totalRamGB -ge $MinimumMemoryGB)
    $checks["MemoryCapacitySufficient"] = $ramSufficient

    # 7. Storage volume discovery across all fixed local drives
    $disks = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 }
    $discoveredVolumes = @()
    $recommendedDrive = "C:"
    $maxFreeBytes = 0

    foreach ($d in $disks) {
        $freeGB = [math]::Round($d.FreeSpace / 1GB, 1)
        $totalGB = [math]::Round($d.Size / 1GB, 1)
        $label = if ($d.VolumeName) { " ($($d.VolumeName))" } else { "" }
        $discoveredVolumes += "$($d.DeviceID)$label - ${freeGB} GB free of ${totalGB} GB"
        if ($d.FreeSpace -gt $maxFreeBytes) {
            $maxFreeBytes = $d.FreeSpace
            $recommendedDrive = $d.DeviceID
        }
    }

    # Evaluate target volume (explicit parameter, persistent config, or fallback)
    $targetPath = if ($StoragePath -and $StoragePath -ne "C:\") {
        $StoragePath
    } else {
        Get-LabStoragePath -ExplicitPath $StoragePath
    }

    $targetLetter = $targetPath.Substring(0, 1)
    $targetDisk = $disks | Where-Object { $_.DeviceID -eq "$targetLetter`:" } | Select-Object -First 1
    $targetFreeGB = if ($targetDisk) { [math]::Round($targetDisk.FreeSpace / 1GB, 1) } else { 0.0 }
    $storageSufficient = ($targetFreeGB -ge $MinimumFreeStorageGB)
    $checks["StorageCapacitySufficient"] = $storageSufficient

    # 8. Outbound network connectivity for cloud base images
    $canConnect = Test-Connection -ComputerName $TestHost -Count 1 -Quiet -ErrorAction SilentlyContinue
    $checks["CloudImageNetworkAccess"] = $canConnect

    $allPassed = (-not ($checks.Values -contains $false))

    $recommendation = if (-not $isAdmin) {
        "Re-launch PowerShell session as Administrator."
    } elseif (-not $hyperVSupported) {
        "Windows Home edition does not support Hyper-V natively. Windows Pro, Enterprise, Education, or Server is required."
    } elseif (-not $hasHyperV) {
        "Enable Hyper-V feature via: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All"
    } elseif (-not $checks["VirtualSwitchAvailable"]) {
        "Create a virtual switch in Hyper-V Manager or run: New-VMSwitch -Name 'LabSwitch' -SwitchType Internal"
    } elseif (-not $cpuSufficient) {
        "Host logical CPU cores ($totalCores) is below minimum recommended threshold ($MinimumCPUCount cores)."
    } elseif (-not $ramSufficient) {
        "Host physical RAM (${totalRamGB} GB) is below minimum recommended threshold (${MinimumMemoryGB} GB)."
    } elseif (-not $storageSufficient) {
        "Target path '$targetPath' has ${targetFreeGB} GB free, which is below the required ${MinimumFreeStorageGB} GB. Available drives: $($discoveredVolumes -join '; ')"
    } elseif (-not $canConnect) {
        "Cannot reach $TestHost. Verify internet connectivity or proxy configuration to download cloud images."
    } else {
        "Host is fully primed for Hyper-V Linux lab deployment."
    }

    $result = [PSCustomObject]@{
        Status                 = if ($allPassed) { "Ready" } else { "Failed" }
        AdministratorRights    = $isAdmin
        WindowsEdition         = "$caption ($regEdition)"
        HyperVSupported        = $hyperVSupported
        HyperVModule           = $hasHyperV
        VirtualSwitch          = $checks["VirtualSwitchAvailable"]
        LogicalCPUCores        = $totalCores
        TotalMemoryGB          = $totalRamGB
        TargetStoragePath      = $targetPath
        TargetFreeStorageGB    = $targetFreeGB
        DiscoveredVolumes      = $discoveredVolumes
        RecommendedDrive       = $recommendedDrive
        CloudImageAccess       = $canConnect
        Recommendation         = $recommendation
    }

    if ($Detailed) {
        return $result
    }

    if ($allPassed) {
        Write-Information "[OK] All prerequisites satisfied. Host is ready to deploy Hyper-V Linux labs." -InformationAction Continue
        if ($recommendedDrive -ne "$targetLetter`:" -and $targetFreeGB -lt 100) {
            Write-Information "     Tip: Drive $recommendedDrive has more free capacity. To deploy there by default, run:" -InformationAction Continue
            Write-Information "          Set-LabConfiguration -StoragePath '$recommendedDrive\HyperV-LinuxLab'" -InformationAction Continue
        }
    } else {
        $failedLines = @()
        if (-not $isAdmin) { $failedLines += "   Admin Rights : Not elevated -> Re-launch PowerShell as Administrator" }
        if (-not $hyperVSupported) { $failedLines += "   OS Edition   : $caption -> Windows Home does not support Hyper-V (Pro/Enterprise required)" }
        if (-not $hasHyperV) { $failedLines += "   Hyper-V Role : Not installed -> Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" }
        if (-not $checks["VirtualSwitchAvailable"]) { $failedLines += "   V-Switch     : Missing -> Create 'Default Switch' or Internal Switch in Hyper-V" }
        if (-not $cpuSufficient) { $failedLines += "   CPU Cores    : $totalCores logical cores (Minimum recommended: $MinimumCPUCount cores)" }
        if (-not $ramSufficient) { $failedLines += "   Host RAM     : ${totalRamGB} GB (Minimum recommended: ${MinimumMemoryGB} GB)" }
        if (-not $storageSufficient) {
            $failedLines += "   Disk Storage : ${targetFreeGB} GB free on $($targetLetter): (Minimum required: ${MinimumFreeStorageGB} GB)"
            $failedLines += "                  Available volumes: $($discoveredVolumes -join ', ')"
        }
        if (-not $canConnect) { $failedLines += "   Network      : Cannot connect to $TestHost -> Verify internet connection" }

        Write-Warning @"

============================================================
 [WARNING] Host Hardware / System Prerequisites Not Met
------------------------------------------------------------
$($failedLines -join "`n")
============================================================
"@
    }

    return $result
}
