# Tutorial 2: Linux Operating System Essentials & Mental Model

Now that you are logged into your Linux prompt (`labadmin@linux-sandbox:~$`), this guide builds your mental model of how Linux works under the hood so you can troubleshoot systems, run containers, and administer Kubernetes with confidence.

---

## 1. The Linux Mental Model

Unlike Windows, where GUI subsystems, registries, and DLLs are deeply interwoven, Linux is built on a clear, layered hierarchy:

```
┌────────────────────────────────────────────────────────┐
│ USER SPACE (Applications: bash, docker, nginx, htop)   │
└───────────────────────────┬────────────────────────────┘
                            │ System Calls (syscalls: open, read, fork, exec)
┌───────────────────────────▼────────────────────────────┐
│ LINUX KERNEL (Memory, CPU scheduling, Drivers, Network)│
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ HARDWARE (CPU, RAM, Hyper-V Virtual Disks & NICs)      │
└────────────────────────────────────────────────────────┘
```

### Key Takeaways:
1. **The Kernel**: Controls hardware, allocates memory, schedules CPU cycles, and manages network packets. You never touch the kernel directly; you communicate through **system calls**.
2. **The Shell (`bash`)**: A text-based command interpreter that reads your commands and asks the kernel to run programs.
3. **PID 1 (`systemd`)**: The very first process started by the kernel. It spawns, monitors, and stops all background services (daemons), including SSH and Docker.

---

## 2. "Everything is a File" & The Filesystem Hierarchy

In Windows, storage is divided into drive letters (`C:\`, `D:\`). In Linux, there are **no drive letters**. Everything begins at the root directory: `/`.

Hardware devices, running kernel metrics, and network sockets all present themselves as files.

```text
/ (Root Directory)
├── etc/         System configurations (plain-text files: network, users, ssh)
├── var/         Variable data (logs in /var/log, docker containers in /var/lib/docker)
├── home/        User home directories (/home/labadmin)
├── proc/        Virtual filesystem: live view of running kernel and process stats
├── sys/         Virtual filesystem: live view of hardware and kernel drivers
├── dev/         Device nodes (disks: /dev/sda, terminals: /dev/pts)
├── usr/         User binaries, libraries, and documentation (/usr/bin)
└── tmp/         Temporary scratch files (cleared on reboot)
```

### 🎯 Hands-On Drill: Inspect the Pseudo-Filesystems
Run these commands right now in your Linux terminal:

```bash
# View CPU hardware info directly from the kernel
cat /proc/cpuinfo | grep "model name"

# View current live memory usage
cat /proc/meminfo | head -n 5

# View network interface statistics maintained by kernel
cat /proc/net/dev
```
*Notice: `/proc` does not take up any disk space. The kernel generates these files on the fly when you read them.*

---

## 3. User Identity, Permissions, and `sudo`

Linux is a multi-user operating system with strict permission boundaries.

### Check Your Identity:
```bash
whoami
# Output: labadmin

id
# Shows your User ID (uid=1000), Primary Group (gid=1000), and supplementary groups (sudo, docker)
```

### The Permission Grid: `rwx`
Every file and directory in Linux has three tiers of permissions:
1. **User (Owner)**: What the creator can do.
2. **Group**: What members of the file's assigned group can do.
3. **Others**: What everyone else on the system can do.

```bash
ls -l /etc/shadow
# Output: -rw-r----- 1 root shadow 1240 Oct 30 15:00 /etc/shadow
```
- `-rw-r-----`: 
  - Owner (`root`) can **read** and **write** (`rw-`).
  - Group (`shadow`) can **read** (`r--`).
  - Others have **zero access** (`---`).
- Try reading it without privileges:
  ```bash
  cat /etc/shadow
  # Permission denied!
  ```
- Now use `sudo` (Super User Do) to elevate temporarily:
  ```bash
  sudo cat /etc/shadow
  # Success! Displays encrypted system password hashes.
  ```

---

## 4. Service Management with `systemd`

In modern Linux, `systemd` manages all background services, boot sequences, and daemons.

### The 4 Essential `systemctl` Commands:

| Command | Purpose | Example |
| :--- | :--- | :--- |
| `systemctl status <service>` | Check if a daemon is running and view recent logs | `systemctl status ssh` |
| `systemctl restart <service>` | Apply configuration changes | `sudo systemctl restart ssh` |
| `systemctl enable --now <service>` | Enable service to auto-start on boot and start it now | `sudo systemctl enable --now docker` |
| `journalctl -u <service> -f` | Stream live logs for a specific service | `journalctl -u ssh -f` |

### 🎯 Hands-On Drill:
```bash
# Inspect the OpenSSH daemon currently keeping your session alive
systemctl status ssh
```
*(Press `q` to exit the status pager).*

---

## 5. The Unix Philosophy: Pipes and Text Streams

Programs in Linux are designed to do **one thing well** and combine with other tools using **text streams**.

Every Linux command has three standard I/O channels:
- `stdin` (0): Standard Input (keyboard)
- `stdout` (1): Standard Output (screen)
- `stderr` (2): Standard Error (error messages)

### The Pipe Operator (`|`)
Connects the `stdout` of one command directly into the `stdin` of the next:

```bash
# 1. List all running processes
# 2. Filter for only ssh processes
# 3. Count how many instances exist
ps aux | grep ssh | wc -l
```

### High-Yield Filtering Utilities:
- **`grep`**: Filters lines matching a pattern.
  ```bash
  cat /etc/os-release | grep "VERSION="
  ```
- **`awk`**: Extracts columns from tabular text.
  ```bash
  # Print only username and default shell from /etc/passwd:
  cat /etc/passwd | awk -F: '{print $1 " -> " $7}'
  ```
- **`jq`**: Parses JSON structures (pre-installed by your profile).
  ```bash
  curl -s https://api.github.com/repos/alkurdy/HyperV-LinuxLab | jq '{name: .name, stars: .stargazers_count}'
  ```

---

## 6. Modern Linux Networking Diagnostics

Forget legacy tools like `ifconfig` and `netstat` (deprecated on modern Linux). Use the `iproute2` suite:

### 1. View IP Addresses:
```bash
ip -br addr
```
- `lo`: Local loopback interface (`127.0.0.1`).
- `eth0`: Virtual Hyper-V network adapter communicating with your Windows host.

### 2. View Active Listening Ports:
```bash
ss -tulpn
```
- Shows every port open on your system (`-t` TCP, `-u` UDP, `-l` listening, `-p` process name, `-n` numeric ports).
- You will see `sshd` listening on port `22`.

### 3. Test Network Reachability:
```bash
# Test DNS resolution
dig +short google.com

# Inspect HTTP headers from remote server
curl -I https://ubuntu.com
```

---

## 7. Next Step: Container & Kubernetes Muscles

Now that you understand the Linux filesystem, permissions, systemd, and networking, you have the exact foundation needed to understand containers:
- **What is a Docker container?** Simply a standard Linux process isolated using **namespaces** (what it can see) and **cgroups** (what resources it can use).
- **What is Kubernetes?** A cluster orchestrator that schedules those isolated processes across multiple Linux nodes.

You can now stand up containers or multi-node clusters anytime using:
```powershell
New-LabVM -Name "container-node" -Profile "Container" -Start
```
or launch the full 3-node cluster from Tutorial 1:
```powershell
New-LabCluster -Path .\examples\k8s-3node-cluster.json
```
