# Hyper-V Tutorial 03: Virtual Networking & Guest IP Routing

> **[HyperV-LinuxLab Tutorials Hub](README.md)** â€¢ **Track 2: Hyper-V Systems Engineering** â€¢ [â† Previous: Hyper-V 02: Installation & Removal](hyperv-02-installation-and-removal.md) â€¢ [ðŸ“‘ Index](README.md) â€¢ [Next: Hyper-V 04: Storage & Differencing Disks â†’](hyperv-04-storage-and-differencing-disks.md)

---
Now that we've got Hyper-V installed, verified, and operational, let's look at virtual networking. So you want your Linux VMs to talk to each other, fetch apt packages from the internet, and let you SSH into them from Windows Terminal—how does Hyper-V route those packets?

Virtual networking is where most virtualization labs stumble. By understanding the virtual switch architecture and how Windows handles Network Address Translation (NAT), you can troubleshoot any connection issue with confidence.

Here are the **7 critical areas** you will master:

---

## 1. Virtual Switch Types: Default vs Internal vs External vs Private

So you want to create a virtual network, but Hyper-V asks you which switch type to pick. What is the difference?

### The Architecture
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
Query all virtual switches configured on your host:
```powershell
Hyper-V\Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription
```

---

## 2. The Windows NAT Engine (WinNAT) & Custom Internal Switches

Now that we understand switch types, why do we often prefer an Internal NAT Switch for lab clusters?

### The Architecture: WinNAT
When running multi-node clusters (like Kubernetes or multi-distro testbeds), you don't want your local home Wi-Fi router handing out random lease IPs or blocking inter-node traffic. 
Windows includes **WinNAT** (Windows Network Address Translation), a kernel-mode NAT router that forwards traffic from internal VM subnets through your host's internet connection.

### Native PowerShell: Building an Internal NAT Network

> [!NOTE]
> **Why `Hyper-V\New-VMSwitch` instead of just `New-VMSwitch`? (Module Qualification)**  
> In PowerShell, prefixing a command with its module name (`<ModuleName>\<CmdletName>`) is known as **Module Qualification**.  
> This protects against **command name collisions**. If you have third-party virtualization modules installed (such as **VMware PowerCLI**), they export identically named cmdlets like `Get-VM`, `New-VM`, and `New-VMSwitch`. If both modules are loaded, typing a bare `Get-VM` runs VMware's cmdlet and fails with: `You are not currently connected to any servers`. Explicitly writing `Hyper-V\New-VMSwitch` and `Hyper-V\Get-VM` instructs the PowerShell parser to route execution directly to Microsoft's native Hyper-V engine, ensuring your scripts run deterministically regardless of what other virtualization tools exist on the host.

Here is how you manually build a dedicated `192.168.100.0/24` lab network from scratch:
```powershell
# 1. Create the Internal Virtual Switch
$switch = Hyper-V\New-VMSwitch -Name "LabSwitch" -SwitchType Internal

# 2. Assign the Host Gateway IP to the new virtual adapter
$adapter = Get-NetAdapter -Name "vEthernet (LabSwitch)"
New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress "192.168.100.1" -PrefixLength 24

# 3. Create the WinNAT Router
New-NetNat -Name "LabNAT" -InternalIPInterfaceAddressPrefix "192.168.100.0/24"
```

### Under the Hood in `HyperV-LinuxLab`
[`Private/Get-LabDefaultSwitch.ps1`](../Private/Get-LabDefaultSwitch.ps1) automatically resolves your active virtual switch. If you don't specify a custom switch name, it safely binds to the native `Default Switch`.

---

## 3. Synthetic vs Emulated Network Adapters

Now that our virtual switch is ready, how does the VM attach to it?

### The Architecture: VMBus vs Emulated NIC
Hyper-V provides two virtual network adapter types:
1. **Synthetic Network Adapter (`NetworkAdapter`)**:
   - Uses the high-speed **VMBus** virtualization channel.
   - Requires Hyper-V Integration Services drivers in the guest OS (built directly into the upstream Linux kernel via `hv_netvsc`).
   - Achieves near-wire-speed 10Gbps+ throughput with minimal CPU overhead.
2. **Legacy / Emulated Adapter**:
   - Emulates a physical DEC 21140 10/100 Mbps NIC. Very slow, high CPU overhead, only used for Gen1 PXE boot.

### Native PowerShell Attachment
Attaching a synthetic adapter to a VM:
```powershell
# Connect a VM to the virtual switch
Hyper-V\Connect-VMNetworkAdapter -VMName "k8s-node-01" -SwitchName "Default Switch"

# Inspect adapter configuration
Hyper-V\Get-VMNetworkAdapter -VMName "k8s-node-01" | Select-Object VMName, SwitchName, MacAddress, Status
```

---

## 4. How Cloud-Init Discovers and Configures the Network

Now that the VM is connected to the switch, how does the Linux guest know how to ask for an IP address?

### The Architecture: Netplan & Systemd-Networkd
When a modern Linux guest boots (Ubuntu, Debian, or AlmaLinux):
1. The kernel loads `hv_netvsc`, creating network interface `eth0`.
2. Cloud-Init's local stage reads default networking directives or lets the distribution's network daemon take over:
   - Ubuntu: **Netplan** (`/etc/netplan/50-cloud-init.yaml`).
   - Debian: **systemd-networkd** or `/etc/network/interfaces`.
   - AlmaLinux: **NetworkManager** (`nmcli` / keyfiles).
3. The guest sends a DHCPDISCOVER packet across the VMBus to the virtual switch.
4. The Hyper-V host DHCP service replies with an assigned IPv4 address, default gateway, and DNS servers.

---

## 5. Discovering Guest IPs via KVP (Key-Value Pair) Data Exchange

Now that the guest has an IP address, how does the Windows host discover what it is without logging in?

### The Architecture: Hyper-V Data Exchange Service
In traditional virtualization, you have to run slow ARP scans or inspect DHCP leases to find a VM's IP address.
Hyper-V solves this with **KVP (Key-Value Pair) Data Exchange**:
- The guest Linux kernel runs `hv_kvp_daemon` (or the integration services driver).
- The guest writes its assigned network IP addresses into kernel KVP registers.
- The Hyper-V host reads these registers directly over VMBus memory exchange without generating any network traffic!

### Native PowerShell Discovery
```powershell
# Query guest IP directly through Integration Services
$adapter = Hyper-V\Get-VMNetworkAdapter -VMName "k8s-node-01"
$ipv4 = $adapter.IPAddresses | Where-Object {
    $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' -and $_ -notlike '169.254*' -and $_ -ne '127.0.0.1'
}
Write-Host "Discovered Guest IPv4: $ipv4"
```

### Under the Hood in `HyperV-LinuxLab`
[`Private/Get-LabVMIPAddress.ps1`](../Private/Get-LabVMIPAddress.ps1) encapsulates this logic with stopwatch polling, waiting up to 45 seconds for cloud-init to finish bringing up the network before presenting your ready-to-use SSH connection string.

---

## 6. Cross-VM Cluster Communication (Multi-Node Labs)

Now that individual VMs can reach the internet, how do multi-node clusters (like Kubernetes) communicate among themselves?

### The Architecture: Flat L2 Virtual Switches
When multiple VMs attach to the same Hyper-V virtual switch (e.g. `k8s-cp-01`, `k8s-worker-01`, `k8s-worker-02`):
- The virtual switch behaves as an unmanaged Layer-2 Ethernet switch.
- Nodes broadcast ARP requests directly to each other without touching your host's physical network adapter.
- Packet latency between nodes is sub-millisecond (in-memory memory copying over VMBus).

### Native PowerShell Verification
```powershell
# Verify all nodes in a cluster are on the same virtual switch
Hyper-V\Get-VM -Name "k8s-*" | Hyper-V\Get-VMNetworkAdapter | Format-Table VMName, SwitchName, IPAddresses
```

---

## 7. Troubleshooting Virtual Network Drops & WinNAT Collisions

Now, what happens when a VM gets stuck with an APIPA (`169.254.x.x`) address, or can't reach the internet?

### Common Issues & Diagnostic Commands

1. **WinNAT Subnet Conflict**:
   - WinNAT only supports **one** NAT prefix per host. If Docker Desktop, WSL2, or a manual `New-NetNat` already created a NAT prefix, new NAT switches will fail.
   - *Fix*: Check active NAT configurations:
     ```powershell
     Get-NetNat
     ```
2. **Missing Host Virtual Adapter**:
   - If the `vEthernet` adapter on the host is disabled in Network Connections, VMs cannot route through the host gateway.
   - *Fix*: Re-enable the interface:
     ```powershell
     Get-NetAdapter -Name "vEthernet*" | Enable-NetAdapter
     ```
3. **Host Firewall Blocking ICMP/SSH**:
   - Windows Defender Firewall might block incoming SSH or ping packets from guest subnets.
   - *Fix*: Allow port 22 and ICMP on host virtual network adapters:
     ```powershell
     Get-NetFirewallRule -DisplayName "*SSH*"
     ```

---

Now that our virtual network and IP discovery are solid, let's explore **[Tutorial 04: Virtual Storage & Differencing Disks](hyperv-04-storage-and-differencing-disks.md)** to see how we achieve sub-5-second VM resets!

---

### ðŸ§­ Navigation
| [â† Previous: Hyper-V 02: Installation & Removal](hyperv-02-installation-and-removal.md) | [ðŸ“‘ All Tutorials](README.md) | [Next: Hyper-V 04: Storage & Differencing Disks â†’](hyperv-04-storage-and-differencing-disks.md) |
| :--- | :---: | ---: |

*(Hands-on lab drill: See [Lab Tutorial 03: Linux Networking & Diagnostics](lab-03-processes-systemd-and-networking.md)).*
