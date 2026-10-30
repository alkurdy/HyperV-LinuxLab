function Get-LabStoragePath {
    <#
    .SYNOPSIS
        Resolves the root storage directory for Hyper-V Linux lab assets.
    .DESCRIPTION
        Checks user-specified path, persistent configuration in ~/.hyperv-linuxlab/config.json,
        or falls back to default 'C:\HyperV-LinuxLab'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ExplicitPath
    )

    if ($ExplicitPath) {
        return $ExplicitPath
    }

    $configPath = Join-Path $env:USERPROFILE ".hyperv-linuxlab\config.json"
    if (Test-Path $configPath) {
        try {
            $cfg = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            if ($cfg.StoragePath) {
                return $cfg.StoragePath
            }
        } catch {
            Write-Verbose "Could not read config at '$configPath': $_"
        }
    }

    return "C:\HyperV-LinuxLab"
}
