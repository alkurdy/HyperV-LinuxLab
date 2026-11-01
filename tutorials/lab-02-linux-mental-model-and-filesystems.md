# Lab Tutorial 02: Linux Operating System Mental Model & Filesystem Hierarchy

> **[HyperV-LinuxLab Tutorials Hub](README.md)** • **Track 1: Hands-On Linux Lab** • [← Previous: Lab Deployment & SSH](lab-01-deployment-and-ssh.md) • [📑 Index](README.md) • [Next: Processes, Services & Networking →](lab-03-processes-systemd-and-networking.md)

---

Now that you are logged into your Linux prompt (`labadmin@linux-sandbox:~$`), let's demystify how Linux actually operates under the hood so you can troubleshoot systems, debug containers, and administer Kubernetes with confidence.

Unlike Windows, where GUI subsystems, registries, and DLLs are deeply interwoven, Linux is built on a clear, layered hierarchy governed by one fundamental axiom: **Everything is a file.**

---

## 🧭 In This Tutorial:
1. [The 3-Layer Linux Mental Model](#1-the-3-layer-linux-mental-model)
2. [The Filesystem Hierarchy (`/`)](#2-everything-is-a-file--the-filesystem-hierarchy)
3. [Drill: Inspecting In-Memory Pseudo-Filesystems (`/proc`, `/sys`)](#3-hands-on-drill-inspect-the-pseudo-filesystems)
4. [User Identity, Permissions & `sudo`](#4-user-identity-permissions-and-sudo)
5. [Dissecting System Configurations in `/etc`](#5-dissecting-system-configurations-in-etc)
6. [Storage Devices & Mount Points (`/dev`, `lsblk`, `df`)](#6-storage-devices--mount-points)
7. [System Calls: Tracing User Space to Kernel Space (`strace`)](#7-system-calls-how-user-space-talks-to-the-kernel)

---

## 1. The 3-Layer Linux Mental Model

So you want to understand what's happening when you type a command? Linux divides all activity into strict boundaries:

```text
┌────────────────────────────────────────────────────────┐
│ USER SPACE (Applications: bash, docker, nginx, htop)   │
└───────────────────────────┬────────────────────────────┘
                            │ System Calls (syscalls: open, read, fork, exec)
┌───────────────────────────▼────────────────────────────┐
│ LINUX KERNEL (Memory, CPU scheduling, Drivers, Network)│
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ HARDWARE (CPU, RAM, Hyper-V Virtual Disks & NICs)      │
└────────────────────────────────────────────────────────┘
```

### Key Takeaways:
1. **The Kernel**: Controls hardware, allocates physical memory pages, schedules CPU time, and processes network packets. You never touch the kernel directly; you communicate through **system calls**.
2. **User Space**: Where all user applications, command shells (`bash`), and daemons run with unprivileged CPU instructions.
3. **PID 1 (`systemd`)**: The first user-space process started by the kernel. It spawns, monitors, and stops all background services.

---

## 2. "Everything is a File" & The Filesystem Hierarchy

In Windows, storage is divided into drive letters (`C:\`, `D:\`). In Linux, there are **no drive letters**. Everything begins at the single root directory: `/`.

Hardware devices, running kernel metrics, and network sockets all present themselves as files.

```text
/ (Root Directory)
├── etc/         System configurations (plain-text files: network, users, ssh)
├── var/         Variable data (logs in /var/log, docker containers in /var/lib/docker)
├── home/        User home directories (/home/labadmin)
├── proc/        Virtual filesystem: live view of running kernel and process stats
├── sys/         Virtual filesystem: live view of hardware and kernel drivers
├── dev/         Device nodes (disks: /dev/sda, terminals: /dev/pts)
├── usr/         User binaries, libraries, and documentation (/usr/bin)
└── tmp/         Temporary scratch files (cleared on reboot)
```

---

## 3. Hands-On Drill: Inspect the Pseudo-Filesystems

Now that we understand the hierarchy, let's explore `/proc` and `/sys`. These directories do not live on physical disk; the Linux kernel generates them dynamically in RAM when read:

```bash
# View CPU hardware info directly from the kernel
cat /proc/cpuinfo | grep "model name"

# View current live memory usage
cat /proc/meminfo | head -n 5

# View network interface statistics maintained by the kernel
cat /proc/net/dev

# View the exact kernel boot command line injected by Hyper-V UEFI
cat /proc/cmdline
```

*Notice: `/proc` consumes 0 bytes of disk storage. It is an open window directly into kernel memory.*

---

## 4. User Identity, Permissions, and `sudo`

Linux is a multi-user operating system with strict permission boundaries.

### Check Your Identity:
```bash
whoami
# Output: labadmin

id
# Shows your User ID (uid=1000), Primary Group (gid=1000), and supplementary groups (sudo, docker)
```

### The Permission Grid: `rwx`
Every file and directory in Linux has three tiers of permissions:
1. **User (Owner)**: What the creator can do.
2. **Group**: What members of the file's assigned group can do.
3. **Others**: What everyone else on the system can do.

```bash
ls -l /etc/shadow
# Output: -rw-r----- 1 root shadow 1240 Oct 30 15:00 /etc/shadow
```
- `-rw-r-----`: 
  - Owner (`root`) can **read** and **write** (`rw-`).
  - Group (`shadow`) can **read** (`r--`).
  - Others have **zero access** (`---`).
- Try reading it without privileges:
  ```bash
  cat /etc/shadow
  # Permission denied!
  ```
- Now use `sudo` (Super User Do) to elevate temporarily:
  ```bash
  sudo cat /etc/shadow
  # Success! Displays encrypted system password hashes.
  ```

---

## 5. Dissecting System Configurations in `/etc`

So you want to know where Linux saves its settings? Unlike the Windows Registry, Linux stores configurations in human-readable plain text inside `/etc`:

```bash
# View hostname configuration
cat /etc/hostname

# View static name resolution (local DNS mappings)
cat /etc/hosts

# View nameserver DNS resolvers
cat /etc/resolv.conf

# View user account records
head -n 5 /etc/passwd
```

---

## 6. Storage Devices & Mount Points

Now that we've seen `/etc`, let's see how Linux exposes physical and virtual hard disks:

```bash
# List all block storage devices and partitions
lsblk

# View mounted filesystems, total disk space, and percent used
df -h
```

- `/dev/sda`: The primary virtual disk attached to the SCSI controller by Hyper-V.
- `/dev/sda1` or `/dev/sda2`: Partition formatted with the `ext4` filesystem and mounted to `/`.
- `/dev/sr0`: The virtual DVD drive containing our injected `cidata.iso` Cloud-Init disk.

---

## 7. System Calls: How User Space Talks to the Kernel

So you want to see the boundary between user applications and the kernel? Programs talk to the kernel via **system calls** (e.g. `read`, `write`, `openat`, `socket`). 

Trace what `ls` does under the hood using `strace`:

```bash
strace -c ls /
```

### What You Will See:
A summary table of system calls executed:
```text
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 35.42    0.000340          42         8           getdents64
 22.15    0.000212          19        11           newfstatat
 18.04    0.000173          15        11           openat
 12.30    0.000118          10        11           close
 ...
```
- `openat`: Kernel opened directory descriptors.
- `getdents64`: Kernel read directory entries.
- `close`: User space released file descriptors.

---

### 🧭 Navigation
| [← Previous: Lab Deployment & SSH](lab-01-deployment-and-ssh.md) | [📑 All Tutorials](README.md) | [Next: Lab Tutorial 03 - Processes, Services & Networking →](lab-03-processes-systemd-and-networking.md) |
| :--- | :---: | ---: |

*(Under the hood: Want to learn how Hyper-V allocates and connects virtual SCSI disks? Read [Hyper-V Tutorial 04: Storage & Differencing Disks](hyperv-04-storage-and-differencing-disks.md)).*
