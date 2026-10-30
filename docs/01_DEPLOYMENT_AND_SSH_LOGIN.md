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
StorageDrive           : C:
FreeStorageGB          : 120.4
CloudImageAccess       : True
Recommendation         : Host is fully primed for Hyper-V Linux lab deployment.
```

> [!TIP]
> If any item fails, a clear warning box will guide you on the exact fix before continuing.

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

## Step 3: Choose Your Login Method & Deploy

You can configure your lab VM for **SSH Key authentication**, **Password authentication**, or **both**.

### Option A: SSH Key Authentication (Recommended / Default)
Cloud-Init automatically discovers your Windows SSH key (`~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`).

```powershell
New-LabVM -Name "linux-sandbox" -Profile "Minimal" -Start
```

---

### Option B: SSH Key AND Password Authentication
If you also want to be able to type a password to log in, provide a password using a SecureString:

```powershell
$password = ConvertTo-SecureString "LabPass123!" -AsPlainText -Force

New-LabVM -Name "linux-sandbox" -Profile "Minimal" -Password $password -Start
```

### What happens behind the scenes in ~15 seconds:
1. Creates a tiny (< 10MB) child differencing disk linked to your base image.
2. Generates a Cloud-Init ISO (`cidata.iso`) configuring the `labadmin` user, password, and SSH keys.
3. Sets up Gen2 UEFI firmware with `MicrosoftUEFICertificateAuthority` (Linux Secure Boot).
4. Boots the VM and resolves its IP address via Hyper-V KVP data exchange.

---

## Step 4: The On-Screen Connection Banner

Once the VM finishes booting, this banner will appear directly on your screen:

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

## Step 5: Log In Via SSH

Now test connecting to your Linux server using either authentication method:

### Method 1: Log in using your SSH Key (Passwordless)
Copy and paste the `Connect` command from your screen:

```powershell
ssh labadmin@<Your-VM-IP>
```

- When prompted: `Are you sure you want to continue connecting (yes/no/[fingerprint])?`, type `yes` and hit **Enter**.
- You will land directly into the Linux terminal without needing to type a password!

---

### Method 2: Log in using Password
If you deployed using Option B and want to test logging in with your password (bypassing the SSH key):

```powershell
ssh -o PubkeyAuthentication=no labadmin@<Your-VM-IP>
```

- The server will prompt: `labadmin@<Your-VM-IP>'s password: `
- Type your password (e.g. `LabPass123!`) and hit **Enter** *(note: characters will not show on screen while typing — this is normal Linux security behavior)*.

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
