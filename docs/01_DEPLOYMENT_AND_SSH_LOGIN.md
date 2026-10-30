# Tutorial 1: Deploying Your Linux Lab & SSH Login (Key & Password)

This tutorial takes you from a blank Windows terminal to a running, hardware-isolated Ubuntu 24.04 Linux VM on Hyper-V, and demonstrates logging in using both **SSH Key Authentication** and **Password Authentication**.

---

## Step 0: Open PowerShell as Administrator

Hyper-V operations require elevated privileges.

1. Press `Win + X`.
2. Click **Terminal (Admin)** or **PowerShell (Administrator)**.
3. Navigate to the module directory:
   ```powershell
   git clone https://github.com/alkurdy/HyperV-LinuxLab.git
   Set-Location .\HyperV-LinuxLab
   ```

---

## Step 1: Check Host Readiness

Run the built-in diagnostic test to confirm your CPU virtualization, RAM, disk space, and Hyper-V features are ready:

```powershell
Import-Module .\HyperV-LinuxLab.psd1 -Force
Test-LabPrerequisites -Detailed
```

### What You Should See:
```text
Status                 : Ready
AdministratorRights    : True
WindowsEdition         : Microsoft Windows 11 Pro 64-bit (Professional)
HyperVSupported        : True
HyperVModule           : True
VirtualSwitch          : True
LogicalCPUCores        : 8
TotalMemoryGB          : 32
TargetStoragePath      : C:\
TargetFreeStorageGB    : 242.4
DiscoveredVolumes      : {C: - 242.4 GB free, D: (BigO) - 942.8 GB free, E: (SSD03) - 194 GB free}
RecommendedDrive       : D:
CloudImageAccess       : True
Recommendation         : Host is fully primed for Hyper-V Linux lab deployment.
```

> [!TIP]
> **Have multiple disks?** Notice `Test-LabPrerequisites` discovers all local drives (`C:`, `D:`, `E:`). If you want to deploy all virtual disks to a secondary drive with more capacity, run:
> ```powershell
> Set-LabConfiguration -StoragePath "D:\HyperV-LinuxLab"
> ```
> This saves your preference persistently. All future base images and VMs will deploy there automatically.

---

## Step 1.5: Built-in Storage "Scream Test" UI

To protect your Windows host from disk exhaustion, `HyperV-LinuxLab` runs an automated pre-flight **Scream Test** before downloading images or allocating disks.

If a target volume has insufficient space (< 10 GB), execution halts immediately and renders an unmissable alert banner:

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

---

## Step 2: Download the Golden Base Image (One-Time)

Download the official Canonical Ubuntu 24.04 LTS Cloud VHDX. It is saved once and locked as read-only:

```powershell
New-LabBaseImage -Distro "Ubuntu2404"
```

- **Size**: ~750 MB.
- **Location**: `C:\HyperV-LinuxLab\BaseImages\ubuntu-24.04-server-cloudimg-amd64.vhdx`.
- *Subsequent runs will automatically detect the cached image and skip download.*

---

## Step 3: Spin Up Your Linux Lab VM

Every time you spin up a lab VM, `HyperV-LinuxLab` automatically:
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

## Step 4: The On-Screen Connection Banner

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

---

## Step 5: Log In Via SSH

Now test connecting to your Linux server using either authentication method:

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

### Step 5.1: Changing Your Password Inside Linux (Optional)

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

You are ready for **[Tutorial 2: Linux Operating System Essentials & Mental Model](02_LINUX_ESSENTIALS_OVERVIEW.md)**!
