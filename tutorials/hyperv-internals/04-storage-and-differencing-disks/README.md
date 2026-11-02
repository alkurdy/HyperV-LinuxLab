# Hyper-V Tutorial 04: Virtual Storage & Differencing Disks

> **[Tutorials Hub](../../README.md)** • **[Hyper-V Internals Track](../README.md)** • [← Previous: Hyper-V 03: Virtual Networking](../03-virtual-networking/README.md) • [Index](../../README.md) • [Next: Hyper-V 05: VM Architecture & Cloud-Init →](../05-vm-architecture-and-cloud-init/README.md)

---
Now that our virtual network and IP discovery are solid, let's look at storage. So you want to spin up a 3-node Kubernetes cluster or multi-distro testbed, but you don't want to burn 60 GB of disk space or wait 15 minutes for full disk clones—how do we spin up fresh VMs in seconds using almost no space?

This is the secret sauce of `HyperV-LinuxLab`: **Child Differencing Disks**. In this tutorial, we will explore virtual hard disk architecture, parent-child pointer chains, and how atomic disk swaps achieve sub-5-second factory resets.

Here are the **7 critical areas** you will master:

---

## 1. Virtual Disk Formats: VHD vs VHDX Architecture

Hyper-V provides two format choices: `.vhd` and `.vhdx`:
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
Hyper-V\Get-VHD -Path "C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx" | Format-List
```

---

## 2. Disk Allocation Types: Fixed vs Dynamic vs Differencing

Hyper-V supports three distinct disk allocation strategies:
1. **Fixed Disk**:
   - The entire virtual disk capacity (e.g. 50 GB) is pre-allocated on physical host storage immediately. Fast writes, zero fragmentation, but wastes massive host disk space.
2. **Dynamic Disk**:
   - Starts small (~2 GB for base OS) and expands physical block allocation dynamically as the guest writes data.
3. **Differencing Disk (Parent-Child Architecture)**:
   - Contains **zero initial operating system files**.
   - Contains only a header pointing to a **Parent Base Image**.
   - On reads: If the block hasn't been written to by the child, the hypervisor reads from the parent.
   - On writes: The modified block is written exclusively to the child differencing disk.

---

## 3. The Golden Base Image: Read-Only Locking Architecture

**The cardinal rule of differencing storage: The parent image must NEVER be modified while child differencing disks exist.**
If a parent disk is booted, modified, or updated:
- The parent disk's internal timestamp, geometry, or block tree shifts.
- Every child differencing disk pointing to it immediately suffers catastrophic filesystem corruption because its relative sector offsets no longer match!

### Native PowerShell: Locking the Golden Master
```powershell
$basePath = "C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx"
$file = Get-Item $basePath
$file.IsReadOnly = $true
Write-Host "[OK] Base image marked Read-Only. Parent is safe from child corruption."
```

---

## 4. Parent-Child Pointer Chains: The 4MB Delta Secret

When you create a child differencing disk, Hyper-V does not clone the parent image. It creates a small metadata envelope (~4 MB):

```
┌─────────────────────────────────────────────────────────────┐
│ Child Differencing VHDX (~4 MB initial size)                │
│ - Virtual Size: Matches parent (e.g. 30 GB)                 │
│ - Physical Size on Host: ~4 MB                              │
│ - Block Allocation Table: Empty                             │
│ - Parent Locator Header:                                    │
│   --> Points to C:\HyperV-LinuxLab\BaseImages\ubuntu.vhdx   │
└─────────────────────────────────────────────────────────────┘
```

```powershell
Hyper-V\New-VHD -Path "C:\HyperV-LinuxLab\VMs\node-01\Virtual Hard Disks\node-01.vhdx" `
                -ParentPath "C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx" `
                -Differencing
```

---

## 5. Sub-5-Second Atomic VM Factory Resets

How do we reset a completely broken Linux VM back to factory clean state in under 2 seconds?

```
┌──────────────┐     Delete child delta      ┌──────────────┐
│  Broken VM   │ ──────────────────────────► │ Re-spawn 4MB │ ──► Clean Factory VM
│ (4GB writes) │       (0.1 seconds)         │ child disk   │      (Sub-2s boot)
└──────────────┘                             └──────────────┘
```

1. Power off the VM: `Hyper-V\Stop-VM -Name "node-01" -TurnOff`
2. Remove the dirty child `.vhdx` file.
3. Spawn a clean 4MB child `.vhdx` pointing to the exact same golden parent.
4. Power on the VM: `Hyper-V\Start-VM -Name "node-01"`

---

## 6. Differencing Disks vs Hyper-V Checkpoints (AVHDX)

- **Differencing Disks**: Architectural parent-child separation created deliberately upfront for disposable VMs.
- **Checkpoints (AVHDX)**: Created at runtime. When you create a checkpoint on a running VM (`Checkpoint-VM`):
  1. Hyper-V freezes writes to the active differencing disk.
  2. It creates an `AVHDX` (Automatic Differencing VHDX) file in a snapshot subdirectory.
  3. All new guest writes flow into the AVHDX.
  4. Merging checkpoints requires the VM to be powered off or Hyper-V to run background live disk merges.

---

## 7. Storage Capacity Scream Gates: Preventing Host Disk Exhaustion

If a Hyper-V host drive hits 0 bytes free while VMs are running:
- The hypervisor immediately suspends all virtual machines on that drive with state **`Paused-Critical`**.
- VMs cannot execute, and ungraceful shutdowns can corrupt open database files inside guests.

Evaluate target volume free space before provisioning:
```powershell
$targetDrive = "C:"
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = '$targetDrive'"
$freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)

if ($freeGB -lt 10.0) {
    throw "[SCREAM ALERT] Target drive $targetDrive only has ${freeGB} GB free. Minimum 10 GB required for safe differencing expansion."
}
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

Run these commands in an elevated PowerShell session to create a test golden master, spawn a child differencing disk, inspect parent locators, and test an atomic disk swap.

### 1. Create a Base Template VHDX
- **Action**: Create a temporary 10GB dynamic base disk and inspect its internal sector topology:
  ```powershell
  $testDir = "C:\HyperV-LinuxLab\StorageDrill"
  New-Item -ItemType Directory -Path $testDir -Force | Out-Null

  $baseVhdPath = "$testDir\base-template.vhdx"
  $baseVhd = Hyper-V\New-VHD -Path $baseVhdPath -SizeBytes 10GB -Dynamic
  Hyper-V\Get-VHD -Path $baseVhdPath | Select-Object VhdType, FileSize, Size, LogicalSectorSize, PhysicalSectorSize
  ```
- **System Reaction**:
  Hyper-V formats the VHDX file header, writes the dynamic block allocation table, sets `LogicalSectorSize` to 4096 (4KB native), and leaves unallocated blocks unmapped. Initial physical size on disk is ~4 MB.
- **Verification**:
  Confirm `VhdType` is `Dynamic`.

### 2. Lock Base Image as Read-Only
- **Action**: Mark the base template read-only:
  ```powershell
  $file = Get-Item $baseVhdPath
  $file.IsReadOnly = $true
  ```
- **System Reaction**:
  Windows sets the NTFS/ReFS read-only file attribute. Any process attempting to open the parent disk in `ReadWrite` mode (such as mounting it directly to a VM) will be rejected by the Windows kernel with `Access Denied`.
- **Verification**:
  ```powershell
  (Get-Item $baseVhdPath).IsReadOnly
  ```

### 3. Spawn Child Differencing Disk & Inspect Parent Locator
- **Action**: Create a child differencing disk linked to the base template:
  ```powershell
  $childVhdPath = "$testDir\child-node.vhdx"
  $childVhd = Hyper-V\New-VHD -Path $childVhdPath -ParentPath $baseVhdPath -Differencing
  Hyper-V\Get-VHD -Path $childVhdPath | Select-Object VhdType, FileSize, ParentPath
  ```
- **System Reaction**:
  Hyper-V writes a Differencing VHDX header containing a Parent Locator table pointing to `$baseVhdPath`. Physical size of `$childVhdPath` is ~4 MB.
- **Verification**:
  Confirm `VhdType` is `Differencing` and `ParentPath` matches the base template.

### 4. Execute an Atomic Reset Simulation
- **Action**: Simulate a 0.1-second factory reset by replacing the child disk with a fresh delta:
  ```powershell
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  # Remove dirty child
  Remove-Item -Path $childVhdPath -Force

  # Spawn fresh child
  $null = Hyper-V\New-VHD -Path $childVhdPath -ParentPath $baseVhdPath -Differencing
  $sw.Stop()

  Write-Host "[OK] Atomic disk reset completed in $($sw.Elapsed.TotalSeconds) seconds!" -ForegroundColor Green
  ```
- **System Reaction**:
  Because no guest files had to be copied or formatted, the file system simply created a fresh 4MB header block. Reset execution completes in milliseconds.

---

## Part B: Platform Solo Drill (Unguided Mission)

Now author an unguided atomic differencing reset utility without copy-paste code.

### The Mission: Atomic Differencing Disk Swapper (`Reset-VirtualDiskDelta`)
Platform engineering needs a reusable function to atomically reset any child differencing disk back to zero-byte delta state while preserving its parent binding.

1. **Customization**:
   - Provide parameters for `-ChildVhdPath` and `-Confirm` safety override.

2. **Acceptance Criteria**:
   - Validates that the targeted VHDX exists and is indeed a `Differencing` disk (rejects `Fixed` or `Dynamic` disks with actionable errors).
   - Reads the existing `ParentPath` from the disk metadata before deletion.
   - Verifies the parent image is marked Read-Only.
   - Deletes the child differencing disk and immediately recreates a fresh differencing disk pointing to the identical parent path.
   - Returns a structured `[PSCustomObject]` reporting `ChildPath`, `ParentPath`, `ResetDurationMs`, and `NewPhysicalSizeBytes`.

3. **Self-Verification**:
   Execute this test suite against your reset function to validate your implementation:
   ```powershell
   # Test against the drill disk
   $testChild = "C:\HyperV-LinuxLab\StorageDrill\child-node.vhdx"
   $resetResult = Reset-VirtualDiskDelta -ChildVhdPath $testChild

   $hasContract = ($resetResult.PSObject.Properties.Name -contains "ParentPath") -and ($resetResult.PSObject.Properties.Name -contains "ResetDurationMs")
   if ($hasContract -and ($resetResult.NewPhysicalSizeBytes -lt 15MB)) {
       Write-Host "[PASS] Atomic differencing disk swapper verified!" -ForegroundColor Green
   } else {
       Write-Host "[FAIL] Missing properties or reset size exceeded threshold!" -ForegroundColor Red
   }

   # Clean up drill folder
   Remove-Item -Path "C:\HyperV-LinuxLab\StorageDrill" -Recurse -Force -ErrorAction SilentlyContinue
   ```

---

In **[Tutorial 05: VM Architecture, Generation 2 UEFI & Cloud-Init](../05-vm-architecture-and-cloud-init/README.md)**, we will combine our network and storage layers: build a Generation 2 VM with Linux Secure Boot, generate a NoCloud ISO (`cidata.iso`), and inject unattended configuration!

---

### Navigation
| [← Previous: Hyper-V 03: Virtual Networking](../03-virtual-networking/README.md) | [Tutorials Index](../../README.md) | [Next: Hyper-V 05: VM Architecture & Cloud-Init →](../05-vm-architecture-and-cloud-init/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Linux Level 03: Directory Hierarchy & Storage](../../01-sysadmin-foundations/level-03-directory-hierarchy-and-storage/README.md)).*
