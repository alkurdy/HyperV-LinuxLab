function Get-LabHostSystemInfo {
    <#
    .SYNOPSIS
        Discovers host hardware telemetry including logical CPU cores, physical RAM, and volume capacities.
    .DESCRIPTION
        Centralized hardware discovery helper providing host resource capacity metrics
        for pre-flight validation and cluster sizing checks.
    .PARAMETER TargetPath
        Optional path to check free storage capacity against. Defaults to 'C:\'.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TargetPath = "C:\"
    )

    # 1. Host Logical CPU cores
    $totalCores = 0
    try {
        $processors = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
        if ($processors) {
            foreach ($p in $processors) {
                if ($p.NumberOfLogicalProcessors) {
                    $totalCores += [int]$p.NumberOfLogicalProcessors
                }
            }
        }
    } catch {
        Write-Verbose "Could not query Win32_Processor: $_"
    }
    if ($totalCores -eq 0) {
        $totalCores = [Environment]::ProcessorCount
    }

    # 2. Host Physical Memory (Total & Free)
    $totalRamGB = 0.0
    $freeRamGB = 0.0
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs -and $cs.TotalPhysicalMemory) {
            $totalRamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        }

        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os -and $os.FreePhysicalMemory) {
            $freeRamGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        }
    } catch {
        Write-Verbose "Could not query Win32_ComputerSystem or Win32_OperatingSystem: $_"
    }

    # 3. Fixed Disk Volume Discovery
    $discoveredVolumes = @()
    $recommendedDrive = "C:"
    $maxFreeBytes = 0
    $disks = @()

    try {
        $disks = @(Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 })
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
    } catch {
        Write-Verbose "Could not query Win32_LogicalDisk: $_"
    }

    # 4. Target Path Capacity
    $targetDriveLetter = if ($TargetPath -match '^([a-zA-Z]):') { $Matches[1] } else { "C" }
    $targetDisk = $disks | Where-Object { $_.DeviceID -eq "$targetDriveLetter`:" } | Select-Object -First 1

    $targetFreeGB = 0.0
    if ($targetDisk -and $null -ne $targetDisk.FreeSpace) {
        $targetFreeGB = [math]::Round($targetDisk.FreeSpace / 1GB, 1)
    } else {
        $psDrive = Get-PSDrive -Name $targetDriveLetter -ErrorAction SilentlyContinue
        if ($psDrive -and $null -ne $psDrive.Free) {
            $targetFreeGB = [math]::Round($psDrive.Free / 1GB, 1)
        }
    }

    return [PSCustomObject]@{
        LogicalCPUCores     = $totalCores
        TotalMemoryGB       = $totalRamGB
        FreeMemoryGB        = $freeRamGB
        TargetDriveLetter   = $targetDriveLetter
        TargetFreeStorageGB = $targetFreeGB
        DiscoveredVolumes   = $discoveredVolumes
        RecommendedDrive    = $recommendedDrive
    }
}
