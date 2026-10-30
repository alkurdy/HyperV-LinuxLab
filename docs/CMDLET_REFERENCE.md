# HyperV-LinuxLab - Cmdlet & Parameter Reference

Complete reference guide detailing all exported cmdlets, parameter sets, pipeline behaviors, and object outputs.

---

## Index of Cmdlets

| Cmdlet | Verb | Noun | Purpose |
| :--- | :--- | :--- | :--- |
| **[`New-LabBaseImage`](#new-labbaseimage)** | `New` | `LabBaseImage` | Downloads and verifies upstream Ubuntu/Debian Cloud VHDX images. |
| **[`Get-LabBaseImage`](#get-labbaseimage)** | `Get` | `LabBaseImage` | Lists cached base golden images and their verification states. |
| **[`New-LabPassphrase`](#new-labpassphrase)** | `New` | `LabPassphrase` | Generates memorable, human-friendly Diceware passphrases. |
| **[`New-LabCloudInitISO`](#new-labcloudinitiso)** | `New` | `LabCloudInitISO` | Generates NoCloud ISO (`cidata.iso`) with user-data and meta-data. |
| **[`New-LabVM`](#new-labvm)** | `New` | `LabVM` | Provisions a Gen2 VM with a differencing VHDX and cloud-init. |
| **[`Get-LabVM`](#get-labvm)** | `Get` | `LabVM` | Queries runtime telemetry, assigned IP address, and disk usage. |
| **[`Reset-LabVM`](#reset-labvm)** | `Reset` | `LabVM` | **Instant sub-5-second reset**: swaps child disk back to pristine state. |
| **[`Remove-LabVM`](#remove-labvm)** | `Remove` | `LabVM` | Completely deletes VM, differencing disk, and attached ISO. |
| **[`Start-LabVM`](#start-labvm)** | `Start` | `LabVM` | Boots VM and waits for network IP acquisition via KVP. |
| **[`Stop-LabVM`](#stop-labvm)** | `Stop` | `LabVM` | Shuts down VM gracefully or forces an immediate power-off. |
| **[`Test-LabPrerequisites`](#test-labprerequisites)** | `Test` | `LabPrerequisites` | Validates Hyper-V hypervisor, admin rights, and virtual switches. |

---

## Cmdlet Specifications

### `New-LabBaseImage`

Downloads an official, production-ready Cloud-Init VHDX image directly from distribution mirrors, verifies its SHA256 checksum, and marks it read-only.

#### Syntax
```powershell
New-LabBaseImage
    [-Distro] <String>
    [[-DestinationPath] <String>]
    [-Force]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Parameters

- **`-Distro`** `<String>` *(Mandatory, Position 0)*
  The Linux distribution image to fetch.
  - *Accepted Values*: `Ubuntu2404`, `Ubuntu2204`, `Debian12`
  - *Default*: `Ubuntu2404`
- **`-DestinationPath`** `<String>` *(Optional, Position 1)*
  Local directory to store master images.
  - *Default*: `C:\HyperV-LinuxLab\BaseImages`
- **`-Force`** `<SwitchParameter>` *(Optional)*
  Overwrites any existing base image even if the checksum matches.

#### Outputs
- `[PSCustomObject]` containing:
  - `Distro`: Distribution name
  - `Path`: Absolute file path to the master `.vhdx`
  - `SizeMB`: File size in megabytes
  - `SHA256`: Verified cryptographic checksum
  - `IsReadOnly`: Set to `$true` to guarantee parent integrity

#### Example
```powershell
New-LabBaseImage -Distro Ubuntu2404 -DestinationPath "D:\LabStorage\BaseImages"
```

---

### `New-LabPassphrase`

Generates a memorable, human-friendly Diceware-style passphrase combining adjectives, nouns, and numbers (e.g., `Swift-Falcon-42`). Each spin-up creates a distinct passphrase satisfying Linux complexity requirements without annoying character ambiguities.

#### Syntax
```powershell
New-LabPassphrase
    [[-WordCount] <Int32>]
    [[-Separator] <String>]
    [[-IncludeNumber] <Boolean>]
    [-AsSecureString]
    [<CommonParameters>]
```

#### Parameters

- **`-WordCount`** `<Int32>` *(Optional)*
  Number of words in the passphrase. Valid range: 1 to 6. Default: `2`.
- **`-Separator`** `<String>` *(Optional)*
  Delimiter placed between words. Default: `'-'`.
- **`-IncludeNumber`** `<Boolean>` *(Optional)*
  Appends a random 2-digit number (10-99). Default: `$true`.
- **`-AsSecureString`** `<SwitchParameter>` *(Optional)*
  Outputs the result as a `System.Security.SecureString` object.

#### Outputs
- `[String]` or `[System.Security.SecureString]`.

#### Example
```powershell
New-LabPassphrase
# Returns: Swift-Falcon-42

New-LabPassphrase -WordCount 3 -Separator "_"
# Returns: Cosmic_Amber_Otter_73
```

---

### `New-LabCloudInitISO`

Generates an ISO 9660 volume labeled `cidata` embedding `user-data` and `meta-data` for unattended Linux cloud initialization.

#### Syntax
```powershell
New-LabCloudInitISO
    [-Name] <String>
    [-SSHAuthorizedKey] <String>
    [[-Username] <String>]
    [[-Password] <String>]
    [[-Packages] <String[]>]
    [[-RunCommands] <String[]>]
    [[-DestinationPath] <String>]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Parameters

- **`-Name`** `<String>` *(Mandatory, Position 0)*
  The hostname assigned to the VM.
- **`-SSHAuthorizedKey`** `<String>` *(Mandatory, Position 1)*
  The public key string (e.g. `ssh-ed25519 AAAAC3NzaC1...`) or a path to a public key file (`~/.ssh/id_ed25519.pub`).
- **`-Username`** `<String>` *(Optional)*
  The default sudo user created inside Linux.
  - *Default*: `labadmin` (or current Windows username)
- **`-Password`** `<String>` *(Optional)*
  Optional initial password for console login (hashed inside cloud-init).
- **`-Packages`** `<String[]>` *(Optional)*
  List of apt packages to install during initial boot (e.g., `@('containerd', 'git', 'curl', 'jq')`).
- **`-RunCommands`** `<String[]>` *(Optional)*
  Shell commands executed by cloud-init at the conclusion of first boot.
- **`-DestinationPath`** `<String>` *(Optional)*
  Directory where the `.iso` file is generated.
  - *Default*: `C:\HyperV-LinuxLab\CloudInit`

#### Outputs
- `[System.IO.FileInfo]` representing the generated ISO file.

#### Example
```powershell
New-LabCloudInitISO -Name "k8s-node01" `
    -SSHAuthorizedKey (Get-Content ~/.ssh/id_ed25519.pub) `
    -Username "labadmin" `
    -Packages @("containerd", "jq", "curl") `
    -RunCommands @("systemctl enable --now containerd")
```

---

### `New-LabVM`

Creates a modern Generation 2 Hyper-V virtual machine utilizing a child differencing disk and attaches the generated cloud-init ISO.

#### Syntax
```powershell
New-LabVM
    [-Name] <String>
    [[-BaseImage] <String>]
    [[-MemoryGB] <Int32>]
    [[-CPUCount] <Int32>]
    [[-SwitchName] <String>]
    [[-SSHAuthorizedKey] <String>]
    [[-Username] <String>]
    [[-Packages] <String[]>]
    [[-LabStoragePath] <String>]
    [-Start]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Parameters

- **`-Name`** `<String>` *(Mandatory, Position 0)*
  Virtual machine identifier and guest hostname.
- **`-BaseImage`** `<String>` *(Optional)*
  Path to the parent base VHDX or distro name (`Ubuntu2404`).
  - *Default*: Uses latest cached `Ubuntu2404` base image.
- **`-MemoryGB`** `<Int32>` *(Optional)*
  Startup RAM allocated to the VM.
  - *Default*: `2` (2 GB RAM)
- **`-CPUCount`** `<Int32>` *(Optional)*
  Virtual processors allocated.
  - *Default*: `2`
- **`-SwitchName`** `<String>` *(Optional)*
  Target virtual switch.
  - *Default*: Automatically resolves to Hyper-V `Default Switch`.
- **`-SSHAuthorizedKey`** `<String>` *(Optional)*
  SSH public key. Defaults to `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub` if present.
- **`-Start`** `<SwitchParameter>` *(Optional)*
  Immediately powers on the VM and waits for an IP address.

#### Outputs
- `[PSCustomObject]` representing the created lab VM with its properties, differencing disk path, and boot status.

#### Example
```powershell
New-LabVM -Name "linux-sandbox" -MemoryGB 4 -CPUCount 2 -Start
```

---

### `Reset-LabVM`

**The core high-speed iteration cmdlet.** Discards the child differencing disk, recreates an empty delta disk pointing to the base image, and boots the VM back to pristine factory state in under 5 seconds.

#### Syntax
```powershell
Reset-LabVM
    [-Name] <String[]>
    [-Force]
    [-PassThru]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Parameters

- **`-Name`** `<String[]>` *(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)*
  Names of one or more lab VMs to reset.
- **`-Force`** `<SwitchParameter>` *(Optional)*
  Suppresses confirmation prompt and forces an immediate VM power off if running.
- **`-PassThru`** `<SwitchParameter>` *(Optional)*
  Emits the updated VM status object back to the pipeline.

#### Performance Metric
- **Execution Duration**: **~3 to 5 seconds** per VM.

#### Example
```powershell
# Reset single VM
Reset-LabVM -Name "linux-sandbox" -Force

# Reset all worker nodes in pipeline
Get-LabVM -Name "worker*" | Reset-LabVM -Force
```

---

### `Checkpoint-LabVM`

Takes an instantaneous snapshot of a lab VM's running differencing state.

#### Syntax
```powershell
Checkpoint-LabVM
    [-Name] <String[]>
    [[-SnapshotName] <String>]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Parameters
- **`-Name`** `<String[]>` *(Mandatory, ValueFromPipeline)*: Names of one or more VMs.
- **`-SnapshotName`** `<String>` *(Optional)*: Descriptive label. Defaults to `checkpoint-yyyyMMdd-HHmmss`.

#### Example
```powershell
Checkpoint-LabVM -Name "node-01" -SnapshotName "pre-docker-install"
```

---

### `Restore-LabVM`

Reverts one or more lab VMs to their most recent checkpoint (or a specified checkpoint) in seconds.

#### Syntax
```powershell
Restore-LabVM
    [-Name] <String[]>
    [[-SnapshotName] <String>]
    [-Force]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Parameters
- **`-Name`** `<String[]>` *(Mandatory, ValueFromPipeline)*: Names of one or more VMs.
- **`-SnapshotName`** `<String>` *(Optional)*: Specific checkpoint name. If omitted, automatically restores the **most recent** checkpoint.
- **`-Force`** `<SwitchParameter>`: Suppresses confirmation prompt.

#### Example
```powershell
# Revert to last checkpoint instantly
Restore-LabVM -Name "node-01" -Force

# Revert to named checkpoint
Restore-LabVM -Name "node-01" -SnapshotName "pre-docker-install" -Force
```

---

### `Get-LabCheckpoint`

Lists checkpoints associated with one or more lab VMs.

#### Syntax
```powershell
Get-LabCheckpoint
    [-Name] <String[]>
    [[-SnapshotName] <String>]
    [<CommonParameters>]
```

---

### `Remove-LabCheckpoint`

Deletes one or all checkpoints from a lab VM.

#### Syntax
```powershell
Remove-LabCheckpoint
    [-Name] <String[]>
    [[-SnapshotName] <String>]
    [-All]
    [-Force]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

---

### `Get-LabVM`

Retrieves status, hardware configuration, assigned IPv4 address, and storage footprint for active lab VMs.

#### Syntax
```powershell
Get-LabVM
    [[-Name] <String[]>]
    [<CommonParameters>]
```

#### Outputs
- `[PSCustomObject[]]` with properties:
  - `Name`: VM identifier
  - `State`: `Running`, `Off`, or `Paused`
  - `IPv4`: Discovered IP address via KVP integration
  - `CPU`: Virtual processor count
  - `MemoryMB`: Allocated RAM
  - `DifferencingDiskMB`: Actual physical disk consumption on host (~50MB - 300MB)
  - `BaseImage`: Parent image name
  - `Uptime`: Operating duration

#### Example
```powershell
Get-LabVM
Get-LabVM -Name "k8s-*" | Format-Table Name, State, IPv4, DifferencingDiskMB
```

---

### `Remove-LabVM`

Gracefully tears down and cleans up a lab VM, its child differencing VHDX, and its temporary cloud-init ISO files.

#### Syntax
```powershell
Remove-LabVM
    [-Name] <String[]>
    [-Force]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Parameters

- **`-Name`** `<String[]>` *(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)*
  Names of one or more lab VMs to delete.
- **`-Force`** `<SwitchParameter>` *(Optional)*
  Forces immediate VM termination and removes files without prompting.

#### Example
```powershell
Remove-LabVM -Name "linux-sandbox" -Force
```

---

### `Get-LabConfiguration`

Retrieves active persistent configuration settings (default storage volume, virtual switch, and directory tree).

#### Syntax
```powershell
Get-LabConfiguration
    [<CommonParameters>]
```

#### Example
```powershell
Get-LabConfiguration
```

---

### `Set-LabConfiguration`

Configures persistent defaults for Hyper-V Linux lab automation, allowing users to choose secondary high-capacity drives (e.g. `D:\` or `E:\`) for all virtual disks, base images, and ISOs.

#### Syntax
```powershell
Set-LabConfiguration
    [[-StoragePath] <String>]
    [[-PreferredSwitch] <String>]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Example
```powershell
# Deploy all virtual disks and base images to D: drive automatically
Set-LabConfiguration -StoragePath "D:\HyperV-LinuxLab"
```

---

### `Get-LabProfile`

Discovers and lists available declarative toolchain profiles (`Minimal`, `Container`, `Kubernetes`, or custom user profiles).

#### Syntax
```powershell
Get-LabProfile
    [[-Name] <String>]
    [<CommonParameters>]
```

#### Example
```powershell
Get-LabProfile
Get-LabProfile -Name "Container"
```

---

### `New-LabProfile`

Scaffolds a new declarative JSON profile template that can be passed directly to `New-LabVM -Profile <Name>`.

#### Syntax
```powershell
New-LabProfile
    [-Name] <String>
    [[-Description] <String>]
    [[-Packages] <String[]>]
    [[-RunCommands] <String[]>]
    [[-DestinationPath] <String>]
    [-Force]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Example
```powershell
# Create custom security lab profile in ~/.hyperv-linuxlab/profiles/
New-LabProfile -Name "SecurityLab" `
    -Description "Penetration testing and packet analysis" `
    -Packages @("nmap", "wireshark", "tcpdump") `
    -RunCommands @("echo 'export LAB=sec' >> /etc/profile")
```

---

### `Test-LabCluster`

Validates a declarative cluster JSON topology specification against host memory and disk limits before provisioning.

#### Syntax
```powershell
Test-LabCluster
    [-Path] <String>
    [<CommonParameters>]
```

#### Example
```powershell
Test-LabCluster -Path .\examples\k8s-3node-cluster.json
```

---

### `New-LabCluster`

Provisions a complete multi-node cluster topology from a declarative JSON file in parallel, configuring differencing disks, profiles, and networking.

#### Syntax
```powershell
New-LabCluster
    [-Path] <String>
    [-Force]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Example
```powershell
New-LabCluster -Path .\examples\k8s-3node-cluster.json
```

---

### `Remove-LabCluster`

Tears down all virtual machines, differencing disks, and configuration ISOs declared in a cluster JSON definition.

#### Syntax
```powershell
Remove-LabCluster
    [-Path] <String>
    [-Force]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

#### Example
```powershell
Remove-LabCluster -Path .\examples\k8s-3node-cluster.json -Force
```

---

### `Test-LabPrerequisites`

Diagnostic verification command checking host requirements prior to deploying lab infrastructure.

#### Syntax
```powershell
Test-LabPrerequisites
    [-StoragePath <String>]
    [-MinimumFreeStorageGB <Int32>]
    [-MinimumMemoryGB <Int32>]
    [-Detailed]
    [-TestHost <String>]
    [<CommonParameters>]
```

#### Parameters

- **`-StoragePath`** `<String>` *(Optional, default: `'C:\'`)*
  Volume path evaluated for virtual disk and image storage space.
- **`-MinimumFreeStorageGB`** `<Int32>` *(Optional, default: `20`)*
  Minimum free storage required in gigabytes.
- **`-MinimumMemoryGB`** `<Int32>` *(Optional, default: `8`)*
  Minimum host physical RAM required in gigabytes.
- **`-Detailed`** `<SwitchParameter>` *(Optional)*
  Returns full diagnostic object with properties for every subsystem.
- **`-TestHost`** `<String>` *(Optional, default: `'cloud-images.ubuntu.com'`)*
  Target host for outbound repository connectivity check.

#### Checks Performed
1. **Administrative Elevation**: Validates whether the PowerShell session is elevated.
2. **Windows Edition Compatibility**: Ensures host runs Windows Pro, Enterprise, Education, or Server (Windows Home edition does not support Hyper-V natively).
3. **Hyper-V Module & Role**: Ensures `Hyper-V\New-VM` is registered and functional.
4. **Virtual Switch Presence**: Verifies `Default Switch` or internal NAT switch exists.
5. **Host RAM Capacity**: Confirms host has sufficient physical memory (>= 8GB) for virtualization workloads.
6. **Disk Free Space**: Validates sufficient free space (>= 20GB) for base VHDX downloads, Cloud-Init ISOs, and differencing virtual disks.
7. **Internet Connectivity**: Tests reachability of `cloud-images.ubuntu.com`.

#### Outputs
- `[PSCustomObject]` with pass/fail status for each subsystem and actionable remedy messages.
