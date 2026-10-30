function Resolve-LabProfile {
    <#
    .SYNOPSIS
        Resolves a profile name or file path to package and runcmd configurations.
    .DESCRIPTION
        Inspects built-in profiles, user profile directory (~/.hyperv-linuxlab/profiles/),
        or absolute file paths.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Profile
    )

    if (-not $Profile) {
        return [PSCustomObject]@{
            Name        = "Custom"
            Description = "User-specified inline packages and commands"
            Packages    = @()
            RunCommands = @()
        }
    }

    # 1. Absolute / relative path check
    if (Test-Path $Profile) {
        $raw = Get-Content -Path $Profile -Raw | ConvertFrom-Json
        return [PSCustomObject]@{
            Name        = if ($raw.Name) { $raw.Name } else { (Split-Path $Profile -LeafBase) }
            Description = if ($raw.Description) { $raw.Description } else { "Custom profile loaded from $Profile" }
            Packages    = @($raw.Packages)
            RunCommands = @($raw.RunCommands)
        }
    }

    # 2. Built-in module directory
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $candidatePaths = @(
        (Join-Path $moduleRoot "Profiles\$Profile.json"),
        (Join-Path $moduleRoot "Profiles\$Profile"),
        (Join-Path $env:USERPROFILE ".hyperv-linuxlab\profiles\$Profile.json"),
        (Join-Path $env:USERPROFILE ".hyperv-linuxlab\profiles\$Profile")
    )

    foreach ($p in $candidatePaths) {
        if (Test-Path $p) {
            $raw = Get-Content -Path $p -Raw | ConvertFrom-Json
            return [PSCustomObject]@{
                Name        = if ($raw.Name) { $raw.Name } else { (Split-Path $p -LeafBase) }
                Description = if ($raw.Description) { $raw.Description } else { "" }
                Packages    = @($raw.Packages)
                RunCommands = @($raw.RunCommands)
            }
        }
    }

    # List available profiles for helpful error message
    $available = @()
    $builtinDir = Join-Path $moduleRoot "Profiles"
    if (Test-Path $builtinDir) {
        $available += (Get-ChildItem -Path $builtinDir -Filter "*.json" | ForEach-Object { $_.BaseName })
    }

    throw "Profile '$Profile' was not found. Available built-in profiles: $($available -join ', '). Or provide a valid path to a custom .json profile file."
}
