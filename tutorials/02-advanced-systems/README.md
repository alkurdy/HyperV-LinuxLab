# Tier 2: Advanced Systems Engineering (Levels 08 – 14)

> **Architectural Roadmap** • Grounded in *LPIC-3 Virtualization/Containerization*, *Ansible: Practical Guide for Administrators*, & *Docker Deep Dive*.

---

## 🎯 Scope & Objectives
Building upon the Sysadmin Foundations (Levels 01–07), Tier 2 transitions the engineer from single-host operational tasks to advanced storage infrastructure plumbing, kernel-level access control, fleet automation, container runtimes, and Linux networking virtualization.

---

## 🗺️ The 7 Advanced Modules

```
Level 08: Logical Volume Management (LVM) & Software RAID Plumbing
     │
     ▼
Level 09: Advanced Linux Networking: Bridges, Bonds, VLANs & Namespaces
     │
     ▼
Level 10: Pluggable Authentication Modules (PAM) & Linux Hardening
     │
     ▼
Level 11: Mandatory Access Control (MAC): SELinux vs AppArmor Internals
     │
     ▼
Level 12: Virtualization, Kernel Namespaces, cgroups v2 & Container Engines
     │
     ▼
Level 13: Configuration Management & Fleet Automation with Ansible
     │
     ▼
Level 14: System Performance Profiling, USE Methodology & Kernel Tuning
```

---

### Module 08: Logical Volume Management (LVM) & Software RAID Plumbing
- **Physical Volumes (PV), Volume Groups (VG), and Logical Volumes (LV)**: Dynamic resizing of storage partitions without unmounting.
- **LVM Thin Provisioning & Snapshots**: Copy-on-Write (CoW) delta allocation mechanics.
- **Software RAID (`mdadm`)**: RAID 0 (striping), RAID 1 (mirroring), RAID 5/6 (distributed parity), disk failure simulation and hot-spare rebuilds.
- **Online Filesystem Resizing**: Expanding Ext4 (`resize2fs`) and XFS (`xfs_growfs`) volumes on active production database systems.

### Module 09: Advanced Linux Networking: Bridges, Bonds, VLANs & Namespaces
- **Network Interface Bonding / Teaming**: LACP (802.3ad) vs Active-Backup for high-availability host uplinks.
- **VLAN Tagging (802.1Q)**: Sub-interfaces (`eth0.10`, `eth0.20`) and trunking.
- **Linux Software Bridges (`br0`)**: Virtual switching connecting KVM VMs and container veth pairs.
- **Network Namespaces (`ip netns`)**: Isolated network routing tables and virtual ethernet cables (`veth`).
- **Policy Routing & Virtual Routing and Forwarding (VRF)**: Multi-homed server routing isolation.

### Module 10: Pluggable Authentication Modules (PAM) & Linux Hardening
- **The PAM Stack Architecture**: `/etc/pam.d/` (`auth`, `account`, `password`, `session`).
- **Control Flags**: `required`, `requisite`, `sufficient`, `optional`.
- **Brute Force Lockout**: `pam_faillock` and `pam_tally2` implementation and unlock workflows.
- **Resource Constraints**: Tuning `/etc/security/limits.conf` (`nofile`, `nproc`, `memlock` for databases and Elasticsearch).
- **SSH Bastion Hardening**: Enforcing FIDO2/ed25519 keys, disabling password authentication, rate-limiting, and root login restriction.

### Module 11: Mandatory Access Control (MAC): SELinux vs AppArmor Internals
- **Discretionary Access Control (DAC) vs Mandatory Access Control (MAC)**: Why root cannot bypass MAC.
- **SELinux Architecture (RHEL/AlmaLinux)**: Targeted vs Strict policies, Type Enforcement (`user:role:type:level`).
- **Troubleshooting SELinux Denials**: Parsing `/var/log/audit/audit.log`, using `ausearch -m avc` and `audit2why`.
- **Managing SELinux Booleans & Ports**: `setsebool -P`, `semanage port -a`.
- **AppArmor Architecture (Ubuntu/Debian)**: Complain mode vs Enforce mode, `/etc/apparmor.d/` profile management (`aa-status`, `aa-enforce`, `aa-complain`).

### Module 12: Virtualization, Kernel Namespaces, cgroups v2 & Container Engines
- **Hardware Virtualization (KVM/QEMU)**: Type-1 bare-metal virtualization, `libvirt`, `virsh` CLI management.
- **Container Plumbing**: The 7 Linux Kernel Namespaces (`PID`, `NET`, `MNT`, `IPC`, `UTS`, `USER`, `CGROUP`).
- **Control Groups v2 (`cgroups v2`)**: Hard limits on CPU throttling (`cpu.max`), memory ceiling (`memory.max`), and I/O IOPS (`io.max`).
- **Container Engines**: Podman (rootless, daemonless, systemd integration) vs Containerd/Docker.
- **Generating Systemd Units from Containers**: `podman generate systemd`.

### Module 13: Configuration Management & Fleet Automation with Ansible
- **Declarative Infrastructure as Code**: Agentless SSH execution, YAML syntax, inventory management.
- **Idempotency Contract**: Ensuring tasks only execute when the system deviates from desired state.
- **Core Modules**: `apt`/`dnf`, `systemd`, `copy`, `template` (Jinja2), `lineinfile`, `user`, `firewalld`.
- **Ansible Roles & Vault**: Modularizing configurations and encrypting sensitive secrets (`ansible-vault`).
- **Fleet Verification**: Detecting drift across multi-node Linux server topologies.

### Module 14: System Performance Profiling, USE Methodology & Kernel Tuning
- **Brendan Gregg's USE Methodology**: Utilization, Saturation, and Errors across CPU, Memory, Disk, and Network.
- **Performance Diagnostics**: `vmstat 1`, `iostat -xz 1`, `pidstat 1`, `sar`, `mpstat`.
- **Kernel Parameter Tuning via `/etc/sysctl.d/`**:
  - Memory: `vm.swappiness`, `vm.dirty_ratio`, `vm.overcommit_memory`.
  - Network: `net.core.somaxconn`, `net.ipv4.tcp_max_syn_backlog`, TCP window auto-tuning.
- **Dynamic Optimization**: Applying kernel tunables persistently without reboots via `sysctl -p`.
