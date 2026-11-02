# HyperV-LinuxLab

[![CI Build](https://github.com/alkurdy/HyperV-LinuxLab/actions/workflows/ci.yml/badge.svg)](https://github.com/alkurdy/HyperV-LinuxLab/actions)
[![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/Platform-Windows%20Hyper--V-lightgrey.svg)](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/)
[![License](https://img.shields.io/badge/License-BSD_2--Clause-orange.svg)](LICENSE)

**Lightweight PowerShell module to provision, test, and instantly reset ephemeral Linux virtual machines on Hyper-V using differencing disks and Cloud-Init.**

---

## ⚡ The Problem: Slow, Heavy, Throwaway Linux Labs

When learning Linux systems engineering, testing Kubernetes clusters (`kubeadm`), or drilling break-fix troubleshooting, you need clean Linux environments frequently:
- **Manual ISO installs** waste 15–20 minutes every time you need a clean machine.
- **Docker / WSL2** share the Windows host kernel, hiding real systemd units, network interfaces, and cgroups v2.
- **Traditional VMs** consume 20GB+ of host storage per machine and take minutes to clone.

## 🚀 The Solution: Sub-5-Second Differencing Resets

`HyperV-LinuxLab` downloads verified Linux Cloud base images (Ubuntu 24.04/22.04, Debian 12, or AlmaLinux 9) once and locks them read-only. Every lab VM runs on a lightweight **child differencing disk**:
- **Disk Footprint**: Only **~50MB to ~200MB** per VM (delta changes only).
- **Zero-Touch Config**: Cloud-Init automatically configures your username, SSH keys, hostname, and packages on initial boot.
- **Instant Reset**: `Reset-LabVM` drops the child disk and swaps in a fresh delta in **under 5 seconds**.

```
┌────────────────────────────────────────────────────────┐
│ MASTER BASE IMAGE (Read-Only Golden VHDX)              │
│ Ubuntu 24.04 LTS Noble Server (~2.2 GB)                │
└───────────────────────────┬────────────────────────────┘
                            │ Read-Only Parent
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ k8s-cp (Diff) │   │ worker1(Diff) │   │ worker2(Diff) │
│ Size: ~150MB  │   │ Size: ~120MB  │   │ Size: ~120MB  │
│ Reset: ~3 sec │   │ Reset: ~3 sec │   │ Reset: ~3 sec │
└───────────────┘   └───────────────┘   └───────────────┘
```

---

## 📋 Requirements

- **Operating System**: Windows 10/11 Pro, Enterprise, Education, or Windows Server 2022/2025 *(Windows Home does not support Hyper-V natively)*
- **Hyper-V Feature Enabled**: `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All`
- **CPU Virtualization**: Intel VT-x or AMD-V enabled in UEFI/BIOS
- **Memory**: Minimum 8 GB RAM (16 GB+ recommended for Kubernetes multi-node topologies)
- **Disk Space**: Minimum 20 GB free space on target drive for base VHDX caching and differencing disks
- **Administrator Privileges**: Required for Hyper-V management
- **PowerShell**: Windows PowerShell 5.1 or PowerShell Core 7.x+

---

## 📖 Enterprise Linux Systems Engineering Mastery (Practitioner Track)

- 🐧 **[Level 01: Mental Model & Architecture](tutorials/01-sysadmin-foundations/level-01-mental-model-and-architecture/README.md)**  
  Windows NT vs Linux VFS unified hierarchy, Ring 0 monolithic kernel vs Ring 3, `/proc`/`/sys`/`/dev`, standard streams and pipes.
- 🔐 **[Level 02: Identity, Users, Groups & Permissions](tutorials/01-sysadmin-foundations/level-02-identity-users-and-permissions/README.md)**  
  UID/GID databases, `visudo` privilege escalation, octal/symbolic permissions, SGID team collaboration folders, POSIX ACLs.
- 💽 **[Level 03: Directory Hierarchy & Block Storage](tutorials/01-sysadmin-foundations/level-03-directory-hierarchy-and-storage/README.md)**  
  Filesystem Hierarchy Standard (FHS 3.0), block devices (`/dev/sdX`, `nvme`), GPT partitioning, `ext4`/`xfs`, persistent `/etc/fstab` UUIDs, swap.
- 🩺 **[Level 04: Troubleshooting, Logging & Diagnostics](tutorials/01-sysadmin-foundations/level-04-troubleshooting-logs-and-diagnostics/README.md)**  
  `journalctl` timeframes and post-crash boot analysis, `dmesg -T` OOM Killer triage, inode exhaustion (`df -i`), open file handle leaks (`lsof +L1`).
- ⚙️ **[Level 05: Process Lifecycle, Signals & Systemd](tutorials/01-sysadmin-foundations/level-05-processes-systemd-and-signals/README.md)**  
  PID 1 ancestry, D-state/Zombie states, POSIX signals (`SIGTERM`, `SIGKILL`, `SIGHUP`), authoring production `.service` units, auto-recovery.
- 🌐 **[Level 06: Linux Networking & Connectivity](tutorials/01-sysadmin-foundations/level-06-networking-and-connectivity/README.md)**  
  Modern `iproute2` (`ip a`, `ip r`), Netplan vs NetworkManager, DNS stub resolver, socket inspection (`ss -tulpn`), host firewalls (`ufw`/`firewalld`).
- 🤖 **[Level 07: Automation, Bash Scripting & Software Lifecycle](tutorials/01-sysadmin-foundations/level-07-automation-bash-and-package-lifecycle/README.md)**  
  Package lifecycles (`apt` vs `dnf`), cron scheduling, defensive strict Bash (`set -euo pipefail`), `sed`/`awk`, full break-fix capstone drill.

See the complete **[Learning Hub Index](tutorials/README.md)**.

---

## 🛠️ Quick Start

### 1. Verify Prerequisites
Run the built-in diagnostic checker:
```powershell
Import-Module .\HyperV-LinuxLab.psd1
Test-LabPrerequisites
```

### 2. Enable Hyper-V (If Not Already Installed)
If `Test-LabPrerequisites` reports `HyperVModule: False`, enable the Hyper-V role and reboot:
```powershell
Install-LabHyperV -Restart
```

### 3. Optional: Configure High-Capacity Storage
If you have a secondary high-capacity SSD (e.g. `D:\`), set it as your lab storage root:
```powershell
Set-LabConfiguration -StoragePath "D:\HyperV-LinuxLab"
```

### 4. Download Base Image (Once)
Downloads and verifies the official Ubuntu 24.04 LTS Cloud VHDX:
```powershell
New-LabBaseImage -Distro Ubuntu2404
```

### 5. Spin Up a Linux Sandbox
Provisions a Generation 2 UEFI Linux VM with a differencing disk and boots it:
```powershell
New-LabVM -Name "linux-box" -MemoryGB 2 -CPUCount 2 -Start
```
*Your VM boots in ~15 seconds and automatically displays its assigned IP address.*

### 6. Connect via SSH
```powershell
ssh labadmin@<VM_IP>
```

### 7. Instant Reset to Factory State (Sub-5 Seconds!)
Broke the OS? Network stack corrupt? Messed up a Kubernetes installation? Reset back to factory clean state in 3 seconds:
```powershell
Reset-LabVM -Name "linux-box" -Force
```

---

## 🎯 Example: Spin Up a 3-Node Kubernetes Lab Cluster

```powershell
# Master node
New-LabVM -Name "k8s-cp" -MemoryGB 4 -CPUCount 2 -Start

# Worker nodes
New-LabVM -Name "k8s-worker01" -MemoryGB 2 -CPUCount 2 -Start
New-LabVM -Name "k8s-worker02" -MemoryGB 2 -CPUCount 2 -Start

# Query status and IP addresses of all lab nodes
Get-LabVM -Name "k8s-*"
```

Total host disk space used for all 3 VMs combined: **under 500 MB**!

---

## 📚 Cmdlet Reference

| Cmdlet | Purpose |
| :--- | :--- |
| **`Install-LabHyperV`** | Validates hardware virtualization (VT-x/AMD-V) and enables the Hyper-V role with reboot handling. |
| **`New-LabBaseImage`** | Downloads official cloud VHDX image, verifies SHA256 checksum, sets read-only. |
| **`Get-LabBaseImage`** | Lists cached base golden images and verification state. |
| **`New-LabPassphrase`**| Generates memorable, human-friendly Diceware passphrases (e.g. `Swift-Falcon-42`). |
| **`New-LabCloudInitISO`**| Generates virtual `cidata.iso` embedding SSH keys, user, and packages. |
| **`New-LabVM`** | Creates Gen2 Hyper-V VM with differencing disk and cloud-init config. |
| **`Get-LabVM`** | Queries IP address (via KVP/ARP), uptime, memory, and differencing disk size. |
| **`Reset-LabVM`** | **Instant sub-5-second reset**: discards child disk and boots fresh delta. |
| **`Remove-LabVM`** | Deletes VM, differencing disk, and temporary cloud-init ISO files. |
| **`Start-LabVM`** | Boots VM and waits for network IP acquisition. |
| **`Stop-LabVM`** | Gracefully shuts down or forces immediate power-off. |
| **`Start-Lab`** | Powers on all lab VMs or cluster topology with IP discovery and connection banner. |
| **`Stop-Lab`** | Gracefully or forcefully stops all lab VMs or cluster topology nodes. |
| **`Enable-LabAutoStart`**| Configures lab VMs to boot automatically on computer startup (Hyper-V native or Scheduled Task). |
| **`Disable-LabAutoStart`**| Disables computer startup auto-boot for lab VMs and tasks. |
| **`Get-LabAutoStart`**| Queries startup auto-boot settings and scheduled task states. |
| **`Test-LabPrerequisites`**| Validates Hyper-V hypervisor role, elevation, multi-volume disks, and virtual switches. |
| **`Set-LabConfiguration`**| Configures persistent storage path (e.g., secondary drive `D:\`) and default switch. |
| **`Get-LabConfiguration`**| Displays current active lab storage root and preferred virtual switch. |

For complete parameter sets, pipeline options, and detailed examples, see **[docs/CMDLET_REFERENCE.md](docs/CMDLET_REFERENCE.md)**.

---

## 📚 Systems Engineering & Under-the-Hood Tutorials

Want to understand what `HyperV-LinuxLab` is doing under the hood without abstracting away native Windows virtualization? Explore our comprehensive 6-part deep-dive tutorials:

- **[Hyper-V 01: Prerequisites, Hardware Virtualization & Host Readiness](tutorials/hyperv-internals/01-prerequisites-and-hardware/README.md)**
- **[Hyper-V 02: Hyper-V Installation, Verification & Clean Removal](tutorials/hyperv-internals/02-installation-and-removal/README.md)**
- **[Hyper-V 03: Virtual Networking, Virtual Switches & Guest IP Routing](tutorials/hyperv-internals/03-virtual-networking/README.md)**
- **[Hyper-V 04: Virtual Storage, Golden Masters & Differencing Disks](tutorials/hyperv-internals/04-storage-and-differencing-disks/README.md)**
- **[Hyper-V 05: VM Architecture, Generation 2 UEFI & Cloud-Init Provisioning](tutorials/hyperv-internals/05-vm-architecture-and-cloud-init/README.md)**
- **[Hyper-V 06: VM Lifecycle, Telemetry, Credentials & Automation](tutorials/hyperv-internals/06-vm-lifecycle-and-telemetry/README.md)**

See the full **[Tutorials Index](tutorials/README.md)**.

---

## 🔮 Upcoming Capabilities & Roadmap

We are actively expanding `HyperV-LinuxLab` to power advanced cross-platform systems engineering and SRE training:

- 🐧 **3-Tier Enterprise Linux Systems Mastery Curriculum**:
  A 21-level structured engineering ladder taking administrators from foundational systems concepts (FHS, permissions, systemd, networking) up through advanced storage plumbing (LVM/RAID), PAM/SELinux, eBPF dynamic tracing, and high-availability clustering.
- 🪟 **Hybrid Windows Server Guest Nodes**:
  Automated provisioning of Windows Server 2022/2025 evaluation guests using unattended XML ISO injection, enabling heterogeneous multi-OS testing (Active Directory, WinRM, and cross-platform Ansible playbooks).
- 🌐 **Isolated Multi-Homed Network Topologies**:
  Declarative support for multi-NIC guests, private internal virtual switches, DMZ perimeter routing, and packet filtering labs without interfering with host network adapters.
- 📋 **Ansible Dynamic Inventory Export**:
  Automatic extraction of running cluster nodes, guest IP addresses, and SSH credentials into standard Ansible inventory files (`hosts.yaml`) for instant playbook orchestration.

---

## 🧪 Testing & Code Quality

The module includes comprehensive **Pester 5.x** unit tests and **PSScriptAnalyzer** rules:

```powershell
# Run Pester unit tests
Invoke-Pester -Path .\Tests\

# Run static code analysis
Invoke-ScriptAnalyzer -Path .\ -Recurse
```

All Hyper-V commands are mocked in unit tests, allowing 100% test coverage in CI runners without requiring bare-metal nested virtualization. See **[docs/TESTING_STRATEGY.md](docs/TESTING_STRATEGY.md)**.

---

## 📄 Documentation Index

- **[docs/SPECIFICATION.md](docs/SPECIFICATION.md)** - Full architectural design and storage mechanics
- **[docs/CMDLET_REFERENCE.md](docs/CMDLET_REFERENCE.md)** - Complete parameter dictionary and syntax guide
- **[docs/TESTING_STRATEGY.md](docs/TESTING_STRATEGY.md)** - Pester 5 test architecture and mocking design
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines and PR standards

---

## ⚖️ License

[BSD-2-Clause License](LICENSE) © 2026 alkurdy.
