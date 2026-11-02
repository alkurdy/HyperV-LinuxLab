# Hyper-V Tutorial 01: Prerequisites, Hardware Virtualization & Host Readiness

> **[Tutorials Hub](../../README.md)** â€¢ **[Hyper-V Internals Track](../README.md)** â€¢ [â† Previous: Lab 05: Multi-Distro Clusters](../../linux/05-multi-distro-clusters/README.md) â€¢ [ðŸ“‘ Index](../../README.md) â€¢ [Next: Hyper-V 02: Installation & Removal â†’](../02-installation-and-removal/README.md)

---
So, you want to build a lightning-fast virtualization lab on your Windows machine, but you're not sure if your hardware and Windows setup are ready to handle it. Before we deploy our first Linux node, we need to inspect the bare metal.

In this tutorial, we will peel back the abstraction layer. While running `Test-LabPrerequisites` checks your host with a single keystroke, understanding what Windows is doing behind the scenes will save you hours of debugging when something doesn't work.

Here are the **7 critical areas** you must master to guarantee host readiness:

---

## 1. Windows Edition Compatibility: Pro vs Home

So you want to turn on Hyper-V, but Windows says no. What gives?

### The Architecture
Hyper-V is a Type-1 bare-metal hypervisor baked into the Windows NT kernel, but Microsoft intentionally gates the management stack and hypervisor role by Windows product SKU:
- **Supported Editions**: Windows 10/11 Pro, Enterprise, Education, and Windows Server 2016/2019/2022/2025.
- **Unsupported Editions**: Windows Home (Core). Windows Home lacks the native Hyper-V management service (`vmms`), virtual switch manager, and hypervisor drivers in its servicing package.

### Native PowerShell Check
You can query your exact Windows edition and product license using CIM:
```powershell
# Query Windows Edition and Operating System Caption
$os = Get-CimInstance -ClassName Win32_OperatingSystem
[PSCustomObject]@{
    Caption     = $os.Caption
    Version     = $os.Version
    BuildNumber = $os.BuildNumber
    OSProduct   = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
}
```

### Under the Hood in `HyperV-LinuxLab`
[`Test-LabPrerequisites.ps1`](../../../Public/Test-LabPrerequisites.ps1) and [`Install-LabHyperV.ps1`](../../../Public/Install-LabHyperV.ps1) query the `EditionID` registry key. If it detects `Core` or `Home`, it immediately halts execution with an actionable recommendation rather than letting DISM throw a cryptic `0x800f080c` feature-not-found error.

---

## 2. Hardware CPU Virtualization: Intel VT-x vs AMD-V

Now that we know your Windows edition can host Hyper-V, let's talk silicon. Your CPU must physically support hardware-assisted virtualization.

### The Architecture
When virtual machines execute CPU instructions, they shouldn't have to emulate every cycle in software. Hardware-assisted virtualization gives the CPU dedicated privilege rings (often referred to as Ring -1 or VMX root mode):
- **Intel**: Named **VT-x** (Virtualization Technology) and **VMX**.
- **AMD**: Named **AMD-V** (SVM / Secure Virtual Machine).

These instructions must be explicitly enabled in your motherboard's UEFI/BIOS firmware settings.

### Native PowerShell Check
Before Hyper-V is running, you can inspect your CPU capabilities directly:
```powershell
# Query bare-metal CPU virtualization capability
Get-CimInstance -ClassName Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, VirtualizationFirmwareEnabled
```
If `VirtualizationFirmwareEnabled` is `False`, Windows cannot virtualize guests until you reboot into your BIOS and enable Intel Virtualization Technology / SVM Mode.

---

## 3. The "Hypervisor Present" WMI Masking Trap

Now that you've enabled VT-x in your BIOS, you boot into Windows, run your CIM query, and find that `VirtualizationFirmwareEnabled` suddenly reports `False`! Did your motherboard lie?

### The Architecture: Ring -1 Masking
Here is the classic Hyper-V engineering trap: **Hyper-V is a Type-1 hypervisor**. 
When Hyper-V is enabled and active:
1. The Hyper-V microkernel (`hvix64.sys`) boots *first* on the physical silicon at Ring -1.
2. The Windows OS you interact with is demoted to the **Root Partition** (parent virtual machine).
3. Because the root partition is already running on top of the hypervisor, the CPU's bare-metal VMX/SVM registers are hidden from it!

As a result, standard WMI queries against `Win32_Processor.VirtualizationFirmwareEnabled` report `False` even though virtualization is 100% active and functioning!

### Native PowerShell Solution
To check virtualization without falling into this trap, you must check if the hypervisor itself is already present:
```powershell
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$isHypervisorRunning = $computerSystem.HypervisorPresent

if ($isHypervisorRunning) {
    Write-Host "[OK] Hypervisor is active in Ring -1. Firmware virtualization is definitely enabled!" -ForegroundColor Green
} else {
    $firmwareEnabled = (Get-CimInstance -ClassName Win32_Processor).VirtualizationFirmwareEnabled
    Write-Host "Hypervisor not running. BIOS Virtualization status: $firmwareEnabled"
}
```

### Under the Hood in `HyperV-LinuxLab`
[`Install-LabHyperV.ps1`](../../../Public/Install-LabHyperV.ps1) evaluates `Win32_ComputerSystem.HypervisorPresent` first. If `True`, it knows the hypervisor is already initialized and skips the raw processor check.

---

## 4. SLAT (Second Level Address Translation) & DEP

Now that our CPU can handle guest instructions, how does it handle guest memory without bringing down your host?

### The Architecture
1. **SLAT (Second Level Address Translation)**:
   - Intel calls it **EPT** (Extended Page Tables).
   - AMD calls it **NPT** (Nested Page Tables) or **RVI**.
   - Traditional virtualization requires the hypervisor to maintain shadow page tables in software. SLAT pushes guest-to-host memory mapping directly into CPU hardware, cutting memory virtualization overhead by up to 80%.
2. **DEP (Data Execution Prevention)**:
   - Hardware-enforced No-Execute (`NX`/`XD`) memory pages preventing buffer-overflow exploits from compromising host physical memory.

### Native PowerShell Check
You can check SLAT and DEP support across all cores using Windows `systeminfo.exe`:
```powershell
# Parse systeminfo firmware requirements
systeminfo.exe | Select-String "Hyper-V Requirements", "Virtualization Enabled In Firmware", "Second Level Address Translation", "Data Execution Prevention Available"
```

---

## 5. Host Memory & Storage Capacity Planning

Now that the processor checks out, let's look at capacity. Virtual machines can easily exhaust physical host resources if you don't calculate sizing before deployment.

### Sizing Principles: The Overcommit Boundary
- **RAM is Inelastic**: While Hyper-V supports Dynamic Memory, Linux kernels and Kubernetes worker nodes perform unpredictably when memory is ballooned or paged to disk. Static memory is standard in our lab environments.
- **Rule of Thumb**: Reserve at least **4 GB to 6 GB RAM** for the Windows root partition (your host OS, IDE, and apps).
- **Core Allocation**: You can safely overcommit CPU cores up to a **2:1 ratio** (e.g., allocating 12 vCPUs across all VMs on a 6-core / 12-thread host CPU) for testing workloads.

### Native PowerShell Telemetry
You can query exact host memory and storage metrics using CIM:
```powershell
# Host Memory Calculation
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$totalRAM_GB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeRAM_GB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

# Fixed Drive Free Capacity
$drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" | Select-Object DeviceID,
    @{Name="FreeGB"; Expression={[math]::Round($_.FreeSpace / 1GB, 2)}},
    @{Name="TotalGB"; Expression={[math]::Round($_.Size / 1GB, 2)}}

Write-Host "Host RAM : ${freeRAM_GB} GB free of ${totalRAM_GB} GB"
$drives | Format-Table -AutoSize
```

### Under the Hood in `HyperV-LinuxLab`
[`Private/Get-LabHostSystemInfo.ps1`](../../../Private/Get-LabHostSystemInfo.ps1) centralizes these queries across [`Test-LabPrerequisites`](../../../Public/Test-LabPrerequisites.ps1) and [`Test-LabCluster`](../../../Public/Test-LabCluster.ps1), dynamically finding your secondary high-capacity drives (like `D:\`) so labs don't crowd your primary OS partition.

---

## 6. Coexistence with Other Hypervisors (VirtualBox, VMware, WSL2)

Now, what if you already have VMware Workstation or VirtualBox installed? Will enabling Hyper-V cause a blue screen?

### The Architecture: WHVP (Windows Hypervisor Platform)
Historically (pre-2020), third-party Type-2 hypervisors like VirtualBox and VMware Workstation fought Hyper-V for hardware VT-x control. If Hyper-V claimed Ring -1, launching VirtualBox resulted in an instant host crash (BSOD).

Modern versions solved this through **WHVP** (Windows Hypervisor Platform):
- **WSL2**: Runs natively on the Hyper-V virtualization platform. 100% compatible.
- **VirtualBox (>= 6.1)**: Can run as a client on top of Hyper-V using the `NEM` (Native Execution Manager) engine.
- **VMware Workstation (>= 15.5)**: Implements Microsoft's WHV APIs, allowing VMware and Hyper-V to run concurrently.

### Native PowerShell Conflict Scan
Before enabling Hyper-V, you can scan for active third-party hypervisor daemons:
```powershell
# Scan running processes and services for legacy hypervisors
$competingProcesses = Get-Process -Name "VBoxSVC", "VirtualBox*", "vmware*", "vmnetdhcp" -ErrorAction SilentlyContinue
if ($competingProcesses) {
    Write-Warning "Detected active VMware / VirtualBox processes. Ensure they are updated to current versions supporting WHVP."
}
```

### Why the `Hyper-V\` Cmdlet Prefix? (PowerShell Module Qualification)
Throughout this curriculum and module source code, you will frequently see cmdlets written with an explicit `Hyper-V\` prefix (e.g. `Hyper-V\New-VMSwitch`, `Hyper-V\Get-VM`, `Hyper-V\Start-VM`).

In PowerShell, this syntax (`<ModuleName>\<CmdletName>`) is called **Module Qualification**.

Why is this critical for enterprise systems engineering?
1. **Cmdlet Name Collisions**: Multiple virtualization management modules use identical cmdlet names. If **VMware PowerCLI** is installed on your workstation, it also exports cmdlets named `Get-VM`, `New-VM`, and `Set-VM`. When both modules are loaded in the same session, typing bare `Get-VM` executes VMware's cmdlet first and throws an unhandled error:
   ```text
   Get-VM : You are not currently connected to any servers.
   ```
2. **Deterministic Script Execution**: Module qualification bypasses PowerShell's command precedence rules (which favor functions and aliases over cmdlets). It guarantees that automation scripts execute Microsoft's native Hyper-V binary module every single time.
3. **Autoload Ambiguity Prevention**: Eliminates module auto-loading guesswork by directing the PowerShell parser directly to the specific binary manifest.

---

## 7. Step-by-Step Host Readiness Verification Drill

Now that we understand each requirement, let's run a complete hands-on verification drill.

### The Drill
Run this pure PowerShell scriptblock in an elevated console to generate a comprehensive host pre-flight audit report:

```powershell
$report = [PSCustomObject]@{
    IsAdmin             = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    WindowsCaption      = (Get-CimInstance Win32_OperatingSystem).Caption
    WindowsEdition      = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
    HypervisorPresent   = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
    LogicalCores        = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    TotalMemoryGB       = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)
    FreeMemoryGB        = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
}

$report | Format-List
```

### The Output
- If `IsAdmin` is `True`, `WindowsEdition` is `Professional`/`Enterprise`, and `TotalMemoryGB` >= `8`, you are ready for the next step.

Now that we've got host prerequisites verified, let's move to **[Tutorial 02: Hyper-V Installation, Verification & Clean Removal](../02-installation-and-removal/README.md)** to install and configure the hypervisor role.

---

### ðŸ§­ Navigation
| [â† Previous: Lab 05: Multi-Distro Clusters](../../linux/05-multi-distro-clusters/README.md) | [ðŸ“‘ Tutorials Index](../../README.md) | [Next: Hyper-V 02: Installation & Removal â†’](../02-installation-and-removal/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Lab 01: Deploying Your Linux Lab](../../linux/01-deployment-and-ssh/README.md)).*
