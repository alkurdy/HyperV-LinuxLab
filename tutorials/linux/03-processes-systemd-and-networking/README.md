# Lab Tutorial 03: Linux Processes, Systemd Services & Modern Networking

> **[Tutorials Hub](../../README.md)** â€¢ **[Linux Lab Track](../README.md)** â€¢ [â† Previous: Lab 02: Linux Mental Model](../02-linux-mental-model-and-filesystems/README.md) â€¢ [ðŸ“‘ Index](../../README.md) â€¢ [Next: Lab 04: Snapshots & Recovery â†’](../04-snapshots-and-disaster-recovery/README.md)

---
So, you want to manage background daemons, inspect live resource hogs, stream production system logs, and debug network sockets like a seasoned systems engineer?

In this tutorial, we will take control of user-space execution. We will inspect PID 1, manage services with `systemd`, harness Unix text pipes, and master modern `iproute2` networking diagnostics.

---

## 🧭 In This Tutorial:
1. [Process Hierarchy & PID 1 (`pstree`)](#1-process-hierarchy--pid-1)
2. [Process Monitoring with `htop` and `ps aux`](#2-process-monitoring-with-htop-and-ps)
3. [Service Management with `systemd` (`systemctl`)](#3-service-management-with-systemd)
4. [Streaming Logs with `journalctl`](#4-streaming-system-logs-with-journalctl)
5. [The Unix Philosophy: Pipes & Text Filtering (`grep`, `awk`, `jq`)](#5-the-unix-philosophy-pipes-and-text-filtering)
6. [Modern Linux Networking with `iproute2` (`ip`)](#6-modern-linux-networking-with-iproute2)
7. [Listening Sockets & Port Diagnostics (`ss`, `curl`)](#7-listening-sockets--port-diagnostics)

---

## 1. Process Hierarchy & PID 1

So you want to know what controls all programs in Linux? When the kernel boots, it initializes a single ancestor process: **PID 1 (`systemd`)**. Every other program is a child, grandchild, or descendant of PID 1.

Run this drill to visualize the complete process tree:

```bash
pstree -p
```

### What You Will See:
```text
systemd(1)─┬─cron(450)
           ├─dbus-daemon(451)
           ├─networkd-dispatcher(462)
           ├─systemd-journal(280)
           ├─systemd-logind(465)
           ├─systemd-network(430)
           ├─systemd-resolved(432)
           ├─systemd-udevd(305)
           ├─sshd(720)───sshd(1420)───sshd(1425)───bash(1426)───pstree(1502)
           └─unattended-upgr(512)
```
Notice how your SSH session (`bash(1426)`) and your current command (`pstree(1502)`) branch directly out of `sshd(720)`, which in turn branches from `systemd(1)`.

---

## 2. Process Monitoring with `htop` and `ps`

Now that we understand the process tree, let's inspect resource consumption in real time:

### Interactive Monitoring: `htop`
Run `htop` (pre-installed by the Minimal lab profile):

```bash
htop
```
- **CPU Bar**: Core utilization breakdown.
- **MEM Bar**: Memory used vs cached.
- **Tree View**: Press `F5` to toggle hierarchical tree view.
- **Quit**: Press `q` or `F10` to exit.

### Tabular Process Listing: `ps aux`
To take a static snapshot of all running processes:

```bash
ps aux | head -n 10
```
- `USER`: The account executing the binary.
- `PID`: Process identifier.
- `%CPU` / `%MEM`: Resource utilization percentages.
- `VSZ` / `RSS`: Virtual memory vs resident (physical RAM) memory.
- `STAT`: Process state (`S` = Sleeping, `R` = Running, `Z` = Zombie).

---

## 3. Service Management with `systemd`

So you want to start, stop, or restart a background service? Modern Linux distributions manage daemons with `systemctl`.

### The 4 Essential `systemctl` Commands:

| Command | Purpose | Example |
| :--- | :--- | :--- |
| `systemctl status <svc>` | View active state, uptime, and last log entries | `systemctl status ssh` |
| `sudo systemctl restart <svc>` | Restart a running daemon to apply new configs | `sudo systemctl restart ssh` |
| `sudo systemctl enable --now <svc>`| Set to auto-start on boot AND start immediately | `sudo systemctl enable --now cron` |
| `sudo systemctl stop <svc>` | Terminate a running daemon | `sudo systemctl stop cron` |

### Hands-On Drill:
Inspect the OpenSSH daemon keeping your terminal connected:

```bash
systemctl status ssh
```
*(Press `q` to exit the status pager).*

---

## 4. Streaming System Logs with `journalctl`

Now that we know how to manage services, what happens when something fails? In Linux, `systemd-journald` captures binary, tamper-resistant system logs.

```bash
# Stream live logs for the OpenSSH daemon as they happen (follow mode)
journalctl -u ssh -f
```
*(Press `Ctrl + C` to stop streaming).*

```bash
# View all critical and error logs across the entire OS since current boot
journalctl -b -p err..emerg --no-pager
```

---

## 5. The Unix Philosophy: Pipes and Text Filtering

So you want to manipulate raw command output? Programs in Linux are built to do **one thing well** and compose with other tools using **text streams** and the pipe operator (`|`).

### 1. Filtering with `grep`:
```bash
# Filter OS release information for the exact version
cat /etc/os-release | grep "VERSION="
```

### 2. Extracting Columns with `awk`:
```bash
# Print only username (field 1) and default login shell (field 7) from /etc/passwd:
cat /etc/passwd | awk -F: '{print $1 " -> " $7}'
```

### 3. Parsing Structured Data with `jq`:
```bash
# Query GitHub API and extract specific JSON keys
curl -s https://api.github.com/repos/alkurdy/HyperV-LinuxLab | jq '{name: .name, stars: .stargazers_count, default_branch: .default_branch}'
```

---

## 6. Modern Linux Networking with `iproute2`

Forget deprecated legacy utilities like `ifconfig` and `route`. Modern Linux uses the high-performance `iproute2` suite.

### 1. View Assigned IP Addresses:
```bash
ip -br addr
```
```text
lo               UNKNOWN        127.0.0.1/8 ::1/128 
eth0             UP             172.23.108.101/24 fe80::215:5dff:fe01:6a02/64 
```
- `lo`: Local loopback interface (`127.0.0.1`).
- `eth0`: Virtual synthetic Hyper-V network adapter bound to the Windows virtual switch.

### 2. View Kernel Routing Table:
```bash
ip route
```
```text
default via 172.23.108.1 dev eth0 proto dhcp src 172.23.108.101 metric 100 
172.23.108.0/24 dev eth0 proto kernel scope link src 172.23.108.101 metric 100 
```
The `default via ...` route sends all outbound internet traffic through the Windows host's virtual gateway.

---

## 7. Listening Sockets & Port Diagnostics

So you want to know what ports are open? Use `ss` (Socket Statistics):

```bash
ss -tulpn
```
- `-t`: Display TCP sockets.
- `-u`: Display UDP sockets.
- `-l`: Show only listening ports.
- `-p`: Show process name and PID.
- `-n`: Numeric IP and port numbers (avoids slow DNS lookups).

You will see `sshd` bound to `0.0.0.0:22`.

### Verify Outbound Internet Connectivity:
```bash
# Test DNS name resolution
dig +short ubuntu.com

# Fetch HTTP headers from a remote endpoint
curl -I https://ubuntu.com
```

---

### 🧭 Navigation
| [← Previous: Linux Mental Model](../02-linux-mental-model-and-filesystems/README.md) | [📑 All Tutorials](README.md) | [Next: Lab Tutorial 04 - Snapshots & Disaster Recovery →](../04-snapshots-and-disaster-recovery/README.md) |
| :--- | :---: | ---: |

*(Under the hood: Want to know how Windows handles virtual NAT switches and packet routing? Read [Hyper-V Tutorial 03: Virtual Networking & Guest IP Routing](../../hyperv/03-virtual-networking/README.md)).*

---

### ðŸ§­ Navigation
| [â† Previous: Lab 02: Linux Mental Model](../02-linux-mental-model-and-filesystems/README.md) | [ðŸ“‘ Tutorials Index](../../README.md) | [Next: Lab 04: Snapshots & Recovery â†’](../04-snapshots-and-disaster-recovery/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V 03: Virtual Networking](../../hyperv/03-virtual-networking/README.md)).*
