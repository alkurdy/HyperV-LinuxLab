# Hyper-V Tutorial 05: VM Architecture, Generation 2 UEFI & Cloud-Init Provisioning

> **[Tutorials Hub](../../README.md)** • **[Hyper-V Internals Track](../README.md)** • [← Previous: Hyper-V 04: Storage & Differencing Disks](../04-storage-and-differencing-disks/README.md) • [Index](../../README.md) • [Next: Hyper-V 06: Lifecycle & Telemetry →](../06-vm-lifecycle-and-telemetry/README.md)

---
Now that our storage and differencing disk architecture is clear, let's look at the virtual machine itself. So you want to boot a Linux VM without sitting through an interactive installer wizard, clicking "Next", selecting timezones, and creating user accounts—how does Hyper-V provision a fully configured, production-ready Linux node in under 10 seconds?

In this tutorial, we will explore Generation 2 virtual hardware, Linux Secure Boot, and how Cloud-Init NoCloud ISO injection automates unattended guest provisioning.

Here are the **7 critical areas** you will master:

---

## 1. Generation 1 vs Generation 2 Virtual Hardware

Hyper-V provides two virtual hardware models:
- **Generation 1 (Legacy BIOS)**:
  - Emulates an ancient 1990s motherboard: Intel 440BX chipset, IDE disk controllers, legacy PCI buses, and MBR partition tables.
  - Slow boot times, emulated hardware overhead, cannot boot from SCSI disks.
- **Generation 2 (Modern UEFI)**:
  - Pure synthetic VMBus hardware architecture. No legacy motherboard or IDE controllers emulated.
  - Boots directly into **UEFI firmware** with GPT partitioning and native SCSI disk controllers.
  - Boots up to **3x faster** and uses substantially less host memory.

### Native PowerShell Command
```powershell
Hyper-V\New-VM -Name "linux-node-01" `
    -Generation 2 `
    -MemoryStartupBytes 2GB `
    -SwitchName "Default Switch"
```

---

## 2. Linux Secure Boot & The Microsoft UEFI Certificate Authority

Generation 2 VMs enable **Secure Boot** by default to prevent bootkits and untrusted firmware. 
By default, Hyper-V configures the Secure Boot template to **"Microsoft Windows"**, which only trusts binaries signed by Microsoft's Windows OS key.
When standard Linux bootloaders (GRUB2, shim) boot, the hypervisor firmware rejects them!

### The Solution: `MicrosoftUEFICertificateAuthority`
To run Ubuntu, Debian, or AlmaLinux with Secure Boot enabled, you must change the firmware template to use the **Microsoft UEFI Certificate Authority** (which includes the third-party Linux shim signing certificate):

```powershell
Hyper-V\Set-VMFirmware -VMName "linux-node-01" `
    -EnableSecureBoot On `
    -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
```

---

## 3. CPU Core Sizing & Static vs Dynamic Memory Allocation

1. **vCPU Count**:
   - Hyper-V defaults to 1 virtual CPU. Modern systemd-based Linux distros run background services (journald, udev, networkd) that benefit dramatically from at least **2 vCPUs**.
2. **Static Memory vs Dynamic Memory**:
   - Hyper-V supports Dynamic Memory (ballooning). However, Linux memory management and container runtimes (like `containerd` and `kubelet`) rely on predictable physical memory boundaries and can crash or deadlock when memory is dynamically reclaimed.
   - For Linux labs, **disable dynamic memory** to guarantee stable physical allocation:

```powershell
Hyper-V\Set-VMProcessor -VMName "linux-node-01" -Count 2
Hyper-V\Set-VMMemory -VMName "linux-node-01" -DynamicMemoryEnabled $false
```

---

## 4. Cloud-Init Architecture: The NoCloud Datasource

How do cloud providers (AWS, Azure, GCP) configure an operating system on first boot without interactive installers?

### The Architecture
Linux cloud images include **Cloud-Init**, an industry-standard initialization framework:
1. On boot, Cloud-Init probes for a **Datasource**.
2. In local environments without cloud metadata HTTP endpoints, Cloud-Init uses the **NoCloud** datasource.
3. It searches attached storage devices for a filesystem labeled **`cidata`** containing two YAML files:
   - `user-data`: Configures default user accounts, SSH authorized keys, sudoers, and packages.
   - `meta-data`: Defines the system hostname and instance ID.

---

## 5. Generating NoCloud ISO Images on Windows

To pass `user-data` and `meta-data` to a Hyper-V VM, we bundle them into an ISO9660 disk image:

```yaml
# user-data
#cloud-config
hostname: my-node-01
manage_etc_hosts: true
users:
  - name: labadmin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    plain_text_passwd: "LabPassword123!"
    lock_passwd: false
ssh_pwauth: true
```

```yaml
# meta-data
instance-id: i-local-lab-01
local-hostname: my-node-01
```

---

## 6. Bypassing Azure Linux Agent (`walinuxagent`) Boot Hangs

Upstream cloud images published for Hyper-V often come pre-configured with the **Azure Linux Guest Agent** (`walinuxagent` / `waagent`):
1. On boot, `walinuxagent` checks if it is running on Microsoft Hyper-V.
2. It attempts to read Azure datacenter fabric configuration (`ovf-env.xml`).
3. In a local lab, it hangs the boot process for 5 to 10 minutes polling for the Azure fabric controller!

Mask `walinuxagent` in the `bootcmd` section of `#cloud-config` to achieve fast 10-second boots:
```yaml
bootcmd:
  - systemctl mask --now walinuxagent.service waagent.service 2>/dev/null || true
  - systemctl stop --now walinuxagent.service waagent.service 2>/dev/null || true
  - mkdir -p /var/lib/waagent
  - touch /var/lib/waagent/ovf-env.xml
  - echo 'datasource_list: [ NoCloud, None ]' > /etc/cloud/cloud.cfg.d/99-nocloud.cfg
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

Run these commands in an elevated PowerShell session to create a test Gen2 virtual machine, configure its firmware and memory, and inspect its synthetic hardware.

### 1. Create Generation 2 VM with Static Memory
- **Action**: Provision a Generation 2 VM container with 2 vCPUs and static memory:
  ```powershell
  $vmName = "drill-gen2-node"
  $vm = Hyper-V\New-VM -Name $vmName -Generation 2 -MemoryStartupBytes 2GB -SwitchName "Default Switch"
  Hyper-V\Set-VMProcessor -VMName $vmName -Count 2
  Hyper-V\Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false
  ```
- **System Reaction**:
  Hyper-V registers the VM in `root\virtualization\v2` and allocates a dedicated VM configuration file (`.vmcx`). Gen2 initializes pure VMBus devices without legacy IDE or PCI bus emulation.
- **Verification**:
  ```powershell
  Hyper-V\Get-VM -Name $vmName | Select-Object Name, Generation, MemoryStartup, DynamicMemoryEnabled
  ```

### 2. Configure Linux Secure Boot Firmware
- **Action**: Switch the UEFI Secure Boot template to the third-party Linux certificate authority:
  ```powershell
  Hyper-V\Set-VMFirmware -VMName $vmName -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
  ```
- **System Reaction**:
  The hypervisor writes the Microsoft Third-Party UEFI CA public certificates into the virtual NVRAM store of the Gen2 VM. When Linux loads `shimx64.efi` and `grubx64.efi`, the signatures match and boot execution is authorized.
- **Verification**:
  ```powershell
  Hyper-V\Get-VMFirmware -VMName $vmName | Select-Object SecureBoot, SecureBootTemplate
  ```

### 3. Attach DVD Drive for Cloud-Init Injection
- **Action**: Attach a virtual DVD drive to the SCSI controller:
  ```powershell
  $dvd = Hyper-V\Add-VMDvdDrive -VMName $vmName -ControllerNumber 0 -ControllerLocation 1
  ```
- **System Reaction**:
  Hyper-V allocates a synthetic SCSI optical device handle. On Linux guest boot, the SCSI driver enumerates `/dev/sr0`, allowing Cloud-Init's `DataSourceNoCloud` engine to mount the ISO and parse configuration files.
- **Verification**:
  ```powershell
  Hyper-V\Get-VMDvdDrive -VMName $vmName
  ```

---

## Part B: Platform Solo Drill (Unguided Mission)

Now author an unguided VM assembly and firmware configuration function without copy-paste code.

### The Mission: Automated Gen2 VM Assembly Engine (`New-PlatformVMContainer`)
Platform engineering needs a reusable function to assemble a fully compliant Generation 2 Linux VM container ready for storage and cloud-init disk attachment.

1. **Customization**:
   - Provide custom parameters: `-VMName`, `-MemoryGB`, `-CPUCount`, and `-SwitchName`.

2. **Acceptance Criteria**:
   - Uses module-qualified cmdlets (`Hyper-V\New-VM`, `Hyper-V\Set-VMFirmware`, etc.).
   - Explicitly creates Generation 2 virtual hardware.
   - Enforces Secure Boot using `MicrosoftUEFICertificateAuthority`.
   - Disables Dynamic Memory and configures the exact specified static memory and vCPU count.
   - Attaches a virtual DVD drive to SCSI Controller 0.
   - Cleans up cleanly if an error occurs mid-creation.
   - Returns a structured `[PSCustomObject]` with properties: `VMName`, `Generation`, `CPUCount`, `MemoryGB`, `SecureBootTemplate`, and `DvdDriveAttached`.

3. **Self-Verification**:
   Execute this test suite against your function to validate your implementation:
   ```powershell
   $testNode = "test-platform-vm"
   $vmObj = New-PlatformVMContainer -VMName $testNode -MemoryGB 2 -CPUCount 2 -SwitchName "Default Switch"

   # Test 1: Gen2 and Linux CA
   $genPass = ($vmObj.Generation -eq 2) -and ($vmObj.SecureBootTemplate -eq "MicrosoftUEFICertificateAuthority")

   # Test 2: Hardware sizing
   $hwPass  = ($vmObj.CPUCount -eq 2) -and ($vmObj.MemoryGB -eq 2)

   if ($genPass -and $hwPass) {
       Write-Host "[PASS] Gen2 VM assembly engine passed all architectural validations!" -ForegroundColor Green
   } else {
       Write-Host "[FAIL] VM container failed generation or firmware validation!" -ForegroundColor Red
   }

   # Clean up drill VM
   Hyper-V\Remove-VM -Name $testNode -Force -ErrorAction SilentlyContinue
   Hyper-V\Remove-VM -Name "drill-gen2-node" -Force -ErrorAction SilentlyContinue
   ```

---

In **[Tutorial 06: VM Lifecycle, Telemetry & Automation](../06-vm-lifecycle-and-telemetry/README.md)**, we will take our complete platform stack and automate day-2 operations: non-blocking IP discovery, dual-write telemetry, and multi-node cluster orchestration!

---

### Navigation
| [← Previous: Hyper-V 04: Storage & Differencing Disks](../04-storage-and-differencing-disks/README.md) | [Tutorials Index](../../README.md) | [Next: Hyper-V 06: Lifecycle & Telemetry →](../06-vm-lifecycle-and-telemetry/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Linux Level 01: Mental Model & Architecture](../../01-sysadmin-foundations/level-01-mental-model-and-architecture/README.md)).*
