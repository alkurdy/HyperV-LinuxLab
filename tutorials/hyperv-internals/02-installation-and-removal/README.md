# Hyper-V Tutorial 02: Hyper-V Installation, Reboot Lifecycle & Clean Removal

> **[Tutorials Hub](../../README.md)** • **[Hyper-V Internals Track](../README.md)** • [← Previous: Hyper-V 01: Prerequisites](../01-prerequisites-and-hardware/README.md) • [Index](../../README.md) • [Next: Hyper-V 03: Virtual Networking →](../03-virtual-networking/README.md)

---
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

On Windows 10/11 desktop editions, optional features are managed by DISM via `Enable-WindowsOptionalFeature`:
```powershell
# Enable the complete Hyper-V stack with all sub-features
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
```

*(Note: On Windows Server editions, you would use `Install-WindowsFeature -Name Hyper-V -IncludeManagementTools`).*

### The `-NoRestart` Switch
By passing `-NoRestart`, DISM stages the drivers and servicing packages into the Windows Component Store without immediately forcing a hard reboot, allowing scripts to inspect the result object (`RestartNeeded: True`).

---

## 3. The Reboot State Machine: Handling Pending Restarts

Now that DISM returned `RestartNeeded: True`, why can't we immediately run `Hyper-V\Get-VM`?

### The Two-Phase Boot Sequence
Enabling a Type-1 hypervisor requires a fundamental restructuring of the Windows boot chain:
1. **Phase 1 (Staging)**: DISM copies `hvix64.sys`, `vmswitch.sys`, and servicing files into `%SystemRoot%\System32\drivers` and updates the Boot Configuration Data (BCD) with `hypervisorlaunchtype Auto`.
2. **Phase 2 (Hardware Handover on Reboot)**: During host restart:
   - The BIOS/UEFI passes CPU control to the Windows Boot Manager (`bootmgr`).
   - `bootmgr` loads `hvix64.sys` at Ring -1.
   - The hypervisor creates the root partition and launches `ntoskrnl.exe` inside it.
   - The Windows kernel starts the `vmms` service.

### Detecting Pending Restarts Programmatically
To prevent scripts from crashing when executed in an un-rebooted state, inspect the 4 authoritative Windows reboot registry keys:

```powershell
function Test-PendingReboot {
    $cbs = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
    $wu  = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
    $sm  = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue

    [bool]($cbs -or $wu -or $sm.PendingFileRenameOperations)
}
```

---

## 4. The 3-Point Post-Install Health Check

Once rebooted, how do you verify Hyper-V is operational without opening the GUI?

### The 3 Verification Checks
1. **The Service Check (`vmms`)**: Is the management service running?
2. **The Hypervisor Check (`hvix64.sys`)**: Is Ring -1 active in hardware?
3. **The WMI Namespace Check (`root\virtualization\v2`)**: Is the hypervisor CIM schema responsive?

```powershell
# Point 1: Service
$serviceRunning = (Get-Service -Name "vmms" -ErrorAction SilentlyContinue).Status -eq "Running"

# Point 2: Hypervisor in Ring -1
$hypervisorActive = (Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent

# Point 3: WMI v2 Namespace
$wmiHealthy = $false
try {
    $null = Get-CimInstance -Namespace "root\virtualization\v2" -ClassName "Msvm_ComputerSystem" -ErrorAction Stop
    $wmiHealthy = $true
} catch {
    $wmiHealthy = $false
}

[PSCustomObject]@{
    VMMS_Service_Running = $serviceRunning
    Hypervisor_Active    = $hypervisorActive
    WMI_Schema_Healthy   = $wmiHealthy
    HyperV_Operational   = ($serviceRunning -and $hypervisorActive -and $wmiHealthy)
}
```

---

## 5. Complete Clean Removal: Reverting to Bare Metal

When decommissioning a virtualization host or recovering from CBS corruption, remove the Hyper-V role cleanly:

```powershell
# 1. Disable all Hyper-V features
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart

# 2. Reset hypervisor launch type in BCD
bcdedit /set hypervisorlaunchtype off
```

---

## 6. Troubleshooting DISM Error Codes & CBS Logs

### Common Failure Codes & Fixes
| Error Code | Name | Cause | Resolution |
| :--- | :--- | :--- | :--- |
| `0x800f080c` | `ERROR_PATH_NOT_FOUND` | Feature name misspelled or not present in Windows Edition (e.g. Windows Home). | Upgrade Windows edition or verify feature name `Microsoft-Hyper-V-All`. |
| `0x800f0922` | `CBS_E_INSTALLERS_FAILED` | Secure Boot conflict, firmware VT-x disabled in BIOS, or third-party antivirus blocking driver install. | Enable VT-x in BIOS; pause third-party security software. |
| `0x80070bc9` | `ERROR_FAIL_REBOOT_REQUIRED` | Another Windows update is already pending restart. | Reboot host first, then re-run installation command. |

### Inspecting Component Based Servicing (CBS) Logs
```powershell
Get-Content -Path "C:\Windows\Logs\CBS\CBS.log" -Tail 50 | Select-String "Error", "Fail"
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

Run these commands in an elevated PowerShell session to inspect the live hypervisor stack and verify service dependencies.

### 1. DISM Feature Hierarchy & State Inspection
- **Action**: Query the complete hierarchy of Hyper-V features:
  ```powershell
  Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -like "*Hyper-V*" } | Select-Object FeatureName, State
  ```
- **System Reaction**:
  DISM queries the Component Based Servicing (CBS) manifest database in `%SystemRoot%\WinSxS`. Notice that `Microsoft-Hyper-V-All` is a parent meta-package containing both `Microsoft-Hyper-V-Hypervisor` (kernel drivers) and `Microsoft-Hyper-V-Tools-All` (user-mode management cmdlets).
- **Verification**:
  Confirm that `Microsoft-Hyper-V-Hypervisor` reports `Enabled`.

### 2. Inspect the Pending Reboot State Machine
- **Action**: Check if any component in the operating system is holding a pending restart:
  ```powershell
  $pending = [PSCustomObject]@{
      CBS_Pending         = [bool](Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending")
      WU_Pending          = [bool](Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")
      SessionManager_Lock = [bool]((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations)
  }
  $pending | Format-List
  ```
- **System Reaction**:
  When Windows stages low-level kernel drivers or updates locked system files, it records rename operations in `Session Manager\PendingFileRenameOperations`. The kernel executes these renames during the early Phase 1 boot sequence before any user-mode service starts.
- **Verification**:
  If all report `False`, the host is in an active, clean runtime state.

### 3. Validate the 3-Point Health Check
- **Action**: Execute the 3-point health audit against the local host:
  ```powershell
  $vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
  $hyp  = (Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent
  $wmi  = $false
  try {
      $null = Get-CimInstance -Namespace "root\virtualization\v2" -ClassName "Msvm_ComputerSystem" -ErrorAction Stop
      $wmi  = $true
  } catch { $wmi = $false }

  [PSCustomObject]@{
      VMMS_Status       = $vmms.Status
      Hypervisor_Active = $hyp
      WMI_V2_Accessible = $wmi
  }
  ```
- **System Reaction**:
  `vmms.exe` communicates through the Hyper-V kernel driver via IOCTLs. Querying the `root\virtualization\v2` WMI namespace exercises the full IPC channel between user-mode PowerShell and Ring -1 hypervisor memory structures.
- **Verification**:
  All three checks must report positive operational status.

---

## Part B: Platform Solo Drill (Unguided Mission)

Now author an unguided hypervisor health auditor function without copy-paste code.

### The Mission: Hypervisor Lifecycle & Health Auditor
Write a reusable diagnostic function (`Test-HyperVRoleHealth`) that can run on any Windows machine to validate whether Hyper-V is ready to host production virtual machines.

1. **Customization**:
   - Provide options to output a human-readable diagnostic summary or a machine-parsable object.

2. **Acceptance Criteria**:
   - Function checks for administrative elevation.
   - Checks whether a host reboot is currently pending across CBS, WindowsUpdate, and Session Manager.
   - Validates that the `vmms` service is installed and in the `Running` state.
   - Validates that `HypervisorPresent` is `$true`.
   - Validates that CIM queries against `root\virtualization\v2` succeed without throwing.
   - Returns a structured `[PSCustomObject]` with properties: `IsReady` (boolean), `RebootPending` (boolean), `ServicesRunning` (boolean), `HypervisorPresent` (boolean), and `Diagnostics` (list of messages).

3. **Self-Verification**:
   Execute this test suite against your function to validate your implementation:
   ```powershell
   $result = Test-HyperVRoleHealth

   $hasContract = ($result.PSObject.Properties.Name -contains "IsReady") -and ($result.PSObject.Properties.Name -contains "RebootPending")
   if ($hasContract -and ($result.IsReady -is [bool])) {
       Write-Host "[PASS] Hyper-V role health auditor passed contract validation!" -ForegroundColor Green
   } else {
       Write-Host "[FAIL] Missing required health properties!" -ForegroundColor Red
   }
   ```

---

In **[Tutorial 03: Virtual Networking & Guest IP Routing](../03-virtual-networking/README.md)**, our running hypervisor will build an Internal Virtual Switch, configure Windows NAT (`New-NetNat`), and route traffic to synthetic VMBus network adapters!

---

### Navigation
| [← Previous: Hyper-V 01: Prerequisites](../01-prerequisites-and-hardware/README.md) | [Tutorials Index](../../README.md) | [Next: Hyper-V 03: Virtual Networking →](../03-virtual-networking/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Linux Level 01: Mental Model & Architecture](../../01-sysadmin-foundations/level-01-mental-model-and-architecture/README.md)).*
