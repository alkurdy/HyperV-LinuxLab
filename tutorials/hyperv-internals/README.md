# Track 2: Hyper-V Systems Engineering Curriculum

> **[Tutorials Hub](../README.md)** • **Hyper-V Internals Track** • [Switch to Linux Lab Track →](../01-sysadmin-foundations/README.md)

Welcome to the **Hyper-V Systems Engineering** track of the HyperV-LinuxLab curriculum.

This track is designed for cloud architects, platform engineers, and Windows administrators who want to understand how Hyper-V, DISM, VMBus, and UEFI function beneath the surface without third-party tool abstraction.

---

## Tutorial Directory

| # | Tutorial Folder | What You Will Learn | Est. Time |
| :---: | :--- | :--- | :---: |
| **01** | [**01-prerequisites-and-hardware**](01-prerequisites-and-hardware/README.md) | Windows SKU gating (Pro vs Home), CPU VT-x/AMD-V registers, Ring -1 hypervisor masking, SLAT, DEP, memory reservation, and PowerShell module qualification (`Hyper-V\Cmdlet`). | 15 min |
| **02** | [**02-installation-and-removal**](02-installation-and-removal/README.md) | The 4 core layers (`hvix64.sys`, `vmms`), DISM features, pending reboot state machines, 3-point health check, **complete clean uninstallation**, and CBS log debugging. | 20 min |
| **03** | [**03-virtual-networking**](03-virtual-networking/README.md) | Default Switch vs Internal NAT switches, WinNAT (`New-NetNat`), synthetic VMBus adapters, guest DHCP routing, and KVP in-memory IP resolution. | 25 min |
| **04** | [**04-storage-and-differencing-disks**](04-storage-and-differencing-disks/README.md) | VHDX block allocation tables, read-only golden masters, 4MB child delta disks, parent-child pointer chains, and sub-5-second atomic resets. | 20 min |
| **05** | [**05-vm-architecture-and-cloud-init**](05-vm-architecture-and-cloud-init/README.md) | Gen1 vs Gen2 UEFI, Linux Secure Boot (`MicrosoftUEFICertificateAuthority`), dynamic RAM tuning, NoCloud ISO9660 generation (`cidata.iso`), and bypassing Azure `walinuxagent` boot hangs. | 25 min |
| **06** | [**06-vm-lifecycle-and-telemetry**](06-vm-lifecycle-and-telemetry/README.md) | Native power states (`Stop-VM -TurnOff`), non-blocking TCP port 22 polling, dual-write metadata (JSON + VM Notes), host startup auto-boot, multi-node orchestration, and worker process termination (`vmwp.exe`). | 25 min |

---

### Navigation
| [← Back to Master Tutorials Hub](../README.md) | [Start Hyper-V 01: Prerequisites & Silicon →](01-prerequisites-and-hardware/README.md) |
| :--- | ---: |
