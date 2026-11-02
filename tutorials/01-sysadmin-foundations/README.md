# Tier 1: Sysadmin Foundations (Levels 01 – 07)

> **[Learning Hub](../README.md)** • Master Track for Administrators Transitioning into Linux Systems Engineering.

---

## 🗺️ Curriculum Overview

Designed specifically for systems administrators with Windows Server, Active Directory, and VMware experience who want to build a deep, unflinching Linux mental model:

| Level | Module | Core Concepts | Hands-On Lab Drill |
| :---: | :--- | :--- | :--- |
| **01** | [**Level 01: Mental Model & Architecture**](level-01-mental-model-and-architecture/README.md) | Windows NT vs Linux VFS single tree, Ring 0 monolithic kernel vs Ring 3, pseudo filesystems (`/proc`, `/sys`, `/dev`), streams (`stdin`/`stdout`/`stderr`), pipes. | Host architecture inspection & stream filtering. |
| **02** | [**Level 02: Identity, Users, Groups & Permissions**](level-02-identity-users-and-permissions/README.md) | UID/GID (`/etc/passwd`, `/etc/shadow`, `/etc/group`), `visudo` privilege escalation, octal/symbolic permissions, directory `x` traversal, SGID team directories, POSIX ACLs (`setfacl`). | Multi-user team collaboration space with SGID & ACLs. |
| **03** | [**Level 03: Directory Hierarchy & Block Storage**](level-03-directory-hierarchy-and-storage/README.md) | Filesystem Hierarchy Standard (FHS 3.0), block devices (`/dev/sdX` vs `nvme`), GPT partitioning (`parted`), formatting `ext4`/`xfs`, persistent mounting (`/etc/fstab` UUIDs), swapfile configuration. | Simulated loopback block disk partitioning, formatting, and persistent mount. |
| **04** | [**Level 04: Troubleshooting, Logging & Diagnostics**](level-04-troubleshooting-logs-and-diagnostics/README.md) | Logging architecture (`systemd-journald` vs `syslog`), `/var/log` triage, `journalctl` timeframes and post-crash boot analysis, `dmesg -T` OOM Killer triage, inode exhaustion (`df -i`), open file handle leaks (`lsof +L1`). | Live deleted file handle disk leak reproduction and recovery without service reboot. |
| **05** | [**Level 05: Process Lifecycle, Signals & Systemd**](level-05-processes-systemd-and-signals/README.md) | Process hierarchy (PID 1, PPID), states (`R`, `S`, `D` uninterruptible sleep, `Z` zombies), POSIX signals (`SIGTERM`, `SIGKILL`, `SIGHUP`), `systemctl` verbs, authoring production `.service` units, systemd timers. | Authoring a custom background service and testing automatic self-healing restart after SIGKILL. |
| **06** | [**Level 06: Linux Networking & Connectivity**](level-06-networking-and-connectivity/README.md) | Modern `iproute2` (`ip a`, `ip link`, `ip r`), Netplan vs NetworkManager, DNS stub resolution (`systemd-resolved`), socket inspection (`ss -tulpn`), HTTP handshakes (`curl -Iv`), firewall management (`ufw`/`firewalld`). | Outbound route tracing, socket listeners, and ad-hoc HTTP verification. |
| **07** | [**Level 07: Automation, Bash Scripting & Capstone**](level-07-automation-bash-and-package-lifecycle/README.md) | Package lifecycles (`apt` vs `dnf`), cron scheduling, defensive Bash scripting (`set -euo pipefail`), text stream filtering (`sed` / `awk`), end-to-end break-fix capstone. | Multi-stage operational capstone: user, SGID storage, Nginx, automated self-healing healthcheck. |

---

## 🛠️ Lab Quick Start

Every drill can be deployed and reset in seconds:

```powershell
# Deploy clean node
New-LabVM -Name "foundations-node" -Start

# Connect via SSH
ssh labadmin@<VM_IP>

# Wipe and reset in under 2 seconds
Reset-LabVM -Name "foundations-node" -Force
```
