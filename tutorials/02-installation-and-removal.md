# Tutorial 02: Hyper-V Installation, Reboot Lifecycle & Clean Removal

Now that we've got host prerequisites verified, let's look at installing the Hyper-V role—and just as importantly, how to cleanly remove it when you want to start fresh or troubleshoot a broken state.

Installing Hyper-V isn't like installing a regular application. Because Hyper-V is a Type-1 hypervisor, enabling it fundamentally restructures how your CPU boots and how Windows executes. In this tutorial, we will walk through the full lifecycle: provisioning, the reboot state machine, verification, and complete uninstallation.

Here are the **7 critical areas** you will master:

---

## 1. Anatomy of the Hyper-V Role: The 4 Core Layers

So you want to install Hyper-V, but what is actually landing on your disk?

### The Architecture
Hyper-V is composed of four distinct operational layers:
1. **The Hypervisor Microkernel (`hvix64.sys`)**:
   - The bare-metal Type-1 hypervisor kernel that boots before Windows and partitions physical CPU/RAM into hardware execution containers.
2. **The Virtual Machine Management Service (`vmms.exe`)**:
   - The user-mode Windows service (`vmms`) responsible for VM lifecycle, device management, and communication between parent and child partitions.
3. **The Virtual Switch & Network Drivers (`vmswitch.sys`)**:
   - The kernel-level virtual switch subsystem handling network virtualization, NAT, and port isolation.
4. **The Management Tools & PowerShell Module (`Hyper-V`)**:
   - The client GUI (`virtmgmt.msc`) and native cmdlets (`New-VM`, `Get-VHD`, `Start-VM`).

### Native PowerShell Feature Discovery
You can query all Hyper-V feature components and their current states using DISM:
```powershell
Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -like "*Hyper-V*" } | Format-Table FeatureName, State
```

---

## 2. Installing Hyper-V: DISM vs Server Manager

Now that we know what components make up the role, let's install them.

### Native PowerShell Command
On Windows 10/11 desktop editions, optional features are managed by DISM via `Enable-WindowsOptionalFeature`:
```powershell
# Enable the complete Hyper-V stack with all sub-features
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
```

*(Note: On Windows Server editions, you would use `Install-WindowsFeature -Name Hyper-V -IncludeManagementTools`).*

### The `-NoRestart` Switch
By passing `-NoRestart`, DISM stages the drivers and servicing packages into the Windows Component Store without immediately forcing a hard reboot, allowing scripts to inspect the result object (`RestartNeeded: True`).

### Under the Hood in `HyperV-LinuxLab`
[`Install-LabHyperV.ps1`](../Public/Install-LabHyperV.ps1) executes this exact DISM command after validating hardware virtualization and Windows SKU compatibility.

---

## 3. The Reboot State Machine: Handling Pending Restarts

Now that DISM returned `RestartNeeded: True`, why can't we immediately run `Hyper-V\Get-VM`?

### The Architecture: Staged vs Active Drivers
When DISM installs a driver like `hvix64.sys`, it registers the driver in the Boot Configuration Data (BCD) store (`hypervisorlaunchtype = auto`). However, the current running kernel cannot dynamically convert itself into a virtualized root partition while active.

A full system restart is **mandatory**. Until that restart happens, the system sits in a **Pending Reboot** state:
- The `vmms` service cannot start.
- The `Hyper-V` PowerShell module cannot connect to the WMI virtualization namespace (`root\virtualization\v2`).

### Native PowerShell Detection
You can detect if Windows is waiting for a restart using two canonical registry locations:
```powershell
# 1. Component Based Servicing (CBS) check
$cbsReboot = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'

# 2. Windows Update Reboot Required check
$wuReboot  = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'

$pending = $cbsReboot -or $wuReboot
Write-Host "Reboot Required: $pending (CBS: $cbsReboot, WindowsUpdate: $wuReboot)"
```

### Under the Hood in `HyperV-LinuxLab`
[`Test-LabPrerequisites.ps1`](../Public/Test-LabPrerequisites.ps1) inspects these registry keys. If a reboot is pending, it sets `PendingReboot: True` and prompts you to restart rather than attempting to launch VMs and crashing.

---

## 4. Post-Reboot Verification: Confirming the Hypervisor Is Alive

Now that your machine has rebooted, how do you verify that the hypervisor microkernel actually booted at Ring -1?

### 3-Point Health Check
Run these three native commands to verify complete operational health:

```powershell
# 1. Verify Hypervisor Presence in Root Partition
$hypervisorActive = (Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent
Write-Host "1. Hypervisor Kernel Active : $hypervisorActive" -ForegroundColor $(if ($hypervisorActive) {'Green'} else {'Red'})

# 2. Verify VMMS Service Status
$vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
Write-Host "2. VMMS Service Status      : $($vmms.Status)" -ForegroundColor $(if ($vmms.Status -eq 'Running') {'Green'} else {'Red'})

# 3. Verify PowerShell Module Communication
$testVM = Hyper-V\Get-VM -ErrorAction SilentlyContinue
Write-Host "3. Hyper-V Module Namespace  : Operational" -ForegroundColor Green
```

---

## 5. Complete Clean Removal: How to Uninstall Hyper-V

Now, what if you want to test the entire installation flow from scratch, or you need to completely remove Hyper-V from your workstation?

### Step-by-Step Clean Removal

#### Step 1: Clean Up Running VMs and Virtual Disks
Before removing the hypervisor, delete any active virtual machines so you don't leave orphaned differencing disks:
```powershell
# Stop and remove all lab VMs
Hyper-V\Get-VM | Hyper-V\Stop-VM -TurnOff -Force
Hyper-V\Get-VM | Hyper-V\Remove-VM -Force
```

#### Step 2: Disable the Hyper-V Feature via DISM
Execute DISM to remove all 7 Hyper-V components:
```powershell
# Disable all Hyper-V feature components without immediate reboot
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
```

#### Step 3: Reboot Host
Restart your PC to allow Windows to reconfigure the kernel and unload the hypervisor:
```powershell
Restart-Computer
```

---

## 6. Verifying Hyper-V Is Completely Uninstalled

Now that the system has rebooted after uninstallation, how do you prove that Hyper-V is truly gone and your CPU is running in pure bare-metal mode?

### Post-Removal Verification Script
Execute this audit script:
```powershell
# 1. Verify DISM Feature States are 'Disabled'
$features = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -like "*Hyper-V*" }
$allDisabled = (-not ($features.State -contains "Enabled"))
Write-Host "1. DISM Features Disabled : $allDisabled" -ForegroundColor $(if ($allDisabled) {'Green'} else {'Red'})

# 2. Verify Hypervisor is NOT Present in Ring -1
$hypervisorPresent = (Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent
Write-Host "2. Hypervisor Unloaded     : $(-not $hypervisorPresent)" -ForegroundColor $(if (-not $hypervisorPresent) {'Green'} else {'Red'})

# 3. Verify VMMS Service is Absent or Stopped
$vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
Write-Host "3. VMMS Service Stopped    : $(-not $vmms -or $vmms.Status -ne 'Running')" -ForegroundColor Green
```

When `HypervisorPresent` is `False`, Windows is executing directly on the bare-metal processor without any hypervisor layer.

---

## 7. Troubleshooting DISM Error Codes & CBS Logs

Now, what happens if `Enable-WindowsOptionalFeature` fails with a cryptic hex code?

### Common Failure Codes & Fixes
| Error Code | Name | Cause | Resolution |
| :--- | :--- | :--- | :--- |
| `0x800f080c` | `ERROR_PATH_NOT_FOUND` | Feature name misspelled or not present in Windows Edition (e.g., trying to enable on Windows Home). | Upgrade Windows edition or verify feature name `Microsoft-Hyper-V-All`. |
| `0x800f0922` | `CBS_E_INSTALLERS_FAILED` | Secure Boot conflict, firmware VT-x disabled in BIOS, or third-party antivirus blocking driver install. | Enable VT-x in BIOS; temporarily pause third-party security software. |
| `0x80070bc9` | `ERROR_FAIL_REBOOT_REQUIRED` | Another Windows update is already pending restart. | Reboot host first, then re-run installation command. |

### Inspecting Component Based Servicing (CBS) Logs
If an installation error occurs, inspect the last 50 lines of the DISM servicing log:
```powershell
Get-Content -Path "C:\Windows\Logs\CBS\CBS.log" -Tail 50 | Select-String "Error", "Fail"
```

---

Now that we've got Hyper-V installed, verified, and operational, let's explore **[Tutorial 03: Virtual Networking & Guest IP Routing](03-virtual-networking.md)** to see how VMs get network connectivity.
