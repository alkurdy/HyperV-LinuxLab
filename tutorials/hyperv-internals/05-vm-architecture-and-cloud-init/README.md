# Hyper-V Tutorial 05: VM Architecture, Generation 2 UEFI & Cloud-Init Provisioning

> **[Tutorials Hub](../../README.md)** • **[Hyper-V Internals Track](../README.md)** • [← Previous: Hyper-V 04: Storage & Differencing Disks](../04-storage-and-differencing-disks/README.md) • [Index](../../README.md) • [Next: Hyper-V 06: Lifecycle & Telemetry →](../06-vm-lifecycle-and-telemetry/README.md)

---
Now that our storage and differencing disk architecture is clear, let's look at the virtual machine itself. So you want to boot a Linux VM without sitting through an interactive installer wizard, clicking "Next", selecting timezones, and creating user accounts—how does Hyper-V provision a fully configured, production-ready Linux node in under 10 seconds?

In this tutorial, we will explore Generation 2 virtual hardware, Linux Secure Boot, and how Cloud-Init NoCloud ISO injection automates unattended guest provisioning.

Here are the **7 critical areas** you will master:

---

## 1. Generation 1 vs Generation 2 Virtual Hardware

So you want to create a VM in Hyper-V, and the first question it asks is: "Generation 1 or Generation 2?" What does that mean for modern Linux?

### The Architecture
- **Generation 1 (Legacy BIOS)**:
  - Emulates an ancient 1990s motherboard: Intel 440BX chipset, IDE disk controllers, legacy PCI buses, and MBR partition tables.
  - Slow boot times, emulated hardware overhead, cannot boot from SCSI disks.
- **Generation 2 (Modern UEFI)**:
  - Pure synthetic VMBus hardware architecture. No legacy motherboard or IDE controllers emulated.
  - Boots directly into **UEFI firmware** with GPT partitioning and native SCSI disk controllers.
  - Boots up to **3x faster** and uses substantially less host memory.

### Native PowerShell Command
```powershell
# Create a pure Generation 2 virtual machine
Hyper-V\New-VM -Name "linux-node-01" `
    -Generation 2 `
    -MemoryStartupBytes 2GB `
    -SwitchName "Default Switch"
```

---

## 2. Linux Secure Boot & The Microsoft UEFI Certificate Authority

Now that your VM is Generation 2, you power it on, and it immediately errors: *"Virtual Machine Boot Summary: 1. SCSI DVD (0,0) Failed. 2. SCSI Disk (0,0) The image's hash and certificate are not allowed (DB)."* What happened?

### The Architecture
Generation 2 VMs enable **Secure Boot** by default to prevent bootkits and untrusted firmware. 
By default, Hyper-V configures the Secure Boot template to **"Microsoft Windows"**, which only trusts binaries signed by Microsoft's Windows OS key.
When standard Linux bootloaders (GRUB2, shim) boot, the hypervisor firmware rejects them!

### The Solution: `MicrosoftUEFICertificateAuthority`
To run Ubuntu, Debian, or AlmaLinux with Secure Boot enabled, you must change the firmware template to use the **Microsoft UEFI Certificate Authority** (which includes the third-party Linux shim signing certificate):

```powershell
# Configure Linux-compatible Secure Boot template
Hyper-V\Set-VMFirmware -VMName "linux-node-01" `
    -EnableSecureBoot On `
    -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
```

### Under the Hood in `HyperV-LinuxLab`
[`New-LabVM.ps1`](../../../Public/New-LabVM.ps1) executes this command on every provisioned VM, ensuring modern Linux distros boot securely without turning off hardware verification.

---

## 3. CPU Core Sizing & Static vs Dynamic Memory Allocation

Now that the firmware is configured, how should we size CPU and memory?

### The Architecture
1. **vCPU Count**:
   - Hyper-V defaults to 1 virtual CPU. Modern systemd-based Linux distros run background services (journald, udev, networkd) that benefit dramatically from at least **2 vCPUs**.
2. **Static Memory vs Dynamic Memory**:
   - Hyper-V supports Dynamic Memory (ballooning). However, Linux memory management and container runtimes (like `containerd` and `kubelet`) rely on predictable physical memory boundaries and can crash or deadlock when memory is dynamically reclaimed.
   - For Linux lab stability, **static memory is strongly recommended**.

### Native PowerShell Configuration
```powershell
# Allocate 2 vCPUs and disable dynamic memory ballooning
Hyper-V\Set-VMProcessor -VMName "linux-node-01" -Count 2
Hyper-V\Set-VMMemory -VMName "linux-node-01" -DynamicMemoryEnabled $false
```

---

## 4. What Is Cloud-Init? The Universal Cloud Provisioning Standard

Now that the VM hardware is ready, how does Linux know its hostname, user password, and SSH keys without manual intervention?

### The Architecture
**Cloud-Init** is the industry-standard multi-distribution package that handles initial instance configuration in cloud environments (AWS, Azure, GCP, OpenStack).
On first boot, Cloud-Init queries a **Datasource** to retrieve two configuration files:
1. **`meta-data`**: Defines instance-specific identity (hostname, instance ID).
2. **`user-data`**: A YAML document beginning with `#cloud-config` declaring users, SSH public keys, sudo privileges, packages to install, and shell scripts to run.

---

## 5. The NoCloud Datasource & Virtual ISO Injection

Now, public clouds pass metadata to VMs through internal HTTP metadata endpoints (e.g. `http://169.254.169.254`). But how do we pass this data locally on Hyper-V?

### The Architecture: NoCloud Volume
Cloud-Init includes a native offline datasource called **NoCloud**:
- If an optical drive (CD/DVD) or block device with filesystem volume label **`cidata`** is attached to the VM, Cloud-Init mounts it on boot.
- It reads `/meta-data` and `/user-data` directly from the filesystem!

### Constructing the Files
1. **`meta-data`**:
   ```yaml
   instance-id: linux-node-01
   local-hostname: linux-node-01
   ```
2. **`user-data` (`#cloud-config`)**:
   ```yaml
   #cloud-config
   users:
     - name: labadmin
       sudo: ALL=(ALL) NOPASSWD:ALL
       groups: [sudo, wheel, admin, docker]
       shell: /bin/bash
       plain_text_passwd: 'MySecurePassphrase-42'
       lock_passwd: false
   ssh_pwauth: true
   package_update: true
   packages:
     - curl
     - git
     - jq
   ```

### Native PowerShell ISO Generation & Mounting
```powershell
# Attach the generated cidata.iso to the VM's virtual DVD drive
Hyper-V\Add-VMDvdDrive -VMName "linux-node-01" -Path "C:\HyperV-LinuxLab\LabVMs\linux-node-01\linux-node-01-cidata.iso"
```

### Under the Hood in `HyperV-LinuxLab`
[`Public/New-LabCloudInitISO.ps1`](../../../Public/New-LabCloudInitISO.ps1) and [`Private/New-ISO9660Image.ps1`](../../../Private/New-ISO9660Image.ps1) construct standard ISO 9660 filesystems natively in pure PowerShell memory without requiring third-party tools like `mkisofs` or `genisoimage`!

---

## 6. The Azure Agent (`walinuxagent`) Polling Trap

Now, here is another engineering trap unique to upstream cloud images: why does an Azure cloud VHD take 5 minutes to boot on Hyper-V if unpatched?

### The Architecture: The `ovf-env.xml` Hang
Official upstream cloud images published by Canonical, Debian, and AlmaLinux for Hyper-V often come pre-configured with the **Azure Linux Guest Agent** (`walinuxagent` / `waagent`):
1. On boot, `walinuxagent` checks if it is running on Microsoft Hyper-V.
2. Because it detects Hyper-V, it attempts to read the Azure fabric configuration file (`ovf-env.xml`) from optical media or KVP.
3. Because our local machine is a local lab—not the public Azure datacenter—the agent hangs the boot process for 5 to 10 minutes polling for the Azure fabric controller!

### The Cloud-Init Bootcmd Fix
To achieve sub-10-second fast boots, we must mask and disable `walinuxagent` in the `bootcmd` section of `#cloud-config`:
```yaml
bootcmd:
  - systemctl mask --now walinuxagent.service waagent.service 2>/dev/null || true
  - systemctl stop --now walinuxagent.service waagent.service 2>/dev/null || true
  - mkdir -p /var/lib/waagent
  - touch /var/lib/waagent/ovf-env.xml
  - echo 'datasource_list: [ NoCloud, None ]' > /etc/cloud/cloud.cfg.d/99-nocloud.cfg
```

---

## 7. Step-by-Step Complete Manual VM Provisioning Drill

Now that we understand each layer, let's assemble them into a complete manual build script.

### The Drill
Run this pure PowerShell script to manually build, configure, attach, and power on a Generation 2 VM from raw components:

```powershell
$vmName     = "manual-lab-01"
$diffDisk   = "C:\HyperV-LinuxLab\LabVMs\$vmName\$vmName-diff.vhdx"
$parentDisk = "C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx"
$isoPath    = "C:\HyperV-LinuxLab\LabVMs\$vmName\$vmName-cidata.iso"

# 1. Create Differencing Disk
New-VHD -ParentPath $parentDisk -Path $diffDisk -Differencing | Out-Null

# 2. Create Gen2 VM
Hyper-V\New-VM -Name $vmName -Generation 2 -MemoryStartupBytes 2GB -VHDPath $diffDisk -SwitchName "Default Switch" | Out-Null

# 3. Configure Hardware & Firmware
Hyper-V\Set-VMProcessor -VMName $vmName -Count 2
Hyper-V\Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false
Hyper-V\Set-VMFirmware -VMName $vmName -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"

# 4. Attach NoCloud ISO
Hyper-V\Add-VMDvdDrive -VMName $vmName -Path $isoPath

# 5. Boot VM
Hyper-V\Start-VM -Name $vmName
Write-Host "[OK] Gen2 VM '$vmName' successfully booted with Cloud-Init NoCloud configuration!"
```

---

Now that our VM is running and provisioned, let's explore **[Tutorial 06: VM Lifecycle, Telemetry & Automation](../06-vm-lifecycle-and-telemetry/README.md)** to see how we monitor and automate our lab environment!

---

### Navigation
| [← Previous: Hyper-V 04: Storage & Differencing Disks](../04-storage-and-differencing-disks/README.md) | [Tutorials Index](../../README.md) | [Next: Hyper-V 06: Lifecycle & Telemetry →](../06-vm-lifecycle-and-telemetry/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Linux Level 01: Mental Model & Architecture](../../01-sysadmin-foundations/level-01-mental-model-and-architecture/README.md)).*
