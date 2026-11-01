# Hyper-V Tutorial 06: VM Lifecycle, Telemetry & Automation

> **[HyperV-LinuxLab Tutorials Hub](README.md)** â€¢ **Track 2: Hyper-V Systems Engineering** â€¢ [â† Previous: Hyper-V 05: VM Architecture & Cloud-Init](hyperv-05-vm-architecture-and-cloud-init.md) â€¢ [ðŸ“‘ Index](README.md) â€¢ [Next: Lab Track 01: Deploying Your Linux Lab â†’](lab-01-deployment-and-ssh.md)

---
Now that our VM is running and provisioned, let's look at day-2 operations. So you want to manage multiple running VMs, recall their dynamic IP addresses and passphrases, monitor resource consumption, and automate cluster startups without clicking through the Hyper-V GUI—how do we automate the complete lifecycle from the command line?

In this final tutorial, we explore native Hyper-V power states, the dual-write metadata architecture, system startup auto-boot engines, and declarative cluster orchestration.

Here are the **7 critical areas** you will master:

---

## 1. Native Hyper-V Power Lifecycle: Running vs Saved vs Off

So you want to power off or suspend a VM, but what is Hyper-V doing to the guest OS?

### The Architecture
Hyper-V supports four distinct power operations:
1. **Graceful Shutdown (`Stop-VM`)**:
   - Sends an ACPI shutdown signal over the VMBus to the guest's Hyper-V Integration Services daemon.
   - The Linux guest triggers `systemctl poweroff`, flushing disk caches and stopping services cleanly.
2. **Immediate Power Off (`Stop-VM -TurnOff`)**:
   - Simulates pulling the physical power cord. Drops the virtual processor execution immediately without flushing memory. Used for instant resets.
3. **Saved State (`Save-VM`)**:
   - Freezes guest vCPUs, dumps guest RAM into a `.bin`/`.vsv` file in the VM directory, and frees host physical memory. Resuming takes under a second.
4. **Pause (`Suspend-VM`)**:
   - Freezes guest vCPU instruction scheduling in host memory without writing RAM to disk.

### Native PowerShell Commands
```powershell
# Graceful shutdown (waits for guest OS)
Hyper-V\Stop-VM -Name "linux-node-01"

# Force immediate power-off (essential for instant differencing resets)
Hyper-V\Stop-VM -Name "linux-node-01" -TurnOff -Force

# Power on
Hyper-V\Start-VM -Name "linux-node-01"
```

---

## 2. Dynamic IP Discovery & The SSH Readiness Poll

Now that the VM is powered on, how do you know when it is actually ready to accept SSH connections?

### The Architecture
Powering on a VM is not instantaneous:
1. The UEFI firmware boots and loads the kernel (`~2 seconds`).
2. The network interface acquires an IP via DHCP (`~3 seconds`).
3. Cloud-Init runs its execution stages, injects SSH keys, and generates host keys (`~5 seconds`).
4. The OpenSSH server daemon (`sshd`) begins listening on port 22.

If you attempt to SSH immediately when `Start-VM` returns, the connection will be refused because `sshd` hasn't opened port 22 yet.

### Native PowerShell: Polling for Port 22
Here is how you write a non-blocking TCP socket poll to detect true SSH readiness:
```powershell
$ip = "192.168.1.150"
$timeoutSeconds = 30
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

while ($stopwatch.Elapsed.TotalSeconds -lt $timeoutSeconds) {
    try {
        $tcp = [System.Net.Sockets.TcpClient]::new()
        $ar = $tcp.BeginConnect($ip, 22, $null, $null)
        if ($ar.AsyncWaitHandle.WaitOne(1000, $false) -and $tcp.Connected) {
            $tcp.EndConnect($ar)
            $tcp.Close()
            Write-Host "[OK] SSH service is ready on ${ip}:22! Connection available." -ForegroundColor Green
            break
        }
        $tcp.Close()
    } catch {
        # Still booting...
    }
    Start-Sleep -Milliseconds 1500
}
```

### Under the Hood in `HyperV-LinuxLab`
[`Start-LabVM.ps1`](../Public/Start-LabVM.ps1) and [`New-LabVM.ps1`](../Public/New-LabVM.ps1) run this TCP probe when `-Wait` or `-Start` is specified, ensuring the ASCII connection banner only prints when the VM is genuinely reachable.

---

## 3. Remembering Credentials & IPs: The Dual-Write Metadata Architecture

Now, how do you recall passphrases, assigned IPs, and usernames after creating 5 different VMs? Where does that information live?

### The Architecture: Dual-Write Storage
Storing lab credentials in the Windows Registry creates orphaned keys and permission hurdles.
Instead, we use a **Dual-Write Architecture**:
1. **Primary Store (`metadata.json`)**:
   - Saved directly into the VM's directory (`<LabStoragePath>\LabVMs\<name>\metadata.json`).
   - Tracks `Name`, `Distro`, `Username`, `Password`, `IPv4`, `SSH`, and `Profile`.
   - Lives with the VM assets and is automatically cleaned up when the VM directory is deleted.
2. **Secondary Store (Hyper-V VM Notes)**:
   - Written to the native Hyper-V VM `Notes` property (`Set-VM -Notes`).
   - Appears directly in the Windows Hyper-V Manager GUI lower pane when you click the VM!

### Native PowerShell Implementation
```powershell
$vmName = "linux-node-01"
$notes = @"
Distro: Ubuntu2404
User: labadmin
Password: Polar-Jaguar-42
IPv4: 192.168.1.150
SSH: ssh labadmin@192.168.1.150
"@

# Sync to native Hyper-V GUI notes
Hyper-V\Set-VM -Name $vmName -Notes $notes
```

### Under the Hood in `HyperV-LinuxLab`
[`Private/Set-LabVMMetadata.ps1`](../Private/Set-LabVMMetadata.ps1) and [`Private/Get-LabVMMetadata.ps1`](../Private/Get-LabVMMetadata.ps1) handle dual-writing and retrieval, powering [`Get-LabVM`](../Public/Get-LabVM.ps1).

---

## 4. Host Startup Auto-Boot: Native Hyper-V vs Scheduled Tasks

Now that your lab works, what happens when you restart your workstation? Do you have to manually power on all nodes?

### The Architecture
Hyper-V provides two ways to automatically boot virtual machines on host startup:
1. **Native Hyper-V Automatic Start Action (`AutomaticStartAction = Start`)**:
   - The Hyper-V host service (`vmms`) powers on the VM as soon as the service starts.
   - Supports a **startup delay** (`AutomaticStartDelay`) so multiple nodes don't slam your host CPU and storage simultaneously during Windows boot.
2. **Windows Scheduled Tasks**:
   - Registers a task triggered `AtStartup` under the `NT AUTHORITY\SYSTEM` account.
   - Useful in enterprise desktop environments where Windows fast-startup or user logon policies interfere with native Hyper-V auto-start.

### Native PowerShell Configuration
```powershell
# Configure native Hyper-V auto-start with a 20-second delay
Hyper-V\Set-VM -Name "linux-node-01" `
    -AutomaticStartAction Start `
    -AutomaticStartDelay 20 `
    -AutomaticStopAction ShutDown
```

### Under the Hood in `HyperV-LinuxLab`
[`Enable-LabAutoStart.ps1`](../Public/Enable-LabAutoStart.ps1) and [`Disable-LabAutoStart.ps1`](../Public/Disable-LabAutoStart.ps1) let you choose `-Mode HyperV`, `-Mode ScheduledTask`, or `-Mode Both`.

---

## 5. Declarative Multi-Node Cluster Orchestration

Now, what if you want to stand up an entire 3-node Kubernetes cluster or multi-distro testbed from a single configuration file?

### The Architecture: Declarative JSON Topology
Rather than running manual provisioning commands for every node, declare your cluster topology in a JSON specification:
```json
{
  "ClusterName": "k8s-lab",
  "Description": "3-Node Kubernetes Cluster",
  "SwitchName": "Default Switch",
  "Nodes": [
    { "Name": "cp-01",     "Role": "ControlPlane", "MemoryGB": 4, "CPU": 2, "Profile": "Kubernetes" },
    { "Name": "worker-01", "Role": "Worker",       "MemoryGB": 2, "CPU": 2, "Profile": "Kubernetes" },
    { "Name": "worker-02", "Role": "Worker",       "MemoryGB": 2, "CPU": 2, "Profile": "Kubernetes" }
  ]
}
```

### Native PowerShell Orchestration Flow
1. **Pre-flight Capacity Review**: Sum all node RAM and CPU requirements and verify host capacity before touching Hyper-V.
2. **Node Name Prefixing**: Prepend `ClusterName` (e.g. `k8s-lab-cp-01`) to isolate clusters from other projects.
3. **Staged Provisioning**: Provision nodes, applying toolchain packages and Cloud-Init configurations sequentially.

### Under the Hood in `HyperV-LinuxLab`
[`Test-LabCluster.ps1`](../Public/Test-LabCluster.ps1) and [`New-LabCluster.ps1`](../Public/New-LabCluster.ps1) parse this JSON, automatically enforce host resource boundaries, and spin up multi-node environments in seconds.

---

## 6. Teardown & Clean Garbage Collection

Now that you've finished testing, how do you cleanly destroy the lab without leaving orphaned files on your SSD?

### The Architecture: Safe Cleanup
Deleting a VM from Hyper-V Manager only removes the VM configuration file from the hypervisor database; **it leaves the virtual hard disks on disk!**
To avoid ghost files consuming gigabytes of storage:
1. Turn off the VM.
2. Remove the VM definition from Hyper-V.
3. Recursively delete the VM's storage folder (`<LabStoragePath>\LabVMs\<name>`).
4. **Leave parent base images intact** so future VM deployments don't need to re-download 2GB cloud images!

### Native PowerShell Teardown
```powershell
$vmName = "linux-node-01"
$vmDir  = "C:\HyperV-LinuxLab\LabVMs\$vmName"

# 1. Stop and remove VM definition
Hyper-V\Stop-VM -Name $vmName -TurnOff -Force
Hyper-V\Remove-VM -Name $vmName -Force

# 2. Delete VM differencing storage folder
if (Test-Path $vmDir) {
    Remove-Item -Path $vmDir -Recurse -Force
}
Write-Host "[OK] VM '$vmName' and all child storage cleanly purged."
```

---

## 7. Troubleshooting Stuck VMs & Worker Process Crashes

Now, what happens when a VM gets stuck in `Stopping` or `Saved` state and Hyper-V Manager freezes?

### The Architecture: `vmwp.exe`
Every running Hyper-V virtual machine is executed by an isolated host worker process named **`vmwp.exe`** (Virtual Machine Worker Process).
If guest kernel panics or storage deadlocks cause `Stop-VM` to hang, you can kill the specific worker process directly:

### Native PowerShell Emergency Worker Process Kill
```powershell
$vmName = "stuck-vm-01"

# 1. Get the VM's unique GUID
$vmGuid = (Hyper-V\Get-VM -Name $vmName).Id.Guid

# 2. Find and kill the corresponding vmwp.exe worker process
$vmwp = Get-CimInstance Win32_Process -Filter "Name = 'vmwp.exe'" | Where-Object {
    $_.CommandLine -match $vmGuid
}

if ($vmwp) {
    Stop-Process -Id $vmwp.ProcessId -Force
    Write-Warning "Terminated stuck worker process (PID: $($vmwp.ProcessId)) for VM '$vmName'."
}
```

---

## Conclusion & Next Steps

You now understand the complete low-level mechanics of Windows Hyper-V virtualization:
- Hardware CPU virtualization registers (VT-x/AMD-V) and Ring -1 hypervisor presence.
- DISM feature installation, pending reboot tracking, and clean uninstallation.
- Virtual switches, WinNAT routing, and VMBus synthetic adapters.
- Golden base image protection and sub-5-second differencing resets.
- Generation 2 UEFI firmware, Linux Secure Boot, and Cloud-Init NoCloud ISO injection.
- Dynamic KVP telemetry, dual-write metadata persistence, and clean teardown.

Armed with this knowledge, you can use the high-level cmdlets in **`HyperV-LinuxLab`** with total confidence, knowing exactly what each command is orchestrating beneath the surface!

---

### ðŸ§­ Navigation
| [â† Previous: Hyper-V 05: VM Architecture & Cloud-Init](hyperv-05-vm-architecture-and-cloud-init.md) | [ðŸ“‘ All Tutorials](README.md) | [Next: Lab Track 01: Deploying Your Linux Lab â†’](lab-01-deployment-and-ssh.md) |
| :--- | :---: | ---: |

*(Hands-on lab drill: See [Lab Tutorial 05: Multi-Distro Clusters](lab-05-multi-distro-clusters.md)).*
