function New-LabVM {
    <#
    .SYNOPSIS
        Provisions an ephemeral Linux lab VM on Hyper-V using differencing storage and cloud-init.
    .DESCRIPTION
        Creates a child differencing VHDX pointing to the golden base image, configures
        UEFI Generation 2 with Linux Secure Boot (MicrosoftUEFICertificateAuthority),
        attaches a generated cloud-init configuration ISO, and starts the virtual machine.
    .PARAMETER Name
        Virtual machine identifier and hostname.
    .PARAMETER BaseImage
        Path to parent VHDX base image or distribution name (defaults to 'Ubuntu2404').
    .PARAMETER MemoryGB
        RAM in gigabytes allocated to the VM (default: 2).
    .PARAMETER CPUCount
        Virtual processors allocated (default: 2).
    .PARAMETER SwitchName
        Hyper-V virtual switch to connect to (defaults to 'Default Switch').
    .PARAMETER SSHAuthorizedKey
        Public SSH key to inject. Defaults to ~/.ssh/id_ed25519.pub if present.
    .PARAMETER Username
        Default sudo user (default: 'labadmin').
    .PARAMETER Packages
        Initial packages to install.
    .PARAMETER LabStoragePath
        Host path where differencing disks and lab VM files are stored.
    .PARAMETER Start
        Powers on the VM immediately upon creation.
    .EXAMPLE
        New-LabVM -Name "k8s-node01" -MemoryGB 4 -CPUCount 2 -Start
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$BaseImage = "Ubuntu2404",

        [int]$MemoryGB = 2,

        [int]$CPUCount = 2,

        [string]$SwitchName,

        [string]$SSHAuthorizedKey,

        [string]$Username = "labadmin",

        [Parameter(Mandatory = $false)]
        [System.Security.SecureString]$Password,

        [Parameter(Mandatory = $false)]
        [string]$Profile,

        [string[]]$Packages = @("curl", "git", "jq"),

        [string[]]$RunCommands = @(),

        [Alias('StoragePath')]
        [string]$LabStoragePath,

        [switch]$Start,

        [switch]$Force
    )

    Assert-Administrator

    if (-not $LabStoragePath) {
        $root = Get-LabStoragePath
        $LabStoragePath = Join-Path $root "LabVMs"
    }

    # Pre-flight Scream Test on storage capacity
    Assert-LabDiskSpace -Path $LabStoragePath -RequiredGB 10.0 -Context "VM Differencing Provisioning" -Force:$Force | Out-Null

    # Check if VM already exists
    $existing = Hyper-V\Get-VM -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        throw "A virtual machine named '$Name' already exists in Hyper-V."
    }

    # Resolve parent base image
    $parentPath = $BaseImage
    if (-not (Test-Path $parentPath)) {
        # Check in default BaseImages directory
        $cachedBases = Get-LabBaseImage
        $match = $cachedBases | Where-Object { $_.Distro -eq $BaseImage -or $_.Name -like "*$BaseImage*" } | Select-Object -First 1
        if ($match) {
            $parentPath = $match.Path
        } else {
            Write-Information "Base image '$BaseImage' not found locally. Initiating download..." -InformationAction Continue
            $downloaded = New-LabBaseImage -Distro "Ubuntu2404"
            $parentPath = $downloaded.Path
        }
    }

    # Resolve Virtual Switch
    $vSwitch = Get-LabDefaultSwitch -PreferredSwitch $SwitchName

    # Setup directories
    $vmDir = Join-Path $LabStoragePath $Name
    if (-not (Test-Path $vmDir)) {
        New-Item -ItemType Directory -Path $vmDir -Force | Out-Null
    }

    $diffDiskPath = Join-Path $vmDir "$Name-diff.vhdx"
    $isoPath = Join-Path $vmDir "$Name-cidata.iso"

    if ($PSCmdlet.ShouldProcess($Name, "Create Gen2 Differencing VM with parent '$parentPath'")) {
        # 1. Resolve Passphrase
        $plainPassword = ""
        if (-not $Password) {
            $plainPassword = New-LabPassphrase
            $sec = [System.Security.SecureString]::new()
            foreach ($c in $plainPassword.ToCharArray()) {
                $sec.AppendChar($c)
            }
            $sec.MakeReadOnly()
            $Password = $sec
        } else {
            $plainPassword = [System.Net.NetworkCredential]::new('', $Password).Password
        }

        # 2. Create Child Differencing Disk
        Write-Verbose "Creating child differencing VHDX at '$diffDiskPath' pointing to '$parentPath'"
        New-VHD -ParentPath $parentPath -Path $diffDiskPath -Differencing | Out-Null

        # 3. Build Cloud-Init ISO in VM directory
        Write-Verbose "Generating Cloud-Init ISO at '$isoPath'"
        $cloudInit = New-LabCloudInitISO -Name $Name `
            -SSHAuthorizedKey $SSHAuthorizedKey `
            -Username $Username `
            -Password $Password `
            -Profile $Profile `
            -Packages $Packages `
            -RunCommands $RunCommands `
            -DestinationPath $vmDir

        # 3. Create Generation 2 VM
        Write-Verbose "Creating Hyper-V Gen2 VM '$Name'"
        $null = Hyper-V\New-VM -Name $Name `
            -Generation 2 `
            -MemoryStartupBytes ([int64]$MemoryGB * 1GB) `
            -VHDPath $diffDiskPath `
            -SwitchName $vSwitch `
            -Path $LabStoragePath

        # 4. Tune CPU, RAM, and UEFI Firmware
        Hyper-V\Set-VMProcessor -VMName $Name -Count $CPUCount | Out-Null
        Hyper-V\Set-VMMemory -VMName $Name -DynamicMemoryEnabled $false | Out-Null

        # Configure Linux Secure Boot (MicrosoftUEFICertificateAuthority)
        Hyper-V\Set-VMFirmware -VMName $Name `
            -EnableSecureBoot On `
            -SecureBootTemplate "MicrosoftUEFICertificateAuthority" | Out-Null

        # Attach Cloud-Init ISO to DVD drive
        Hyper-V\Add-VMDvdDrive -VMName $Name -Path $cloudInit.ISOPath | Out-Null

        Write-Information "[OK] Provisioned Gen2 VM '$Name' (Differencing Disk size: < 10MB)" -InformationAction Continue

        $ipAddress = ""
        if ($Start) {
            Write-Information "Starting VM '$Name' and waiting for network readiness..." -InformationAction Continue
            Hyper-V\Start-VM -Name $Name | Out-Null
            $ipAddress = Get-LabVMIPAddress -VMName $Name -TimeoutSeconds 45
            if ($ipAddress) {
                # Wait for SSH listener on port 22
                Write-Information "Waiting for SSH service to become ready on $ipAddress..." -InformationAction Continue
                $sshStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                while ($sshStopwatch.Elapsed.TotalSeconds -lt 45) {
                    try {
                        $tcp = [System.Net.Sockets.TcpClient]::new()
                        $ar = $tcp.BeginConnect($ipAddress, 22, $null, $null)
                        if ($ar.AsyncWaitHandle.WaitOne(1000, $false) -and $tcp.Connected) {
                            $tcp.EndConnect($ar)
                            $tcp.Close()
                            break
                        }
                        $tcp.Close()
                    } catch {
                        Write-Verbose "Waiting for SSH on port 22: $_"
                    }
                    Start-Sleep -Milliseconds 1500
                }

                Write-Information @"

============================================================
 [OK] Linux Lab VM Ready!
------------------------------------------------------------
 Name     : $Name
 Status   : Running
 IPv4     : $ipAddress
 User     : $Username
 Password : $plainPassword
 Connect  : ssh $Username@$ipAddress
============================================================
"@ -InformationAction Continue
            } else {
                Write-Information "[OK] VM '$Name' started. IP will populate once cloud-init completes." -InformationAction Continue
            }
        }

        return [PSCustomObject]@{
            Name              = $Name
            State             = if ($Start) { "Running" } else { "Off" }
            IPv4              = $ipAddress
            SSH               = if ($ipAddress) { "ssh $Username@$ipAddress" } else { "" }
            Password          = $plainPassword
            Profile           = if ($Profile) { $Profile } else { "None" }
            CPU               = $CPUCount
            MemoryGB          = $MemoryGB
            BaseImage         = (Split-Path $parentPath -Leaf)
            DifferencingDisk  = $diffDiskPath
            Switch            = $vSwitch
        }
    }
}
