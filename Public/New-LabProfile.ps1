function New-LabProfile {
    <#
    .SYNOPSIS
        Scaffolds a new declarative toolchain profile JSON file.
    .DESCRIPTION
        Creates a custom profile template in the user profile directory (~/.hyperv-linuxlab/profiles/)
        or a specified destination directory.
    .PARAMETER Name
        Identifier for the new profile (e.g. 'SecurityLab', 'PythonDev').
    .PARAMETER Description
        Brief summary of what packages and tools the profile installs.
    .PARAMETER Packages
        Array of apt package names to include.
    .PARAMETER RunCommands
        Array of shell commands to execute after packages are installed.
    .PARAMETER DestinationPath
        Directory to write the profile JSON. Defaults to user profile repository (~/.hyperv-linuxlab/profiles/).
    .PARAMETER Force
        Overwrites existing profile if present.
    .EXAMPLE
        New-LabProfile -Name "SecurityLab" -Description "Penetration testing & network analysis" -Packages @("nmap", "wireshark", "tcpdump")
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description = "Custom lab toolchain profile",

        [Parameter(Mandatory = $false)]
        [string[]]$Packages = @("curl", "git", "jq", "htop", "tmux"),

        [Parameter(Mandatory = $false)]
        [string[]]$RunCommands = @(),

        [Parameter(Mandatory = $false)]
        [string]$DestinationPath,

        [switch]$Force
    )

    if (-not $DestinationPath) {
        $DestinationPath = Join-Path $env:USERPROFILE ".hyperv-linuxlab\profiles"
    }

    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    $targetFile = Join-Path $DestinationPath "$Name.json"

    if ((Test-Path $targetFile) -and (-not $Force)) {
        throw "Profile file already exists at '$targetFile'. Use -Force to overwrite."
    }

    if ($PSCmdlet.ShouldProcess($targetFile, "Create new lab profile template")) {
        $payload = [ordered]@{
            Name        = $Name
            Description = $Description
            Packages    = $Packages
            RunCommands = $RunCommands
        }

        $json = $payload | ConvertTo-Json -Depth 4
        Set-Content -Path $targetFile -Value $json -Encoding UTF8

        Write-Information "[OK] Created profile '$Name' at '$targetFile'." -InformationAction Continue

        return [PSCustomObject]@{
            Name        = $Name
            Description = $Description
            Path        = $targetFile
            Packages    = $Packages
            RunCommands = $RunCommands
        }
    }
}
