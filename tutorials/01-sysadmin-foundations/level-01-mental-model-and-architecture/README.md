# Level 01: The Sysadmin Mental Model Transition (Windows/VMware to Linux)

> **[Tier 1: Sysadmin Foundations](../README.md)** • Grounded in *Operating Systems: Internals and Design Principles* (Stallings) & *Linux Command Line and Shell Scripting Bible* (Blum).

---

## Objective
Bridge the conceptual gap between Windows Server/vSphere infrastructure administration and Linux systems engineering. By the end of this module, you will understand how Linux executes code, organizes files, handles input/output streams, and manages devices as files.

---

## 1. Architectural Mental Model: Windows NT vs Linux

As an experienced systems administrator, you are accustomed to the Windows NT and VMware operating model. Understanding the architectural divergence prevents fundamental mistakes:

```
┌───────────────────────────────────────┐   ┌───────────────────────────────────────┐
│              WINDOWS NT               │   │                 LINUX                 │
├───────────────────────────────────────┤   ├───────────────────────────────────────┤
│ Microkernel / Hybrid Architecture     │   │ Monolithic Kernel Architecture        │
│ Distinct Drive Letters (C:, D:, E:)   │   │ Single Hierarchical Virtual VFS (/)   │
│ Monolithic Registry (HKLM, HKCU)      │   │ Plaintext Modular Files (/etc/)       │
│ GUI / WMI / CIM Object-Based Pipeline │   │ POSIX Stream-Based Plaintext & Pipes  │
│ Strict Security Descriptors & DACLs   │   │ Octal Permissions + Capabilities/ACLs │
│ Services interact via SCM (services)  │   │ Units managed by systemd (PID 1)      │
└───────────────────────────────────────┘   └───────────────────────────────────────┘
```

### The Monolithic Kernel & Privilege Rings
- **Kernel Space (Ring 0)**: The Linux kernel (`vmlinuz`) runs directly on the CPU silicon in Ring 0. Drivers (called **Kernel Modules**, `.ko` files) run in kernel space with direct memory access. There is no user-mode driver isolation by default.
- **User Space (Ring 3)**: All applications, daemons, containers, and shells execute in Ring 3. User programs communicate with the kernel strictly via **System Calls** (`syscalls` like `read()`, `write()`, `open()`, `fork()`, `epoll()`).
- **Inspection Command**:
  ```bash
  # Check active running kernel release and architecture
  uname -r -m
  # Output example: Linux 6.8.0-31-generic x86_64

  # List loaded kernel modules (equivalent to Windows drivers)
  lsmod | head -n 15

  # Inspect specific module metadata
  modinfo hv_vmbus
  ```

### The First Process: PID 1 (`systemd`) & The Boot Handoff
When the computer powers on:
1. UEFI/BIOS loads GRUB bootloader.
2. GRUB loads the Linux kernel (`vmlinuz`) into Ring 0 memory.
3. The kernel initializes CPU cores, memory page tables, and hardware drivers.
4. Once hardware is ready, the kernel's boot job is done. The kernel **must hand off control to user space**.
5. The kernel executes exactly **one** program: `/sbin/init` (which symlinks to `/lib/systemd/systemd`).
6. Because it is the first program executed in user space, the kernel assigns it **Process ID 1 (PID 1)**.

#### What `systemd` Does:
- **Windows Equivalent**: A unified blend of `smss.exe` (Session Manager), `wininit.exe`, `services.exe` (Service Control Manager), and Task Scheduler.
- **The Process Ancestor**: Every single process running on Linux—including your SSH daemon and your Bash shell—is a child or grandchild of PID 1.
- **Service Supervisor**: Starts daemons (`sshd`, `cron`, `systemd-journald`, `systemd-resolved`), monitors health, and restarts them automatically if they crash.
- **The Adoptive Orphan Reaper**: When a background process terminates and its parent shell has already died, the orphan is adopted by PID 1, which collects its exit status so it doesn't become a permanent "zombie" occupying kernel process table slots.
- **Critical System Invariant**: If PID 1 ever crashes or exits, the Linux kernel immediately throws a **Kernel Panic** and the OS halts.

---

## 2. The Unified Virtual Filesystem (VFS) vs Drive Letters

In Windows, every storage partition is bound to a drive letter (`C:\`, `D:\`).
In Linux, there are **no drive letters**. There is exactly one tree starting at the root directory `/`.

### The Mount Abstraction
Any physical disk partition, optical drive, remote network share (NFS/SMB), or virtual pseudo-filesystem is **mounted** to an existing directory in the tree:

```
                  / (Root VFS)
       ┌──────────┼──────────┬──────────┐
       ▼          ▼          ▼          ▼
     /etc       /var       /mnt        /proc (Pseudo Kernel VFS)
                             ▼
                        /mnt/backup (Mounted from physical NVMe /dev/sdb1)
```

- When you write to `/mnt/backup/file.tar`, you are writing to `/dev/sdb1`.
- When you unmount `/mnt/backup`, the directory `/mnt/backup` becomes an empty folder on the root disk. The data on `/dev/sdb1` remains intact.
- **Everything is a File**: Disks (`/dev/sda`), network cards (`/sys/class/net/eth0`), running process metadata (`/proc/$$/status`), and terminals (`/dev/pts/0`) are all accessed using standard file I/O system calls (`open`, `read`, `write`, `close`).

---

## 3. Virtual Pseudo-Filesystems: `/proc`, `/sys`, and `/dev`

Linux surfaces kernel internal data structures directly as readable files in RAM:

### 1. `/proc` (Process & Kernel Telemetry in RAM)
The files in `/proc` consume 0 bytes of disk space. They are dynamically generated by the kernel when read.
```bash
# Host CPU topology and hardware flags (VT-x/AMD-V)
cat /proc/cpuinfo | grep -E "model name|flags" | head -n 5

# Host RAM telemetry (active, buffers, cache, dirty memory)
cat /proc/meminfo | head -n 10

# System uptime in seconds (raw idle time)
cat /proc/uptime

# Running process introspection (PID 1)
cat /proc/1/cmdline
cat /proc/1/status | grep -E "Name|State|VmRSS"
```

### 2. `/sys` (Device Tree & Hardware Topology)
Exposes physical buses, PCIe lanes, disk controller state, and ACPI tables.
```bash
# Query disk rotational state (0 = SSD/NVMe, 1 = Mechanical HDD)
cat /sys/block/vda/queue/rotational

# Query disk scheduler algorithm
cat /sys/block/vda/queue/scheduler
```

### 3. `/dev` (Device Nodes)
Contains character and block device handles managed by `udevd`:
- `vda` / `sda`: Entire physical or virtual hard drive.
- `vda1` / `sda1`: First partition on the drive.
- `/dev/null`: The bit bucket (discards all data written; returns EOF on read).
- `/dev/urandom`: Cryptographically secure pseudo-random number generator stream.

---

## 4. The Linux Stream Philosophy & Pipelines (UNIX Philosophy)

In PowerShell, cmdlets pass rich .NET objects down the pipeline (`Get-Process | Where-Object CPU -gt 10`).
In Linux, commands follow the **UNIX philosophy**: *Write programs that do one thing well, and make programs read and write streams of plaintext.*

### Standard Streams
Every process launched by the shell inherits three standard file descriptors (FD):
- **FD 0 (stdin)**: Standard Input (keyboard or incoming pipe).
- **FD 1 (stdout)**: Standard Output (screen or outgoing pipe).
- **FD 2 (stderr)**: Standard Error (diagnostic messages; separate from stdout).

```bash
# Redirect stdout to a file (overwrite)
cat /proc/cpuinfo > cpu_info.txt

# Redirect stdout to a file (append)
date >> cpu_info.txt

# Redirect stderr only to a log file
ls /root 2> errors.log

# Discard both stdout and stderr (silent execution)
command > /dev/null 2>&1
# Modern syntax:
command &> /dev/null

# Piping stdout of command A into stdin of command B
cat /etc/passwd | cut -d: -f1 | sort | grep -v "nologin"
```

---

---

## 5. Environment Variables, Execution Scopes & History Recall

Every running process inherits an execution environment composed of key-value string pairs. Understanding shell vs environment variable scope is fundamental to systems automation and troubleshooting:

### Shell Variables vs Exported Environment Variables
- **Shell Variable** (`MY_ENV="staging"`): Exists only inside the current active shell process memory. Not accessible to child processes or commands spawned by the shell.
- **Exported Environment Variable** (`export MY_ENV="staging"`): Placed in the process environment block. When the shell spawns a child process (`fork()` + `execve()`), the child receives a duplicate copy of this environment block.
- **Child Modification Rule**: A child process can modify its own environment variables, but changes can **never** propagate backward to modify the parent shell's environment.

```bash
# Set a local shell variable (not exported)
APP_TIER="frontend"
bash -c 'echo "Child sees: $APP_TIER"'  # Outputs nothing!

# Export variable to environment
export APP_TIER="frontend"
bash -c 'echo "Child sees: $APP_TIER"'  # Outputs: Child sees: frontend

# Inspect all active environment variables
env
# Or print specific variable:
printenv APP_TIER

# Remove variable from environment
unset APP_TIER
```

### The `$PATH` Search Variable
When you type a command like `ls` or `systemctl`, the shell searches directories listed in `$PATH` sequentially from left to right (separated by colons `:`):
```bash
echo $PATH
# Output: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```
If an executable is located in a directory not present in `$PATH` (e.g. `/opt/custom/bin`), you must specify the absolute path (`/opt/custom/bin/app`) or prepend the directory to `$PATH`:
```bash
export PATH="/opt/custom/bin:$PATH"
```

### Persistence: `.bashrc` vs `/etc/profile.d/`
- Variables set via `export` in a terminal vanish when that terminal closes.
- For **user-specific persistence**: Add `export VAR="value"` to `~/.bashrc` (interactive non-login shells) or `~/.bash_profile` (login shells).
- For **system-wide persistence**: Create a `.sh` file inside `/etc/profile.d/` (e.g. `/etc/profile.d/company-env.sh`).

### Shell History Recall (`!N`)
The shell history mechanism stores previous commands in memory and writes them to `~/.bash_history` upon session exit:
```bash
# View recent command history with line numbers
history | tail -n 10

# Re-execute command by history line number (e.g., line 42)
!42

# Re-execute the immediately preceding command
!!

# Re-execute the last command starting with 'sys'
!sys
```

## 6. Modern Sysadmin Discovery Cheatsheet

| Windows Task | Linux Command | Description |
| :--- | :--- | :--- |
| `systeminfo` / `Get-ComputerInfo` | `hostnamectl`, `uname -a` | OS edition, kernel version, hardware architecture |
| `Get-WmiObject Win32_Processor` | `lscpu` | CPU model, sockets, cores, virtualization flags |
| `Get-Counter '\Memory\% Available'` | `free -h` | Total, used, free, cached RAM in human-readable units |
| `Get-Volume` / `Get-Disk` | `lsblk`, `df -h` | Block devices, partitions, mount points, capacity |
| `Get-Service` | `systemctl list-units --type=service` | Running system daemons and units |
| `Get-NetIPConfiguration` | `ip -br addr` | Interface state, assigned IPv4 and IPv6 addresses |
| `Get-NetTCPConnection` | `ss -tulpn` | Listening TCP/UDP sockets and owning process PIDs |
| `Get-EventLog System` | `journalctl -b` | Current boot system event log |

---

## Hands-On Lab: Provisioning Your Continuous Server

In this track, you are not spinning up disposable toy VMs that get wiped at the end of every tutorial. **You are building `sysadmin-node`, a single continuous enterprise Linux server that you will configure, expand, troubleshoot, and automate across all 7 levels.**

### Step 0: Deploy Continuous Lab Node
Run from your host elevated PowerShell console:
```powershell
New-LabVM -Name "sysadmin-node" -MemoryGB 2 -CPUCount 2 -Start
```

### SSH Connection & Credential Architecture

`HyperV-LinuxLab` automates first-boot operating system initialization via **Cloud-Init** using a synthetic NoCloud ISO volume:

1. **Automatic SSH Public Key Injection**:
   - `New-LabVM` inspects your host `~/.ssh/` directory and auto-discovers all active public keys (`id_ed25519.pub`, `id_rsa.pub`, etc.).
   - All discovered keys are automatically added to `/home/labadmin/.ssh/authorized_keys`.
   - Connect using standard SSH:
     ```powershell
     ssh labadmin@<VM_IP>
     ```
   - If your private key has a passphrase, OpenSSH will prompt for it. If you maintain multiple identity keys:
     ```powershell
     ssh -i ~/.ssh/id_ed25519 labadmin@<VM_IP>
     ```

2. **Ephemeral Console Passphrase (Safety Net)**:
   - Every provisioned node generates a secure random password displayed in the green success banner (e.g. `Password: Green-Rabbit-95`).
   - If you ever forget the password or need to log in via console / password auth, query metadata from host PowerShell:
     ```powershell
     Get-LabVM -Name "sysadmin-node"
     ```

3. **Troubleshooting Reassigned IPs (`known_hosts` Mismatch)**:
   - Hyper-V Default Switch DHCP re-uses IP addresses across destroyed and recreated VMs.
   - If you see `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`, clear the stale cached SSH fingerprint from your host console:
     ```powershell
     ssh-keygen -R <VM_IP>
     ```
   - Then reconnect.

4. **The 3 Layers of SSH Security (Why Passphrases Exist)**:
   - **Layer 1: Public Key (`id_ed25519.pub`)**: Placed on the server inside `~/.ssh/authorized_keys`. Acts as a digital padlock. Sharing it publicly poses zero security risk.
   - **Layer 2: Private Key (`id_ed25519`) & Passphrase**: Stored strictly on your client workstation (`C:\Users\<user>\.ssh\id_ed25519`). Never transmitted across the wire.
     - *The Threat Model*: If malware or a physical thief copies your `id_ed25519` file, an unencrypted key gives them instant root access to all your servers.
     - *The Passphrase*: Encrypts the private key file on disk using **AES-256-CBC** and key derivation (**bcrypt**). When OpenSSH prompts `Enter passphrase for key...`, it decrypts the key strictly in volatile RAM to sign the authentication challenge. The private key on disk remains encrypted ciphertext.
   - **Layer 3: Linux OS Account Password (e.g. `Green-Rabbit-95`)**: The password of the `labadmin` user account inside the Linux VM. Used for **`sudo` privilege escalation** to root and emergency Hyper-V console logins.

   #### How "Passwordless" Access Works: Wire Encryption vs. Authentication
   A common misconception is that your SSH key encrypts the connection. It does not! SSH splits the session into two completely distinct cryptographic phases:

   ```
   PHASE 1: WIRE ENCRYPTION (Ephemeral Diffie-Hellman / ECDH)
   Client <══════════════════════════════════════════════════════> Server
   - Negotiate temporary symmetric session key (ChaCha20 / AES-GCM).
   - Server presents Host Key to prove its identity (known_hosts).
   - RESULT: A secure, encrypted pipe is established. (User key NOT used yet!)

   PHASE 2: USER AUTHENTICATION ("Passwordless" Challenge-Response)
   Client                                                          Server
     │                                                               │
     │ ── 1. "I want to log in as labadmin using public key X" ───►  │
     │                                                               │ (Checks ~/.ssh/authorized_keys)
     │ ◄── 2. "Prove it. Sign this random challenge: 9f4a8b..." ──── │
     │                                                               │
     │ (Client signs challenge in RAM using private key id_ed25519)  │
     │                                                               │
     │ ── 3. "Here is the digital signature" ──────────────────────► │
     │                                                               │ (Verifies signature using Public Key X)
     │ ◄── 4. "Signature matches! Access granted. Spawning bash" ─── │
   ```

   - **Why it is "Passwordless"**: Neither a password nor your private key is ever transmitted across the network.
   - **Zero-Knowledge Proof**: The server gives you a unique, random mathematical challenge. Only someone holding the private key can generate the valid signature, but anyone holding the public key can verify that the signature is genuine. An eavesdropper recording the traffic only sees the signature of a one-time random number that will never be used again.

5. **Enterprise & Cloud Key Injection (Hyper-V vs. AWS vs. Azure)**:
   A foundational rule of public-key cryptography: **Private keys are NEVER shared or copied to the cloud.** Only your *public key* is injected into the VM:

   ```
   LOCAL HYPER-V LAB (NoCloud ISO)
   Host PowerShell reads ~/.ssh/*.pub ──► bakes into cidata.iso ──► Cloud-Init mounts ISO on boot ──► writes ~/.ssh/authorized_keys

   AWS EC2 (Instance Metadata Service / IMDS)
   User registers Public Key in AWS ──► VM boots ──► Cloud-Init curls http://169.254.169.254/latest/meta-data/ ──► writes ~/.ssh/authorized_keys

   AZURE VMS (Azure IMDS / ARM)
   Portal passes Public Key via ARM ──► VM boots ──► Cloud-Init queries Azure Fabric / IMDS ──► writes ~/.ssh/authorized_keys
   ```

   - **How `HyperV-LinuxLab` Does It**:
     1. `New-LabVM` runs `New-LabCloudInitISO.ps1` on your Windows workstation.
     2. It discovers all `.pub` files in `C:\Users\<user>\.ssh\`.
     3. It bakes them into a temporary `cidata.iso` image formatted with the **NoCloud** datasource schema.
     4. Hyper-V attaches the ISO as a virtual DVD drive.
     5. Canonical Ubuntu boots, `cloud-init.service` reads the virtual DVD, creates `labadmin`, writes the public keys into `/home/labadmin/.ssh/authorized_keys`, and enforces strict permissions (`chmod 700 ~/.ssh`, `chmod 600 authorized_keys`).
   - **How AWS EC2 Does It**:
     1. AWS never sees or touches your private key. You upload your public key (or AWS generates a key pair and gives you the private `.pem` to download once).
     2. AWS attaches the public key metadata to the EC2 instance profile.
     3. When Ubuntu boots inside EC2, Cloud-Init detects the AWS hypervisor and queries the link-local **Instance Metadata Service (IMDS)** at `http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key`.
     4. Cloud-Init downloads the public key over the internal virtual NIC and injects it into `/home/ubuntu/.ssh/authorized_keys`.
   - **How Azure Does It**:
     1. Azure Resource Manager (ARM) injects public keys via the Azure Instance Metadata Service (`http://169.254.169.254/metadata/instance`) or via provisioned configuration files.

6. **Enterprise Remote Access: How Users Connect From Home or Corporate Networks**:
   In enterprise infrastructure, production servers rarely sit on open public IP addresses. Organizations use three primary network patterns to connect:

   ```
   Pattern 1: Direct Public IP + Firewall (Home Labs & Dev)
   [Home Laptop] ───────── Public Internet (TCP Port 22) ─────────► [Cloud VM (Public IP)]
                                (Restricted by Security Group to your IP)

   Pattern 2: Bastion Host / Jump Box (Traditional Enterprise)
   [Home / Office] ──► VPN ──► [Hardened Bastion (DMZ)] ──► Private Subnet (10.0.1.x) ──► [Internal Linux VM]
                                 (SSH Agent Forwarding)

   Pattern 3: Zero-Trust & Identity-Aware Proxies (Modern Cloud / SRE Standard)
   [Workstation] ──► [Cloud Control Plane (IAM + MFA)] ◄── Outbound HTTPS Tunnel ──► [SSM/Tailscale Agent on VM]
                     (NO OPEN INBOUND PORTS! NO PUBLIC IPS!)
   ```

   - **Pattern 1: Direct Network Security Group (NSG / SG)**:
     The VM has a public IP, but an AWS Security Group or Azure NSG firewall rule restricts port 22 strictly to your home WAN IP (`x.x.x.x/32`). Cheap and simple for labs, but unsuitable for enterprise compliance.
   - **Pattern 2: Bastion Host (Jump Box)**:
     All database and application servers sit in private subnets with RFC1918 IPs (`10.x.x.x`) and **zero public internet access**. A single heavily monitored Linux VM (the Bastion) sits in a public DMZ. Users connect through a corporate VPN, SSH to the Bastion, and "jump" to the internal servers using SSH Agent Forwarding (`ssh -A`).
   - **Pattern 3: Zero-Trust Identity Proxies (AWS SSM & Azure Bastion & Tailscale)**:
     The modern cloud standard. **Port 22 is completely closed and VMs have no public IPs.**
     - **AWS Systems Manager (SSM) Session Manager**: A lightweight agent inside the VM initiates an *outbound HTTPS connection* (TCP 443) to AWS APIs. Engineers authenticate with corporate Single Sign-On (SSO) + MFA and run:
       ```bash
       aws ssm start-session --target i-0123456789abcdef0
       ```
     - **Tailscale / WireGuard**: A peer-to-peer encrypted mesh network. Each node runs a WireGuard daemon and receives a private `100.x.y.z` overlay IP. Engineers SSH seamlessly from home or coffee shops over end-to-end encrypted tunnels authenticated by their identity provider (Google Workspace, Okta, Microsoft Entra ID).

7. **Why Firewalls Are Mandatory: Defense-in-Depth vs. Public Port 22**:
   If Ed25519 keys are mathematically unbreakable, why can't we leave port 22 open to `0.0.0.0/0`?
   Because authentication protects *user accounts*, but firewalls protect the *daemon and kernel*:

   ```
   ATTACK SURFACE COMPARISON:

   With Open Port 22 (0.0.0.0/0):
   [Internet Bots] ──► [TCP Handshake] ──► [sshd performs CPU Diffie-Hellman] ──► [Exposes sshd C code bugs!]
                                                                                       │
                                                                                       ▼ (CVE-2024-6387 RegreSSHion)
                                                                                  [ROOT COMPROMISE BEFORE AUTH!]

   With Cloud Security Group / Firewall (Restricted IP):
   [Internet Bots] ──► [Hypervisor Drops TCP SYN Packet (SILENT DISCARD)]
                       (sshd never wakes up, CPU burns 0 cycles, zero zero-day exposure!)
   ```

   - **The 3 Fatal Dangers of Public Port 22**:
     1. **Zero-Day Remote Code Execution (RCE) in `sshd`**:
        In July 2024, **CVE-2024-6387 ("RegreSSHion")** revealed a signal handler race condition in OpenSSH `sshd`. Attackers gained unauthenticated **root execution** on Linux servers *before* logging in! If port 22 was open to the internet, no key or password could protect the server.
     2. **Resource Exhaustion & Denial of Service (DoS)**:
        Every incoming TCP connection forces `sshd` to fork a child process and execute asymmetric Diffie-Hellman math. Thousands of internet bots brute-forcing `root` fill the `MaxStartups` connection table, locking legitimate administrators out.
     3. **Log Poisoning & Disk Exhaustion**:
        Failed attempts generate millions of lines in `/var/log/auth.log`, consuming gigabytes of disk space and swamping SIEM alerting pipelines.
   - **The Golden Production Rule**: Firewalls stop the enemy at the perimeter gate. SSH keys only lock the door to the office. Never expose the office door to the public street.

8. **PKI Decoded: Public Key Infrastructure vs. SSH Keys (HTTPS, LDAPS, mTLS)**:
   Why doesn't the global web use `authorized_keys`? How does PKI scale trust across billions of devices?

   #### The Core Problem: Direct Trust vs. Third-Party Trust
   - **Plain SSH (Direct Trust / Peer-to-Peer)**: You copy your public key directly into the server's `~/.ssh/authorized_keys`. Works great for 1 admin and 10 servers. Breaks completely at 1,000 engineers and 10,000 servers (you cannot sync millions of key files).
   - **PKI / Public Key Infrastructure (Hierarchical Trust)**: Solves the *scale* problem. When you connect to your bank (`https://bank.com`), you have never visited before, and you do not have their public key on your laptop. Yet your browser trusts them immediately. How? Through a **Certificate Authority (CA)**.

   #### The Passport Analogy
   - **SSH Key Pair**: Like a handwritten note left with a friend: *"If someone shows up with this secret signature, let them in."*
   - **PKI Certificate**: Like a **Government-Issued Passport**:
     - The airport border guard (your browser/client) has never met you.
     - The border guard does not have your personal photo stored locally.
     - BUT the border guard has a master list of **Trusted Governments (Root CAs)**.
     - Your passport contains your name, your public key, an expiration date, and a **cryptographic digital signature from the Government**.
     - The guard verifies the Government's signature using the Government's public key (pre-installed in the OS). If the signature is valid, you are admitted!

   #### The Rosetta Stone: SSH vs. HTTPS vs. LDAPS vs. mTLS
   | Protocol | Standard Port | Certificate / Key Format | Who Authenticates Whom? | Trust Mechanism | Primary Enterprise Use Case |
   | :--- | :--- | :--- | :--- | :--- | :--- |
   | **Standard SSH** | TCP 22 | OpenSSH Key (`id_ed25519`) | Server authenticates Client | **Direct Trust**: Public key pre-shared in `~/.ssh/authorized_keys`. | Remote server shell administration. |
   | **HTTPS (TLS)** | TCP 443 | X.509 Certificate (`.crt`, `.pem`) | Client authenticates Server | **Hierarchical PKI**: Public CA (Let's Encrypt, DigiCert) signs server cert. | Web browsing, REST APIs, microservices. |
   | **LDAPS (LDAP over TLS)** | TCP 636 | X.509 Certificate (`.crt`, `.pem`) | Client authenticates Domain Controller | **Enterprise Internal PKI**: Active Directory CS (AD CS) issues DC cert. | Secure Active Directory authentication & directory queries. |
   | **mTLS (Mutual TLS)** | Any TCP | X.509 Certificates on **both** sides | **Both** authenticate each other | **Hierarchical PKI**: Internal CA issues certs to both client and server. | Kubernetes Pod-to-Pod zero-trust mesh (Istio, Linkerd). |

   #### The 5-Step Framework to Understand ANY PKI System
   Whenever you encounter a certificate or PKI problem in production, evaluate these 5 elements:
   1. **The Root CA (The Sovereign)**: The ultimate trust anchor. A self-signed certificate and private key stored in an offline physical safe or Hardware Security Module (HSM).
   2. **The Intermediate CA**: Signed by the Root CA. Used for day-to-day certificate issuance so the Root key is never exposed online.
   3. **The Leaf Certificate (End-Entity)**: The cert on the server or service. Bundles:
      - **Subject / SAN**: The DNS names it represents (e.g. `CN=login.company.com`).
      - **Public Key**: The server's public encryption key.
      - **Validity Window**: Exact start and expiration timestamps (`Not Before` / `Not After`).
      - **Issuer Signature**: Cryptographic proof signed by the Intermediate CA.
   4. **The Local Trust Store**: Every OS maintains a bundle of trusted Root CA certificates:
      - Windows: `certmgr.msc` -> *Trusted Root Certification Authorities*.
      - Linux: `/etc/ssl/certs/ca-certificates.crt` (managed via `update-ca-certificates`).
   5. **The Chain of Trust Verification**: The client traces signatures upward:
      `Leaf Cert ──► signed by Intermediate CA ──► signed by Root CA in Trust Store`. If any link in the chain is broken, missing, or expired, the OS rejects the connection with a Certificate Error.

   #### Confidentiality vs. Identity: The Armored Truck vs. The ID Badge
   A critical mental distinction for systems engineers:
   - **Confidentiality (Securing the Traffic)**: Making sure an eavesdropper on the network cannot read your commands or passwords. **This is handled automatically by Diffie-Hellman session encryption**, regardless of whether you use passwords, raw keys, or certificates.
   - **Identity & Authorization (What the Key/Certificate is For)**: Answering the server's question: *"Who is at the keyboard, and are they authorized to enter?"*

   #### Why Plain SSH Keys Fail in Enterprise & Why SSH Certificates Exist
   With raw SSH keys (`authorized_keys`):
   - **No Expiration Date**: A raw SSH key generated in 2020 never expires. If an engineer leaves the company or a service account key leaks on GitHub, it remains valid forever until someone manually deletes it.
   - **The 10,000 Server Sync Nightmare**: To revoke access for one departed engineer or leaked service account, you must connect to all 10,000 servers and scrub their `authorized_keys` file. If one server is offline or missed, the attacker retains root access indefinitely.

   **What an SSH Certificate Solves**:
   An SSH Certificate is **an ephemeral cryptographic ID badge with embedded policy**:
   1. **Burned-In Expiration (TTL)**: The certificate explicitly states: `Valid from 09:00 AM to 05:00 PM today`. At 5:01 PM, the certificate mathematically self-destructs. No key revocation list or manual scrubbing required!
   2. **Identity & Principal Restrictions**: The certificate declares: `Principals: deploy-bot, app-runner`. The holder can ONLY log in as those specific system accounts, never as `root`.
   3. **Stateless Servers (Zero `authorized_keys` Files)**:
      Servers no longer store individual user keys. The server configuration (`/etc/ssh/sshd_config`) contains one single directive:
      ```
      TrustedUserCAKeys /etc/ssh/ca.pub
      ```
      When an engineer or automated CI/CD pipeline connects, they present an ephemeral certificate signed by the company's central Certificate Authority (e.g., HashiCorp Vault, Teleport, or Smallstep). The server checks the CA signature, checks the expiration timestamp, checks the allowed username, and grants access.

---

## 9. The End-to-End Execution Path: What Happens When You Type a Command?

When you connect via SSH, type `cat /proc/uptime` and press `[Enter]`, Linux is not performing a single monolithic action. A chain of decoupled components collaborates to execute your intent:

```
[Windows Terminal Client]
       │ (Keystrokes transmitted over encrypted TCP port 22)
       ▼
[Hyper-V Virtual Switch]
       │
       ▼
[sshd daemon (PID 840)] ─── allocates ───► [Pseudo-Terminal: /dev/pts/0]
                                                         │
                                                         ▼
                                                [Bash Shell (PID 1052)]
                                                         │ (fork + execve)
                                                         ▼
                                                [/usr/bin/cat (PID 2104)]
                                                         │ (read syscall)
                                                         ▼
                                                [Linux Kernel (Ring 0)]
```

### The 4 Actors in Every Remote CLI Session

1. **The Terminal Emulator (Client Side)**:
   Windows Terminal or PowerShell is just a graphical window that captures keystrokes and draws colored character glyphs (pixels) on your screen. It knows *nothing* about Linux, filesystems, or shell syntax.
2. **The Secure Transport (`sshd`)**:
   The OpenSSH server daemon listens on port 22. It authenticates your public key, allocates a **Pseudo-Terminal** (`/dev/pts/0`), and acts as a bidirectional encrypted pipe between your Windows terminal and the Linux shell.
3. **The Shell (`bash`)**:
   Bash is simply a user-space C program running an infinite loop (**REPL**: Read-Eval-Print Loop):
   ```c
   while (1) {
       display_prompt();
       char *line = read_line_from_pts();
       execute_command(line);
   }
   ```
   - **Yes, Bash is a living process throughout your entire SSH connection!**
   - Each time you open a new SSH terminal, `sshd` spawns a brand new, independent `bash` process.
   - When you disconnect, the kernel sends a `SIGHUP` (Hangup Signal) to that `bash` process, terminating it.
   - You can inspect your own active shell PID anytime with `echo $$`.
4. **The Kernel (`vmlinuz`)**:
   The single Ring 0 supervisor that manages CPU scheduling, hardware, memory page tables, and file descriptors.

### History in 60 Seconds: Before Bash & Linux
- **1970s (The Teletype / TTY)**: Before video screens, terminals were mechanical paper typewriters wired to computers (hence the name **TTY**). The original Unix shell was Ken Thompson's `sh` (1971), followed by Stephen Bourne's `sh` (1977).
- **1989 (Bash Created)**: Brian Fox authored **Bash** (**B**ourne **A**gain **SH**ell) for the GNU Project to provide a free, open-source upgrade to the Bourne shell.
- **1991 (Linux Born)**: Linus Torvalds released the Linux kernel. The very first two user programs Linus ported to run on his new kernel were **GCC (the compiler)** and **Bash**. Linux *never existed* without a shell—from day one, it was designed to boot straight into Bash.

---

### The 6-Step Command Lifecycle (What Happens When You Hit `[Enter]`)

When you type `cat /proc/uptime > output.txt` and press `[Enter]`, Bash executes a deterministic pipeline:

```
1. TOKENIZE   ──► Splits line by whitespace into words: ["cat", "/proc/uptime", ">", "output.txt"]
2. EXPAND     ──► Evaluates variables ($VAR), wildcards (*), tildes (~), history (!N)
3. IDENTIFY   ──► Resolves command type: Alias? Builtin? Function? Binary on disk?
4. REDIRECT   ──► Sets up File Descriptors (opens output.txt on FD 1 / stdout via dup2)
5. FORK/EXEC  ──► fork() clones process; execve() replaces child memory with /usr/bin/cat
6. WAIT/REAP  ──► Bash sleeps (waitpid()); child runs; Bash wakes up, captures exit code ($?)
```

#### The Critical Distinction: Builtins vs. Disk Binaries
Not all commands are files on disk!
- **Disk Binaries (`cat`, `ls`, `grep`, `systemctl`)**:
  Compiled ELF executable files stored in `$PATH` (e.g. `/usr/bin/cat`). Bash MUST spawn a new child process via `fork()` + `execve()` to run them.
- **Shell Builtins (`cd`, `export`, `source`, `alias`, `exit`)**:
  Internal C functions compiled *directly into the `bash` executable itself*.
  - **Why `cd` CANNOT be an external binary**: If `/usr/bin/cd` existed as an external binary, Bash would `fork()` a child process. The child would change its own working directory and exit. The parent shell's directory would remain unchanged! Therefore, `cd` MUST run directly inside the parent shell's own process memory.

```bash
# Test how Linux resolves any command:
type cd      # cd is a shell builtin
type cat     # cat is /usr/bin/cat
type ll      # ll is an alias
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

Execute the following commands and observe how the Linux kernel and user space interact.

### 1. Host Architecture & Kernel Privilege Ring
- **Action**: Query the running kernel release, CPU topology, and virtualization instruction sets:
  ```bash
  uname -a
  lscpu | grep -E "Architecture|CPU\(s\)|Model name|Hypervisor"
  ```
- **System Reaction**:
  The kernel executes a system call (`uname(2)`) directly from Ring 0 memory structures. Notice the hypervisor flag: because your VM runs under Hyper-V, the Linux kernel detects Microsoft Hyper-V synthetic virtualization Enlightenment features (`hv_vmbus`) and bypasses legacy BIOS device emulation.
- **The Kernel Compilation Invariant (`=y` Built-In vs. `=m` Loadable Module)**:
  - When you run `lsmod | grep hv_`, it returns **nothing**.
  - *Why?* In Ubuntu 24.04, Canonical compiles Hyper-V drivers directly into the core `vmlinuz` binary (`CONFIG_HYPERV=y`, `CONFIG_HYPERV_STORAGE=y`, `CONFIG_HYPERV_NET=y`) rather than as loadable kernel modules (`=m`).
  - Statically built-in drivers never appear in `lsmod`.
- **Verification**:
  Inspect synthetic VMBus device handles registered directly in `/sys`, check kernel boot telemetry, and inspect the compile-time kernel config:
  ```bash
  # 1. Count and view live VMBus synthetic device handles in sysfs:
  ls /sys/bus/vmbus/devices | wc -l
  ls -l /sys/bus/vmbus/devices/

  # 2. View boot-time hypervisor driver registrations:
  sudo dmesg | grep -i vmbus | grep "registering driver"

  # 3. View the drivers that claimed those 14 synthetic devices:
  ls -l /sys/bus/vmbus/drivers/

  # 4. Verify driver was compiled statically into the kernel (=y):
  grep -E "CONFIG_HYPERV(_STORAGE|_NET)?=" /boot/config-$(uname -r)
  ```
- **Why are there 14 VMBus devices?**:
  In Generation 2 VMs, VMBus is not just for disks and network cards. Hyper-V routes **all guest integration services** over synthetic VMBus channels:
  - `hv_storvsc`: Synthetic SCSI storage (disks & DVD ISO)
  - `hv_netvsc`: Synthetic network adapter
  - `hv_balloon`: Dynamic memory management
  - `hv_utils`: Heartbeat, TimeSync, Guest Shutdown, KVP (how `Get-LabVM` queries the guest IP!), and VSS backup
  - `hyperv_keyboard` & `hid_hyperv`: Synthetic keyboard & mouse
  - `hyperv_drm`: Synthetic display adapter

### 2. Memory & The Page Cache (Why "Free" RAM is a Lie)
- **Action**: Check system memory:
  ```bash
  free -m
  ```
- **System Reaction**:
  In Windows Task Manager, unused RAM sits empty. In Linux, **unused RAM is wasted RAM**.
  The kernel aggressively repurposes idle memory for **Page Cache (`buff/cache`)**, caching recently accessed disk blocks in RAM.
  - When an application demands memory, the kernel evicts clean cache pages in microseconds.
  - **The metric that actually matters is `available`**, NOT `free`.
- **The Warehouse Mental Model (Windows vs. Linux RAM)**:
  - **Active Inventory (`used` / Windows `In Use`)**: Application heaps, stacks, and process memory. Cannot be dropped without crashing or writing to swap/pagefile.
  - **Temporary Staging Pallets (`buff/cache` / Windows `Standby List`)**: Cached disk blocks. Discardable instantaneously ($O(1)$) with zero I/O if a process demands memory.
  - **Empty Concrete (`free`)**: Completely unmapped physical RAM doing zero work.
- **The Rosetta Stone: Windows vs. Linux Memory**:
  | Concept | Windows (Task Manager / RAMMap) | Linux (`free -m` / `/proc/meminfo`) | Operational Invariant |
  | :--- | :--- | :--- | :--- |
  | **Process Working Set** | **In Use** (`Private Bytes`) | **`used`** (`Active(anon)`) | Real memory owned by processes. |
  | **Read Cache** | **Standby List** | **`buff/cache`** (`Cached` + `Buffers`) | Clean disk blocks cached in RAM; evictable in microseconds. |
  | **Dirty Cache** | **Modified List** | **`Dirty`** pages | Memory waiting for kernel flusher threads to commit to disk. |
  | **Untouched RAM** | **Free** | **`free`** | Zero data. Linux intentionally drives this near 1-5%. |
  | **True Usable RAM** | **Available** (`Free` + `Standby`) | **`available`** (`free` + reclaimable cache) | **The primary metric for capacity planning and alerting.** |
  | **Disk Spillover** | **Pagefile** (`pagefile.sys`) | **Swap** (`/swapfile` or partition) | Disk spillover when process memory exceeds physical RAM. |

> [!TIP]
> **The Golden Sysadmin Rule for Memory Alerting**:
> Never trigger alerts on `free < 10%`. A healthy Linux database server will often show less than 2% `free` because the kernel maximizes cache hits. Always alert on **`available < 10%`**.

- **Verification**:
  Generate dummy disk reads and watch the cache grow in real-time:
  ```bash
  cat /proc/meminfo | grep -E "MemAvailable|Cached"
  ```

### 3. In-Memory Kernel Telemetry (`/proc` and `/sys`)
- **Action**: Query kernel parameters and host uptime directly from RAM:
  ```bash
  cat /proc/uptime
  cat /proc/sys/kernel/hostname
  cat /proc/sys/vm/swappiness
  ```
- **System Reaction**:
  These files have a size of `0` bytes on disk (`ls -l /proc/uptime`). When your process issues `read()`, the kernel intercepts the syscall and executes a kernel-side C function that writes the raw data straight into your process's memory buffer.
- **Verification**:
  ```bash
  stat /proc/uptime
  # Notice: Size is 0, IO Block is 1024, regular file, zero disk allocation.
  ```

### 4. Environment Variables & Child Process Isolation
- **Action**: Test variable inheritance between parent and child processes, test unsetting, and recall via history:
  ```bash
  # 1. Define exported variable
  export LAB_NODE="sysadmin-node-01"
  env | grep LAB_NODE

  # 2. Verify child process receives the variable
  bash -c 'echo "Child process sees: $LAB_NODE"'

  # 3. Unset variable and confirm removal
  unset LAB_NODE
  env | grep LAB_NODE || echo "Variable successfully unset"
  ```
- **System Reaction**:
  Both variables live in process memory, but in different structures:
  - **Local Shell Variables (`VAR="val"`)**: Stored in Bash's internal private symbol dictionary. Never passed across process boundaries.
  - **Exported Environment Variables (`export VAR="val"`)**: Added to the process's standard POSIX environment vector (`char **environ`), located at the top of the process memory stack.
  - **Process Execution Boundary**: When Bash spawns a child command, it calls `fork(2)` followed by `execve(2)`. The kernel passes `environ` (`envp`) into the new process's memory space, completely dropping Bash's internal private dictionary.
  - **One-Way Isolation Rule**: Inheritance is strictly top-down. A child process *cannot* modify or export variables into its parent process's environment.
- **Process Memory Architecture (Stack vs. Heap)**:
  Every Linux process runs inside an isolated 64-bit Virtual Address Space:
  ```
  High Memory (0x7FFFFFFFFFFF)
  ┌──────────────────────────────────────────────┐
  │ Kernel Mapping (Ring 0 - Protected)          │
  ├──────────────────────────────────────────────┤
  │ argc, argv, **environ (POSIX env table)      │  <-- Top of User Stack
  ├──────────────────────────────────────────────┤
  │ STACK (grows DOWN ↓ towards heap)            │  <-- Fast, automatic, CPU RSP register
  │   - Function call frames & return addresses  │      Fixed limit (~8 MB, ulimit -s)
  │   - Local primitive variables & pointers     │      Dies when function returns
  ├──────────────────────────────────────────────┤
  │                      ↓↓↓                     │
  │                 (Unmapped Gap)               │
  │                      ↑↑↑                     │
  ├──────────────────────────────────────────────┤
  │ HEAP (grows UP ↑ towards stack)              │  <-- Dynamic allocation (malloc / new)
  │   - Bash internal variable hash table        │      Syscalls: brk() / sbrk() / mmap()
  │   - Long-lived buffers, objects, data        │      Manual lifetime (or memory leak)
  ├──────────────────────────────────────────────┤
  │ BSS / Data Segments (Global variables)       │
  ├──────────────────────────────────────────────┤
  │ Text Segment (Compiled binary machine code)  │  <-- Read-only, executable
  └──────────────────────────────────────────────┘
  Low Memory (0x000000000000)
  ```
  - **The Stack**: Managed directly by CPU hardware via the **`RSP`** (**R**egister **S**tack **P**ointer) CPU register. Allocation takes 1 CPU cycle (`sub rsp, 32`). Short-term execution scratchpad: variables are strictly scoped to their function and evaporate the moment the function returns.
  - **The Heap**: Managed by OS allocators (`glibc`). Flexible in size, lives until explicitly freed. Long-term state: stores data whose size is dynamic or whose lifespan outlasts the function that allocated it. Bash stores its internal variable dictionary here.
  - **The Multi-Process Virtual Memory Sandbox**:
    - Every running process gets its *own* private copy of this `0x0` to `0x7FFF...` address map.
    - Process A (`bash`) and Process B (`nginx`) can both have data at virtual address `0x7ffe0000`.
    - The CPU's hardware **MMU (Memory Management Unit)** uses per-process **Page Tables** (loaded into CPU register `CR3` on context switch) to map identical virtual addresses to completely separate physical DRAM chips.
    - If Process A attempts to read Process B's physical memory, the hardware MMU triggers a Page Fault and the kernel terminates Process A with `SIGSEGV` (Segmentation Fault).
  - **The Mental Model: The Clerk's Desk (Stack) vs. The Filing Cabinet (Heap)**:
    - **The Desk (Stack)**: Fast, tiny, arm's reach. Holds sticky notes, current tool, and tracking index cards ("Customer file is in Drawer 42"). Swept clean the instant the current call ends.
    - **The Filing Cabinet (Heap)**: Massive, slower, back room. Holds the actual 500-page customer file. Survives across many calls.
    - **Neither runs code!** CPU instructions live in the **Text Segment** (`.text`, read-only). The Stack only holds execution tracking and tiny 8-byte pointer cards; the Heap holds the actual payload.
  - **The Bridge: What `export` Actually Does**:
    - **Step 1 (Without `export`)**: `VAR="val"` stores `"val"` in Bash's private Heap hash table with `flags = 0`. It is completely invisible outside this single Bash process.
    - **Step 2 (With `export`)**: `export VAR` flips the internal bit (`flags |= VAR_EXPORTED`) and writes a pointer into the POSIX **`char **environ`** vector (`["VAR=val", "USER=labadmin", ..., NULL]`).
    - **Step 3 (The `fork()` + `execve()` Boundary)**:
      1. Bash calls `fork()` (clones process).
      2. Child calls `execve(binary, argv, envp)`.
      3. The Linux kernel **destroys** the child's inherited address space (old Heap, old symbol tables, unexported variables are erased).
      4. The kernel creates a fresh address space, maps the new binary into `.text`, builds a brand new Stack, and copies **only the `envp` (`environ`) array** directly to the top of the child's new Stack.
      5. The child's C runtime (`crt0`) reads `envp` and initializes its own environment. Unexported variables never cross this bridge.
  - **Memory Reclamation Lifecycle (How Cleanup Works)**:
    - **Stack Cleanup (Instant & Zero-Overhead)**: Managed entirely by pointer math in CPU `RSP`. When a function returns, the CPU increments `RSP` back up in 1 clock cycle (`add rsp, N` / `ret`). The memory is *not* wiped with zeroes; the CPU simply moves the boundary pointer above it, and subsequent function calls overwrite the dead memory.
    - **Heap Cleanup (Manual or GC)**:
      - *Manual (C/C++)*: `free()` returns memory chunks to the application allocator's free-list bins (`ptmalloc`). The allocator typically retains these physical pages to service future `malloc()` calls without making expensive kernel syscalls. Only large contiguous top-of-heap releases trigger `brk()` or `madvise(MADV_DONTNEED)` syscalls to hand physical pages back to the Linux kernel.
      - *Garbage Collected (Go, Java, Python)*: Background GC threads periodically mark live reachable objects from root pointers (Stack & Globals) and sweep or compact dead heap memory, trading CPU cycles to prevent leaks.
    - **The Nuclear Cleanup Rule (Process Termination)**: When a process exits or receives `SIGKILL` (`kill -9`), the Linux kernel destroys the process's entire `mm_struct`, tears down its Page Tables in the MMU, and unconditionally returns **all** physical pages (Stack, Heap, and BSS) to the OS free pool. No memory leak survives process termination.
- **Verification**:
  ```bash
  printenv LAB_NODE
  ```

### 5. POSIX Streams & Administrative Baseline Profile

#### The Problem: Why `sudo echo ... > /var/log/file` Fails (The Shell Redirection Trap)
A universal gotcha in Linux administration:
```bash
sudo uname -r > /var/log/sysadmin/baseline.txt  # FAILS: Permission denied!
```
- **Why it fails**: Remember the 6-step command lifecycle from Section 9! Bash sets up stream redirections (`>`) **before** spawning the command. Because your interactive shell is running as unprivileged user `labadmin`, *your unprivileged shell* attempts to open `/var/log/sysadmin/baseline.txt` for writing. The kernel rejects it with `Permission denied` before `sudo` ever runs!
- **Solution 1 (`sudo bash -c '...'`)**: Spawns a root shell so the shell setting up the redirection has root privileges:
  ```bash
  sudo bash -c 'uname -r > /var/log/sysadmin/baseline.txt'
  ```
- **Solution 2 (`sudo tee`)**: Piped standard input is read by `tee` running as root:
  ```bash
  echo "data" | sudo tee /var/log/sysadmin/baseline.txt
  ```

#### Step 1: Create Audit Directory & Build Baseline Report
- **Action**: Create dedicated log directory and redirect system telemetry:
  ```bash
  # 1. Create directory owned by root
  sudo mkdir -p /var/log/sysadmin

  # 2. Overwrite (>) baseline file with kernel release
  sudo bash -c 'uname -r > /var/log/sysadmin/baseline.txt'

  # 3. Append (>>) memory statistics to baseline
  sudo bash -c 'free -m | grep Mem >> /var/log/sysadmin/baseline.txt'

  # 4. Append (>>) system hostname to baseline
  sudo bash -c 'cat /proc/sys/kernel/hostname >> /var/log/sysadmin/baseline.txt'
  ```
- **System Reaction**:
  - `>` opens with `O_TRUNC` (erases existing contents; starts at byte 0).
  - `>>` opens with `O_APPEND` (preserves existing data; writes to end of file).
- **Verification**:
  ```bash
  cat /var/log/sysadmin/baseline.txt
  ```

#### Step 2: Global Profile Setup via Heredoc (`<< 'EOF'`) & `sudo tee`
Sysadmins need global aliases (`ll`, `ports`) and history timestamps (`HISTTIMEFORMAT`) across all admin sessions.
- **Why `/etc/profile.d/`**: When any user logs in via SSH, `/etc/profile` executes and sources every `*.sh` script in `/etc/profile.d/`. This provides central management without manually editing every user's `~/.bashrc`.
- **What is a Heredoc (`<< 'EOF'`)**: In scripts or automation, you cannot open interactive editors like `nano` or `vim`. A Heredoc feeds multi-line text directly into a command's standard input (`stdin`) until it encounters the delimiter `EOF`.
- **Action**: Write the global profile configuration:
  ```bash
  cat << 'EOF' | sudo tee /etc/profile.d/00-sysadmin.sh
  export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "
  export EDITOR="nano"
  alias ll='ls -lah --color=auto'
  alias ports='ss -tulpn'
  EOF
  ```
  > [!TIP]
  > **Terminal Multi-Line Paste Pitfall**:
  > When pasting multi-line blocks into an SSH terminal, network latency or line-wrap can occasionally drop trailing quotes or duplicate lines, producing `unexpected EOF while looking for matching '"'`. If this occurs, overwrite the file cleanly using discrete single-line commands:
  > ```bash
  > echo 'export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "' | sudo tee /etc/profile.d/00-sysadmin.sh
  > echo 'export EDITOR="nano"' | sudo tee -a /etc/profile.d/00-sysadmin.sh
  > echo "alias ll='ls -lah --color=auto'" | sudo tee -a /etc/profile.d/00-sysadmin.sh
  > echo "alias ports='ss -tulpn'" | sudo tee -a /etc/profile.d/00-sysadmin.sh
  > ```
- **Verification & Activation**:
  - Direct execution (`bash /etc/profile.d/00-sysadmin.sh`) would spawn a child process that sets aliases and exits, leaving your current shell unchanged.
  - To load aliases into your *current active shell*, use the builtin `source` (or `.`):
  ```bash
  source /etc/profile.d/00-sysadmin.sh
  alias ports
  ll /var/log/sysadmin
  ```

---

## The Everyday Sysadmin Toolbox: The 4 Tool Archetypes & When to Use Each

In Windows, GUI tools like Event Viewer, Services MMC, and Task Manager combine viewing, filtering, and management into big monolithic windows.
In Linux, the UNIX philosophy reigns: **Small, specialized tools that do exactly one thing, connected by pipes (`|`).**

Before writing scripts, you must build intuitive muscle memory for the **4 core tool archetypes**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        THE 4 TOOL ARCHETYPES                           │
├─────────────────┬─────────────────┬──────────────────┬─────────────────┤
│ 1. VIEWERS      │ 2. FINDERS      │ 3. SLICERS       │ 4. MONITORS     │
├─────────────────┼─────────────────┼──────────────────┼─────────────────┤
│ cat (dump all)  │ grep (in-file)  │ cut (delimited)  │ top (CPU/RAM)   │
│ head (top N)    │ find (on-disk)  │ awk (whitespace) │ ss (sockets)    │
│ tail (bottom N) │ which (binary)  │ sort (order)     │ df -h (disks)   │
│ less (pager)    │ type (identity) │ wc -l (count)    │ du -sh (dirs)   │
└─────────────────┴─────────────────┴──────────────────┴─────────────────┘
```

---

### The Built-In Discovery Engine: How Linux Teaches You Its Own Tools

You never need to memorize flags or search Google. Linux has its entire reference library built directly into the operating system:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        THE DISCOVERY ENGINE                            │
├─────────────────┬──────────────────────────────────────────────────────┤
│ Command         │ What It Does                                         │
├─────────────────┼──────────────────────────────────────────────────────┤
│ whatis <tool>   │ 1-sentence plain-English definition of the tool      │
│ <tool> --help   │ Quick command-line cheatsheet of flags and options   │
│ man <tool>      │ Full architectural manual (scroll with Space, q quit)│
│ apropos <word>  │ Reverse search: finds commands matching a concept    │
└─────────────────┴──────────────────────────────────────────────────────┘
```

Try these directly in your terminal to see how Linux self-documents:
```bash
whatis head
whatis tail
whatis last
whatis wc
whatis grep
```

---

### Memory Pathways & Etymology: What Are These Tools Actually Doing?

To build permanent intuition, understand the physical metaphor and the kernel mechanism behind each tool:

#### 1. `head` & `tail` (The Animal Metaphor)
- **Mental Model**: Imagine a physical paper document or an animal.
  - The **`head`** is the top of the paper.
  - The **`tail`** is the rear end.
- **Kernel Mechanism**:
  - `head -n 5 /etc/passwd`: The kernel opens the file, reads until it encounters 5 newline characters (`\n`), sends them to stdout, and **immediately closes the file descriptor**. It does not waste CPU reading the rest of the file.
  - `tail -n 5 /etc/passwd`: The kernel seeks directly to the end of the file (`lseek(fd, 0, SEEK_END)`), reads backwards until it finds 5 newlines, and outputs them.
  - `tail -f /var/log/syslog`: **The Follow Monitor**. The kernel does NOT close the file. It registers an `inotify` watch on the file inode. Whenever background daemons append new bytes, the kernel instantly wakes up `tail` to print them to your screen.

#### 2. `last` (The System Timeclock)
- **Mental Model**: *"Who was here last?"*
- **Kernel Mechanism**:
  - `last` does NOT read plaintext.
  - Whenever a user logs in via SSH, logs out, or reboots, the Linux PAM system writes a binary C struct (`struct utmp`) into the system accounting file **`/var/log/wtmp`**.
  - `last` parses that binary database and prints the login history: username, terminal (`pts/0`), client IP address, and session duration.

#### 3. `grep` (Global Regular Expression Print)
- **Mental Model**: In the 1970s UNIX text editor `ed`, the command to search the entire file was:
  **`g/re/p`** (**G**lobally search for **R**egular **E**xpression and **P**rint).
- **Kernel Mechanism**:
  - Streams text through CPU memory line by line.
  - Evaluates each line against a pattern matcher.
  - Lines that match are written to File Descriptor 1 (`stdout`).
  - With `-v` (invert), lines that *fail* to match are written to `stdout`.

#### 4. `wc` (Word Count)
- **Mental Model**: The typesetter's counter (**W**ord **C**ount).
- **Kernel Mechanism**:
  - Streams bytes from `stdin` or a file.
  - `-l`: Counts newline characters (`\n`).
  - `-w`: Counts whitespace-separated words.
  - `-c`: Counts total raw bytes.

---

### Archetype 1: The Viewers (Inspecting Data Safely)

- **`cat` ("Concatenate / Dump")**:
  - *When to use*: Inspecting tiny files (< 30 lines) or feeding files into pipes (`cat /proc/uptime`).
  - *When NEVER to use*: Large files (e.g., `/var/log/syslog`). It dumps 100,000 lines onto your screen, blowing away your terminal scrollback!
- **`head` & `tail` ("Inspect the Boundaries")**:
  - `head -n 5 /etc/passwd`: Shows the first 5 lines.
  - `tail -n 5 /var/log/dpkg.log`: Shows the last 5 lines.
  - `tail -f /var/log/syslog`: **The Live EKG Monitor**. Keeps the file open and prints new log lines in real-time as background daemons write them. Press `Ctrl + C` to stop.
- **`less` ("The Interactive Book Reader")**:
  - *When to use*: Any file longer than one terminal screen.
  - Opens in full-screen pager without dumping text into terminal history:
    - `Space` or `Page Down`: Scroll down.
    - `b` or `Page Up`: Scroll up.
    - `/error` + `[Enter]`: Search forward for "error" (`n` for next match).
    - `q`: Quit cleanly.

---

### Archetype 2: The Finders (Inside Files vs. On Disk)

- **`grep` (Search INSIDE files)**:
  Searches file streams for regex patterns:
  ```bash
  # Find all users with /bin/bash shell:
  grep "bash" /etc/passwd

  # Inverted search (find lines that do NOT match):
  grep -v "nologin" /etc/passwd

  # Case-insensitive search:
  grep -i "error" /var/log/syslog
  ```
- **`find` (Search the FILESYSTEM)**:
  Crawls directory trees on disk by filename, size, or modification date:
  ```bash
  # Find all log files under /var/log:
  find /var/log -name "*.log"

  # Find files larger than 10MB:
  find /var -size +10M
  ```
- **`which` & `type` (Find EXECUTABLES)**:
  - `which nginx`: Shows the absolute disk path of a command (`/usr/sbin/nginx`).
  - `type cd`: Explains whether a command is a binary on disk, an alias, or a shell builtin.

---

### Archetype 3: The Slicers & Counters (Transforming Plaintext)

- **`cut` (Split Delimited Strings)**:
  Best for files with consistent delimiters (like colons `:` or commas `,`):
  ```bash
  # /etc/passwd format is username:password:UID:GID:...
  # Extract only usernames (Field 1, delimiter ':'):
  cut -d: -f1 /etc/passwd
  ```
- **`awk` (Extract Table Columns)**:
  Best for whitespace-aligned tables (like `df -h` or `free -m`):
  ```bash
  # Extract filesystem name (col 1) and use percentage (col 5):
  df -h | awk '{print $1, $5}'
  ```
- **`sort` & `uniq` (Deduplication & Frequency)**:
  ```bash
  # List all login shells in /etc/passwd, sorted and deduplicated with counts:
  cut -d: -f7 /etc/passwd | sort | uniq -c
  ```
- **`wc` (Word & Line Counter)**:
  ```bash
  # Count total users configured on the system:
  wc -l /etc/passwd
  ```

---

### The LEGO Philosophy: Snapping Tools Together

In Linux, you rarely run these tools in isolation. You snap them together with pipes (`|`):

```bash
# Question: How many human users have bash as their login shell?
cat /etc/passwd | grep "/bin/bash" | cut -d: -f1 | sort | wc -l
```
1. `cat` reads the file.
2. `grep` filters lines ending in `/bin/bash`.
3. `cut` extracts only the username column.
4. `sort` sorts them alphabetically.
5. `wc -l` counts the lines.

---

Before writing administrative scripts, you must master the five primitives that connect commands together:

### 1. The Shebang (`#!/bin/bash`)
In Windows, file extensions (`.exe`, `.ps1`, `.bat`) determine how a file runs.
In Linux, **file extensions are purely cosmetic**. A file named `script.txt` can execute just as easily as `script.sh`.
- The first two bytes of an executable script must be **`#!`** (hex `0x23 0x21`, called the **Shebang**).
- When the Linux kernel executes `execve("script.sh")`, it reads those two bytes, extracts the interpreter path following them (`/bin/bash`), and automatically invokes:
  `/bin/bash script.sh`.
- **Rule**: Every bash script must begin with line 1:
  ```bash
  #!/bin/bash
  ```

### 2. Command Substitution (`$(...)`)
How do you capture the output of a command into a variable inside a script?
Use `$()` (command substitution):
```bash
# Capture command outputs into variables:
CURRENT_HOST=$(hostname)
KERNEL_REV=$(uname -r)
```
The shell spawns a subshell, executes the command inside `$()`, captures its standard output stream, and assigns the string to the variable.

### 3. Field & Token Extraction (`cut` vs. `awk`)
Linux system files and commands output tabular or delimited plaintext. Two core tools extract specific columns:
- **`cut` (Delimited fields)**:
  Extracts fields separated by a single delimiter:
  ```bash
  # /proc/uptime outputs: "12345.67 45678.90" (uptime idle_time)
  # Extract first field separated by space:
  UPTIME=$(cat /proc/uptime | cut -d' ' -f1)
  ```
- **`awk` (Whitespace-separated columns)**:
  Extracts specific columns regardless of varying spaces:
  ```bash
  # free -m outputs:
  #               total        used        free      shared  buff/cache   available
  # Mem:           1975         380        1150           2         444        1442
  # Column 7 is 'available':
  AVAIL_MEM=$(free -m | grep Mem | awk '{print $7}')
  ```

### 4. File Execution Permissions (`chmod +x`)
By default, newly created text files in Linux have read and write permissions, but **zero execution permissions** (`-rw-r--r--`).
If you try to run `./script.sh`, the kernel returns `Permission denied`.
To permit execution, add the executable bit (`+x`) to the file inode:
```bash
sudo chmod +x /usr/local/bin/script.sh
```

### 5. Editing in the Terminal (`nano` Basics)
When working on remote headless servers over SSH, you don't have graphical editors:
- Open file: `sudo nano /usr/local/bin/my-script.sh`
- Write or paste your bash code.
- **Save**: Press `Ctrl + O`, then hit `[Enter]` to confirm filename.
- **Exit**: Press `Ctrl + X`.

---

## Part B: Admin Solo Drill (Unguided Mission)

Now it is your turn to act as the systems administrator. **No step-by-step commands or answers are provided for this mission.** Use the concepts above, standard Linux utilities, man pages, or your notes.

### The Mission: Custom Host Telemetry Extractor
The operations team requires an automated host telemetry extractor that records server vitals upon demand.

1. **Customization**:
   - Choose your own script name located in `/usr/local/bin/` (e.g. `audit-host.sh`, `srv-telemetry.sh`, or `node-probe.sh`).
   - Choose your own log file destination under `/var/log/` (e.g. `/var/log/node-status.log` or `/var/log/host-metrics.log`).

2. **Acceptance Criteria**:
   - The script must be located in a dedicated administrative binary directory (e.g., `/opt/ops/bin` or `/srv/tools/bin`).
   - The custom binary directory must be added to your administrative account's `$PATH` via `~/.bashrc`, enabling execution by bare name without specifying the full path.
   - The script must be executable (`chmod 755` or `chmod +x`).
   - When executed, the script must output at least four distinct parameters in `KEY=VALUE` plaintext format:
     - `HOSTNAME=<value>` (Extracted from `/proc` or `hostname`)
     - `KERNEL=<value>` (Extracted from `uname`)
     - `UPTIME_SEC=<value>` (Total seconds of system uptime from `/proc/uptime`)
     - `MEM_AVAILABLE_MB=<value>` (Current available RAM in megabytes from `/proc/meminfo` or `free -m`)
   - If an error occurs during execution, errors must NOT be swallowed silently; standard output must append to your chosen log file, while standard error is redirected to a companion `.err` file.

3. **Self-Verification**:
   Run your script, then execute this verification check to validate your work:
   ```bash
   # Replace with your actual log path
   LOG_FILE="/var/log/node-status.log"

   test -s "$LOG_FILE" && grep -E "HOSTNAME=" "$LOG_FILE" && grep -E "MEM_AVAILABLE_MB=" "$LOG_FILE" && echo "[PASS] Telemetry collector satisfied all acceptance criteria!" || echo "[FAIL] Acceptance criteria missing."
   ```

---

## Milestone Checkpoint

Once you have verified Part A and Part B, **do not reset the VM**. Save your milestone checkpoint from your host PowerShell console:

```powershell
Checkpoint-LabVM -Name "sysadmin-node" -SnapshotName "level-01-complete"
```

In [Level 02](../level-02-identity-users-and-permissions/README.md), we will build identity boundaries, sudoer privilege tiers, and a collaborative application directory tree directly on this server!

---

### Navigation
| [Tier 1: Sysadmin Foundations](../README.md) | [Tutorials Hub](../../README.md) | [Next: Level 02: Identity, Users & Permissions →](../level-02-identity-users-and-permissions/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V Tutorial 01: Host Prerequisites & Silicon](../../hyperv-internals/01-prerequisites-and-hardware/README.md)).*
