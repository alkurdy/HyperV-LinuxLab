function Set-LabConfiguration {
    <#
    .SYNOPSIS
        Sets persistent default configurations for Hyper-V Linux lab automation.
    .DESCRIPTION
        Saves user preferences (such as default storage volume or virtual switch) to
        ~/.hyperv-linuxlab/config.json. Enables users to deploy virtual disks to secondary
        high-capacity drives (e.g. D:\ or E:\) automatically without re-specifying on every command.
    .PARAMETER StoragePath
        Default root directory for base images and lab VM differencing disks (e.g. 'D:\HyperV-LinuxLab').
    .PARAMETER PreferredSwitch
        Default virtual switch name.
    .EXAMPLE
        Set-LabConfiguration -StoragePath "D:\HyperV-LinuxLab"
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$StoragePath,

        [Parameter(Mandatory = $false)]
        [string]$PreferredSwitch
    )

    $configDir = Join-Path $env:USERPROFILE ".hyperv-linuxlab"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $configFile = Join-Path $configDir "config.json"
    $existing = if (Test-Path $configFile) {
        try { Get-Content -Path $configFile -Raw | ConvertFrom-Json } catch { $null }
    } else {
        $null
    }

    $currentStorage = if ($StoragePath) {
        $StoragePath
    } elseif ($existing -and $existing.StoragePath) {
        $existing.StoragePath
    } else {
        "C:\HyperV-LinuxLab"
    }

    $currentSwitch = if ($PreferredSwitch) {
        $PreferredSwitch
    } elseif ($existing -and $existing.PreferredSwitch) {
        $existing.PreferredSwitch
    } else {
        "Default Switch"
    }

    if ($PSCmdlet.ShouldProcess($configFile, "Save configuration (Storage: $currentStorage, Switch: $currentSwitch)")) {
        $payload = [ordered]@{
            StoragePath     = $currentStorage
            PreferredSwitch = $currentSwitch
            UpdatedAt       = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }

        $json = $payload | ConvertTo-Json -Depth 4
        Set-Content -Path $configFile -Value $json -Encoding UTF8

        Write-Information "[OK] Lab configuration saved to '$configFile'." -InformationAction Continue
        Write-Information "     Default Storage : $currentStorage" -InformationAction Continue
        Write-Information "     Default Switch  : $currentSwitch" -InformationAction Continue

        return [PSCustomObject]@{
            StoragePath     = $currentStorage
            PreferredSwitch = $currentSwitch
            ConfigFile      = $configFile
        }
    }
}
