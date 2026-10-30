# Getting Started: Linux Systems Learning Lab

A hands-on, step-by-step guide to provisioning your first ephemeral Linux virtual machine on Windows 11 Hyper-V using `HyperV-LinuxLab`.

---

## What You Are Building

You will stand up a true, hardware-virtualized **Ubuntu 24.04 LTS Noble Numbat** Linux server in seconds:
- **Child Differencing Disk**: Starts at under **10MB** on host disk.
- **Zero-Touch Config**: Your SSH key and `labadmin` sudo user are injected automatically on boot via Cloud-Init.
- **Pure Linux**: Native kernel, real `systemd` init, real `cgroups v2`, real network interfaces.
- **Fearless Experimentation**: Test broken configs, kernel panics, or deleted packages, and revert back in **under 3 seconds**.

---

## Step 0: Open PowerShell as Administrator

Hyper-V virtual machine and switch operations require local administrator privileges.

1. Press `Win + X`.
2. Select **Terminal (Admin)** or **PowerShell (Administrator)**.
3. Navigate to the module directory:
   ```powershell
   git clone https://github.com/alkurdy/HyperV-LinuxLab.git
   Set-Location .\HyperV-LinuxLab
   ```

---

## Step 1: Verify Host Prerequisites

Run the diagnostic readiness check:

```powershell
Import-Module .\HyperV-LinuxLab.psd1 -Force
Test-LabPrerequisites -Detailed
```

### Expected Output:
```text
Status              : Ready
AdministratorRights : True
WindowsEdition      : Microsoft Windows 11 Pro 64-bit (Professional)
HyperVSupported     : True
HyperVModule        : True
VirtualSwitch       : True
LogicalCPUCores     : 8
TotalMemoryGB       : 32
StorageDrive        : C:
FreeStorageGB       : 142.5
CloudImageAccess    : True
Recommendation      : Host is fully primed for Hyper-V Linux lab deployment.
```

> [!NOTE]
> If any item fails, a warning box will guide you on the exact fix (e.g., enabling the Hyper-V Windows feature or freeing storage space).

---

## Step 2: Cache the Ubuntu 24.04 Golden Base Image (One-Time)

Download Canonical's official Ubuntu 24.04 LTS cloud VHDX image. This image is locked as **read-only** and shared by all your future labs:

```powershell
New-LabBaseImage -Distro "Ubuntu2404"
```

- **File size**: ~700MB - 800MB.
- **Stored at**: `C:\HyperV-LinuxLab\BaseImages\`
- *Note: If you run this again in the future, it instantly skips because the image is already cached.*

---

## Step 3: Launch Your First Linux Lab VM

Deploy an isolated Linux virtual machine named `linux-sandbox` with essential diagnostic tools pre-installed:

```powershell
New-LabVM -Name "linux-sandbox" -Profile "Minimal" -MemoryGB 2 -CPUCount 2 -Start
```

### What happens in ~10 seconds:
1. Spawns an ephemeral child differencing VHDX (< 10MB).
2. Generates a custom `cidata.iso` embedding your local Windows SSH key.
3. Provisions a Gen2 UEFI VM with Linux Secure Boot.
4. Boots the machine and resolves its IP address via Hyper-V KVP.

### On-Screen Banner
When ready, your screen displays:

```text
============================================================
 [OK] Linux Lab VM Ready!
------------------------------------------------------------
 Name    : linux-sandbox
 Status  : Running
 IPv4    : 172.28.140.85
 User    : labadmin
 Connect : ssh labadmin@172.28.140.85
============================================================
```

---

## Step 4: SSH Into Your Linux Machine

Copy the `ssh` command displayed in your banner and paste it into PowerShell:

```powershell
ssh labadmin@<Your-VM-IP>
```

> [!TIP]
> If prompted `Are you sure you want to continue connecting (yes/no/[fingerprint])?`, type `yes` and press Enter. You will land directly at the Ubuntu bash prompt without needing a password.

---

## Step 5: First Linux Drills (Exploring the System)

Once inside the bash prompt (`labadmin@linux-sandbox:~$`), run these core drills:

### Drill 1: System and Kernel Identity
```bash
# Check running Linux kernel version
uname -r

# Check operating system release
cat /etc/os-release

# Inspect system uptime and load averages
uptime
```

### Drill 2: Process & Resource Inspection
```bash
# Open interactive process viewer (pre-installed by Minimal profile)
htop
# (Press 'q' to exit htop)

# View tree representation of all processes under systemd
pstree -p
```

### Drill 3: Network Diagnostics
```bash
# View assigned IP addresses and interfaces
ip -br addr

# View active listening ports and sockets
ss -tulpn
```

### Drill 4: Trace a Linux System Call
Linux binaries talk to the kernel via **system calls**. Watch `ls` communicate with the kernel in real time:
```bash
strace -c ls /
```

---

## Step 6: The Snapshot Drill (Save State & Revert in 2 Seconds)

While still logged into your VM, create a sample project:

```bash
mkdir ~/my-project && echo "Critical Data v1.0" > ~/my-project/app.txt
exit
```

Back in your Windows PowerShell terminal:

### 1. Take a Checkpoint
```powershell
Checkpoint-LabVM -Name "linux-sandbox" -SnapshotName "v1.0-clean"
```

### 2. SSH Back In & Simulate an Accident
```powershell
ssh labadmin@<Your-VM-IP>
```
```bash
# Accurately simulate an accidental deletion:
rm -rf ~/my-project
ls ~/my-project
# Returns: No such file or directory
exit
```

### 3. Revert Back to Snapshot
```powershell
Restore-LabVM -Name "linux-sandbox" -Force
```
*Reverts in ~2 seconds.*

### 4. Verify Data Restored
```powershell
ssh labadmin@<Your-VM-IP>
```
```bash
cat ~/my-project/app.txt
# Output: Critical Data v1.0
exit
```

---

## Step 7: The Break-Fix Factory Reset Drill

What happens if you run a bad command that completely destroys the OS? Let's test it:

```powershell
ssh labadmin@<Your-VM-IP>
```
```bash
# Destroy critical configuration:
sudo rm -rf /etc/network /etc/systemd
exit
```

Instead of spending 20 minutes reinstalling an OS, run:

```powershell
Reset-LabVM -Name "linux-sandbox" -Force
```

In **3 seconds**, the corrupted child disk is discarded and a pristine copy is linked to the golden base image. Your VM is fresh out-of-the-box again.

---

## Step 8: Clean Teardown When Finished

When you are done learning for the day, clean up all storage and hypervisor registrations with a single command:

```powershell
Remove-LabVM -Name "linux-sandbox" -Force
```

All differencing disks and ISO files are erased cleanly. Your host storage is restored to zero overhead.

---

## Summary of Essential Commands

| Action | PowerShell Command |
| :--- | :--- |
| **Check Host Health** | `Test-LabPrerequisites -Detailed` |
| **List Available Profiles** | `Get-LabProfile` |
| **Launch Linux VM** | `New-LabVM -Name "node-01" -Profile "Minimal" -Start` |
| **View Active Lab VMs** | `Get-LabVM` |
| **Take Snapshot** | `Checkpoint-LabVM -Name "node-01" -SnapshotName "pre-drill"` |
| **Revert to Snapshot** | `Restore-LabVM -Name "node-01" -Force` |
| **Instant Factory Wipe** | `Reset-LabVM -Name "node-01" -Force` |
| **Delete Lab VM** | `Remove-LabVM -Name "node-01" -Force` |
