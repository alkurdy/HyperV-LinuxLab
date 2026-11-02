# Level 03: Directory Hierarchy, Block Storage & Filesystems

> **Tier 1: Sysadmin Foundations** • Grounded in *CompTIA Linux+ Study Guide* & *Linux Command Line and Shell Scripting Bible*.

---

## 🎯 Objective
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

## 2. Storage Topography: Block Devices vs Partitions

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

### Partitioning with `gdisk` or `parted`
```bash
# Non-interactive GPT partition creation using parted:
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

```bash
# Format partition as Ext4 with standard journal
sudo mkfs.ext4 -L "DataVolume" /dev/sdb1

# Check filesystem integrity (equivalent to Windows chkdsk)
# WARNING: Never run fsck on a mounted filesystem!
sudo umount /dev/sdb1
sudo fsck.ext4 -f /dev/sdb1
```

---

## 5. Mounting & The `/etc/fstab` Contract

A filesystem must be mounted to a directory to become accessible.

### Manual Mount / Unmount
```bash
# Create mount directory
sudo mkdir -p /mnt/data

# Mount partition
sudo mount /dev/sdb1 /mnt/data

# Verify mount state and disk space
df -hT /mnt/data

# Unmount
sudo umount /mnt/data
```

### The `/etc/fstab` Golden Rule: ALWAYS USE UUIDs
**Why device names fail**: On reboot, the kernel scans SATA/PCIe buses asynchronously. The drive that was `/dev/sda` yesterday may become `/dev/sdb` today. If `/etc/fstab` references `/dev/sdb1`, the boot will hang or enter Emergency Mode!

Every filesystem has a persistent, unique **UUID** that never changes:

```bash
# Find the UUID of /dev/sdb1
sudo blkid /dev/sdb1
# /dev/sdb1: UUID="9f8b4c2a-1122-3344-5566-778899aabbcc" TYPE="ext4"
```

### Anatomy of an `/etc/fstab` Line
`/etc/fstab` contains 6 columns separated by whitespace:

```
[Device/UUID]                     [Mount Point]  [Type]  [Mount Options]          [Dump] [Pass]
UUID=9f8b4c2a-1122-3344-5566...   /mnt/data      ext4    defaults,noatime,nofail  0      2
```

1. **Device / UUID**: Identifies the filesystem.
2. **Mount Point**: Directory where files appear.
3. **Type**: `ext4`, `xfs`, `nfs`, `btrfs`.
4. **Options**:
   - `defaults`: Enables `rw, suid, dev, exec, auto, nouser, async`.
   - `noatime`: Disables updating access timestamps on every file read (major I/O speedup!).
   - `nofail`: **Critical for cloud/data drives**. Tells systemd to continue booting if this drive is missing!
5. **Dump**: Backup flag (legacy; set to `0`).
6. **Pass**: `fsck` boot check order (`1` for root `/`, `2` for data drives, `0` to disable).

> [!CAUTION]
> **Test Before Rebooting**: Always run `sudo mount -a` after editing `/etc/fstab`. If `mount -a` returns errors, fix them immediately. An erroneous line in `/etc/fstab` will cause boot failure into emergency maintenance mode!

---

## 6. Swap Space: Memory Relief Valve

When physical RAM is exhausted, the Linux kernel pages anonymous memory out to disk swap:

```bash
# 1. Allocate a 2GB contiguous swap file
sudo fallocate -l 2G /swapfile

# 2. Lock permissions to root only (CRITICAL security requirement)
sudo chmod 600 /swapfile

# 3. Format as Linux swap area
sudo mkswap /swapfile

# 4. Activate swap
sudo swapon /swapfile

# 5. Persist in /etc/fstab
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 6. Verify active swap memory
free -h
```

---

## 🛠️ Hands-On Lab Drill: Disk Allocation & Persistent Mount

Deploy or reuse your lab VM (`New-LabVM -Name "drill-03" -Start`):

> [!TIP]
> **Safety Net: Snapshot Before Modifying Storage & /etc/fstab**  
> Corrupting `/etc/fstab` causes systemd to drop into an emergency shell on reboot. Take a snapshot before editing storage:
> ```powershell
> Checkpoint-LabVM -Name "drill-03" -SnapshotName "pre-storage-drill"
> ```
> If the VM fails to boot or mount, revert back in 2 seconds:
> ```powershell
> Restore-LabVM -Name "drill-03" -SnapshotName "pre-storage-drill" -Force
> ```
> Once persistent mounts are verified, merge and consolidate deltas:
> ```powershell
> Remove-LabCheckpoint -Name "drill-03" -All -Force
> ```

```bash
# 1. Check existing disk usage and partitions
lsblk
df -hT

# 2. Create a simulated secondary block device (1GB loopback disk)
sudo dd if=/dev/zero of=/var/lib/virtualdisk.img bs=1M count=1024
sudo losetup /dev/loop10 /var/lib/virtualdisk.img

# 3. Create a GPT partition table on the loop device
sudo parted /dev/loop10 --script mklabel gpt
sudo parted /dev/loop10 --script mkpart primary ext4 1MiB 100%

# 4. Format with Ext4 filesystem
sudo mkfs.ext4 -L "VirtualData" /dev/loop10p1

# 5. Query its persistent UUID
TARGET_UUID=$(sudo blkid -s UUID -o value /dev/loop10p1)
echo "Generated UUID: $TARGET_UUID"

# 6. Mount and create test files
sudo mkdir -p /mnt/production_data
sudo mount /dev/loop10p1 /mnt/production_data
echo "Systems engineering drill verified" | sudo tee /mnt/production_data/proof.txt

# 7. Unmount and verify the directory is empty when unmounted
sudo umount /mnt/production_data
ls /mnt/production_data
# Empty!
```
