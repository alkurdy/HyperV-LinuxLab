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

`HyperV-LinuxLab` downloads a verified Ubuntu/Debian Cloud VHDX once and locks it read-only. Every lab VM runs on a lightweight **child differencing disk**:
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

## 📖 Step-by-Step Learning Guides
- 🚀 **[Tutorial 1: Deploying Your Linux Lab & SSH Login (Key & Password)](docs/01_DEPLOYMENT_AND_SSH_LOGIN.md)**  
  Walks step-by-step from zero to a running VM, testing both SSH key and password authentication.
- 🐧 **[Tutorial 2: Linux Operating System Essentials & Mental Model](docs/02_LINUX_ESSENTIALS_OVERVIEW.md)**  
  High-yield architectural overview of the Linux kernel, filesystem hierarchy, permissions, systemd, pipes, and networking.
- 🛠️ **[Advanced Lab Drills: Snapshots & Instant Reset](docs/TUTORIAL_LEARNING_LINUX.md)**  
  Break-fix scenarios, 2-second snapshots, and 3-second factory resets.

---

## 🛠️ Quick Start

### 1. Verify Prerequisites
Run the built-in diagnostic checker:
```powershell
Import-Module .\HyperV-LinuxLab.psd1
Test-LabPrerequisites
```

### 2. Download Base Image (Once)
Downloads and verifies the official Ubuntu 24.04 LTS Cloud VHDX:
```powershell
New-LabBaseImage -Distro Ubuntu2404
```

### 3. Spin Up a Linux Sandbox
Provisions a Generation 2 UEFI Linux VM with a differencing disk and boots it:
```powershell
New-LabVM -Name "linux-box" -MemoryGB 2 -CPUCount 2 -Start
```
*Your VM boots in ~15 seconds and automatically displays its assigned IP address.*

### 4. Connect via SSH
```powershell
ssh labadmin@<VM_IP>
```

### 5. Instant Reset to Factory State (Sub-5 Seconds!)
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
| **`New-LabBaseImage`** | Downloads official cloud VHDX image, verifies SHA256 checksum, sets read-only. |
| **`Get-LabBaseImage`** | Lists cached base golden images and verification state. |
| **`New-LabCloudInitISO`**| Generates virtual `cidata.iso` embedding SSH keys, user, and packages. |
| **`New-LabVM`** | Creates Gen2 Hyper-V VM with differencing disk and cloud-init config. |
| **`Get-LabVM`** | Queries IP address (via KVP/ARP), uptime, memory, and differencing disk size. |
| **`Reset-LabVM`** | **Instant sub-5-second reset**: discards child disk and boots fresh delta. |
| **`Remove-LabVM`** | Deletes VM, differencing disk, and temporary cloud-init ISO files. |
| **`Start-LabVM`** | Boots VM and waits for network IP acquisition. |
| **`Stop-LabVM`** | Gracefully shuts down or forces immediate power-off. |
| **`Test-LabPrerequisites`**| Validates Hyper-V hypervisor role, elevation, and virtual switches. |

For complete parameter sets, pipeline options, and detailed examples, see **[docs/CMDLET_REFERENCE.md](docs/CMDLET_REFERENCE.md)**.

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
