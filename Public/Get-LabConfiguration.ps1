function Get-LabConfiguration {
    <#
    .SYNOPSIS
        Retrieves active persistent configuration settings for Hyper-V Linux lab automation.
    .DESCRIPTION
        Reads ~/.hyperv-linuxlab/config.json or returns default fallback paths.
    .EXAMPLE
        Get-LabConfiguration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $configFile = Join-Path $env:USERPROFILE ".hyperv-linuxlab\config.json"
    $storage = "C:\HyperV-LinuxLab"
    $switchName = "Default Switch"
    $isCustom = $false

    if (Test-Path $configFile) {
        try {
            $cfg = Get-Content -Path $configFile -Raw | ConvertFrom-Json
            if ($cfg.StoragePath) {
                $storage = $cfg.StoragePath
                $isCustom = $true
            }
            if ($cfg.PreferredSwitch) {
                $switchName = $cfg.PreferredSwitch
            }
        } catch {
            Write-Verbose "Could not parse config at '$configFile': $_"
        }
    }

    $driveLetter = $storage.Substring(0, 1)
    $drive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
    $freeGB = if ($drive) { [math]::Round($drive.Free / 1GB, 2) } else { 0.0 }

    return [PSCustomObject]@{
        StoragePath     = $storage
        BaseImagePath   = (Join-Path $storage "BaseImages")
        LabVMPath       = (Join-Path $storage "LabVMs")
        CloudInitPath   = (Join-Path $storage "CloudInit")
        StorageFreeGB   = $freeGB
        PreferredSwitch = $switchName
        IsConfigured    = $isCustom
        ConfigFile      = $configFile
    }
}
