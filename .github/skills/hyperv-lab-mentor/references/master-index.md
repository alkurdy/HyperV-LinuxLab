# Master Location Index: HyperV-LinuxLab

Master navigation map for all tutorials, PowerShell cmdlets, documentation, and technical modules in `HyperV-LinuxLab` (`C:\Users\alkur\OneDrive\Documents\HyperV-LinuxLab`).

---

## 1. Tutorials Curriculum Index (3 Tiers, 21 Levels + Specialized Tracks)

### Tier 1: Sysadmin Foundations (`tutorials/01-sysadmin-foundations/`)
| Level | Topic | Core Tags | Exact File Location |
| :--- | :--- | :--- | :--- |
| **Overview** | Foundations Overview | `#curriculum`, `#overview` | [`tutorials/01-sysadmin-foundations/README.md`](../../../../tutorials/01-sysadmin-foundations/README.md) |
| **Level 01** | Mental Model, VFS & Architecture | `#vfs`, `#kernel`, `#syscalls`, `#modules` | [`tutorials/.../level-01-mental-model-and-architecture/README.md`](../../../../tutorials/01-sysadmin-foundations/level-01-mental-model-and-architecture/README.md) |
| **Level 02** | Identity, Users & Permissions | `#identity`, `#permissions`, `#sudo`, `#acls` | [`tutorials/.../level-02-identity-users-and-permissions/README.md`](../../../../tutorials/01-sysadmin-foundations/level-02-identity-users-and-permissions/README.md) |
| **Level 03** | Directory Hierarchy & Storage | `#fhs`, `#storage`, `#inodes`, `#fstab`, `#gpt` | [`tutorials/.../level-03-directory-hierarchy-and-storage/README.md`](../../../../tutorials/01-sysadmin-foundations/level-03-directory-hierarchy-and-storage/README.md) |
| **Level 04** | Troubleshooting & Diagnostics | `#troubleshooting`, `#journald`, `#oom-killer`, `#leaks` | [`tutorials/.../level-04-troubleshooting-logs-and-diagnostics/README.md`](../../../../tutorials/01-sysadmin-foundations/level-04-troubleshooting-logs-and-diagnostics/README.md) |
| **Level 05** | Processes, Systemd & Signals | `#systemd`, `#processes`, `#signals`, `#cgroups` | [`tutorials/.../level-05-processes-systemd-and-signals/README.md`](../../../../tutorials/01-sysadmin-foundations/level-05-processes-systemd-and-signals/README.md) |
| **Level 06** | Networking & Connectivity | `#networking`, `#cidr`, `#routes`, `#dns`, `#ports` | [`tutorials/.../level-06-networking-and-connectivity/README.md`](../../../../tutorials/01-sysadmin-foundations/level-06-networking-and-connectivity/README.md) |
| **Level 07** | Bash Automation & Packages | `#bash`, `#automation`, `#apt`, `#dpkg`, `#pipelines` | [`tutorials/.../level-07-automation-bash-and-package-lifecycle/README.md`](../../../../tutorials/01-sysadmin-foundations/level-07-automation-bash-and-package-lifecycle/README.md) |

---

### Tier 2, Tier 3 & Tier 4 Advanced Tracks
| Track | Description | Core Tags | Exact File Location |
| :--- | :--- | :--- | :--- |
| **Tier 2** | Advanced Enterprise Systems | `#lvm`, `#raid`, `#bridges`, `#pam`, `#selinux`, `#containers` | [`tutorials/02-advanced-systems/README.md`](../../../../tutorials/02-advanced-systems/README.md) |
| **Tier 3** | Expert SRE & Fleet Automation | `#sre`, `#kubernetes`, `#use-method`, `#observability` | [`tutorials/03-expert-sre/README.md`](../../../../tutorials/03-expert-sre/README.md) |
| **Tier 4** | Ansible Infrastructure Automation | `#ansible`, `#iac`, `#playbooks`, `#roles`, `#vault`, `#idempotency` | [`tutorials/04-ansible-automation/README.md`](../../../../tutorials/04-ansible-automation/README.md) |

---

### Specialized Hyper-V Internals (`tutorials/hyperv-internals/`)
| Module | Topic | Core Tags | Exact File Location |
| :--- | :--- | :--- | :--- |
| **Overview** | Hyper-V Architecture Map | `#hyperv`, `#hypervisor`, `#architecture` | [`tutorials/hyperv-internals/README.md`](../../../../tutorials/hyperv-internals/README.md) |
| **Module 01** | Prerequisites & Hardware | `#slat`, `#nested-virt`, `#powershell` | [`tutorials/.../01-prerequisites-and-hardware/README.md`](../../../../tutorials/hyperv-internals/01-prerequisites-and-hardware/README.md) |
| **Module 02** | Installation & Configuration | `#hyperv-install`, `#dism`, `#reboot` | [`tutorials/.../02-installation-and-removal/README.md`](../../../../tutorials/hyperv-internals/02-installation-and-removal/README.md) |
| **Module 03** | Virtual Networking & NAT | `#vswitch`, `#nat`, `#internal-switch`, `#ipam` | [`tutorials/.../03-virtual-networking/README.md`](../../../../tutorials/hyperv-internals/03-virtual-networking/README.md) |
| **Module 04** | Storage & Differencing Disks | `#vhdx`, `#differencing-disk`, `#vmfork`, `#cow` | [`tutorials/.../04-storage-and-differencing-disks/README.md`](../../../../tutorials/hyperv-internals/04-storage-and-differencing-disks/README.md) |
| **Module 05** | VM Architecture & Cloud-Init | `#cloud-init`, `#nocloud`, `#iso`, `#seed` | [`tutorials/.../05-vm-architecture-and-cloud-init/README.md`](../../../../tutorials/hyperv-internals/05-vm-architecture-and-cloud-init/README.md) |
| **Module 06** | VM Lifecycle & Telemetry | `#lifecycle`, `#telemetry`, `#metrics`, `#wmi` | [`tutorials/.../06-vm-lifecycle-and-telemetry/README.md`](../../../../tutorials/hyperv-internals/06-vm-lifecycle-and-telemetry/README.md) |

---

### Academic Curriculum
| Track | Course | Core Tags | Exact File Location |
| :--- | :--- | :--- | :--- |
| **UVA** | IT 3140 Linux Systems Administration | `#academic`, `#curriculum`, `#syllabus` | [`tutorials/academic/uva-it3140/README.md`](../../../../tutorials/academic/uva-it3140/README.md) |

---

## 2. Tiered Linux Utility & Tool Progression Matrix (Levels 01 – 07)

The mentor weaves these tools organically into each level so the learner builds muscle memory incrementally without syntax overload:

| Level | Systems Focus | Primary Tools Unlocked & Mastered | Pedagogical Objective |
| :---: | :--- | :--- | :--- |
| **01** | **VFS & Core Streams** | `cat`, `head`, `tail` (`-f`), `less`, `grep` (`-i`, `-v`), `wc` (`-l`), `type` | Safe inspection of files without terminal flooding; filtering streams via basic pipes (`\|`); identifying builtins vs disk binaries. |
| **02** | **Identity & Permissions** | `whoami`, `id`, `useradd`, `usermod`, `groupadd`, `chmod` (octal/symbolic), `chown`, `chgrp`, `visudo`, `getfacl`, `setfacl` | User and service account provisioning; POSIX permission modes (`rwx`), SGID directory inheritance, and fine-grained ACLs. |
| **03** | **Storage & FHS Navigation** | `ls` (`-lah`), `cp`, `mv`, `rm`, `mkdir` (`-p`), `touch`, `df` (`-h`), `du` (`-sh`), `lsblk`, `fdisk`/`parted`, `mkfs.ext4`, `mount`, `umount`, `blkid` | File/directory CRUD; filesystem capacity auditing; partition creation, Ext4 formatting, and persistent `/etc/fstab` UUID mounts. |
| **04** | **Troubleshooting & Diagnostics** | `journalctl` (`-b`, `-u`, `-f`, `-p`), `dmesg`, `lsof` (`+L1`), `fuser`, `vmstat`, `free` (`-h`), `uptime` | Live incident triage: identifying unlinked open file leaks, kernel OOM triggers, and hardware ring-buffer events. |
| **05** | **Processes & Systemd** | `ps` (`aux`, `-ef`), `top`/`htop`, `pstree` (`-p`), `kill`, `pkill`, `systemctl` (`status`, `start`, `stop`, `restart`, `enable`), `systemd-cgls` | Process state inspection (`R`/`S`/`D`/`Z`); signal dispatching (`SIGTERM` vs `SIGKILL`); declarative systemd service lifecycle. |
| **06** | **Networking & Connectivity** | `ip addr`, `ip route`, `ip link`, `ss` (`-tulpn`), `curl` (`-Iv`), `resolvectl`/`dig`, `ping`, `ufw` (`status`, `allow`, `deny`) | Modern `iproute2` network stack; socket inspection; DNS stub resolution; perimeter host firewall hardening. |
| **07** | **Automation & Pipelines** | `cut`, `awk`, `sed`, `sort`, `uniq` (`-c`), `tr`, `xargs`, `tar`, `gzip`, `find` (`-exec`), `apt`/`dpkg`, `crontab` | Complex stream transformation, columnar text parsing, package management, archive generation, and robust Bash automation (`set -euo pipefail`). |

---

## 3. Public PowerShell Cmdlets Index (`Public/`)

All cmdlets exported by `HyperV-LinuxLab.psd1`:

| Cmdlet | Responsibility | Category | File Link |
| :--- | :--- | :--- | :--- |
| `New-LabVM` | Provisions new lab VM using differencing VHDX + Cloud-Init | Provisioning | [`New-LabVM.ps1`](../../../../Public/New-LabVM.ps1) |
| `Start-LabVM` | Boots a specific lab virtual machine | Lifecycle | [`Start-LabVM.ps1`](../../../../Public/Start-LabVM.ps1) |
| `Stop-LabVM` | Gracefully shuts down a lab VM | Lifecycle | [`Stop-LabVM.ps1`](../../../../Public/Stop-LabVM.ps1) |
| `Reset-LabVM` | Replaces differencing disk with fresh child VHDX | Reset / Ephemeral | [`Reset-LabVM.ps1`](../../../../Public/Reset-LabVM.ps1) |
| `Remove-LabVM` | Teardown and de-provisions lab VM and child storage | Cleanup | [`Remove-LabVM.ps1`](../../../../Public/Remove-LabVM.ps1) |
| `Get-LabVM` | Retrieves status and runtime metadata of lab VMs | Inspection | [`Get-LabVM.ps1`](../../../../Public/Get-LabVM.ps1) |
| `Start-Lab` | Orchestrates parallel startup of entire lab topology | Orchestration | [`Start-Lab.ps1`](../../../../Public/Start-Lab.ps1) |
| `Stop-Lab` | Orderly shutdown of entire lab topology | Orchestration | [`Stop-Lab.ps1`](../../../../Public/Stop-Lab.ps1) |
| `New-LabBaseImage` | Downloads/verifies official Ubuntu 24.04 cloud image | Base Images | [`New-LabBaseImage.ps1`](../../../../Public/New-LabBaseImage.ps1) |
| `Get-LabBaseImage` | Inspects local base image repository | Base Images | [`Get-LabBaseImage.ps1`](../../../../Public/Get-LabBaseImage.ps1) |
| `New-LabCloudInitISO` | Generates NoCloud optical seed ISO with user-data | Cloud-Init | [`New-LabCloudInitISO.ps1`](../../../../Public/New-LabCloudInitISO.ps1) |
| `New-LabCluster` | Deploys multi-node lab cluster topology | Multi-Node | [`New-LabCluster.ps1`](../../../../Public/New-LabCluster.ps1) |
| `Test-LabCluster` | Verifies SSH and inter-node network connectivity | Verification | [`Test-LabCluster.ps1`](../../../../Public/Test-LabCluster.ps1) |
| `Checkpoint-LabVM` | Takes named Hyper-V recovery checkpoint | Disaster Recovery | [`Checkpoint-LabVM.ps1`](../../../../Public/Checkpoint-LabVM.ps1) |
| `Restore-LabVM` | Rolls VM state back to saved checkpoint | Disaster Recovery | [`Restore-LabVM.ps1`](../../../../Public/Restore-LabVM.ps1) |
| `Get-LabConfiguration` | Reads active lab JSON settings and directories | Configuration | [`Get-LabConfiguration.ps1`](../../../../Public/Get-LabConfiguration.ps1) |
| `Set-LabConfiguration` | Updates lab paths, memory limits, and NAT subnets | Configuration | [`Set-LabConfiguration.ps1`](../../../../Public/Set-LabConfiguration.ps1) |
| `Test-LabPrerequisites` | Validates Hyper-V, SLAT, RAM, and admin privileges | Diagnostics | [`Test-LabPrerequisites.ps1`](../../../../Public/Test-LabPrerequisites.ps1) |

---

## 4. Project Architecture & Documentation Index (`docs/`)

| Document | Purpose | File Link |
| :--- | :--- | :--- |
| **`CMDLET_REFERENCE.md`** | Comprehensive syntax, parameters, and examples for every cmdlet | [`docs/CMDLET_REFERENCE.md`](../../../../docs/CMDLET_REFERENCE.md) |
| **`DEV_NOTES.md`** | Architectural design decisions, cloud-init quirks, differencing disk geometry | [`docs/DEV_NOTES.md`](../../../../docs/DEV_NOTES.md) |
| **`SPECIFICATION.md`** | Formal engineering specification and non-functional requirements | [`docs/SPECIFICATION.md`](../../../../docs/SPECIFICATION.md) |
| **`TESTING_STRATEGY.md`** | Pester unit tests, integration test harnesses, and mock frameworks | [`docs/TESTING_STRATEGY.md`](../../../../docs/TESTING_STRATEGY.md) |
