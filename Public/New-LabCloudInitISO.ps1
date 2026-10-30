function New-LabCloudInitISO {
    <#
    .SYNOPSIS
        Generates a NoCloud ISO volume (cidata.iso) embedding cloud-init configuration.
    .DESCRIPTION
        Constructs standard `#cloud-config` user-data and meta-data, embedding SSH authorized keys,
        sudo users, package installations, and post-boot execution commands, and writes an ISO 9660
        volume labeled 'cidata'.
    .PARAMETER Name
        Virtual machine hostname.
    .PARAMETER SSHAuthorizedKey
        Public SSH key string or path to a public key file (~/.ssh/id_ed25519.pub).
    .PARAMETER Username
        Default sudo user created inside Linux (Defaults to 'labadmin').
    .PARAMETER Password
        Optional plaintext console password.
    .PARAMETER Packages
        Optional array of packages to install on first boot.
    .PARAMETER RunCommands
        Optional array of shell commands to execute at end of cloud-init run.
    .PARAMETER DestinationPath
        Directory to save generated ISO file.
    .EXAMPLE
        New-LabCloudInitISO -Name "node-01" -SSHAuthorizedKey (Get-Content ~/.ssh/id_ed25519.pub)
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$SSHAuthorizedKey,

        [string]$Username = "labadmin",

        [Parameter(Mandatory = $false)]
        [System.Security.SecureString]$Password,

        [string[]]$Packages = @("curl", "git", "jq", "tar"),

        [string[]]$RunCommands = @(),

        [string]$DestinationPath = "C:\HyperV-LinuxLab\CloudInit"
    )

    # Auto-discover SSH key if not provided
    if (-not $SSHAuthorizedKey) {
        $keyPaths = @(
            (Join-Path $env:USERPROFILE ".ssh\id_ed25519.pub"),
            (Join-Path $env:USERPROFILE ".ssh\id_rsa.pub")
        )
        foreach ($kp in $keyPaths) {
            if (Test-Path $kp) {
                $SSHAuthorizedKey = (Get-Content $kp -Raw).Trim()
                Write-Verbose "Discovered local SSH key: $kp"
                break
            }
        }
    }

    if (-not $SSHAuthorizedKey) {
        Write-Warning "No SSH key provided or discovered in ~/.ssh/. Generating fallback cloud-init without SSH authentication."
    } elseif (Test-Path $SSHAuthorizedKey) {
        $SSHAuthorizedKey = (Get-Content $SSHAuthorizedKey -Raw).Trim()
    }

    # Build meta-data
    $metaData = @"
instance-id: $Name
local-hostname: $Name
"@

    # Build user-data (cloud-config)
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine("#cloud-config")
    $null = $sb.AppendLine("users:")
    $null = $sb.AppendLine("  - name: $Username")
    $null = $sb.AppendLine("    sudo: ALL=(ALL) NOPASSWD:ALL")
    $null = $sb.AppendLine("    groups: [sudo, docker]")
    $null = $sb.AppendLine("    shell: /bin/bash")

    if ($null -ne $Password) {
        $plainPass = [System.Net.NetworkCredential]::new('', $Password).Password
        $null = $sb.AppendLine("    plain_text_passwd: '$plainPass'")
        $null = $sb.AppendLine("    lock_passwd: false")
    }

    if ($SSHAuthorizedKey) {
        $null = $sb.AppendLine("    ssh_authorized_keys:")
        $null = $sb.AppendLine("      - $SSHAuthorizedKey")
    }

    $null = $sb.AppendLine("package_update: true")
    $null = $sb.AppendLine("package_upgrade: false")

    if ($Packages -and $Packages.Count -gt 0) {
        $null = $sb.AppendLine("packages:")
        foreach ($pkg in $Packages) {
            $null = $sb.AppendLine("  - $pkg")
        }
    }

    if ($RunCommands -and $RunCommands.Count -gt 0) {
        $null = $sb.AppendLine("runcmd:")
        foreach ($cmd in $RunCommands) {
            $null = $sb.AppendLine("  - $cmd")
        }
    }

    $userData = $sb.ToString()

    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    $isoFile = Join-Path $DestinationPath "$Name-cidata.iso"

    if ($PSCmdlet.ShouldProcess($isoFile, "Create Cloud-Init NoCloud ISO")) {
        $files = @{
            "meta-data" = $metaData
            "user-data" = $userData
        }

        New-ISO9660Image -Path $isoFile -VolumeId "cidata" -Files $files

        $info = Get-Item $isoFile
        return [PSCustomObject]@{
            Name     = $Name
            ISOPath  = $info.FullName
            SizeKB   = [math]::Round($info.Length / 1KB, 2)
            Username = $Username
            HasSSH   = [bool]$SSHAuthorizedKey
        }
    }
}
