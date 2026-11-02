# Track 2: Hyper-V Systems Engineering Curriculum

> **[Tutorials Hub](../README.md)** • **Hyper-V Internals Track** • [Switch to Linux Lab Track →](../01-sysadmin-foundations/README.md)

Welcome to the **Hyper-V Systems Engineering** track of the HyperV-LinuxLab curriculum.

This track is designed for cloud architects, platform engineers, and Windows administrators who want to understand how Hyper-V, DISM, VMBus, and UEFI function beneath the surface without third-party tool abstraction.

---

## Curriculum Architecture: The Continuous Local Cloud Engine

Rather than isolated, throwaway exercises, **Track 2 simulates the lifecycle of building a custom bare-metal virtualization engine on Windows from silicon to declarative cluster orchestration.**

Each tutorial forms an essential architectural layer:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   HYPER-V PLATFORM ENGINEERING ARCHITECTURE                      │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Tutorial 01: Silicon Qualification & Hardware Masking Audit                      │
│              ├── VT-x/AMD-V registers, Ring -1 hypervisor detection, SLAT/DEP     │
│              └── Module qualification defense (Hyper-V\<Cmdlet>)                 │
│                                      │                                           │
│ Tutorial 02: Hypervisor Kernel Stack & Reboot Lifecycle                          │
│              ├── DISM servicing stack (hvix64.sys, vmms) & CBS logging           │
│              └── Pending reboot state machines & 3-point health validation       │
│                                      │                                           │
│ Tutorial 03: Virtual Switching & Kernel WinNAT Routing                           │
│              ├── Internal Virtual Switches & synthetic VMBus bus interfaces       │
│              └── WinNAT translation engine (New-NetNat) & static IP routing      │
│                                      │                                           │
│ Tutorial 04: Storage Topography & Atomic Differencing Disks                      │
│              ├── Read-only golden master VHDX & dynamic block allocation tables  │
│              └── 4MB delta child disks & sub-second atomic state resets          │
│                                      │                                           │
│ Tutorial 05: Gen2 UEFI Architecture & Cloud-Init Provisioning                    │
│              ├── Gen2 virtual silicon, Linux Secure Boot & memory reservation    │
│              └── Unattended NoCloud ISO9660 injection (cidata.iso)               │
│                                      │                                           │
│ Tutorial 06: Telemetry, Lifecycle Automation & Cluster Orchestration             │
│              ├── KVP exchange IP discovery, dual-write state & vmwp.exe control  │
│              └── Declarative multi-node cluster provisioning & parallel health   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## Learning Structure in Each Tutorial

Every module in Track 2 follows a rigorous engineering structure:

1. **Part A: Guided Architectural Drill (Action & System Reaction)**  
   Step-by-step PowerShell commands paired with deep-dive technical explanations of what the Windows NT kernel, Hyper-V microkernel (`hvix64.sys`), VMBus, or Virtual Machine Management Service (`vmms`) is doing beneath the surface. You see the reaction and verify it with CIM/WMI.

2. **Part B: Unguided Platform Solo Drill (No Answers Given)**  
   Real-world platform engineering mission with explicit **Acceptance Criteria**. You choose your own custom parameters (switch names, subnet CIDRs, disk labels, VM names) and configure the environment independently. No copy-paste solutions are provided—you must apply what you learned or consult Windows documentation and PowerShell help. An automated self-verification script tests your solution.

---

## Tutorial Directory

| # | Tutorial | Core Systems Concept | Layered Platform Milestone |
| :---: | :--- | :--- | :--- |
| **01** | [**01-prerequisites-and-hardware**](01-prerequisites-and-hardware/README.md) | Windows SKU gating (Pro vs Home), CPU VT-x/AMD-V registers, Ring -1 hypervisor masking, SLAT, DEP, memory reservation, and PowerShell module qualification (`Hyper-V\Cmdlet`). | Audit silicon readiness, verify Ring -1 masking, build unguided pre-flight hardware gatekeeper. |
| **02** | [**02-installation-and-removal**](02-installation-and-removal/README.md) | The 4 core layers (`hvix64.sys`, `vmms`), DISM features, pending reboot state machines, 3-point health check, **complete clean uninstallation**, and CBS log debugging. | Provision hypervisor stack, evaluate reboot state machine, build unguided health auditor. |
| **03** | [**03-virtual-networking**](03-virtual-networking/README.md) | Default Switch vs Internal NAT switches, WinNAT (`New-NetNat`), synthetic VMBus adapters, guest DHCP routing, and KVP in-memory IP resolution. | Build internal virtual switch, bind gateway, configure WinNAT, build unguided isolated tenant subnet. |
| **04** | [**04-storage-and-differencing-disks**](04-storage-and-differencing-disks/README.md) | VHDX block allocation tables, read-only golden masters, 4MB child delta disks, parent-child pointer chains, and sub-5-second atomic resets. | Construct golden master VHDX, spawn child differencing disks, build unguided multi-tier storage chain. |
| **05** | [**05-vm-architecture-and-cloud-init**](05-vm-architecture-and-cloud-init/README.md) | Gen1 vs Gen2 UEFI, Linux Secure Boot (`MicrosoftUEFICertificateAuthority`), dynamic RAM tuning, NoCloud ISO9660 generation (`cidata.iso`), and bypassing Azure `walinuxagent` boot hangs. | Provision Gen2 UEFI VM with Linux Secure Boot, generate and inject Cloud-Init ISO, build unguided unattended node. |
| **06** | [**06-vm-lifecycle-and-telemetry**](06-vm-lifecycle-and-telemetry/README.md) | Native power states (`Stop-VM -TurnOff`), non-blocking TCP port 22 polling, dual-write metadata (JSON + VM Notes), host startup auto-boot, multi-node orchestration, and worker process termination (`vmwp.exe`). | Capture KVP guest telemetry, persist dual-write metadata, build unguided declarative multi-node cluster orchestrator. |

---

### Navigation
| [← Back to Master Tutorials Hub](../README.md) | [Start Hyper-V 01: Prerequisites & Silicon →](01-prerequisites-and-hardware/README.md) |
| :--- | ---: |
