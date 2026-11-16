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

        [Parameter(Mandatory = $false)]
        [string]$Profile,

        [string[]]$Packages = @("curl", "git", "jq", "tar"),

        [string[]]$RunCommands = @(),

        [Alias('StoragePath')]
        [string]$DestinationPath
    )

    if (-not $DestinationPath) {
        $root = Get-LabStoragePath
        $DestinationPath = Join-Path $root "CloudInit"
    }

    # Resolve Profile if specified
    if ($Profile) {
        $resolvedProfile = Resolve-LabProfile -Profile $Profile
        $combinedPackages = @($resolvedProfile.Packages)
        if ($PSBoundParameters.ContainsKey('Packages')) {
            $combinedPackages += $Packages
        }
        $Packages = $combinedPackages | Select-Object -Unique

        $combinedCmds = @($resolvedProfile.RunCommands)
        if ($PSBoundParameters.ContainsKey('RunCommands')) {
            $combinedCmds += $RunCommands
        }
        $RunCommands = $combinedCmds
    }

    # Auto-discover SSH keys if not provided
    $discoveredKeys = @()
    if (-not $SSHAuthorizedKey) {
        $sshDir = Join-Path $env:USERPROFILE ".ssh"
        if (Test-Path $sshDir) {
            $pubFiles = Get-ChildItem -Path $sshDir -Filter "*.pub" -ErrorAction SilentlyContinue
            foreach ($pf in $pubFiles) {
                $keyContent = (Get-Content $pf.FullName -Raw).Trim()
                if ($keyContent -match '^ssh-(ed25519|rsa|ecdsa)') {
                    $discoveredKeys += $keyContent
                    Write-Verbose "Discovered local SSH key: $($pf.Name)"
                }
            }
        }
        if ($discoveredKeys.Count -eq 0) {
            Write-Warning "No SSH keys discovered in ~/.ssh/. Generating fallback cloud-init without SSH authentication."
        }
    } elseif (Test-Path $SSHAuthorizedKey) {
        $discoveredKeys += (Get-Content $SSHAuthorizedKey -Raw).Trim()
    } else {
        $discoveredKeys += $SSHAuthorizedKey.Trim()
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
    $null = $sb.AppendLine("    groups: [sudo, wheel, admin, docker]")
    $null = $sb.AppendLine("    shell: /bin/bash")

    # Set default lab password if omitted
    $plainPass = if ($null -ne $Password) {
        ConvertFrom-LabSecureString -SecureString $Password
    } else {
        New-LabPassphrase
    }

    $null = $sb.AppendLine("    plain_text_passwd: '$plainPass'")
    $null = $sb.AppendLine("    lock_passwd: false")

    if ($discoveredKeys.Count -gt 0) {
        $null = $sb.AppendLine("    ssh_authorized_keys:")
        foreach ($k in ($discoveredKeys | Select-Object -Unique)) {
            $null = $sb.AppendLine("      - $k")
        }
    }

    $null = $sb.AppendLine("ssh_pwauth: true")
    $null = $sb.AppendLine("package_update: true")
    $null = $sb.AppendLine("package_upgrade: false")
    $null = $sb.AppendLine("datasource_list: [ NoCloud, None ]")

    # Disable and mask Azure guest agent (walinuxagent) to prevent ovf-env.xml polling loop
    $null = $sb.AppendLine("bootcmd:")
    $null = $sb.AppendLine("  - systemctl mask --now walinuxagent.service waagent.service 2>/dev/null || true")
    $null = $sb.AppendLine("  - systemctl stop --now walinuxagent.service waagent.service 2>/dev/null || true")
    $null = $sb.AppendLine("  - mkdir -p /var/lib/waagent")
    $null = $sb.AppendLine("  - touch /var/lib/waagent/ovf-env.xml")

    if ($Packages -and $Packages.Count -gt 0) {
        $null = $sb.AppendLine("packages:")
        foreach ($pkg in $Packages) {
            $null = $sb.AppendLine("  - $pkg")
        }
    }

    $allRunCmds = @(
        "systemctl mask --now walinuxagent.service waagent.service 2>/dev/null || true",
        "systemctl stop --now walinuxagent.service waagent.service 2>/dev/null || true"
    )
    if ($RunCommands -and $RunCommands.Count -gt 0) {
        $allRunCmds += $RunCommands
    }

    $null = $sb.AppendLine("runcmd:")
    foreach ($cmd in $allRunCmds) {
        $null = $sb.AppendLine("  - $cmd")
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
            Password = $plainPass
            Profile  = if ($Profile) { $Profile } else { "None" }
            HasSSH   = ($discoveredKeys.Count -gt 0)
        }
    }
}
