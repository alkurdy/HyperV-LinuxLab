# HyperV-LinuxLab Systems Engineering & Linux Mastery Hub

Welcome to the **single authoritative learning hub** for `HyperV-LinuxLab`.

Whether you are an enterprise systems administrator transitioning from Windows/VMware into Linux engineering, or a cloud engineer wanting to master low-level Hyper-V hypervisor internals, this hub provides a unified, structured curriculum.

---

## 🧭 The Single Master Curriculum Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    HYPERV-LINUXLAB UNIFIED LEARNING HUB                         │
└───────────────────────┬─────────────────────────────────┬───────────────────────┘
                        │                                 │
           ┌────────────▼──────────────┐   ┌──────────────▼─────────────┐
           │ TRACK 1: LINUX MASTERY    │   │ TRACK 2: HYPER-V INTERNALS │
           │   (21 Levels across 3     │   │   (The Systems Engineer)   │
           │        Tiers)             │   │    [hyperv-internals]      │
           └────────────┬──────────────┘   └──────────────┬─────────────┘
                        │                                 │
                        ├─ 01-sysadmin-foundations        ├─ 01-prerequisites-and-hardware
                        │   (Levels 01 - 07 Complete)     ├─ 02-installation-and-removal
                        │                                 ├─ 03-virtual-networking
                        ├─ 02-advanced-systems            ├─ 04-storage-differencing-disks
                        │   (Levels 08 - 14 Roadmap)      ├─ 05-vm-architecture-cloud-init
                        │                                 └─ 06-vm-lifecycle-and-telemetry
                        └─ 03-expert-sre
                            (Levels 15 - 21 Roadmap)
```

---

## 🐧 Track 1: Enterprise Linux Systems Engineering (21 Levels)

Grounded in canonical operating systems literature (*Linux Command Line Bible*, *Stallings OS Internals*, *Linux Cookbook*, *CompTIA Linux+*).

### Tier 1: Sysadmin Foundations (Levels 01 – 07)
*Designed specifically for administrators with Windows Server, Active Directory, and VMware experience transitioning into Linux systems engineering.*

| Level | Module | Core Systems Concept | Layered Server Milestone & Admin Solo Drill |
| :---: | :--- | :--- | :--- |
| **01** | [**Mental Model & Architecture**](01-sysadmin-foundations/level-01-mental-model-and-architecture/README.md) | VFS single tree, Ring 0 vs Ring 3, pseudo filesystems (`/proc`, `/sys`), streams (`stdin`/`stdout`/`stderr`), pipes. | Provision `sysadmin-node`, audit bare-metal baseline, build unguided custom telemetry extractor. |
| **02** | [**Identity, Users & Permissions**](01-sysadmin-foundations/level-02-identity-users-and-permissions/README.md) | UID/GID (`/etc/passwd`, `/etc/shadow`), `visudo`, octal permissions, directory traversal, SGID sticky groups, POSIX ACLs. | Create `appteam`, `svc-app`, provision `/srv/app` with SGID/ACLs, unguided contractor boundary lockdown. |
| **03** | [**Directory Hierarchy & Storage**](01-sysadmin-foundations/level-03-directory-hierarchy-and-storage/README.md) | FHS 3.0, block devices (`/dev/sdX`), GPT partitioning, `ext4`/`xfs`, persistent `/etc/fstab` UUID mounting, swap memory. | Partition block disk, format Ext4, mount to `/srv/app`, activate swap, unguided secondary archive mount. |
| **04** | [**Troubleshooting & Diagnostics**](01-sysadmin-foundations/level-04-troubleshooting-logs-and-diagnostics/README.md) | `systemd-journald` vs `rsyslog`, `/var/log` triage, `journalctl` timeframes, OOM Killer triage, open file handle leaks (`lsof +L1`). | Diagnose/reclaim phantom disk space on `/srv/app`, unguided inode saturation triage & audit. |
| **05** | [**Processes, Signals & Systemd**](01-sysadmin-foundations/level-05-processes-systemd-and-signals/README.md) | Process hierarchy, states (`R`, `S`, `D`, `Z`), signals (`SIGTERM`, `SIGKILL`), systemd service units, restart policies, timers. | Deploy `app.service` under `svc-app` logging to `/var/log/app`, test kill/restart, unguided timer daemon. |
| **06** | [**Networking & Connectivity**](01-sysadmin-foundations/level-06-networking-and-connectivity/README.md) | Modern `iproute2`, DNS resolution (`systemd-resolved`), socket states (`ss -tulpn`), HTTP handshakes (`curl -Iv`), UFW firewalls. | Bind app to port 8080, verify DNS/routes, lock down UFW firewall, unguided subnet-restricted listener. |
| **07** | [**Automation, Bash & Capstone**](01-sysadmin-foundations/level-07-automation-bash-and-package-lifecycle/README.md) | Package lifecycles, cron/timer scheduling, defensive Bash (`set -euo pipefail`), stream filtering (`awk`/`sed`), break-fix capstone. | Defensive self-healing automation, unguided multi-layer incident recovery capstone (storage, perms, service, firewall). |

---

### Tier 2: Advanced Systems Engineering (Levels 08 – 14)
👉 **[Browse Tier 2 Roadmap](02-advanced-systems/README.md)**
- **Level 08**: Logical Volume Management (LVM PV/VG/LV, thin provisioning) & Software RAID (`mdadm`).
- **Level 09**: Advanced Linux Networking (Bridges `br0`, bonded interfaces, VLAN tagging 802.1Q, network namespaces).
- **Level 10**: Pluggable Authentication Modules (PAM stack `/etc/pam.d/`, lockout policies, `/etc/security/limits.conf`, SSH hardening).
- **Level 11**: Mandatory Access Control (SELinux contexts, booleans, and AVC audit analysis vs AppArmor).
- **Level 12**: Linux Virtualization & Container Engines (KVM/QEMU, cgroups v2, namespaces, rootless Podman).
- **Level 13**: Fleet Configuration Management with Ansible (Idempotent playbooks, roles, vault, drift detection).
- **Level 14**: System Performance Profiling (Brendan Gregg's USE methodology, `vmstat`, `iostat`, `sysctl.conf` tuning).

---

### Tier 3: Expert Architect & SRE (Levels 15 – 21)
👉 **[Browse Tier 3 Roadmap](03-expert-sre/README.md)**
- **Level 15**: Linux Kernel Internals & Virtual Memory (SLAB allocator, HugePages, page cache, dirty page flusher).
- **Level 16**: Deep Observability with eBPF & Dynamic Tracing (`bpftrace`, BCC tools, `perf`, `kdump`/`crash`).
- **Level 17**: Enterprise High-Availability Clustering (Corosync quorum, Pacemaker STONITH fencing, DRBD replicated storage).
- **Level 18**: Enterprise Directory Integration & Distributed Storage (SSSD, Active Directory/FreeIPA realm join, Kerberos NFSv4, Ceph/GlusterFS).
- **Level 19**: High-Throughput Kernel Bypass Networking (DPDK, XDP / eXpress Data Path, SR-IOV).
- **Level 20**: Threat Forensics, Kernel Hardening & Compliance (CIS Level 2 benchmarks, Kernel Lockdown, `seccomp-bpf`, IMA/EVM).
- **Level 21**: Linux Chaos Engineering & Disaster Recovery (Kernel panic recovery, manual GRUB rescue, chroot repair).

---

## ⚡ Track 2: Hyper-V Systems Engineering (Under the Hood)

*Master what Hyper-V, DISM, VMBus, and UEFI are doing behind the scenes on your Windows host without abstraction.*

👉 **[Browse Full Hyper-V Track Hub](hyperv-internals/README.md)**

| # | Tutorial | Core Hypervisor Concept | Layered Platform Milestone & Solo Drill |
| :---: | :--- | :--- | :--- |
| **01** | [**Prerequisites, Hardware Virtualization & Silicon**](hyperv-internals/01-prerequisites-and-hardware/README.md) | Windows SKU gating (Pro vs Home), CPU VT-x/AMD-V registers, Ring -1 hypervisor masking, SLAT, DEP, memory reservation, and coexistence. | Audit silicon readiness, verify Ring -1 masking, build unguided pre-flight hardware gatekeeper. |
| **02** | [**Hyper-V Installation, Reboot Lifecycle & Clean Removal**](hyperv-internals/02-installation-and-removal/README.md) | The 4 core layers (`hvix64.sys`, `vmms`), DISM features, pending reboot state machines, 3-point health check, **complete clean uninstallation**, and CBS log debugging. | Provision hypervisor stack, evaluate reboot state machine, build unguided role health auditor. |
| **03** | [**Virtual Networking & Guest IP Routing**](hyperv-internals/03-virtual-networking/README.md) | Default Switch vs Internal NAT switches, WinNAT (`New-NetNat`), synthetic VMBus adapters, guest DHCP routing, and KVP in-memory IP resolution. | Build internal virtual switch, bind gateway, configure WinNAT, build unguided isolated tenant subnet. |
| **04** | [**Virtual Storage & Differencing Disks**](hyperv-internals/04-storage-and-differencing-disks/README.md) | VHDX block allocation tables, read-only golden masters, 4MB child delta disks, parent-child pointer chains, and sub-5-second atomic resets. | Construct golden master VHDX, spawn child differencing disks, build unguided atomic disk reset utility. |
| **05** | [**VM Architecture, Generation 2 UEFI & Cloud-Init**](hyperv-internals/05-vm-architecture-and-cloud-init/README.md) | Gen1 vs Gen2 UEFI, Linux Secure Boot (`MicrosoftUEFICertificateAuthority`), dynamic RAM tuning, NoCloud ISO9660 generation (`cidata.iso`), and bypassing Azure `walinuxagent` boot hangs. | Provision Gen2 UEFI VM with Linux Secure Boot, generate and inject Cloud-Init ISO, build unguided unattended node. |
| **06** | [**VM Lifecycle, Telemetry & Automation**](hyperv-internals/06-vm-lifecycle-and-telemetry/README.md) | Native power states (`Stop-VM -TurnOff`), non-blocking TCP port 22 polling, dual-write metadata (JSON + VM Notes), host startup auto-boot, multi-node orchestration, and worker process termination (`vmwp.exe`). | Capture KVP guest telemetry, persist dual-write metadata, build unguided declarative multi-node cluster orchestrator. |

---

## 🛠️ Running Any Lab Drill

Every drill in this curriculum runs on your local machine using `HyperV-LinuxLab`:

```powershell
# 1. Spin up an ephemeral lab node
New-LabVM -Name "drill-node" -MemoryGB 2 -CPUCount 2 -Start

# 2. Connect via SSH
ssh labadmin@<VM_IP>

# 3. Complete the exercise, then wipe back to clean state in < 2 seconds
Reset-LabVM -Name "drill-node" -Force

# 4. Teardown when finished
Remove-LabVM -Name "drill-node" -Force
```

---

## 📸 The Student Safety Net: Checkpoints, Rollbacks & Consolidation

When learning Linux systems engineering, you will inevitably break your operating system: lock yourself out of `sudo`, write a syntax error into `/etc/fstab` that prevents boot, or misconfigure a firewall that terminates your SSH session.

Instead of re-deploying the VM from scratch and re-installing all your packages, use **Hyper-V Checkpoints (Snapshots)**.

### How Hyper-V Checkpoints Work Under the Hood

```
[ Master Base Golden VHDX (Read-Only) ]  <-- Cached once on host
                   │
                   ▼
       [ Child Differencing VHDX ]       <-- Created by New-LabVM (~100 MB)
                   │
                   ▼ (When you run Checkpoint-LabVM)
     [ Checkpoint Delta .avhdx Disk ]    <-- Freezes child disk; all new writes land here!
```

1. **`Checkpoint-LabVM`**: Instantly freezes the active differencing disk and creates a lightweight delta disk (`.avhdx`). Your VM continues running with zero downtime.
2. **`Restore-LabVM`**: Discards the `.avhdx` delta and returns the VM execution pointer back to the exact frozen point in **~1 to 2 seconds**. All packages and configuration files you had when you took the snapshot are preserved!
3. **`Remove-LabCheckpoint` (Consolidate/Merge)**: When an exercise milestone is completed and verified, deleting the checkpoint merges the `.avhdx` delta back into your child differencing disk in the background.
4. **`Reset-LabVM` vs `Restore-LabVM`**:
   - `Restore-LabVM`: Reverts back to your **last saved tutorial milestone** (retains packages you installed).
   - `Reset-LabVM`: Reverts back to the **original factory golden image** (drops everything in < 2 seconds).

### The Student Snapshot Arsenal

```powershell
# Take a snapshot before touching risky configuration files
Checkpoint-LabVM -Name "drill-node" -SnapshotName "pre-fstab-edit"

# View all saved checkpoints and timestamps
Get-LabCheckpoint -Name "drill-node"

# Made a catastrophic mistake? Revert in 2 seconds:
Restore-LabVM -Name "drill-node" -SnapshotName "pre-fstab-edit" -Force

# Exercise completed successfully? Consolidate and merge deltas:
Remove-LabCheckpoint -Name "drill-node" -All -Force
```

### 🎯 Best Places in the Curriculum to Snapshot

| Level | Risky Operation | Recommended Snapshot Command |
| :---: | :--- | :--- |
| **Level 02** | Editing `/etc/sudoers.d/` or locking accounts | `Checkpoint-LabVM -Name "drill-node" -SnapshotName "pre-sudo-edit"` |
| **Level 03** | Modifying partition tables or `/etc/fstab` mounts | `Checkpoint-LabVM -Name "drill-node" -SnapshotName "pre-fstab-edit"` |
| **Level 04** | Simulating unlinked file leaks or killing services | `Checkpoint-LabVM -Name "drill-node" -SnapshotName "pre-outage-drill"` |
| **Level 05** | Masking system services or modifying unit dependencies | `Checkpoint-LabVM -Name "drill-node" -SnapshotName "pre-systemd-test"` |
| **Level 06** | Enabling firewalls (`ufw enable`) or Netplan changes | `Checkpoint-LabVM -Name "drill-node" -SnapshotName "pre-firewall-lock"` |
| **Level 07** | Executing custom automated root Bash scripts | `Checkpoint-LabVM -Name "drill-node" -SnapshotName "pre-script-run"` |
