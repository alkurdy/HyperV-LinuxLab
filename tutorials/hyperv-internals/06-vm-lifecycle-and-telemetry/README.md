# Hyper-V Tutorial 06: VM Lifecycle, Telemetry & Automation

> **[Tutorials Hub](../../README.md)** • **[Hyper-V Internals Track](../README.md)** • [← Previous: Hyper-V 05: VM Architecture & Cloud-Init](../05-vm-architecture-and-cloud-init/README.md) • [Index](../../README.md) • [Linux Track: Sysadmin Foundations →](../../01-sysadmin-foundations/README.md)

---
Now that our VM is running and provisioned, let's look at day-2 operations. So you want to manage multiple running VMs, recall their dynamic IP addresses and passphrases, monitor resource consumption, and automate cluster startups without clicking through the Hyper-V GUI—how do we automate the complete lifecycle from the command line?

In this final tutorial, we explore native Hyper-V power states, the dual-write metadata architecture, system startup auto-boot engines, and declarative cluster orchestration.

Here are the **7 critical areas** you will master:

---

## 1. Native Hyper-V Power Lifecycle: Running vs Saved vs Off

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

Powering on a VM is not instantaneous:
1. The UEFI firmware boots and loads the kernel (`~2 seconds`).
2. The network interface acquires an IP via DHCP (`~3 seconds`).
3. Cloud-Init runs its execution stages, injects SSH keys, and generates host keys (`~5 seconds`).
4. The OpenSSH server daemon (`sshd`) begins listening on port 22.

If you attempt to SSH immediately when `Start-VM` returns, the connection will be refused because `sshd` hasn't opened port 22 yet.

### Native PowerShell: Polling for Port 22
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
            Write-Host "[OK] SSH port 22 is open on $ip!"
            break
        }
    } catch {
        # Port not listening yet; retry
    }
    Start-Sleep -Milliseconds 500
}
```

---

## 3. Dual-Write Metadata Architecture (VM Notes & JSON)

How do you persist dynamically generated credentials, assigned IP addresses, and distro information without requiring a centralized database?

### The Architecture: Dual-Write
1. **Layer 1: Local JSON Configuration**: Written to `<LabStoragePath>\metadata\<VMName>.json` for fast local PowerShell pipeline queries.
2. **Layer 2: Hyper-V VM Notes**: Injected directly into the hypervisor's virtual machine object metadata (`Hyper-V\Set-VM -Notes`):
   - Stored in the VM's `.vmcx` configuration file.
   - Visible in Hyper-V Manager GUI under the "Notes" tab.
   - Survives directory renames, folder moves, and machine migrations!

```powershell
$metadata = @{
    Distro      = "Ubuntu2404"
    IPv4        = "192.168.1.150"
    Username    = "labadmin"
    CreatedUtc  = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Compress

Hyper-V\Set-VM -Name "linux-node-01" -Notes $metadata
```

---

## 4. Host Startup Auto-Boot Engines

When your Windows workstation or server reboots after Windows Updates, how do your lab VMs resume automatically?

Hyper-V provides **Automatic Start Actions**:
```powershell
# Set VM to restart automatically when host boots, with a 15-second delay to let host networking initialize
Hyper-V\Set-VM -Name "linux-node-01" `
    -AutomaticStartAction StartIfRunning `
    -AutomaticStartDelay 15
```

---

## 5. Declarative Cluster Topology Orchestration

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

---

## 6. Teardown & Clean Garbage Collection

Deleting a VM from Hyper-V Manager only removes the VM configuration file from the hypervisor database; **it leaves the virtual hard disks on disk!**
To avoid ghost files consuming gigabytes of storage:
1. Turn off the VM.
2. Remove the VM definition from Hyper-V.
3. Recursively delete the VM's storage folder (`<LabStoragePath>\LabVMs\<name>`).
4. **Leave parent base images intact** so future VM deployments don't need to re-download 2GB cloud images!

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

## 7. Troubleshooting Stuck VMs & Worker Process (`vmwp.exe`)

Every running Hyper-V virtual machine is executed by an isolated host worker process named **`vmwp.exe`** (Virtual Machine Worker Process).
If guest kernel panics or storage deadlocks cause `Stop-VM` to hang, you can kill the specific worker process directly:

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

## Part A: Guided Architectural Drill (Action & Reaction)

Run these commands in an elevated PowerShell session to inspect worker processes, query in-memory metadata, and verify non-blocking readiness detection.

### 1. Map VM Worker Processes (`vmwp.exe`) to Hyper-V GUIDs
- **Action**: Query running `vmwp.exe` instances and cross-reference them with active Hyper-V VMs:
  ```powershell
  $runningVMs = Hyper-V\Get-VM | Where-Object { $_.State -eq 'Running' }
  $workerProcesses = Get-CimInstance Win32_Process -Filter "Name = 'vmwp.exe'"

  foreach ($vm in $runningVMs) {
      $guid = $vm.Id.Guid
      $proc = $workerProcesses | Where-Object { $_.CommandLine -match $guid }
      [PSCustomObject]@{
          VMName    = $vm.Name
          VMGuid    = $guid
          WorkerPID = $proc.ProcessId
          MemoryWS  = [math]::Round($proc.WorkingSetSize / 1MB, 1)
      }
  }
  ```
- **System Reaction**:
  When a VM powers on, `vmms.exe` launches an isolated `vmwp.exe` instance in the host root partition. The worker process allocates the virtual machine's RAM space, initializes virtual hardware threads, and proxies VMBus channels. Terminating `vmwp.exe` immediately tears down the VM container without crashing the host OS.
- **Verification**:
  Each running VM maps to exactly one host `vmwp.exe` PID.

### 2. Dual-Write Metadata Persistence
- **Action**: Inject structured JSON telemetry into the VM's internal metadata Notes field:
  ```powershell
  $targetVM = Hyper-V\Get-VM | Select-Object -First 1
  if ($targetVM) {
      $telemetry = @{
          ManagedBy   = "HyperV-LinuxLab"
          Environment = "Development"
          UpdatedUtc  = (Get-Date).ToUniversalTime().ToString("o")
      } | ConvertTo-Json -Compress

      Hyper-V\Set-VM -Name $targetVM.Name -Notes $telemetry
      (Hyper-V\Get-VM -Name $targetVM.Name).Notes | ConvertFrom-Json
  }
  ```
- **System Reaction**:
  Hyper-V stores this string directly inside the VM's `.vmcx` binary configuration file. It is accessible across Hyper-V Manager, PowerShell, and WMI without external file dependencies.
- **Verification**:
  Confirm the JSON parses back cleanly from `(Get-VM).Notes`.

---

## Part B: Platform Solo Drill (Grand Track 2 Capstone Mission)

Now author an unguided declarative cluster orchestrator without copy-paste code.

### The Mission: Declarative Multi-Node Cluster Orchestrator (`Deploy-PlatformCluster`)
Platform engineering requires an automated declarative deployment function that accepts a cluster JSON configuration, enforces pre-flight host headroom, provisions multiple nodes, polls for network readiness, and generates a consolidated status board.

1. **Customization**:
   - Author a test cluster specification JSON file (e.g. `cluster-spec.json`) defining at least two nodes (e.g. `alpha-node` and `beta-node`) with custom memory, CPU, and roles.

2. **Acceptance Criteria**:
   - **Stage 1 (Pre-flight Gate)**: Calculates total required RAM across all nodes; verifies host has at least that amount plus 4 GB host reserve.
   - **Stage 2 (Prefix Isolation)**: Prefixes node names with the cluster name (e.g. `<ClusterName>-<NodeName>`).
   - **Stage 3 (Provisioning)**: Creates the Gen2 VM containers, attaches differencing disks pointing to your golden base image, configures Linux Secure Boot, and powers them on.
   - **Stage 4 (Telemetry & Readiness)**: Polls for dynamic IPv4 address acquisition and queries SSH port 22 readiness using non-blocking TCP socket polling.
   - **Stage 5 (Status Board)**: Injects metadata into `VM.Notes` and outputs a consolidated `[PSCustomObject]` table showing `NodeName`, `Role`, `IPv4`, `State`, and `SSHConnectionString`.
   - **Stage 6 (Teardown Function)**: Includes a companion `-Destroy` switch that shuts down all cluster nodes, removes VM definitions, and purges child storage while leaving golden master images untouched.

3. **Self-Verification**:
   Execute this test suite against your cluster deployment engine to validate your implementation:
   ```powershell
   # Validate function exists and responds to contract
   $fn = Get-Command Deploy-PlatformCluster -ErrorAction SilentlyContinue
   if ($fn -and ($fn.Parameters.ContainsKey("ClusterConfigPath"))) {
       Write-Host "[PASS] Declarative cluster orchestrator function contract verified!" -ForegroundColor Green
   } else {
       Write-Host "[FAIL] Missing Deploy-PlatformCluster function or ClusterConfigPath parameter!" -ForegroundColor Red
   }
   ```

---

## Track 2 Completion & Full Systems Engineering Mastery

Congratulations! You have completed **Track 2: Hyper-V Systems Engineering**!
You now possess a complete, unflinching mental model of:
- Bare-metal CPU privilege rings and hypervisor presence detection.
- DISM feature trees and reboot state machine inspection.
- Kernel WinNAT routing and synthetic VMBus adapters.
- Golden base image protection and sub-second atomic differencing resets.
- Generation 2 UEFI virtual architecture and unattended Cloud-Init injection.
- Dynamic KVP telemetry, process lifecycle control, and declarative multi-node orchestration.

Now, take your local cloud platform and apply it to **[Track 1: Enterprise Linux Systems Engineering](../../01-sysadmin-foundations/README.md)** to master Linux systems administration from the ground up!

---

### Navigation
| [← Previous: Hyper-V 05: VM Architecture & Cloud-Init](../05-vm-architecture-and-cloud-init/README.md) | [Tutorials Index](../../README.md) | [Linux Track: Sysadmin Foundations →](../../01-sysadmin-foundations/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Linux Level 07: Automation & Bash](../../01-sysadmin-foundations/level-07-automation-bash-and-package-lifecycle/README.md)).*
