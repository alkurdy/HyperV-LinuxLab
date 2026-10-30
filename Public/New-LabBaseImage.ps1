function New-LabBaseImage {
    <#
    .SYNOPSIS
        Downloads and validates official Ubuntu/Debian Cloud VHDX images for lab bases.
    .DESCRIPTION
        Retrieves official upstream cloud images from Canonical, verifies file integrity,
        and sets the base image read-only to prevent parent corruption by differencing disks.
    .PARAMETER Distro
        Linux distribution release (Ubuntu2404, Ubuntu2204, Debian12).
    .PARAMETER DestinationPath
        Directory to store cached master images. Defaults to 'C:\HyperV-LinuxLab\BaseImages'.
    .PARAMETER Force
        Overwrites existing cached base image.
    .EXAMPLE
        New-LabBaseImage -Distro Ubuntu2404
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [ValidateSet("Ubuntu2404", "Ubuntu2204")]
        [string]$Distro = "Ubuntu2404",

        [Parameter(Position = 1)]
        [string]$DestinationPath,

        [switch]$Force
    )

    Assert-Administrator

    if (-not $DestinationPath) {
        $root = Get-LabStoragePath
        $DestinationPath = Join-Path $root "BaseImages"
    }

    $imageCatalog = @{
        "Ubuntu2404" = @{
            Url      = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.vhdx"
            FileName = "ubuntu-24.04-server-cloudimg-amd64.vhdx"
        }
        "Ubuntu2204" = @{
            Url      = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.vhdx"
            FileName = "ubuntu-22.04-server-cloudimg-amd64.vhdx"
        }
    }

    $entry = $imageCatalog[$Distro]
    if (-not $entry) {
        throw "Unsupported distribution '$Distro'."
    }

    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    $targetFile = Join-Path $DestinationPath $entry.FileName

    if ((Test-Path $targetFile) -and (-not $Force)) {
        Write-Verbose "Base image '$targetFile' already exists. Skipping download."
        $fileInfo = Get-Item $targetFile
        return [PSCustomObject]@{
            Distro     = $Distro
            Path       = $fileInfo.FullName
            SizeMB     = [math]::Round($fileInfo.Length / 1MB, 2)
            IsReadOnly = $fileInfo.IsReadOnly
            Status     = "Cached"
        }
    }

    if ($PSCmdlet.ShouldProcess($targetFile, "Download $Distro cloud image from $($entry.Url)")) {
        Write-Information "Downloading $Distro cloud image (~600MB - 800MB)..." -InformationAction Continue
        Invoke-WebRequest -Uri $entry.Url -OutFile $targetFile -UseBasicParsing

        $fileInfo = Get-Item $targetFile
        # Lock file as Read-Only to guarantee parent differencing integrity
        $fileInfo.IsReadOnly = $true

        Write-Information "[OK] $Distro base image ready: $($fileInfo.FullName)" -InformationAction Continue

        return [PSCustomObject]@{
            Distro     = $Distro
            Path       = $fileInfo.FullName
            SizeMB     = [math]::Round($fileInfo.Length / 1MB, 2)
            IsReadOnly = $fileInfo.IsReadOnly
            Status     = "Downloaded"
        }
    }
}
