function New-LabBaseImage {
    <#
    .SYNOPSIS
        Downloads and validates official Ubuntu Cloud images and converts them to Hyper-V VHDX.
    .DESCRIPTION
        Retrieves official upstream Azure/Hyper-V cloud image archives from Canonical,
        extracts the virtual disk, converts it to dynamic VHDX, and sets the base image
        read-only to prevent parent corruption by differencing disks.
    .PARAMETER Distro
        Linux distribution release (Ubuntu2404, Ubuntu2204).
    .PARAMETER DestinationPath
        Directory to store cached master images. Defaults to '<LabStoragePath>\BaseImages'.
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

    # Pre-flight Scream Test on destination disk capacity (10GB required for download + conversion workspace)
    Assert-LabDiskSpace -Path $DestinationPath -RequiredGB 10.0 -Context "Base Image Download & Conversion" -Force:$Force | Out-Null

    $imageCatalog = @{
        "Ubuntu2404" = @{
            Url            = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64-azure.vhd.tar.gz"
            InternalVhd    = "livecd.ubuntu-cpc.azure.vhd"
            TargetFileName = "ubuntu-24.04-server-cloudimg-amd64.vhdx"
        }
        "Ubuntu2204" = @{
            Url            = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-azure.vhd.tar.gz"
            InternalVhd    = "livecd.ubuntu-cpc.azure.vhd"
            TargetFileName = "ubuntu-22.04-server-cloudimg-amd64.vhdx"
        }
    }

    $entry = $imageCatalog[$Distro]
    if (-not $entry) {
        throw "Unsupported distribution '$Distro'."
    }

    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    $targetFile = Join-Path $DestinationPath $entry.TargetFileName
    $archiveFile = Join-Path $DestinationPath "$($entry.TargetFileName).tar.gz"

    if (Test-Path $targetFile) {
        if (-not $Force) {
            Write-Verbose "Base image '$targetFile' already exists. Skipping download."
            $fileInfo = Get-Item $targetFile
            return [PSCustomObject]@{
                Distro     = $Distro
                Path       = $fileInfo.FullName
                SizeMB     = [math]::Round($fileInfo.Length / 1MB, 2)
                IsReadOnly = $fileInfo.IsReadOnly
                Status     = "Cached"
            }
        } else {
            Write-Verbose "Force specified. Unlocking and removing existing base image '$targetFile'."
            $existing = Get-Item $targetFile
            $existing.IsReadOnly = $false
            Remove-Item $targetFile -Force -ErrorAction SilentlyContinue
        }
    }

    if ($PSCmdlet.ShouldProcess($targetFile, "Download $Distro cloud image from $($entry.Url) and convert to VHDX")) {
        try {
            Write-Information "Downloading $Distro cloud image archive (~600MB - 800MB)..." -InformationAction Continue
            Invoke-WebRequest -Uri $entry.Url -OutFile $archiveFile -UseBasicParsing

            Write-Information "Extracting VHD from archive..." -InformationAction Continue
            $extractOutput = & tar.exe -xzf $archiveFile -C $DestinationPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to extract cloud image archive: $extractOutput"
            }

            # Locate extracted .vhd file
            $extractedVhd = Join-Path $DestinationPath $entry.InternalVhd
            if (-not (Test-Path $extractedVhd)) {
                $foundVhd = Get-ChildItem -Path $DestinationPath -Filter "*.vhd" | Select-Object -First 1
                if ($foundVhd) {
                    $extractedVhd = $foundVhd.FullName
                } else {
                    throw "Extracted VHD not found in '$DestinationPath'."
                }
            }

            Write-Information "Converting VHD to optimized dynamic VHDX ($($entry.TargetFileName))..." -InformationAction Continue
            Hyper-V\Convert-VHD -Path $extractedVhd -DestinationPath $targetFile -VHDType Dynamic -DeleteSource

            # Lock file as Read-Only to guarantee parent differencing integrity
            Set-ItemProperty -Path $targetFile -Name IsReadOnly -Value $true
            $fileInfo = Get-Item $targetFile

            Write-Information "[OK] $Distro base image ready: $($fileInfo.FullName)" -InformationAction Continue

            return [PSCustomObject]@{
                Distro     = $Distro
                Path       = $fileInfo.FullName
                SizeMB     = [math]::Round($fileInfo.Length / 1MB, 2)
                IsReadOnly = $fileInfo.IsReadOnly
                Status     = "Downloaded"
            }
        }
        finally {
            # Clean up temporary archive file if still present
            if (Test-Path $archiveFile) {
                Remove-Item $archiveFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
