function Assert-LabDiskSpace {
    <#
    .SYNOPSIS
        Evaluates target drive capacity and renders a high-visibility alert banner if space is insufficient.
    .DESCRIPTION
        Pre-flight safety gate preventing base image downloads and differencing disk allocations
        from exhausting host storage. Recommends alternative volumes if available.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [double]$RequiredGB = 10.0,

        [Parameter(Mandatory = $false)]
        [string]$Context = "Virtual Machine Deployment",

        [switch]$Force
    )

    $driveLetter = $Path.Substring(0, 1)
    $drive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
    $freeGB = if ($drive) { [math]::Round($drive.Free / 1GB, 2) } else { 0.0 }

    if ($freeGB -ge $RequiredGB) {
        return $true
    }

    # Discover alternative fixed drives that have space
    $disks = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 }
    $alternatives = @()
    foreach ($d in $disks) {
        $altFree = [math]::Round($d.FreeSpace / 1GB, 1)
        if ($altFree -ge $RequiredGB -and $d.DeviceID -ne "$($driveLetter):") {
            $label = if ($d.VolumeName) { " ($($d.VolumeName))" } else { "" }
            $alternatives += "$($d.DeviceID)$label -> ${altFree} GB free"
        }
    }

    $deficitGB = [math]::Round($RequiredGB - $freeGB, 2)

    $lines = @()
    $lines += "================================================================================"
    $lines += " [SCREAM ALERT] INSUFFICIENT DISK CAPACITY FOR $Context"
    $lines += "--------------------------------------------------------------------------------"
    $lines += " Target Drive   : $($driveLetter): ($Path)"
    $lines += " Available Space: $freeGB GB"
    $lines += " Required Space : $RequiredGB GB"
    $lines += " Deficit        : -$deficitGB GB (TOO LOW FOR SAFE DEPLOYMENT)"
    $lines += "--------------------------------------------------------------------------------"

    if ($alternatives.Count -gt 0) {
        $lines += " ALTERNATIVE HIGH-CAPACITY VOLUMES DETECTED ON THIS HOST:"
        foreach ($alt in $alternatives) {
            $lines += "   * $alt"
        }
        $firstAltDrive = ($alternatives[0].Split(' ')[0]).TrimEnd(':')
        $lines += " SWITCH STORAGE ROOT INSTANTLY BY RUNNING:"
        $lines += "   Set-LabConfiguration -StoragePath '$firstAltDrive`:\HyperV-LinuxLab'"
    } else {
        $lines += " ACTION REQUIRED:"
        $lines += "   Free up at least $deficitGB GB on drive $($driveLetter): before continuing."
    }

    $lines += " (Pass -Force to override this safety check at your own risk)"
    $lines += "================================================================================"

    $alertBanner = ($lines -join "`n")
    Write-Warning $alertBanner

    if (-not $Force) {
        throw "Deployment halted by storage scream test: Volume $($driveLetter): has insufficient space ($freeGB GB free, $RequiredGB GB required)."
    }

    return $false
}
