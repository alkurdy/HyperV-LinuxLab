# HyperV-LinuxLab Tutorials Hub & Systems Engineering Curriculum

Welcome to the **HyperV-LinuxLab Learning & Systems Engineering Hub**.

Whether you are a Linux beginner looking to master bash, systemd, and networking, or a systems engineer wanting to understand the low-level Windows kernel, Type-1 hypervisor microkernel, and VHDX storage block tables, this curriculum provides two synchronized learning tracks.

---

## 🧭 Curriculum Tracks

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       HYPERV-LINUXLAB LEARNING HUB                              │
└───────────────────────┬─────────────────────────────────┬───────────────────────┘
                        │                                 │
           ┌────────────▼──────────────┐   ┌──────────────▼─────────────┐
           │ TRACK 1: HANDS-ON LINUX   │   │ TRACK 2: HYPER-V INTERNALS │
           │   (The Practitioner Path) │   │  (The Systems Engineer)    │
           └────────────┬──────────────┘   └──────────────┬─────────────┘
                        │                                 │
                        ├─ lab-01: Deployment & SSH       ├─ hyperv-01: Prerequisites
                        ├─ lab-02: Linux Mental Model     ├─ hyperv-02: Install/Removal
                        ├─ lab-03: Systemd & Networking   ├─ hyperv-03: Virtual Networks
                        ├─ lab-04: Snapshots & Disaster   ├─ hyperv-04: Differencing Disks
                        └─ lab-05: Multi-Distro Clusters  ├─ hyperv-05: UEFI & Cloud-Init
                                                          └─ hyperv-06: VM Lifecycle
```

---

## 🐧 Track 1: Hands-On Linux Lab (Practitioner Path)

*Designed for developers, DevOps engineers, and students who want a fast, repeatable sandbox to learn real Linux operating system internals without fear.*

| # | Tutorial | What You Will Learn | Est. Time |
| :---: | :--- | :--- | :---: |
| **01** | [**Lab Deployment & SSH Authentication**](lab-01-deployment-and-ssh.md) | Single-command provisioning, storage Scream test protection, SSH key discovery, generated passphrases, and dual-auth login. | 10 min |
| **02** | [**Linux Mental Model & Filesystem Hierarchy**](lab-02-linux-mental-model-and-filesystems.md) | User space vs kernel space, "Everything is a file", pseudo-filesystems (`/proc`, `/sys`), user permissions, `sudo`, and `strace`. | 15 min |
| **03** | [**Processes, Systemd Services & Modern Networking**](lab-03-processes-systemd-and-networking.md) | PID 1 ancestry (`pstree`), `htop`, managing services with `systemctl`, log streaming with `journalctl`, Unix pipes, and `iproute2` (`ip`, `ss`). | 20 min |
| **04** | [**Snapshots, Break-Fix Drills & Instant Disaster Recovery**](lab-04-snapshots-and-disaster-recovery.md) | Fearless failure: checkpoints (`Checkpoint-LabVM`), 2-second rollbacks (`Restore-LabVM`), catastrophic OS destruction, and 3-second differencing resets (`Reset-LabVM`). | 15 min |
| **05** | [**Multi-Distro Heterogeneous Clusters & Coexistence**](lab-05-multi-distro-clusters.md) | Running Ubuntu 24.04, Debian 12, and AlmaLinux 9 side-by-side, cross-distro sudo (`sudo` vs `wheel`), cluster validation, and credential recall (`Get-LabVM`). | 20 min |

---

## ⚡ Track 2: Hyper-V Systems Engineering (Under the Hood)

*Designed for cloud architects, platform engineers, and Windows administrators who want to master what Hyper-V, DISM, VMBus, and UEFI are doing behind the scenes without abstraction.*

| # | Tutorial | What You Will Learn | Est. Time |
| :---: | :--- | :--- | :---: |
| **01** | [**Prerequisites, Hardware Virtualization & Silicon**](hyperv-01-prerequisites-and-hardware.md) | Windows SKU gating (Pro vs Home), CPU VT-x/AMD-V registers, Ring -1 hypervisor masking, SLAT, DEP, memory reservation, and coexistence. | 15 min |
| **02** | [**Hyper-V Installation, Reboot Lifecycle & Clean Removal**](hyperv-02-installation-and-removal.md) | The 4 core layers (`hvix64.sys`, `vmms`), DISM features, pending reboot state machines, 3-point health check, **complete clean uninstallation**, and CBS log debugging. | 20 min |
| **03** | [**Virtual Networking & Guest IP Routing**](hyperv-03-virtual-networking.md) | Default Switch vs Internal NAT switches, WinNAT (`New-NetNat`), synthetic VMBus adapters, guest DHCP routing, and KVP in-memory IP resolution. | 25 min |
| **04** | [**Virtual Storage & Differencing Disks**](hyperv-04-storage-and-differencing-disks.md) | VHDX block allocation tables, read-only golden masters, 4MB child delta disks, parent-child pointer chains, and sub-5-second atomic resets. | 20 min |
| **05** | [**VM Architecture, Generation 2 UEFI & Cloud-Init**](hyperv-05-vm-architecture-and-cloud-init.md) | Gen1 vs Gen2 UEFI, Linux Secure Boot (`MicrosoftUEFICertificateAuthority`), dynamic RAM tuning, NoCloud ISO9660 generation (`cidata.iso`), and bypassing Azure `walinuxagent` boot hangs. | 25 min |
| **06** | [**VM Lifecycle, Telemetry & Automation**](hyperv-06-vm-lifecycle-and-telemetry.md) | Native power states (`Stop-VM -TurnOff`), non-blocking TCP port 22 polling, dual-write metadata (JSON + VM Notes), host startup auto-boot, multi-node orchestration, and worker process termination (`vmwp.exe`). | 25 min |

---

## 🔍 Interactive Quick-Jump Matrix

Looking for a specific concept or command? Jump directly to the relevant tutorial:

| Concept / Technology | Hands-On Guide | Systems Engineering Deep Dive |
| :--- | :--- | :--- |
| **SSH Key & Passphrase Auth** | [lab-01 Step 6](lab-01-deployment-and-ssh.md#step-6-log-in-via-ssh) | [hyperv-05 Topic 5](hyperv-05-vm-architecture-and-cloud-init.md#5-generating-nocloud-iso9660-metadata-without-third-party-tools) |
| **Differencing Disks (Child VHDX)** | [lab-04 Step 5](lab-04-snapshots-and-disaster-recovery.md#drill-5-the-3-second-factory-wipe) | [hyperv-04 Topic 3](hyperv-04-storage-and-differencing-disks.md#3-parent-child-pointer-chains-in-differencing-disks) |
| **Host Storage Scream Gate** | [lab-01 Step 2](lab-01-deployment-and-ssh.md#step-2-built-in-storage-scream-test-ui) | [hyperv-04 Topic 7](hyperv-04-storage-and-differencing-disks.md#7-handling-disk-capacity-scream-test--out-of-space-traps) |
| **Virtual Switch & WinNAT** | [lab-03 Step 6](lab-03-processes-systemd-and-networking.md#6-modern-linux-networking-with-iproute2) | [hyperv-03 Topic 2](hyperv-03-virtual-networking.md#2-creating-an-isolated-internal-nat-switch) |
| **Multi-Distro (Ubuntu/Debian/Alma)** | [lab-05](lab-05-multi-distro-clusters.md) | [hyperv-06 Topic 6](hyperv-06-vm-lifecycle-and-telemetry.md#6-multi-node-cluster-orchestration) |
| **Hyper-V Complete Removal** | - | [hyperv-02 Topic 5](hyperv-02-installation-and-removal.md#5-how-to-completely-remove-hyper-v) |
| **UEFI & Secure Boot Template** | [lab-01 Step 4](lab-01-deployment-and-ssh.md#step-4-spin-up-your-linux-lab-vm) | [hyperv-05 Topic 2](hyperv-05-vm-architecture-and-cloud-init.md#2-linux-secure-boot--uefi-certificate-authorities) |
| **IP Resolution via KVP** | [lab-01 Step 5](lab-01-deployment-and-ssh.md#step-5-the-on-screen-connection-banner) | [hyperv-03 Topic 5](hyperv-03-virtual-networking.md#5-resolving-guest-ips-without-external-dhcp-servers) |
| **System Calls (`strace`)** | [lab-02 Step 7](lab-02-linux-mental-model-and-filesystems.md#7-system-calls-how-user-space-talks-to-the-kernel) | - |
| **Service Management (`systemctl`)** | [lab-03 Step 3](lab-03-processes-systemd-and-networking.md#3-service-management-with-systemd) | - |

---

## 💡 Reading on GitHub

All tutorial documents feature standardized top and bottom navigation bars:
- Click **[← Previous]** to step back.
- Click **[📑 Index]** to return to this hub.
- Click **[Next →]** to advance to the next lesson.
- Click cross-track links at the bottom of any page to toggle between hands-on commands and low-level architectural internals.
