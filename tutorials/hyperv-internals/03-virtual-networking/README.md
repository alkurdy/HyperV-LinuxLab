# Hyper-V Tutorial 03: Virtual Networking & Guest IP Routing

> **[Tutorials Hub](../../README.md)** • **[Hyper-V Internals Track](../README.md)** • [← Previous: Hyper-V 02: Installation & Removal](../02-installation-and-removal/README.md) • [Index](../../README.md) • [Next: Hyper-V 04: Storage & Differencing Disks →](../04-storage-and-differencing-disks/README.md)

---
Now that we've got Hyper-V installed, verified, and operational, let's look at virtual networking. So you want your Linux VMs to talk to each other, fetch apt packages from the internet, and let you SSH into them from Windows Terminal—how does Hyper-V route those packets?

Virtual networking is where most virtualization labs stumble. By understanding the virtual switch architecture and how Windows handles Network Address Translation (NAT), you can troubleshoot any connection issue with confidence.

Here are the **7 critical areas** you will master:

---

## 1. Virtual Switch Types: Default vs Internal vs External vs Private

Hyper-V provides four distinct types of virtual switches (`VMSwitch`):
1. **The Default Switch (Windows 10/11 native)**:
   - Built-in, zero-configuration virtual switch provided by the Windows host.
   - Automatically manages NAT, internal IP addressing via host DHCP, and internet sharing through the host's active adapter (Wi-Fi or Ethernet).
2. **Internal Virtual Switch**:
   - Allows network traffic strictly between VMs and the host operating system. Does not bind to physical network cards.
   - You configure custom IP subnets and manual NAT routing via `New-NetNat`.
3. **External Virtual Switch**:
   - Binds directly to a physical network adapter (e.g., your Intel Ethernet NIC).
   - VMs appear as physical devices on your real home/office LAN, acquiring IP addresses directly from your physical router's DHCP server.
4. **Private Virtual Switch**:
   - Pure isolated sandbox. VMs can only talk to other VMs on that exact switch. The host cannot communicate with the VMs, and VMs cannot reach the internet.

### Native PowerShell Check
```powershell
Hyper-V\Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription
```

---

## 2. The Windows NAT Engine (WinNAT) & Custom Internal Switches

When running multi-node clusters (like Kubernetes or multi-distro testbeds), you don't want your local home Wi-Fi router handing out random lease IPs or blocking inter-node traffic. 
Windows includes **WinNAT** (Windows Network Address Translation), a kernel-mode NAT router that forwards traffic from internal VM subnets through your host's internet connection:

```powershell
# 1. Create the Internal Virtual Switch
$switch = Hyper-V\New-VMSwitch -Name "LabSwitch" -SwitchType Internal

# 2. Assign the Host Gateway IP to the new virtual adapter
$adapter = Get-NetAdapter -Name "vEthernet (LabSwitch)"
New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress "192.168.100.1" -PrefixLength 24

# 3. Create the WinNAT Router
New-NetNat -Name "LabNAT" -InternalIPInterfaceAddressPrefix "192.168.100.0/24"
```

---

## 3. Synthetic vs Emulated Network Adapters (VMBus vs Legacy)

When creating virtual network cards, Hyper-V offers two fundamentally different hardware architectures:

| Feature | Synthetic Network Adapter (Default) | Legacy Network Adapter (Generation 1 only) |
| :--- | :--- | :--- |
| **Driver Model** | VMBus synthetic device (`hv_netvsc`) | Emulated Intel 21140 10/100 Mbps NIC |
| **Privilege Rings** | Direct Ring 0 memory shared bus | Software CPU trap emulation |
| **Throughput** | 10 Gbps - 40 Gbps+ (Bus speed) | Capped at ~100 Mbps |
| **Generation** | Gen1 and Gen2 | Gen1 only (PXE boot on Gen1) |

Modern Linux kernels include upstream enlightened drivers for synthetic VMBus adapters (`hv_netvsc`). Never use legacy emulated adapters for Linux guests.

---

## 4. Key-Value Pair (KVP) In-Memory Telemetry Exchange

How does the Windows host discover the dynamic IP address assigned to a Linux guest without logging into it via SSH?

### The Architecture: Hyper-V Data Exchange (KVP)
Hyper-V includes a hardware memory ring-buffer mechanism called **Key-Value Pair (KVP) Data Exchange**:
1. The guest Linux kernel driver (`hv_utils`) reads network interfaces (`eth0`) inside the VM.
2. The guest KVP daemon writes the IP configuration into a designated shared memory window exposed by the hypervisor.
3. The hypervisor copies these pairs into the root partition's WMI database (`root\virtualization\v2`).
4. PowerShell reads the guest IP address straight from host RAM:

```powershell
$vm = Hyper-V\Get-VM -Name "my-node"
$adapter = Hyper-V\Get-VMNetworkAdapter -VM $vm
$adapter.IPAddresses
```

---

## 5. WinNAT Limitations & Single-Subnet Constraints

WinNAT in client Windows (Windows 10/11) has one architectural constraint:
- **Client Windows supports only ONE active WinNAT instance simultaneously.**
- If Docker Desktop or WSL2 has created a NetNat instance, creating a second `New-NetNat` will throw an error: `The parameter is incorrect`.

```powershell
# Inspect active NAT instances across the host
Get-NetNat
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

Run these commands in an elevated PowerShell session to inspect virtual network switches and observe how Windows configures internal routing.

### 1. Inspect Virtual Switches & Synthetic Host Adapters
- **Action**: Query the existing virtual switch configurations and their corresponding host adapters:
  ```powershell
  $switches = Hyper-V\Get-VMSwitch
  $adapters = Get-NetAdapter -Name "vEthernet*" -ErrorAction SilentlyContinue

  [PSCustomObject]@{
      TotalSwitches    = $switches.Count
      SwitchNames      = ($switches.Name -join ", ")
      HostAdapters     = ($adapters.Name -join ", ")
  }
  ```
- **System Reaction**:
  When Hyper-V initializes an internal or external switch, the Windows kernel network stack creates a synthetic miniport adapter named `vEthernet (<SwitchName>)`. The miniport driver (`vmswitch.sys`) binds to the NDIS protocol stack.
- **Verification**:
  Verify the existence of the `Default Switch` or custom lab switch.

### 2. Inspect the WinNAT Translation Engine
- **Action**: Query active Windows Network Address Translation (NAT) bindings:
  ```powershell
  Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix, Active
  ```
- **System Reaction**:
  The WinNAT driver intercepts IP packets arriving on internal virtual switch interfaces whose destination is outside the local subnet. It replaces the guest VM's private source IP with the host's IP address, dynamically maps a source TCP/UDP port, and updates its in-memory translation table.
- **Verification**:
  Confirm whether an active NAT prefix is registered on the host.

### 3. KVP Guest IP Discovery Drill
- **Action**: Query a running VM's network adapter for dynamic IP addresses without SSH:
  ```powershell
  $runningVM = Hyper-V\Get-VM | Where-Object { $_.State -eq 'Running' } | Select-Object -First 1
  if ($runningVM) {
      $ipData = (Hyper-V\Get-VMNetworkAdapter -VM $runningVM).IPAddresses
      [PSCustomObject]@{
          VMName      = $runningVM.Name
          IPv4Address = ($ipData | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
      }
  } else {
      Write-Host "No active VM currently running; will verify during VM provisioning." -ForegroundColor Yellow
  }
  ```
- **System Reaction**:
  Hyper-V queries the `Msvm_KvpExchangeDataItem` WMI instances populated by the guest kernel's `hv_utils` module, retrieving the IP without invoking guest user-space credentials.

---

## Part B: Platform Solo Drill (Unguided Mission)

Now author an unguided virtual network provisioning and cleanup utility without copy-paste code.

### The Mission: Isolated Tenant NAT Switch Engine
Cloud platforms require the ability to dynamically stand up isolated internal virtual subnets for testing and cleanly tear them down.

1. **Customization**:
   - Choose a unique Switch Name (e.g. `TenantSwitch-Dev` or `IsolatedLabSwitch`).
   - Choose a custom private CIDR prefix (e.g. `10.220.0.0/24` or `172.28.10.0/24`) and assign the `.1` address as the gateway.

2. **Acceptance Criteria**:
   - Stand up:
     1. Creates an Internal Virtual Switch using module qualification (`Hyper-V\New-VMSwitch`).
     2. Identifies the generated `vEthernet (<SwitchName>)` host adapter.
     3. Assigns the `.1` gateway IP address with proper prefix length.
     4. Creates a `NetNat` object mapping the chosen subnet CIDR.
   - Clean Teardown:
     1. Removes the `NetNat` object.
     2. Removes the `VMSwitch` cleanly.
     3. Verifies zero orphaned virtual adapters remain.

3. **Self-Verification**:
   Execute this test suite against your network deployment to validate your implementation:
   ```powershell
   # Replace with your chosen switch name and CIDR
   $testSwitch = "TenantSwitch-Dev"
   $testPrefix = "10.220.0.0/24"

   # Test 1: VMSwitch exists and is Internal
   $sw = Hyper-V\Get-VMSwitch -Name $testSwitch -ErrorAction SilentlyContinue
   $swPass = ($sw -and $sw.SwitchType -eq 'Internal')

   # Test 2: NetNat active for prefix
   $nat = Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -eq $testPrefix }
   $natPass = ($nat -ne $null)

   if ($swPass -and $natPass) {
       Write-Host "[PASS] Tenant NAT network successfully provisioned and verified!" -ForegroundColor Green
   } else {
       Write-Host "[FAIL] Virtual switch or NetNat prefix failed verification!" -ForegroundColor Red
   }
   ```

---

In **[Tutorial 04: Virtual Storage & Differencing Disks](../04-storage-and-differencing-disks/README.md)**, we will build our high-performance storage layer: create read-only golden masters, spawn 4MB child delta disks, and execute sub-second atomic resets!

---

### Navigation
| [← Previous: Hyper-V 02: Installation & Removal](../02-installation-and-removal/README.md) | [Tutorials Index](../../README.md) | [Next: Hyper-V 04: Storage & Differencing Disks →](../04-storage-and-differencing-disks/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Linux Level 06: Networking & Connectivity](../../01-sysadmin-foundations/level-06-networking-and-connectivity/README.md)).*
