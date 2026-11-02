# Tier 1: Sysadmin Foundations (Levels 01 – 07)

> **[Learning Hub](../README.md)** • Master Track for Administrators Transitioning into Linux Systems Engineering.

---

## Curriculum Overview: The Layered Server Architecture

Unlike isolated tutorials that spin up disposable VMs and discard work, **Tier 1 simulates the lifecycle of a real production enterprise Linux server: `sysadmin-node`**.

Each level builds directly upon the architecture, users, storage, services, and security rules established in the preceding levels. By the end of Tier 1, you have built, secured, hardened, troubleshot, and automated a complete production environment.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   CONTINUOUS LAB SERVER: sysadmin-node                           │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Level 01: Host Baseline, Kernel VFS & Telemetry Audit                            │
│           ├── Kernel parameters (/proc, /sys) & stream redirection               │
│           └── Administrative baseline environment (/etc/profile.d/sysadmin.sh)   │
│                                   │                                              │
│ Level 02: Identity, Privilege Tiers & Team Collaboration Directory               │
│           ├── Service account (svc-app), engineering users, sudoers restrictions  │
│           └── Application tree (/srv/app, /var/log/app) with SGID & POSIX ACLs    │
│                                   │                                              │
│ Level 03: Block Storage Allocation & Filesystem Persistence                      │
│           ├── Dedicated GPT block partition formatted Ext4                       │
│           └── Persistent UUID mount in /etc/fstab for /srv/app + swap space      │
│                                   │                                              │
│ Level 04: Production Troubleshooting & Live Outage Triage                        │
│           ├── Phantom disk space exhaustion via unlinked file handles (lsof +L1) │
│           └── Structured journald boot triage & OOM Killer memory diagnostics   │
│                                   │                                              │
│ Level 05: Production Systemd Services, Signals & Self-Healing                    │
│           ├── Systemd unit running as svc-app writing to /var/log/app            │
│           └── Signal testing (SIGTERM vs SIGKILL), restart policies & timers     │
│                                   │                                              │
│ Level 06: Network Exposure, Socket Inspection & Firewall Hardening               │
│           ├── Socket binding (ss -tulpn), DNS stub resolution (systemd-resolved) │
│           └── UFW / firewalld perimeter defense (allow SSH/app port, drop rest)  │
│                                   │                                              │
│ Level 07: Defensive Bash Automation & Multi-Layer Incident Capstone              │
│           ├── Robust self-healing health checks (set -euo pipefail)              │
│           └── Comprehensive unguided break-fix recovery across all 6 layers      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## Learning Structure in Each Level

Every module in Tier 1 follows a two-part learning structure:

1. **Part A: Guided Architectural Drill with System Action & Reaction**  
   Step-by-step commands paired with deep-dive technical explanations of what the Linux kernel, VFS, systemd, or network stack is doing behind the scenes. You see what happens, why it happens, and how to verify the system reaction.

2. **Part B: Unguided Admin Solo Drill (No Answers Given)**  
   Real-world administrator mission with explicit **Acceptance Criteria**. You choose your own custom parameters (usernames, directory names, ports) and configure the system independently. No copy-paste solutions are provided—you must apply what you learned or consult system notes, logs, and man pages. A self-verification script tests your work.

---

## Lab Lifecycle & Safety Net

Work on the continuous lab node and use snapshots as milestones:

```powershell
# 1. Deploy the continuous lab node (done once at start of Level 01)
New-LabVM -Name "sysadmin-node" -MemoryGB 2 -CPUCount 2 -Start

# 2. Checkpoint your server state as you complete each level
Checkpoint-LabVM -Name "sysadmin-node" -SnapshotName "level-01-complete"

# 3. If you make a breaking mistake, revert instantly in under 2 seconds:
Restore-LabVM -Name "sysadmin-node" -SnapshotName "level-01-complete" -Force

# 4. Consolidate snapshots when finished:
Remove-LabCheckpoint -Name "sysadmin-node" -All -Force
```

---

## Modules Matrix

| Level | Module | Core Systems Concept | Layered System Milestone |
| :---: | :--- | :--- | :--- |
| **01** | [**Level 01: Mental Model & Architecture**](level-01-mental-model-and-architecture/README.md) | VFS single tree, Ring 0 vs Ring 3, pseudo filesystems (`/proc`, `/sys`), streams (`stdin`/`stdout`/`stderr`), pipes. | Provision `sysadmin-node`, audit bare-metal baseline, create admin profile. |
| **02** | [**Level 02: Identity, Users, Groups & Permissions**](level-02-identity-users-and-permissions/README.md) | UID/GID (`/etc/passwd`, `/etc/shadow`), `visudo`, octal permissions, directory traversal, SGID sticky groups, POSIX ACLs. | Create `appteam`, `svc-app`, provision `/srv/app` and `/var/log/app` with SGID & ACLs. |
| **03** | [**Level 03: Directory Hierarchy & Block Storage**](level-03-directory-hierarchy-and-storage/README.md) | FHS 3.0, block devices (`/dev/sdX`), GPT partitioning, `ext4`/`xfs`, persistent `/etc/fstab` UUID mounting, swap memory. | Partition block disk, format Ext4, mount persistently to `/srv/app`, activate swapfile. |
| **04** | [**Level 04: Troubleshooting, Logging & Diagnostics**](level-04-troubleshooting-logs-and-diagnostics/README.md) | `systemd-journald` vs `rsyslog`, `/var/log` triage, `journalctl` timeframes, OOM Killer triage, open file handle leaks (`lsof +L1`). | Diagnose and resolve phantom disk exhaustion and process leaks on `/srv/app` without reboot. |
| **05** | [**Level 05: Process Lifecycle, Signals & Systemd**](level-05-processes-systemd-and-signals/README.md) | Process hierarchy, states (`R`, `S`, `D`, `Z`), signals (`SIGTERM`, `SIGKILL`), systemd service units, restart policies, timers. | Deploy production `app.service` running as `svc-app` writing to `/var/log/app`, test kill/restart. |
| **06** | [**Level 06: Linux Networking & Connectivity**](level-06-networking-and-connectivity/README.md) | Modern `iproute2`, DNS resolution (`systemd-resolved`), socket states (`ss -tulpn`), HTTP handshakes (`curl -Iv`), UFW firewalls. | Bind app listener to port, verify DNS/routes, lock down perimeter firewall with UFW. |
| **07** | [**Level 07: Automation, Bash Scripting & Capstone**](level-07-automation-bash-and-package-lifecycle/README.md) | Package lifecycles, cron/timer scheduling, defensive Bash (`set -euo pipefail`), stream filtering (`awk`/`sed`), break-fix capstone. | Multi-layer unguided incident triage: repair permissions, mounts, crashed daemon, and firewall. |
