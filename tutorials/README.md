# Hyper-V Systems Engineering & Under-the-Hood Tutorials

Welcome to the **HyperV-LinuxLab Architecture & Systems Engineering Guide**.

The purpose of these tutorials is to **demystify Hyper-V virtualization**. While the `HyperV-LinuxLab` PowerShell module automates lab creation into single high-level commands, engineers must understand the exact low-level Windows APIs, DISM operations, hypervisor microkernel behaviors, and storage pointer chains working beneath the surface.

---

## Tutorial Roadmap

Each tutorial document is structured around **7 comprehensive topics** detailing the underlying Windows architecture, native PowerShell commands, module automation mappings, diagnostics, and verification drills.

| # | Tutorial | Core Focus |
| :--- | :--- | :--- |
| **01** | [**Prerequisites & Hardware Virtualization**](01-prerequisites-and-hardware.md) | CPU VT-x/AMD-V registers, Ring -1 hypervisor masking, Windows editions, SLAT, DEP, and third-party hypervisor coexistence. |
| **02** | [**Hyper-V Installation, Verification & Clean Removal**](02-installation-and-removal.md) | DISM feature states, `hvix64.sys` microkernel, pending reboot registry tracking, service validation, complete removal, and uninstall verification. |
| **03** | [**Virtual Networking & Guest IP Routing**](03-virtual-networking.md) | Default Switch vs Internal NAT switches, WinNAT (`New-NetNat`), synthetic adapters, guest routing, and KVP data exchange resolution. |
| **04** | [**Virtual Storage & Differencing Disks**](04-storage-and-differencing-disks.md) | VHDX block architecture, read-only golden masters, child differencing disks, parent-child pointer chains, and sub-5-second atomic resets. |
| **05** | [**VM Architecture, UEFI Gen2 & Cloud-Init**](05-vm-architecture-and-cloud-init.md) | Gen1 vs Gen2 UEFI, Linux Secure Boot certificate authorities, NoCloud ISO9660 generation, `#cloud-config` user-data, and `walinuxagent` masking. |
| **06** | [**VM Lifecycle, Telemetry & Automation**](06-vm-lifecycle-and-telemetry.md) | Native power states, KVP network polling, dual-write metadata persistence (JSON + VM Notes), Scheduled Tasks vs native auto-boot, and cluster orchestration. |

---

## Levels of Detail in Each Tutorial

Every tutorial explores its 7 topics through standardized depths:
1. **System Architecture**: What happens at the Windows operating system and kernel level.
2. **Native PowerShell / DISM Commands**: The exact, un-abstracted commands you can execute manually without any modules.
3. **Under the Hood (`HyperV-LinuxLab` Mapping)**: How the module automates the pattern safely.
4. **Common Pitfalls & Edge Cases**: Failures, quirks, and gotchas encountered in enterprise environments.
5. **Verification & Diagnostics**: How to prove the component is operating normally.
