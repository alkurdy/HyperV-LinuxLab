# Hyper-V Tutorial 04: Virtual Storage & Differencing Disks

> **[HyperV-LinuxLab Tutorials Hub](README.md)** â€¢ **Track 2: Hyper-V Systems Engineering** â€¢ [â† Previous: Hyper-V 03: Virtual Networking](hyperv-03-virtual-networking.md) â€¢ [ðŸ“‘ Index](README.md) â€¢ [Next: Hyper-V 05: VM Architecture & Cloud-Init â†’](hyperv-05-vm-architecture-and-cloud-init.md)

---
Now that our virtual network and IP discovery are solid, let's look at storage. So you want to spin up a 3-node Kubernetes cluster or multi-distro testbed, but you don't want to burn 60 GB of disk space or wait 15 minutes for full disk clones—how do we spin up fresh VMs in seconds using almost no space?

This is the secret sauce of `HyperV-LinuxLab`: **Child Differencing Disks**. In this tutorial, we will explore virtual hard disk architecture, parent-child pointer chains, and how atomic disk swaps achieve sub-5-second factory resets.

Here are the **7 critical areas** you will master:

---

## 1. Virtual Disk Formats: VHD vs VHDX Architecture

So you want to create a virtual hard drive, but Hyper-V gives you two format choices: `.vhd` and `.vhdx`. What's the difference under the hood?

### The Architecture
- **VHD (Legacy, 2003)**:
   - Maximum capacity: 2 TB.
   - 512-byte logical sectors.
   - Vulnerable to metadata corruption during unexpected power outages or host crashes.
- **VHDX (Modern, Gen2)**:
   - Maximum capacity: 64 TB.
   - 4 KB logical sectors (matches modern physical NVMe/SSD physical sector layout).
   - **Internal Log Mechanism**: Writes metadata changes to an internal transaction log before committing them to the virtual disk header. If the host loses power mid-write, the VHDX replays the log upon next mount without disk corruption.

### Native PowerShell Inspection
```powershell
# Inspect the internal structure of any virtual hard disk
Hyper-V\Get-VHD -Path "C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx" | Format-List
```

---

## 2. Disk Allocation Types: Fixed vs Dynamic vs Differencing

Now that we know VHDX is our format, how does Hyper-V allocate blocks on physical host storage?

### The Architecture
Hyper-V supports three distinct disk allocation strategies:
1. **Fixed Disk**:
   - The entire virtual disk capacity (e.g. 50 GB) is pre-allocated on physical host storage immediately. Fast writes, zero fragmentation, but wastes massive amounts of host disk space.
2. **Dynamic Disk**:
   - Starts small (~2 GB for base OS) and expands physical block allocation dynamically as the guest writes data.
3. **Differencing Disk (Parent-Child Architecture)**:
   - Contains **zero initial operating system files**.
   - Contains only a header pointing to a **Parent Base Image**.
   - On reads: If the block hasn't been written to by the child, the hypervisor reads from the parent.
   - On writes: The modified block is written exclusively to the child differencing disk.

---

## 3. The Golden Base Image: Read-Only Locking Architecture

Now that we understand differencing disks, what happens if something accidentally modifies the parent image?

### The Architecture: Preventing Parent Corruption
Here is the cardinal rule of differencing storage: **The parent image must NEVER be modified while child differencing disks exist.**
If a parent disk is booted, modified, or updated:
- The parent disk's internal timestamp, geometry, or block tree shifts.
- Every child differencing disk pointing to it immediately suffers catastrophic filesystem corruption because its relative sector offsets no longer match!

### Native PowerShell: Locking the Golden Master
To physically prevent host processes or users from touching golden master images, we mark them read-only:
```powershell
$basePath = "C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx"
$file = Get-Item $basePath
$file.IsReadOnly = $true
Write-Host "[OK] Base image marked Read-Only. Parent is safe from child corruption."
```

### Under the Hood in `HyperV-LinuxLab`
[`New-LabBaseImage.ps1`](../Public/New-LabBaseImage.ps1) sets `IsReadOnly = $true` immediately after verifying the upstream image's SHA256 checksum and completing dynamic VHDX conversion.

---

## 4. Spawning Child Differencing Disks in Seconds

Now that our golden master is locked and safe, let's create a child differencing disk for a new lab VM.

### Native PowerShell Command
Creating a child differencing disk takes **less than 100 milliseconds** because no data is copied:
```powershell
# Spawn a child differencing disk pointing to parent
$parentPath = "C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx"
$childPath  = "C:\HyperV-LinuxLab\LabVMs\k8s-node-01\k8s-node-01-diff.vhdx"

New-VHD -ParentPath $parentPath -Path $childPath -Differencing
```

### Disk Footprint
- When created, `k8s-node-01-diff.vhdx` is only **4 MB** in size (just VHDX header and parent locator blocks).
- Even after full OS boot and package installation, the child disk typically consumes only **150 MB to 350 MB** on your host drive!

---

## 5. Instant Sub-5-Second Factory Resets (The Core Secret)

Now, what happens when you break your Linux lab, corrupt your Kubernetes control plane, or mess up an iptables rule? How do you reset to factory clean in under 5 seconds?

### The Architecture: The Differencing Swap
Traditional lab tools delete the VM, recreate the VM definition, re-download images, and run slow installers.
`HyperV-LinuxLab` uses the **Atomic Differencing Swap**:
1. Power off the VM (`Stop-VM -TurnOff`).
2. Delete the dirty child differencing disk (`Remove-Item child-diff.vhdx`).
3. Instantly spawn a brand-new, empty child differencing disk with the exact same name pointing to the pristine parent master.
4. Power on the VM (`Start-VM`).

Because the parent master was never touched, the VM boots back into a pristine OS state in **3 to 5 seconds**!

### Native PowerShell Implementation
```powershell
$vmName = "k8s-node-01"

# 1. Power off
Hyper-V\Stop-VM -Name $vmName -TurnOff -Force

# 2. Get current disk and parent path
$hdd = Hyper-V\Get-VMHardDiskDrive -VMName $vmName | Select-Object -First 1
$vhdInfo = Hyper-V\Get-VHD -Path $hdd.Path
$parent = $vhdInfo.ParentPath

# 3. Swap disk
Remove-Item -Path $hdd.Path -Force
New-VHD -ParentPath $parent -Path $hdd.Path -Differencing | Out-Null

# 4. Boot clean
Hyper-V\Start-VM -Name $vmName
Write-Host "[OK] VM '$vmName' reset to factory state in ~3 seconds!"
```

### Under the Hood in `HyperV-LinuxLab`
This exact sequence is encapsulated in [`Reset-LabVM.ps1`](../Public/Reset-LabVM.ps1), supporting single VMs or pipelined wildcard cluster resets (`Get-LabVM "k8s-*" | Reset-LabVM -Force`).

---

## 6. Differencing Disks vs Checkpoints (Snapshots)

Now, how does a differencing disk differ from a Hyper-V Checkpoint (Snapshot)?

### The Architecture
- **Differencing Disks**: Architectural parent-child separation created deliberately upfront for disposable VMs.
- **Checkpoints (AVHDX)**: Created at runtime. When you create a checkpoint on a running VM (`Checkpoint-VM`):
  1. Hyper-V freezes writes to the active differencing disk.
  2. It creates an `AVHDX` (Automatic Differencing VHDX) file in a snapshot subdirectory.
  3. All new guest writes flow into the AVHDX.
  4. Merging checkpoints requires the VM to be powered off or Hyper-V to run background live disk merges.

### Native PowerShell Checkpoint Management
```powershell
# Create named checkpoint
Hyper-V\Checkpoint-VM -Name "k8s-node-01" -SnapshotName "pre-k8s-init"

# Revert to checkpoint
Hyper-V\Restore-VMSnapshot -Name "pre-k8s-init" -VMName "k8s-node-01" -Confirm:$false
```

---

## 7. Storage Capacity Scream Gates: Preventing Host Disk Exhaustion

Now, what happens if your host drive runs out of disk space while a differencing disk is expanding?

### The Architecture: Pause-Critical Storage Failures
If a Hyper-V host drive hits 0 bytes free while VMs are running:
- The hypervisor immediately suspends all virtual machines on that drive with state **`Paused-Critical`**.
- VMs cannot execute, and ungraceful shutdowns can corrupt open database files inside guests.

### Native PowerShell Pre-Flight Gate
Before launching deployments, evaluate target volume free space:
```powershell
$targetDrive = "C:"
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = '$targetDrive'"
$freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)

if ($freeGB -lt 10.0) {
    throw "[SCREAM ALERT] Target drive $targetDrive only has ${freeGB} GB free. Minimum 10 GB required for safe differencing expansion."
}
```

### Under the Hood in `HyperV-LinuxLab`
[`Private/Assert-LabDiskSpace.ps1`](../Private/Assert-LabDiskSpace.ps1) acts as an automated safety gate. If free space is below the required threshold, it prints a high-visibility terminal banner and blocks provisioning unless `-Force` is passed.

---

Now that our storage and differencing disk architecture is clear, let's explore **[Tutorial 05: VM Architecture, UEFI Gen2 & Cloud-Init](hyperv-05-vm-architecture-and-cloud-init.md)** to see how VMs initialize without interactive installers!

---

### ðŸ§­ Navigation
| [â† Previous: Hyper-V 03: Virtual Networking](hyperv-03-virtual-networking.md) | [ðŸ“‘ All Tutorials](README.md) | [Next: Hyper-V 05: VM Architecture & Cloud-Init â†’](hyperv-05-vm-architecture-and-cloud-init.md) |
| :--- | :---: | ---: |

*(Hands-on lab drill: See [Lab Tutorial 04: Snapshots & Disaster Recovery](lab-04-snapshots-and-disaster-recovery.md)).*
