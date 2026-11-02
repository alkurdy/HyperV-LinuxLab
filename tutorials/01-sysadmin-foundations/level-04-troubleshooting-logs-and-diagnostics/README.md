# Level 04: Troubleshooting, Logging & Diagnostics Engineering

> **Tier 1: Sysadmin Foundations** • Grounded in *Site Reliability Engineering* & *Linux Cookbook* (Schroder).

---

## 🎯 Objective
Learn where Linux records failures, how to parse system logs, how to query systemd journal archives, how to detect hardware and kernel panic events via `dmesg`, and how to triage high-severity production outages (OOM Killer, Inode exhaustion, and unlinked open file handle leaks).

---

## 1. The Linux Logging Architecture: Journald vs Syslog

In Windows, all events flow through the Windows Event Log service (`Event Viewer` / `Get-WinEvent`).
In Linux, logging is structured into two coordinated layers:

```
Applications / Daemons / Kernel (printk)
                     │
                     ▼
          systemd-journald (Socket: /run/systemd/journal/socket)
          Binary structured indexed logs (/var/log/journal/)
                     │
                     ▼ (Forwarded via socket)
             rsyslog / syslog-ng
          Plaintext category logs (/var/log/*.log)
```

1. **`systemd-journald`**: Captures stdout, stderr, syslog calls, and kernel messages into binary indexed journal files.
2. **Traditional Syslog (`rsyslog`)**: Reads from journald and sorts logs into plaintext files in `/var/log/` for legacy compatibility.

---

## 2. The `/var/log` Directory Topography

When troubleshooting across different Linux distributions, know where each family routes plaintext logs:

| Purpose | Debian / Ubuntu | RHEL / CentOS / AlmaLinux |
| :--- | :--- | :--- |
| **General System Activity** | `/var/log/syslog` | `/var/log/messages` |
| **Authentication & SSH Logins** | `/var/log/auth.log` | `/var/log/secure` |
| **Kernel Ring Buffer** | `/var/log/dmesg` / `dmesg` | `/var/log/dmesg` / `dmesg` |
| **Boot Process** | `/var/log/boot.log` | `/var/log/boot.log` |
| **Package Manager Actions** | `/var/log/dpkg.log` | `/var/log/dnf.log` |
| **Security Auditing** | `/var/log/audit/audit.log` | `/var/log/audit/audit.log` |

---

## 3. High-Yield `journalctl` Command Arsenal

`journalctl` is the single most powerful diagnostic utility on a modern Linux host:

```bash
# 1. Real-time log stream for a specific service (equivalent to tail -f)
journalctl -u nginx.service -f

# 2. Inspect logs from the CURRENT boot only
journalctl -b

# 3. CRITICAL POST-MORTEM: Inspect logs from the PREVIOUS boot (before a crash/reboot)
journalctl -b -1

# 4. Filter strictly by Syslog priority (0=Emergency, 1=Alert, 2=Crit, 3=Err)
journalctl -p err..emerg

# 5. Filter by timeframe
journalctl --since "30 minutes ago"
journalctl --since "2026-11-01 14:00:00" --until "2026-11-01 14:30:00"

# 6. View kernel events logged by journald
journalctl -k

# 7. Reverse chronological output (newest logs first)
journalctl -u ssh -r -n 50
```

---

## 4. Kernel Telemetry & The OOM (Out Of Memory) Killer

The Linux kernel buffers low-level hardware events, PCIe link renegotiations, and memory allocation traps in an in-memory ring buffer accessible via `dmesg`.

### The Out-Of-Memory (OOM) Killer Trap
When physical RAM and swap are 100% saturated, the kernel cannot allocate a single memory page to execute code. Rather than kernel panicking the entire server, the kernel invokes the **OOM Killer** (`oom-killer`):
1. Calculates `oom_score` for every running process (based on RAM usage and runtime).
2. Selects the process with the highest score (usually a runaway Java JVM, Node.js, or database).
3. Sends an uncatchable `SIGKILL` (Signal 9) to abruptly terminate the process and recover memory!

```bash
# Inspect kernel buffer with human-readable timestamps (-T)
sudo dmesg -T | head -n 20

# Check if the OOM Killer executed and killed a service
sudo dmesg -T | grep -i -E "oom|out of memory|killed process"

# View process OOM scores (higher = more likely to be killed first)
cat /proc/$(pgrep nginx | head -n 1)/oom_score
```

---

## 5. Classic Enterprise Linux Storage Outages

### Outage A: The Inode Exhaustion Trap ("No space left on device", but `df -h` shows 50% free!)
Every file on an ext4/xfs filesystem requires an **Inode** (metadata record holding permissions, timestamps, and data block pointers). The number of inodes is determined when the filesystem is formatted.
- If an application generates millions of 0-byte temporary files or uncollected session tokens, the filesystem runs out of inodes even though gigabytes of storage remain free!

```bash
# Diagnostic command: Check Inode utilization percentage
df -ih

# Find which directory is consuming millions of inodes
sudo find / -xdev -printf '%h\n' | sort | uniq -c | sort -k1 -n | tail -n 10
```

### Outage B: The Deleted File Handle Leak (Disk is 100% full, but `du` cannot find any large files!)
In Linux, deleting a file (`rm huge_log.log`) merely removes the directory entry (unlinks it). **The physical data blocks are NOT released back to the filesystem if a running process still holds an open file descriptor to that file.**
- If you delete a 50GB log file while `nginx` or `app.py` is still actively writing to it, the disk remains 100% full!

```bash
# Diagnostic command: Find open file handles pointing to deleted unlinked files
sudo lsof +L1

# How to resolve without rebooting or restarting the service:
# 1. Identify the PID and File Descriptor from lsof output (e.g. PID 1420, FD 3)
# 2. Truncate the file to zero bytes via the /proc filesystem:
sudo truncate -s 0 /proc/1420/fd/3
```

---

## 6. Log Rotation: `/etc/logrotate.d/`

To prevent `/var/log` from consuming 100% of the root disk, Linux executes `logrotate` via cron/systemd timers:

```bash
# Inspect logrotate configuration for Nginx or Syslog
cat /etc/logrotate.d/rsyslog

# Force a manual dry-run of logrotate with verbose debug output
sudo logrotate -d /etc/logrotate.conf

# Force immediate execution
sudo logrotate -f /etc/logrotate.conf
```

---

## 🛠️ Hands-On Lab Drill: Diagnostic Triage Under Pressure

Deploy or reuse your lab VM (`New-LabVM -Name "drill-04" -Start`):

> [!TIP]
> **Safety Net: Snapshot Before Simulating Outages**  
> Before leaking open file handles or running processes out of memory, take a snapshot:
> ```powershell
> Checkpoint-LabVM -Name "drill-04" -SnapshotName "pre-outage-drill"
> ```
> Revert instantly if the system becomes unresponsive:
> ```powershell
> Restore-LabVM -Name "drill-04" -SnapshotName "pre-outage-drill" -Force
> ```
> Consolidate when finished:
> ```powershell
> Remove-LabCheckpoint -Name "drill-04" -All -Force
> ```

```bash
# 1. Investigate authentication logs for failed login attempts
# (Simulate a failed login by attempting SSH with an invalid user)
sudo grep -i "failed" /var/log/auth.log | tail -n 10

# 2. Simulate Outage B (Open File Descriptor Leak)
# Create a 200MB file and hold it open with a background python process
dd if=/dev/urandom of=/tmp/leak.dat bs=1M count=200
python3 -c "f = open('/tmp/leak.dat'); import time; time.sleep(300)" &
PY_PID=$!

# Now delete the file while python holds it open
rm /tmp/leak.dat

# Verify the file is invisible to 'ls' but still consuming disk space
ls /tmp/leak.dat  # Returns: No such file or directory!

# Run diagnostic tool to expose the phantom file
sudo lsof +L1 | grep leak.dat
# Notice: reports (deleted) and displays the size!

# Kill the rogue process to finally release the disk blocks
kill -9 $PY_PID
sudo lsof +L1 | grep leak.dat # Gone! Disk blocks recovered.
```
