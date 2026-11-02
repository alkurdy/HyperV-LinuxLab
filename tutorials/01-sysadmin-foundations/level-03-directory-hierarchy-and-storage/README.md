# Level 03: Directory Hierarchy, Block Storage & Filesystems

> **[Tier 1: Sysadmin Foundations](../README.md)** • Grounded in *CompTIA Linux+ Study Guide* & *Linux Command Line and Shell Scripting Bible*.

---

## Objective
Master the Filesystem Hierarchy Standard (FHS), understand Linux block device storage topography, partition drives using modern GPT tables, format filesystems (`ext4` and `xfs`), establish persistent mounts via `/etc/fstab` with UUIDs, and configure swap space.

---

## 1. Filesystem Hierarchy Standard (FHS 3.0)

Linux enforces a standardized organizational contract across all distributions known as the **Filesystem Hierarchy Standard (FHS)**. Memorizing this structure eliminates confusion during troubleshooting:

```
/ (Root Directory)
├── etc/          # Host-specific system configuration files (plaintext, no binaries)
├── var/          # Variable runtime data: logs (/var/log), spool, cache, mail
├── usr/          # User system binaries, libraries, docs (/usr/bin, /usr/lib)
│   └── local/    # Locally compiled or custom administrator software
├── opt/          # Third-party self-contained proprietary packages (e.g. /opt/google)
├── srv/          # Site-specific service data (e.g. web servers /srv/www, FTP)
├── home/         # User home directories (/home/username)
├── root/         # Home directory for the root superuser (separated from /home)
├── mnt/          # Temporary manual mount points for administrators
├── media/        # Removable media automounts (CD-ROMs, USB flash drives)
├── boot/         # Static bootloader files, Linux kernel (vmlinuz), initramfs
├── dev/          # Hardware device nodes managed by udev
├── proc/         # Virtual process and kernel memory telemetry
├── sys/          # Hardware device tree and kernel subsystems
└── tmp/          # Temporary scratch storage (cleared on reboot; sticky bit enabled)
```

> [!NOTE]
> **UsrMerge Standard**: Modern distributions (Ubuntu, Debian, RHEL) merge `/bin`, `/sbin`, and `/lib` into `/usr/bin` and `/usr/lib`. The legacy root directories `/bin` and `/sbin` are simply symlinks pointing to `/usr/bin`.

---

---

## 2. Directory Architecture & File Manipulation Hygiene

Before partitioning and mounting disks, systems administrators must master standard directory structuring and defensive file operations:

### Creating Project Hierarchies
Use the `-p` (parents) flag to build nested directory structures in a single command without failing if parent directories do not exist:
```bash
sudo mkdir -p /srv/projects/{app,backups,config,logs}
```

### File Operations: `mv` vs `cp`
- **`mv` (Move / Rename)**: On the same filesystem, `mv` simply updates the directory's inode lookup table. The file data blocks and inode number remain completely unchanged. It is an atomic, instantaneous ($O(1)$) operation regardless of file size. Across different filesystems, `mv` behaves as a copy-then-delete operation.
- **`cp` (Copy)**: Allocates fresh inodes and disk blocks, reading byte-for-byte from the source and writing duplicate data blocks to the destination.

### Administrative Backup Hygiene
Before editing any critical configuration file or deploying application updates, **always create a timestamped backup copy**:
```bash
# Create timestamped configuration backup
sudo cp /etc/hosts /etc/hosts.bak.$(date +%F)

# Quick rollback if a syntax error or typo occurs
sudo cp /etc/hosts.bak.$(date +%F) /etc/hosts
```
*Why backup copies are essential*: In production incidents, quick recovery depends on rolling back to a known good state immediately rather than trying to recreate complex configurations from memory.

### Visual Verification with `ls -l`
Running `ls -l` after every file operation is standard sysadmin muscle memory. The long listing provides immediate verification:
- Confirms whether permissions (`-rw-r--r--`) match intended security posture.
- Confirms ownership (`root:root` vs `svc-app:appteam`).
- Confirms file size (verifying copies are not 0 bytes or truncated).
- Confirms modification timestamp.

## 3. Storage Topography: Block Devices vs Partitions

In Windows Disk Management, you see Disk 0, Disk 1 with Volume labels.
In Linux, physical storage controllers and disks are represented as **block device nodes** in `/dev/`:

| Storage Interface | Whole Disk Device Node | First Partition Node | Second Partition Node |
| :--- | :--- | :--- | :--- |
| **SCSI / SATA / USB** | `/dev/sda` | `/dev/sda1` | `/dev/sda2` |
| **Second SCSI Disk** | `/dev/sdb` | `/dev/sdb1` | `/dev/sdb2` |
| **NVMe High-Speed** | `/dev/nvme0n1` | `/dev/nvme0n1p1` | `/dev/nvme0n1p2` |
| **Virtual Disk (VirtIO)** | `/dev/vda` | `/dev/vda1` | `/dev/vda2` |

### Block Device Discovery Commands
```bash
# List all block devices, partitions, mountpoints, and sizes in a visual tree
lsblk

# Display filesystem types and unique UUID identifiers
lsblk -f

# Inspect physical disk geometry and partition tables
sudo fdisk -l /dev/sda
```

---

## 3. Partitioning: MBR vs Modern GPT

- **MBR (Master Boot Record)**: Legacy 1980s partitioning. Maximum 2 TB disk size, limited to 4 primary partitions.
- **GPT (GUID Partition Table)**: Modern standard. Supports 18 Exabytes, up to 128 partitions, includes secondary backup partition header at the end of the disk. **Always use GPT on modern systems.**

### Partitioning with `parted`
```bash
# 1. Label secondary disk with GPT
sudo parted /dev/sdb --script mklabel gpt

# 2. Create a primary partition from 1MB to 10GB
sudo parted /dev/sdb --script mkpart primary ext4 1MiB 10GiB

# 3. Inform the Linux kernel of partition table updates without rebooting
sudo partx -u /dev/sdb
```

---

## 4. Modern Linux Filesystems: Ext4 vs XFS

Linux supports numerous filesystem formats. In enterprise production, two dominate:

| Feature | Ext4 (Extended 4) | XFS (Enterprise Journaling) |
| :--- | :--- | :--- |
| **Primary Ecosystem** | Debian, Ubuntu | RHEL, CentOS, Rocky, AlmaLinux |
| **Max Filesystem Size** | 1 Exabyte | 8 Exabytes |
| **Shrink Support** | Yes (Offline via `resize2fs`) | **No** (XFS cannot be shrunk; grow only) |
| **Metadata Journaling**| Yes | High-performance allocation groups |
| **Creation Command** | `sudo mkfs.ext4 /dev/sdb1` | `sudo mkfs.xfs /dev/sdb1` |

---

## 5. Persistent Mounting via `/etc/fstab` (The UUID Rule)

The `/etc/fstab` configuration file dictates what storage mounts upon host boot:

```text
# <file system>                           <mount point>  <type>  <options>       <dump>  <pass>
UUID=3a1b4c9e-5f8a-4d2b-9e1a-8c7b6a5d4e3f /srv/app       ext4    defaults,nofail 0       2
```

### The 6 Column Fields Explained:
1. **Device Identifier**: **Always use UUID** (`UUID=...`). Device node paths (`/dev/sdb1`) can dynamically shift names after hardware changes or reboot order shifts!
2. **Mount Point**: The target directory where the filesystem tree is grafted.
3. **Type**: `ext4`, `xfs`, `btrfs`, `swap`.
4. **Mount Options**:
   - `defaults`: Enables `rw, suid, dev, exec, auto, nouser, async`.
   - `nofail`: **CRITICAL DEFENSE**: Prevents systemd from halting the boot sequence in an emergency rescue shell if this secondary drive is disconnected or fails to mount!
5. **Dump**: Legacy backup utility flag (always set to `0`).
6. **Pass / Fsck Order**: `1` for root filesystem `/`; `2` for secondary filesystems; `0` for swap or network shares.

> [!WARNING]
> **Corrupt `/etc/fstab` Trap**: Never reboot without verifying your `/etc/fstab` syntax! Always run `sudo mount -a`. If it outputs any error, fix the line immediately before rebooting.

---

## 7. Linux Swap Space Architecture

When physical RAM is exhausted, the Linux kernel swaps anonymous idle memory pages to disk:

```bash
# 1. Allocate a contiguous 1GB swapfile
sudo fallocate -l 1G /swapfile

# 2. Restrict permissions (SECURITY: only root may read memory dumps)
sudo chmod 0600 /swapfile

# 3. Format as swap space
sudo mkswap /swapfile

# 4. Activate swap
sudo swapon /swapfile

# 5. Persist in /etc/fstab
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## Hands-On Lab: Isolating Application Storage

We continue on **`sysadmin-node`** from Level 02. In Level 02, we created `/srv/app`. Now, the application requires dedicated block storage so its data and logs do not exhaust root `/`.

Connect via SSH:
```powershell
ssh labadmin@<VM_IP>
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

In this drill, we provision a simulated secondary block storage device, partition it with GPT, format it with Ext4, migrate existing `/srv/app` data onto it, persist it in `/etc/fstab` via UUID, and activate a swapfile.

### 1. Create a Simulated Secondary Block Disk
- **Action**: Create a 1GB sparse block image on the host and bind it as a loopback block device:
  ```bash
  sudo dd if=/dev/zero of=/var/lib/appdisk.img bs=1M count=1024
  sudo losetup /dev/loop10 /var/lib/appdisk.img
  lsblk /dev/loop10
  ```
- **System Reaction**:
  The kernel's `loop` module creates a block device node `/dev/loop10` mapped to the underlying disk file. The Linux storage stack treats `/dev/loop10` identically to a physical SAS/SATA/NVMe disk.
- **Verification**:
  ```bash
  lsblk | grep loop10
  ```

### 2. Partition with GPT and Format Ext4
- **Action**: Create a modern GPT partition table, allocate 100% of the disk to a primary partition, and format with Ext4:
  ```bash
  # Partition with GPT
  sudo parted /dev/loop10 --script mklabel gpt
  sudo parted /dev/loop10 --script mkpart primary ext4 1MiB 100%

  # Format with Ext4 filesystem and custom label
  sudo mkfs.ext4 -L "AppStorage" /dev/loop10p1
  ```
- **System Reaction**:
  `mkfs.ext4` writes the Superblock, Block Group Descriptors, Inode Tables, and Journal onto `/dev/loop10p1`. The kernel generates a unique 128-bit UUID for the volume.
- **Verification**:
  ```bash
  sudo blkid /dev/loop10p1
  ```

### 3. Migrate `/srv/app` Data to the New Filesystem
- **Action**: Mount the new volume temporarily, copy existing files, and mount to `/srv/app`:
  ```bash
  # Mount to temporary staging directory
  sudo mkdir -p /mnt/stage
  sudo mount /dev/loop10p1 /mnt/stage

  # Copy existing application files while preserving ownership and permissions (archive mode)
  sudo cp -a /srv/app/. /mnt/stage/

  # Unmount staging and mount directly to /srv/app
  sudo umount /mnt/stage
  sudo mount /dev/loop10p1 /srv/app
  ```
- **System Reaction**:
  The VFS attaches the root inode of `/dev/loop10p1` to directory entry `/srv/app`. Notice that the files created in Level 02 (`config.json`) are preserved with exact permissions!
- **Verification**:
  ```bash
  df -hT /srv/app
  ls -la /srv/app
  ```

### 4. Persist in `/etc/fstab` Using UUID
- **Action**: Extract the UUID and add an entry with `nofail` protection:
  ```bash
  APP_UUID=$(sudo blkid -s UUID -o value /dev/loop10p1)
  echo "UUID=$APP_UUID /srv/app ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

  # Test fstab syntax without rebooting
  sudo umount /srv/app
  sudo mount -a
  ```
- **System Reaction**:
  `mount -a` parses `/etc/fstab`, matches the UUID against kernel udev block tables, and remounts `/srv/app`. If `/etc/fstab` has a syntax error, `mount -a` reports it immediately.
- **Verification**:
  ```bash
  findmnt /srv/app
  ```

### 5. Provision Swap Memory
- **Action**: Allocate and enable a 512MB swapfile:
  ```bash
  sudo fallocate -l 512M /swapfile
  sudo chmod 0600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  ```
- **System Reaction**:
  The kernel virtual memory subsystem adds `/swapfile` to its swap allocation bitmap. `free -h` immediately displays the new swap capacity.
- **Verification**:
  ```bash
  free -h
  swapon --show
  ```

---

## Part B: Admin Solo Drill (Unguided Mission)

Now perform an unguided storage provisioning mission. No answers are provided.

### The Mission: Secondary Dedicated Archive & Backup Partition
Operations needs a dedicated archive partition for system backups and historical telemetry.

1. **Customization**:
   - Choose your own mount point directory under `/srv/` or `/var/` (e.g. `/srv/backup` or `/var/archive`).
   - Create a secondary loopback disk or partition of at least 256MB.
   - Choose your own filesystem label (e.g. `ArchiveStore` or `BackupData`).

2. **Acceptance Criteria**:
   - The partition is formatted with an enterprise filesystem (`ext4` or `xfs`).
   - The filesystem is mounted to your designated directory with permissions allowing the `sudo` group write access.
   - An entry exists in `/etc/fstab` identifying the partition **strictly by `UUID=`** with `defaults,nofail` options.
   - Unmounting the volume and running `sudo mount -a` cleanly restores the mount point with exit code `0`.
   - Inside your mounted archive partition, create an organized project hierarchy (`backups/`, `archive/`, `configs/`).
   - Take a timestamped backup of `/etc/fstab` and place it in the `configs/` subfolder (`cp /etc/fstab <mount>/configs/fstab.bak.$(date +%F)`).
   - Verify file permissions, ownership, and non-zero size using `ls -l`.

3. **Self-Verification**:
   Execute this test suite to validate your storage implementation:
   ```bash
   # Replace with your chosen mount point
   MOUNT_DIR="/srv/backup"

   echo "--- Testing Storage Persistence for $MOUNT_DIR ---"
   # Test 1: Active mount
   findmnt "$MOUNT_DIR" >/dev/null 2>&1 && echo "[PASS] Directory is actively mounted" || echo "[FAIL] Not mounted!"

   # Test 2: In fstab by UUID
   grep -E "UUID=.*$MOUNT_DIR" /etc/fstab >/dev/null 2>&1 && echo "[PASS] /etc/fstab entry uses UUID" || echo "[FAIL] Missing or not using UUID in /etc/fstab!"

   # Test 3: Clean remount via mount -a
   sudo umount "$MOUNT_DIR"
   sudo mount -a && findmnt "$MOUNT_DIR" >/dev/null 2>&1 && echo "[PASS] mount -a remount successful" || echo "[FAIL] mount -a failed to remount!"
   ```

---

## Milestone Checkpoint

Save your milestone snapshot from host PowerShell:

```powershell
Checkpoint-LabVM -Name "sysadmin-node" -SnapshotName "level-03-complete"
```

In [Level 04](../level-04-troubleshooting-logs-and-diagnostics/README.md), `/srv/app` will face a real-world production crisis: an unlinked open file handle leak will exhaust disk capacity while `ls` reports zero large files! We will troubleshoot and recover without a reboot!

---

### Navigation
| [← Previous: Level 02: Identity, Users & Permissions](../level-02-identity-users-and-permissions/README.md) | [Tier 1: Sysadmin Foundations](../README.md) | [Next: Level 04: Troubleshooting, Logging & Diagnostics →](../level-04-troubleshooting-logs-and-diagnostics/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V Tutorial 04: Virtual Storage & Differencing Disks](../../hyperv-internals/04-storage-and-differencing-disks/README.md)).*
