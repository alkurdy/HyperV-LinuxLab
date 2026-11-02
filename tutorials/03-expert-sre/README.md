# Tier 3: Expert Linux Architect & Site Reliability Engineering (Levels 15 – 21)

> **Architectural Roadmap** • Grounded in *Site Reliability Engineering*, *Operating Systems: Internals and Design Principles*, & *Linux Kernel Development*.

---

## 🎯 Scope & Objectives
The pinnacle tier of Linux engineering. Focuses on low-level kernel mechanics, in-kernel tracing with eBPF and perf, enterprise distributed consensus and high-availability clustering, high-throughput packet processing, threat forensics, and automated disaster recovery.

---

## 🗺️ The 7 Expert Modules

```
Level 15: Linux Kernel Internals, Virtual Memory Management & I/O Schedulers
     │
     ▼
Level 16: Deep Observability: eBPF Bytecode, BCC, bpftrace, perf & kdump
     │
     ▼
Level 17: Enterprise High-Availability Clustering: Corosync, Pacemaker & DRBD
     │
     ▼
Level 18: Enterprise Directory Integration, Kerberos, SSSD & Distributed Storage
     │
     ▼
Level 19: High-Throughput Kernel Bypass Networking: DPDK, XDP & SR-IOV
     │
     ▼
Level 20: Advanced Threat Forensics, Kernel Lockdown, seccomp & IMA/EVM
     │
     ▼
Level 21: Linux Chaos Engineering, Catastrophic Recovery & Bare-Metal Automation
```

---

### Module 15: Linux Kernel Internals, Virtual Memory Management & I/O Schedulers
- **Virtual Memory Architecture**: Page tables, TLB (Translation Lookaside Buffer), Transparent HugePages (THP) vs 2MB/1GB static HugePages.
- **Kernel Memory Allocators**: Buddy allocator, SLAB/SLUB cache, diagnosing memory leaks via `/proc/slabinfo` and `slabtop`.
- **Page Cache & I/O Flusher**: Write-back mechanics, dirty memory throttling (`dirty_background_ratio`, `dirty_expire_centisecs`).
- **I/O Scheduler Internals**: `none` (NVMe), `mq-deadline`, `bfq` (budget fair queueing), queue depth tuning.

### Module 16: Deep Observability: eBPF Bytecode, BCC, bpftrace, perf & kdump
- **Extended Berkeley Packet Filter (eBPF)**: Running verified sandboxed bytecode inside the Linux kernel without kernel module crashes.
- **Dynamic Tracing with `bpftrace`**: Writing ad-hoc one-liners to trace syscall latency, file opens, and lock contention.
- **BCC (BPF Compiler Collection) Tooling**: `opensnoop`, `execsnoop`, `biolatency`, `tcpconnect`, `runqlat`.
- **Hardware Performance Counters (`perf`)**: CPU instruction profiling, cache-miss analysis, flame graphs generation.
- **Kernel Crash Dump Analysis (`kdump`/`crash`)**: Configuring `kexec`, capturing `/proc/vmcore` on kernel panic, and inspecting stack traces in GDB.

### Module 17: Enterprise High-Availability Clustering: Corosync, Pacemaker & DRBD
- **Cluster Quorum & Membership (Corosync)**: Totem Single Ring / Redundant Ring protocol, split-brain avoidance mechanics.
- **Cluster Resource Manager (Pacemaker)**: Fencing agents (STONITH - Shoot The Other Node In The Head), VIP failover, systemd resource agents.
- **Distributed Replicated Block Device (DRBD 9)**: Synchronous network RAID 1 between nodes, split-brain auto-recovery.
- **Active-Passive vs Active-Active Clustered Topologies**: Keepalived VRRP routing failover vs Pacemaker fencing.

### Module 18: Enterprise Directory Integration, Kerberos, SSSD & Distributed Storage
- **System Security Services Daemon (SSSD)**: Integrating Linux hosts with Active Directory / FreeIPA via Kerberos (Kinit/Keytab) and LDAP.
- **Single Sign-On (SSO)**: Pluggable PAM/NSS identity mapping without local `/etc/passwd` accounts.
- **Secure Enterprise Storage**: NFSv4 with Kerberos (`sec=krb5p`) data integrity and encryption.
- **Distributed Software-Defined Storage**: Ceph architecture (OSD, MON, MGR, RADOS block devices `RBD`, CephFS) and GlusterFS volumes.

### Module 19: High-Throughput Kernel Bypass Networking: DPDK, XDP & SR-IOV
- **The Linux Network Stack Bottleneck**: Context switching, socket allocations, and interrupt overhead at 40GbE/100GbE line rates.
- **XDP (eXpress Data Path)**: Processing packets directly in the network card driver via eBPF before sk_buff allocation (DDoS mitigation at wire speed).
- **DPDK (Data Plane Development Kit)**: Poll Mode Drivers (PMD), HugePages memory pools, complete kernel network stack bypass.
- **SR-IOV (Single Root I/O Virtualization)**: Partitioning physical PCIe network adapters into Virtual Functions (VF) mapped directly into VM/container memory.

### Module 20: Advanced Threat Forensics, Kernel Lockdown, seccomp & IMA/EVM
- **CIS Benchmark Level 2 Hardening**: Kernel lockdown mode (`integrity` vs `confidentiality`), disabling `/dev/mem` and arbitrary kernel patching.
- **System Call Sandboxing (`seccomp-bpf`)**: Whitelisting allowed syscalls in production binaries, blocking execution of unauthorized calls.
- **Integrity Measurement Architecture (IMA) & EVM**: Cryptographically signing binaries and verifying file hashes in the TPM before kernel execution.
- **Linux Incident Response & Forensics**: Live memory acquisition (`LiME`), volatile artifact collection, volatile process analysis (`/proc/PID/mem`).

### Module 21: Linux Chaos Engineering, Catastrophic Recovery & Bare-Metal Automation
- **Chaos Injection**: Simulating sudden CPU starvation, corrupting partition superblocks, and forcing kernel panics (`echo c > /proc/sysrq-trigger`).
- **Emergency Recovery Workflows**:
  - Manual GRUB 2 rescue shell navigation and kernel parameter overrides (`init=/bin/bash`, `rd.break`).
  - Corrupted Ext4/XFS filesystem repair from live emergency environments.
  - Chroot repair: Booting live ISO, binding `/sys`, `/proc`, `/dev`, regenerating `initramfs` and reinstalling EFI bootloader.
- **Automated Bare-Metal Provisioning**: Building headless Cloud-Init / PXE iPXE automated provisioning pipelines.
