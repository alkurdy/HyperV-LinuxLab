function Get-LabProfile {
    <#
    .SYNOPSIS
        Discovers and lists available toolchain and configuration profiles.
    .DESCRIPTION
        Scans module built-in profiles and user directory (~/.hyperv-linuxlab/profiles/)
        for declarative .json profile templates.
    .PARAMETER Name
        Optional profile name filter (supports wildcards, e.g. 'Kube*').
    .EXAMPLE
        Get-LabProfile
    .EXAMPLE
        Get-LabProfile -Name "Container" | Format-List
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Name = "*"
    )

    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $searchDirs = @(
        @{ Type = "BuiltIn"; Path = (Join-Path $moduleRoot "Profiles") },
        @{ Type = "User";    Path = (Join-Path $env:USERPROFILE ".hyperv-linuxlab\profiles") }
    )

    $results = @()
    foreach ($entry in $searchDirs) {
        if (Test-Path $entry.Path) {
            $files = Get-ChildItem -Path $entry.Path -Filter "*.json" -ErrorAction SilentlyContinue |
                Where-Object { $_.BaseName -like $Name }

            foreach ($f in $files) {
                try {
                    $content = Get-Content -Path $f.FullName -Raw | ConvertFrom-Json
                    $results += [PSCustomObject]@{
                        Name         = if ($content.Name) { $content.Name } else { $f.BaseName }
                        Type         = $entry.Type
                        Description  = $content.Description
                        PackageCount = if ($content.Packages) { @($content.Packages).Count } else { 0 }
                        CommandCount = if ($content.RunCommands) { @($content.RunCommands).Count } else { 0 }
                        Path         = $f.FullName
                    }
                } catch {
                    Write-Verbose "Could not parse JSON profile at '$($f.FullName)': $_"
                }
            }
        }
    }

    return $results
}
