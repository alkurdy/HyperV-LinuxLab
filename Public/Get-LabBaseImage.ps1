function Get-LabBaseImage {
    <#
    .SYNOPSIS
        Lists locally cached Linux golden base images.
    .DESCRIPTION
        Inspects base image storage directory and returns metadata on available parent VHDX images.
    .PARAMETER Path
        Directory containing master VHDX images. Defaults to 'C:\HyperV-LinuxLab\BaseImages'.
    .EXAMPLE
        Get-LabBaseImage
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Position = 0)]
        [string]$Path = "C:\HyperV-LinuxLab\BaseImages"
    )

    if (-not (Test-Path $Path)) {
        return @()
    }

    $files = Get-ChildItem -Path $Path -Filter "*.vhdx" -ErrorAction SilentlyContinue
    $results = foreach ($f in $files) {
        $distroName = if ($f.Name -match "24\.04") { "Ubuntu2404" } `
                      elseif ($f.Name -match "22\.04") { "Ubuntu2204" } `
                      else { "Custom" }

        [PSCustomObject]@{
            Distro     = $distroName
            Name       = $f.Name
            Path       = $f.FullName
            SizeMB     = [math]::Round($f.Length / 1MB, 2)
            IsReadOnly = $f.IsReadOnly
            Created    = $f.CreationTime
        }
    }

    return $results
}
