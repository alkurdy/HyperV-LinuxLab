# Hyper-V Tutorial 01: Prerequisites, Hardware Virtualization & Host Readiness

> **[Tutorials Hub](../../README.md)** • **[Hyper-V Internals Track](../README.md)** • [Index](../../README.md) • [Next: Hyper-V 02: Installation & Removal →](../02-installation-and-removal/README.md)

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

```
┌─────────────────────────────────────────────────────────────┐
│ Physical Hardware (CPU, RAM, Motherboard, IOMMU)            │
├─────────────────────────────────────────────────────────────┤
│ Ring -1: Hyper-V Microkernel (hvix64.sys)                   │
├──────────────────────────────┬──────────────────────────────┤
│ Root Partition (Parent VM)   │ Child Partitions (Guest VMs) │
│ - Windows Host OS            │ - Ubuntu / Debian Nodes      │
│ - Hardware Drivers           │ - Direct VMBus synthetic     │
│ - CPU VT-x MASKED FROM CIM!  │   channels                   │
└──────────────────────────────┴──────────────────────────────┘
```

### The Correct Detection Logic
To determine if your hardware is ready when Hyper-V or WSL2 is active, query `Win32_ComputerSystem.HypervisorPresent`:

```powershell
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$cs  = Get-CimInstance -ClassName Win32_ComputerSystem

$isReady = $cpu.VirtualizationFirmwareEnabled -or $cs.HypervisorPresent
[PSCustomObject]@{
    CPU_VT_Enabled    = $cpu.VirtualizationFirmwareEnabled
    HypervisorPresent = $cs.HypervisorPresent
    SystemCanHostVMs  = $isReady
}
```

---

## 4. Second Level Address Translation (SLAT) & DEP

CPU privilege rings alone aren't enough. Modern hypervisors require memory translation hardware.

### The Architecture
In virtualization, memory addresses undergo two translations:
1. **Guest Virtual Address (GVA)** -> **Guest Physical Address (GPA)** (managed by the guest OS).
2. **Guest Physical Address (GPA)** -> **Host Physical Address (HPA)** (managed by the hypervisor).

Without hardware assistance, the hypervisor must emulate this mapping using expensive software "shadow page tables". 
**SLAT** adds hardware memory management unit (MMU) registers to do this translation in silicon:
- **Intel**: **EPT** (Extended Page Tables).
- **AMD**: **NPT** (Nested Page Tables) / Rapid Virtualization Indexing (RVI).

Additionally, **DEP (Data Execution Prevention)** or NX-bit (No-Execute) prevents buffer overflow attacks in memory pages. Hyper-V enforces hardware DEP.

---

## 5. Host Memory Headroom & Sizing

Unlike containers that share the host kernel, virtual machines allocate real physical RAM pages.

### Sizing Equation for Local Labs
Your Windows host OS needs dedicated RAM to remain responsive while running background applications, indexing, and management services:

$$\text{Usable Lab Memory} = \text{Total Host RAM} - \text{Host Reserved RAM (4 GB)}$$

If your host has:
- **8 GB RAM**: 4 GB host reserve = 4 GB lab pool (enough for 2-3 minimal Linux nodes).
- **16 GB RAM**: 4 GB host reserve = 12 GB lab pool (comfortable 3-node Kubernetes cluster).
- **32 GB+ RAM**: 4 GB host reserve = 28 GB+ lab pool (enterprise multi-distro testbeds).

---

## 6. Coexistence with Other Hypervisors (VirtualBox, VMware, WSL2)

Now, what if you already have VMware Workstation or VirtualBox installed? Will enabling Hyper-V cause a blue screen?

### The Architecture: WHVP (Windows Hypervisor Platform)
Historically (pre-2020), third-party Type-2 hypervisors like VirtualBox and VMware Workstation fought Hyper-V for hardware VT-x control. If Hyper-V claimed Ring -1, launching VirtualBox resulted in an instant host crash (BSOD).

Modern versions solved this through **WHVP** (Windows Hypervisor Platform):
- **WSL2**: Runs natively on the Hyper-V virtualization platform. 100% compatible.
- **VirtualBox (>= 6.1)**: Can run as a client on top of Hyper-V using the `NEM` (Native Execution Manager) engine.
- **VMware Workstation (>= 15.5)**: Implements Microsoft's WHV APIs, allowing VMware and Hyper-V to run concurrently.

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

## Part A: Guided Architectural Drill (Action & Reaction)

Run the following commands in an elevated PowerShell console to audit the physical host and observe how Windows surfaces hypervisor telemetry.

### 1. Windows Edition & Servicing SKU Entitlement
- **Action**: Query the operating system caption and the raw registry product `EditionID`:
  ```powershell
  $os = Get-CimInstance -ClassName Win32_OperatingSystem
  $editionId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
  [PSCustomObject]@{
      Caption   = $os.Caption
      EditionID = $editionId
      Build     = $os.BuildNumber
  }
  ```
- **System Reaction**:
  The Windows NT kernel checks `EditionID` during DISM feature servicing. If `EditionID` is `Core` or `Home`, the CBS servicing subsystem deliberately masks Hyper-V packages, returning error `0x800f080c` on installation attempts.
- **Verification**:
  Confirm your `EditionID` contains `Professional`, `Enterprise`, or `Server`.

### 2. Ring -1 Hypervisor Presence & CPU Register Masking
- **Action**: Query processor hardware registers alongside the hypervisor status flag:
  ```powershell
  $proc = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
  $cs   = Get-CimInstance -ClassName Win32_ComputerSystem

  [PSCustomObject]@{
      CPU_Name                = $proc.Name
      LogicalCores            = $proc.NumberOfLogicalProcessors
      FirmwareVirtEnabled     = $proc.VirtualizationFirmwareEnabled
      HypervisorPresent       = $cs.HypervisorPresent
  }
  ```
- **System Reaction**:
  If `HypervisorPresent` is `$true`, the CPU is running in VMX root mode (Ring -1). In this state, Windows root partition queries to `VirtualizationFirmwareEnabled` may return `$false` because the hypervisor intercepts CPUID instructions and masks bare-metal virtualization flags to isolate the host partition.
- **Verification**:
  Either `FirmwareVirtEnabled` or `HypervisorPresent` MUST be `$true`.

### 3. Module Collision Defense & Command Precedence
- **Action**: Test module qualification resolution across active PowerShell modules:
  ```powershell
  # Check all available implementations of Get-VM on the host
  Get-Command -Name Get-VM -All -ErrorAction SilentlyContinue | Select-Object Name, CommandType, Source, Version
  ```
- **System Reaction**:
  PowerShell searches its command resolution path: Aliases -> Functions -> Cmdlets -> External Scripts. If VMware PowerCLI is installed, bare `Get-VM` binds to VMware. Qualifying the call with `Hyper-V\Get-VM` instructs the execution engine to bypass search order and dispatch directly to Microsoft's binary cmdlet.
- **Verification**:
  Verify `Hyper-V\Get-VM` resolves to `Microsoft.HyperV.PowerShell.Cmdlets`.

---

## Part B: Platform Solo Drill (Unguided Mission)

Now author an unguided host qualification gatekeeper function without copy-paste code.

### The Mission: Enterprise Pre-Flight Hardware Gatekeeper
Operations requires a reusable pre-flight qualification function (`Assert-PlatformHost`) to audit servers before provisioning virtualization clusters.

1. **Customization**:
   - Define custom thresholds: Minimum RAM (e.g. `8` or `16` GB) and minimum free storage on your target volume (e.g. `C:` or `D:`, minimum 20 GB).

2. **Acceptance Criteria**:
   - Function verifies process is elevated as Administrator (throws actionable error if unelevated).
   - Verifies `EditionID` is a supported Hyper-V SKU (`Professional`, `Enterprise`, `Server*`).
   - Verifies virtualization support via the dual-check logic (`VirtualizationFirmwareEnabled` OR `HypervisorPresent`).
   - Verifies available RAM and target drive free space exceed your custom thresholds.
   - Returns a structured `[PSCustomObject]` with properties: `IsEligible` (boolean), `HostEdition`, `TotalRAM_GB`, `FreeDisk_GB`, and `Blockers` (array of string failure reasons if any).

3. **Self-Verification**:
   Execute this test suite against your function to validate your implementation:
   ```powershell
   # Run your function and test the resulting object contract
   $audit = Assert-PlatformHost -MinRAMGB 8 -TargetDrive "C:" -MinFreeDiskGB 20

   # Test 1: Returns correct object contract
   $hasContract = ($audit.PSObject.Properties.Name -contains "IsEligible") -and ($audit.PSObject.Properties.Name -contains "Blockers")
   if ($hasContract -and ($audit.IsEligible -is [bool])) {
       Write-Host "[PASS] Pre-flight gatekeeper returned valid contract!" -ForegroundColor Green
   } else {
       Write-Host "[FAIL] Missing required properties or invalid types!" -ForegroundColor Red
   }
   ```

---

In **[Tutorial 02: Hyper-V Installation, Verification & Clean Removal](../02-installation-and-removal/README.md)**, we will take our qualified bare-metal host and deploy the Hyper-V kernel role, inspect the DISM pending reboot state machine, and validate the 3-point health check!

---

### Navigation
| [Hyper-V Internals Track](../README.md) | [Tutorials Index](../../README.md) | [Next: Hyper-V 02: Installation & Removal →](../02-installation-and-removal/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Linux Level 01: Mental Model & Architecture](../../01-sysadmin-foundations/level-01-mental-model-and-architecture/README.md)).*
