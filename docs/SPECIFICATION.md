# HyperV-LinuxLab - Architectural Specification

**Module Name**: `HyperV-LinuxLab`  
**Target Environment**: Windows 10/11 Pro, Enterprise, Education, or Windows Server 2022/2025  
**PowerShell Compatibility**: Windows PowerShell 5.1 & PowerShell Core 7.x+  
**License**: BSD-2-Clause  

---

## 1. Problem Statement & Mission

Building and testing multi-node Kubernetes clusters, container runtimes (`podman`, `containerd`), and Linux kernel mechanics requires frequent, clean operating system resets. Existing solutions suffer from significant drawbacks:
- **Manual ISO Installations**: 15–25 minutes per VM; non-repeatable.
- **Docker Desktop / WSL2**: Shares the Windows host kernel; lacks independent `systemd` init, native `cgroups v2` isolation, and real Linux network interfaces.
- **Heavyweight Vagrant / VirtualBox**: High disk consumption (20GB+ per VM), slow teardown cycles, and VirtualBox/Hyper-V hypervisor coexistence friction.

### The Solution
`HyperV-LinuxLab` is an infrastructure-as-code PowerShell module that provisions and resets true, hardware-virtualized Linux virtual machines in seconds by combining:
1. **Official Cloud-Init VHDX Images**: Upstream Canonical Ubuntu / Debian cloud images.
2. **Hyper-V Differencing Disks**: Multi-tier virtual disk architecture where child disks store only session delta writes (~50MB to ~300MB per VM), leaving the master image pristine and read-only.
3. **Automated Cloud-Init Injection**: Dynamic generation of virtual NoCloud configuration disks (`cidata.iso`) injecting SSH keys, user credentials, network configurations, and bootstrap packages on boot.
4. **Sub-5-Second Rebuilds**: Instant reset mechanism that discards the child differencing disk and spawns a fresh replacement without touching hypervisor network adapters or base images.

---

## 2. System Architecture

```
+-------------------------------------------------------------------------+
| Windows 11 Host                                                         |
|                                                                         |
|  [ PowerShell 7 / Windows Terminal ]                                    |
|         │                                                               |
|         ├──> New-LabBaseImage      (Fetches & validates Cloud VHDX)     |
|         ├──> New-LabCloudInitISO   (Builds cidata.iso config)           |
|         ├──> New-LabVM             (Orchestrates Hyper-V differencing)  |
|         └──> Reset-LabVM           (Instant delta swap in < 5 seconds)  |
+---------│---------------------------------------------------------------│
          │                                                               │
          ▼                                                               ▼
+------------------------------------+   +------------------------------------+
| Hyper-V Virtual Switch             |   | Storage Layer                      |
| (Default Switch / Internal NAT)    |   |                                    |
|                                    |   | [ Master Base Image (Read-Only) ]  |
|  * DHCP Allocation (172.x / 192.x) |   |   ubuntu-24.04-server.vhdx         |
|  * DNS Forwarding                  |   |                 │                  |
|  * Host-to-Guest SSH Routing       |   |                 ├──────────────────┤
+-----------------│------------------+   |                 ▼                  ▼
                  │                      |         [ Child Diff VHDX ] [ Child Diff VHDX ]
                  ▼                      |           k8s-cp.vhdx         worker1.vhdx
+────────────────────────────────────+   +-----------------│──────────────────│
| Linux Lab Virtual Machine          |                     │                  │
|                                    |<────────────────────┴──────────────────┘
|  * Gen 2 UEFI Firmware             |
|  * Linux Secure Boot (MS Cert Auth)|
|  * 100% Native Linux Kernel        |
|  * Real systemd & cgroups v2       |
|  * Cloud-Init auto-configuration   |
+------------------------------------+
```

---

## 3. Core Technical Mechanics

### 3.1 Differencing VHDX Storage Pattern
- **Parent Disk**: A downloaded, verified, read-only Cloud VHDX. Multiple child VMs point to the exact same parent image simultaneously.
- **Child Disk**: Created via `New-VHD -ParentPath $BaseVHDX -Path $ChildVHDX -Differencing`.
- **Reset Mechanism**:
  1. `Hyper-V\Stop-VM -Name $Name -TurnOff`
  2. `Remove-Item $ChildVHDX -Force`
  3. `New-VHD -ParentPath $BaseVHDX -Path $ChildVHDX -Differencing`
  4. `Hyper-V\Start-VM -Name $Name`
  *Result: Zero manual reconfiguration, sub-5-second reset time, 98% disk storage reduction.*

### 3.2 Cloud-Init NoCloud Injection
Linux cloud images look for a volume labeled `cidata` on boot:
- **`meta-data`**: Defines `instance-id`, `local-hostname`, and network configurations.
- **`user-data`**: Defines user accounts (`default_user`), authorized SSH keys (`ssh_authorized_keys`), package installation lists (`packages`), and startup commands (`runcmd`).
The module dynamically builds a standards-compliant ISO or FAT image in memory and mounts it to the VM's virtual DVD drive.

### 3.3 Gen 2 UEFI & Linux Secure Boot
Standard Hyper-V VMs default to Windows Secure Boot certificates, which cause Linux cloud images to halt with `Verification failed: (0x1A) Security Violation`.
`HyperV-LinuxLab` explicitly configures:
```powershell
Set-VMFirmware -VM $VM -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
```
This enables hardware-level UEFI Secure Boot using the Microsoft UEFI CA standard, matching enterprise production deployments.

### 3.4 IP Address Discovery via Hyper-V KVP Exchange
Rather than requiring static IP configurations or slow ping sweeps, `HyperV-LinuxLab` queries the Hyper-V Key-Value Pair (KVP) Data Exchange Integration Service directly from the Windows guest registry:
`Get-VM -Name $Name | Select-Object -ExpandProperty NetworkAdapters | Select-Object -ExpandProperty IPAddresses`
This returns the assigned IPv4 address within 2 seconds of the Linux network stack coming up.

---

## 4. Directory & Repository Layout

```
HyperV-LinuxLab/
├── .github/
│   └── workflows/
│       └── ci.yml                     # Automated Pester 5 testing & ScriptAnalyzer
├── docs/
│   ├── SPECIFICATION.md               # This architectural specification
│   ├── CMDLET_REFERENCE.md            # Complete parameter & syntax dictionary
│   └── TESTING_STRATEGY.md            # Pester test execution & mocking design
├── examples/
│   ├── 01-Single-Linux-Node.ps1       # Single sandbox for kernel & podman drills
│   ├── 02-K8s-3Node-Cluster.ps1       # Multi-node topology for kubeadm
│   └── 03-Automated-Reset-Loop.ps1    # Break-fix reset iteration script
├── HyperV-LinuxLab.psd1               # Module manifest
├── HyperV-LinuxLab.psm1               # Root module loader
├── Private/
│   ├── Assert-Administrator.ps1       # Elevation validation
│   ├── Get-LabDefaultSwitch.ps1       # Virtual switch resolution
│   ├── Get-LabVMIPAddress.ps1         # KVP / ARP IP resolution helper
│   └── New-ISO9660Image.ps1           # Pure PowerShell ISO packaging engine
├── Public/
│   ├── Get-LabBaseImage.ps1           # Query local golden images
│   ├── Get-LabVM.ps1                  # Query lab VMs and runtime telemetry
│   ├── New-LabBaseImage.ps1           # Download and verify official cloud VHDX
│   ├── New-LabCloudInitISO.ps1        # Generate cidata configuration ISO
│   ├── New-LabVM.ps1                  # Provision Gen2 differencing VM
│   ├── Remove-LabVM.ps1               # Complete teardown of VM and child assets
│   ├── Reset-LabVM.ps1                # Sub-5-second delta reset
│   ├── Start-LabVM.ps1                # Start and wait for IP readiness
│   ├── Stop-LabVM.ps1                 # Graceful or forced shutdown
│   └── Test-LabPrerequisites.ps1      # Validate Hyper-V and environment health
├── Tests/
│   ├── Module.Tests.ps1               # PSScriptAnalyzer & manifest validation
│   ├── Public/
│   │   ├── Get-LabVM.Tests.ps1
│   │   ├── New-LabBaseImage.Tests.ps1
│   │   ├── New-LabCloudInitISO.Tests.ps1
│   │   ├── New-LabVM.Tests.ps1
│   │   ├── Remove-LabVM.Tests.ps1
│   │   └── Reset-LabVM.Tests.ps1
│   └── TestData/
│       └── sample-userdata.yaml
├── README.md                          # Public repository landing page
├── CONTRIBUTING.md                    # Contributor standards & PR workflow
└── LICENSE                            # BSD-2-Clause license
```
