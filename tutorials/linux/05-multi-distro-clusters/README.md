# Lab Tutorial 05: Multi-Distro Heterogeneous Clusters & Coexistence

> **[Tutorials Hub](../../README.md)** â€¢ **[Linux Lab Track](../README.md)** â€¢ [â† Previous: Lab 04: Snapshots & Recovery](../04-snapshots-and-disaster-recovery/README.md) â€¢ [ðŸ“‘ Index](../../README.md) â€¢ [Next: Hyper-V 01: Hardware Prerequisites â†’](../../hyperv/01-prerequisites-and-hardware/README.md)

---
So, you want to test distributed systems, Ansible playbooks, or Kubernetes clusters across different Linux distributions at the same time? 

In this tutorial, we will deploy a heterogeneous 3-node cluster running **Ubuntu 24.04**, **Debian 12**, and **AlmaLinux 9 (RHEL 9 binary compatible)** side-by-side on the same virtual switch, with automated credential discovery and zero IP conflicts.

---

## 🧭 In This Tutorial:
1. [Multi-Distro Coexistence Architecture](#1-multi-distro-coexistence-architecture)
2. [Declarative Topology JSON](#2-declarative-topology-json)
3. [Cross-Distro Sudo Architecture (`sudo` vs `wheel`)](#3-cross-distro-sudo-architecture)
4. [Deploying the Cluster (`New-LabCluster`)](#4-deploying-the-cluster)
5. [Validating Cluster Health (`Test-LabCluster`)](#5-validating-cluster-health)
6. [Recalling Connection Telemetry & Passwords (`Get-LabVM`)](#6-recalling-connection-telemetry--passwords)
7. [Cluster Teardown (`Remove-LabCluster`)](#7-cluster-teardown)

---

## 1. Multi-Distro Coexistence Architecture

So you want to run Debian, Red Hat family, and Ubuntu together? `HyperV-LinuxLab` isolates each virtual machine while attaching them to the shared `LinuxLabSwitch` NAT bridge:

```text
               ┌────────────────────────────────────────────────────────┐
               │         Windows Host (LinuxLabSwitch: 172.23.108.1)    │
               └───────────┬─────────────────┬──────────────────┬───────┘
                           │                 │                  │
               ┌───────────▼──┐   ┌──────────▼───┐   ┌──────────▼───┐
               │    node-01   │   │    node-02   │   │    node-03   │
               │ Ubuntu 24.04 │   │   Debian 12  │   │  AlmaLinux 9 │
               │ (APT / deb)  │   │  (APT / deb) │   │  (RPM / dnf) │
               └──────────────┘   └──────────────┘   └──────────────┘
```

All three distributions receive independent dynamic IP leases, have their respective Cloud-Init configurations injected at boot, and communicate with each other over low-latency virtual Ethernet.

---

## 2. Declarative Topology JSON

Instead of typing repetitive PowerShell commands for every node, define your entire infrastructure declaratively in JSON. 

Inspect `examples/multi-distro-cluster.json`:

```json
{
  "ClusterName": "multi-distro-mesh",
  "DefaultProfile": "Minimal",
  "Nodes": [
    {
      "Name": "distro-ubuntu",
      "Distro": "Ubuntu2404",
      "Profile": "Container",
      "MemoryGB": 4,
      "CPUCount": 2,
      "Role": "ControlPlane"
    },
    {
      "Name": "distro-debian",
      "Distro": "Debian12",
      "Profile": "Minimal",
      "MemoryGB": 2,
      "CPUCount": 1,
      "Role": "WorkerDebian"
    },
    {
      "Name": "distro-almalinux",
      "Distro": "AlmaLinux9",
      "Profile": "Minimal",
      "MemoryGB": 2,
      "CPUCount": 1,
      "Role": "WorkerRHEL"
    }
  ]
}
```

---

## 3. Cross-Distro Sudo Architecture

Why do Linux distributions handle administrative privileges differently?
- **Debian / Ubuntu**: Grant root elevation through membership in the `sudo` group.
- **RHEL / AlmaLinux / CentOS**: Grant root elevation through membership in the `wheel` group.

If a provisioning script only assigns the `sudo` group, your AlmaLinux user will not be able to run `sudo` commands! 

`HyperV-LinuxLab` solves this automatically by baking a universal cross-distro group array into every generated `user-data` payload:
```yaml
groups: [sudo, wheel, admin, docker]
```
This guarantees that `labadmin` has seamless passwordless sudo out of the box regardless of which Linux distro powers the node.

---

## 4. Deploying the Cluster

Now that we have our topology file ready, deploy all 3 nodes with a single command:

```powershell
New-LabCluster -Path .\examples\multi-distro-cluster.json -AutoDownload
```

### What Happens:
1. Validates the cluster manifest against the hardware capacity of your Windows host.
2. Automatically downloads and caches golden master images for any distro not already cached.
3. Spawns child differencing disks for each node in parallel.
4. Generates unique ISOs with independent passwords for each VM.
5. Boots all nodes and polls for their respective IP leases.

---

## 5. Validating Cluster Health

Once deployment finishes, run the automated cluster validation test:

```powershell
Test-LabCluster -Path .\examples\multi-distro-cluster.json
```

### What You Should See:
```text
ClusterName  : multi-distro-mesh
Status       : Healthy
TotalNodes   : 3
RunningNodes : 3
Ready        : True
```

---

## 6. Recalling Connection Telemetry & Passwords

So you walked away for coffee and forgot the IP addresses and generated passwords? You don't need to dig through log files.

Run `Get-LabVM` to recall active lab credentials instantly:

```powershell
Get-LabVM
```

### Output:
```text
Name             Distro       Status   IPv4           Username  Password         SSH
----             ------       ------   ----           --------  --------         ---
distro-ubuntu    Ubuntu2404   Running  172.23.108.101 labadmin  Swift-Falcon-42  ssh labadmin@172.23.108.101
distro-debian    Debian12     Running  172.23.108.102 labadmin  Cosmic-Otter-73  ssh labadmin@172.23.108.102
distro-almalinux AlmaLinux9   Running  172.23.108.103 labadmin  Bright-Badger-19 ssh labadmin@172.23.108.103
```

All credentials are dual-written to:
1. Disk: `<StoragePath>\LabVMs\<node-name>\metadata.json`
2. Hyper-V: Native VM `Notes` (visible directly inside the Hyper-V Manager GUI).

---

## 7. Cluster Teardown

When you are finished testing cross-distro playbooks, tear down all cluster nodes in one shot:

```powershell
Remove-LabCluster -Path .\examples\multi-distro-cluster.json -Force
```

All 3 VMs, their differencing disks, and metadata files are safely removed.

---

### 🧭 Navigation
| [← Previous: Snapshots & Disaster Recovery](../04-snapshots-and-disaster-recovery/README.md) | [📑 All Tutorials](README.md) | [Next: Hyper-V Systems Engineering Track →](../../hyperv/01-prerequisites-and-hardware/README.md) |
| :--- | :---: | ---: |

*(Under the hood: Want to learn how Hyper-V handles multi-node power orchestration and non-blocking telemetry? Read [Hyper-V Tutorial 06: VM Lifecycle, Telemetry & Automation](../../hyperv/06-vm-lifecycle-and-telemetry/README.md)).*

---

### ðŸ§­ Navigation
| [â† Previous: Lab 04: Snapshots & Recovery](../04-snapshots-and-disaster-recovery/README.md) | [ðŸ“‘ Tutorials Index](../../README.md) | [Next: Hyper-V 01: Hardware Prerequisites â†’](../../hyperv/01-prerequisites-and-hardware/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V 06: Lifecycle & Telemetry](../../hyperv/06-vm-lifecycle-and-telemetry/README.md)).*
