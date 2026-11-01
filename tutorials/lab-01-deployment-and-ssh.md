# Lab Tutorial 01: Deploying Your Linux Lab & SSH Login (Key & Password)

> **[HyperV-LinuxLab Tutorials Hub](README.md)** • **Track 1: Hands-On Linux Lab** • [📑 Index](README.md) • [Next: Linux Mental Model & Filesystems →](lab-02-linux-mental-model-and-filesystems.md)

---

So, you want to deploy a real, hardware-isolated Linux server on Windows in under 10 seconds, but you don't want the clunkiness of slow ISO installers or heavy third-party virtualization software. 

In this tutorial, we will take you from a blank Windows terminal to a running, hardware-accelerated Linux virtual machine on Hyper-V, and demonstrate logging in using both **SSH Key Authentication** (passwordless) and the **Auto-Generated Lab Passphrase**.

---

## 🧭 In This Tutorial:
1. [Step 0: Elevation & Administrator Shell](#step-0-open-powershell-as-administrator)
2. [Step 1: Host Readiness Verification](#step-1-check-host-readiness)
3. [Step 2: Pre-Flight Storage Scream Gate](#step-2-built-in-storage-scream-test-ui)
4. [Step 3: Golden Base Image Caching](#step-3-cache-the-golden-base-image-one-time)
5. [Step 4: Launching Your First Lab VM](#step-4-spin-up-your-linux-lab-vm)
6. [Step 5: The On-Screen Connection Banner](#step-5-the-on-screen-connection-banner)
7. [Step 6: Logging In via SSH (Key vs Passphrase)](#step-6-log-in-via-ssh)

---

## Step 0: Open PowerShell as Administrator

So you want to manage hypervisors? Hyper-V talks directly to Ring -1 silicon and Windows network filter drivers, which requires elevated administrator privileges.

1. Press `Win + X`.
2. Click **Terminal (Admin)** or **PowerShell (Administrator)**.
3. Clone or open the repository:
   ```powershell
   git clone https://github.com/alkurdy/HyperV-LinuxLab.git
   Set-Location .\HyperV-LinuxLab
   ```

---

## Step 1: Check Host Readiness

Now that our administrative terminal is open, let's verify that your CPU virtualization, memory, storage volumes, and Hyper-V features are ready:

```powershell
Import-Module .\HyperV-LinuxLab.psd1 -Force
Test-LabPrerequisites -Detailed
```

### What You Should See:
```text
Status              : Ready
AdministratorRights : True
WindowsEdition      : Microsoft Windows 11 Pro 64-bit (Professional)
HyperVSupported     : True
HyperVModule        : True
VirtualSwitch       : True
LogicalCPUCores     : 8
TotalMemoryGB       : 32
TargetStoragePath   : C:\
TargetFreeStorageGB : 242.4
DiscoveredVolumes   : {C: - 242.4 GB free, D: (BigO) - 942.8 GB free, E: (SSD03) - 194 GB free}
RecommendedDrive    : D:
CloudImageAccess    : True
Recommendation      : Host is fully primed for Hyper-V Linux lab deployment.
```

> [!TIP]
> **Have multiple physical drives?** Notice `Test-LabPrerequisites` evaluates all local storage volumes (`C:`, `D:`, `E:`). If you want to deploy all virtual disks to a secondary drive with more capacity, run:
> ```powershell
> Set-LabConfiguration -StoragePath "D:\HyperV-LinuxLab"
> ```
> This saves your preference persistently. All future base images and VMs will deploy there automatically.

---

## Step 2: Built-in Storage "Scream Test" UI

So you want to make sure your host drive never fills up unexpectedly? `HyperV-LinuxLab` runs an automated pre-flight **Scream Test** before allocating disks or downloading images.

If your target volume has less than 10 GB of free space, execution halts immediately and renders an unmissable alert banner:

```text
================================================================================
 [SCREAM ALERT] INSUFFICIENT DISK CAPACITY FOR VM Differencing Provisioning
--------------------------------------------------------------------------------
 Target Drive   : C: (C:\HyperV-LinuxLab\LabVMs)
 Available Space: 4.2 GB
 Required Space : 10 GB
 Deficit        : -5.8 GB (TOO LOW FOR SAFE DEPLOYMENT)
--------------------------------------------------------------------------------
 ALTERNATIVE HIGH-CAPACITY VOLUMES DETECTED ON THIS HOST:
   * D: (BigO) -> 942.8 GB free
   * E: (SSD03) -> 194 GB free
 SWITCH STORAGE ROOT INSTANTLY BY RUNNING:
   Set-LabConfiguration -StoragePath 'D:\HyperV-LinuxLab'
 (Pass -Force to override this safety check at your own risk)
================================================================================
```

*(To understand how storage allocation and differencing disks work under the hood, jump to [Tutorial 04: Virtual Storage & Differencing Disks](hyperv-04-storage-and-differencing-disks.md)).*

---

## Step 3: Cache the Golden Base Image (One-Time)

Now that we've confirmed storage capacity, let's download the official Canonical Ubuntu 24.04 LTS Cloud VHDX. It is saved once and locked as read-only:

```powershell
New-LabBaseImage -Distro "Ubuntu2404"
```

- **Size**: ~750 MB.
- **Location**: `C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx`.
- *Subsequent runs automatically detect the cached image and skip download.*
- *Want other distributions? Run `New-LabBaseImage -Distro "Debian12"` or `New-LabBaseImage -Distro "AlmaLinux9"`.*

---

## Step 4: Spin Up Your Linux Lab VM

So you want a running Linux instance? Every time you provision a lab VM, `HyperV-LinuxLab` automatically:
1. Discovers your Windows SSH public key (`~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`) and authorizes it.
2. Generates a fresh, memorable, human-friendly passphrase (e.g. `Swift-Falcon-42` via `New-LabPassphrase`) so you can log in with password even if your SSH key has a forgotten passphrase or is absent.
3. Configures Gen2 UEFI firmware with `MicrosoftUEFICertificateAuthority` (Linux Secure Boot).
4. Attaches a dynamic differencing disk (< 10 MB initial size).

```powershell
New-LabVM -Name "linux-sandbox" -Profile "Minimal" -Start
```

> [!TIP]
> **Need a custom passphrase or password?**
> You can generate a fresh passphrase at any time using:
> ```powershell
> New-LabPassphrase
> # e.g. 'Cosmic-Otter-73'
> ```
> Or pass your own custom password to `New-LabVM`:
> ```powershell
> $customPass = ConvertTo-SecureString "MyCustomPass123!" -AsPlainText -Force
> New-LabVM -Name "linux-sandbox" -Password $customPass -Start
> ```

---

## Step 5: The On-Screen Connection Banner

Once the VM finishes booting (~10 seconds), this connection banner displays directly on your screen:

```text
============================================================
 [OK] Linux Lab VM Ready!
------------------------------------------------------------
 Name     : linux-sandbox
 Status   : Running
 IPv4     : 172.23.108.101
 User     : labadmin
 Password : Swift-Falcon-42
 Connect  : ssh labadmin@172.23.108.101
============================================================
```

> [!NOTE]
> All credentials and connection telemetry are dual-written to `$StoragePath\LabVMs\<name>\metadata.json` and the native Hyper-V VM `Notes` field. You can recall connection strings anytime with `Get-LabVM`.

---

## Step 6: Log In via SSH

Now that our VM is running and its IP is bound, test connecting using either authentication method:

### Method 1: Log in using your SSH Key (Passwordless)
Copy and paste the `Connect` command from your screen:

```powershell
ssh labadmin@<Your-VM-IP>
```

- When prompted: `Are you sure you want to continue connecting (yes/no/[fingerprint])?`, type `yes` and hit **Enter**.
- If your local Windows SSH key has no passphrase, you land directly in the Linux terminal without typing a password.
- If your local Windows key asks for a passphrase you don't remember, use **Method 2** below.

---

### Method 2: Log in using the Generated Lab Passphrase
To bypass the local Windows SSH key prompt and log in with the lab passphrase shown in the banner:

```powershell
ssh -o PubkeyAuthentication=no labadmin@<Your-VM-IP>
```

- The server will prompt: `labadmin@<Your-VM-IP>'s password: `
- Type or paste the generated passphrase (e.g. `Swift-Falcon-42`) and hit **Enter** *(note: characters will not echo on screen while typing — this is standard Linux security behavior)*.

---

### Step 6.1: Changing Your Password Inside Linux (Optional)

Once logged into your VM, you can change your password anytime using the standard Linux command:

```bash
passwd
```

1. Enter the current passphrase (e.g. `Swift-Falcon-42`).
2. Type your new desired password twice.
3. Done! All future logins will use your new password.

---

## Success!

You are now logged into your native Linux server:

```text
Welcome to Ubuntu 24.04 LTS (GNU/Linux 6.8.0-31-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

labadmin@linux-sandbox:~$ 
```

---

### 🧭 Navigation
| [📑 All Tutorials](README.md) | [Next: Lab Tutorial 02 - Linux Mental Model & Filesystems →](lab-02-linux-mental-model-and-filesystems.md) |
| :--- | :--- |

*(Under the hood: Want to know how the VM, UEFI, and Cloud-Init were built? Read [Hyper-V Tutorial 05: VM Architecture, Generation 2 UEFI & Cloud-Init Provisioning](hyperv-05-vm-architecture-and-cloud-init.md)).*
