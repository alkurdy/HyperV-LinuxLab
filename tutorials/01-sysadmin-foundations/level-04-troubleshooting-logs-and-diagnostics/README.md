# Level 04: Troubleshooting, Logging & Diagnostics Engineering

> **[Tier 1: Sysadmin Foundations](../README.md)** • Grounded in *Site Reliability Engineering* & *Linux Cookbook* (Schroder).

---

## Objective
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
cat /proc/$(pgrep -f "systemd" | head -n 1)/oom_score
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

## Hands-On Lab: Live Incident Triage Under Pressure

We continue on **`sysadmin-node`** from Level 03. Connect via SSH:
```powershell
ssh labadmin@<VM_IP>
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

In this drill, we simulate a severe storage leak on our `/srv/app` volume from Level 03, diagnose why standard tools disagree, trace the culprit with `lsof` and `journalctl`, and recover the filesystem live.

### 1. Simulate the Unlinked File Handle Leak
- **Action**: Create a 200MB file on `/srv/app`, open it with a background Python process, and immediately delete it with `rm`:
  ```bash
  # Check initial free space on /srv/app
  df -h /srv/app

  # Allocate 200MB on /srv/app
  sudo dd if=/dev/urandom of=/srv/app/leak.dat bs=1M count=200

  # Open the file descriptor in a background process
  python3 -c "f = open('/srv/app/leak.dat'); import time; time.sleep(600)" &
  LEAK_PID=$!

  # Delete the file while the python process holds it open
  sudo rm -f /srv/app/leak.dat
  ```
- **System Reaction**:
  `rm` issues the `unlink(2)` syscall. The VFS removes the filename `leak.dat` from the `/srv/app` directory inode table. However, because `LEAK_PID` still holds an open file descriptor pointing to the inode, the kernel's reference counter remains `1`. **The disk blocks are NOT freed.**
- **Verification**:
  Notice the discrepancy between `ls` and `df`:
  ```bash
  ls -l /srv/app/leak.dat
  # Returns: No such file or directory!

  df -h /srv/app
  # Notice: The 200MB is STILL consumed!
  ```

### 2. Expose the Phantom File via `lsof +L1`
- **Action**: Query the kernel's open file descriptor table for unlinked files with link count less than 1:
  ```bash
  sudo lsof +L1 | grep "/srv/app"
  ```
- **System Reaction**:
  `lsof` inspects `/proc/*/fd/` across all running processes. It surfaces the exact process name, PID, file descriptor number, size, and marks it as `(deleted)`.
- **Verification**:
  ```bash
  # Inspect the file descriptor directly in the /proc filesystem
  ls -l /proc/$LEAK_PID/fd
  ```

### 3. Recover Disk Capacity Live Without Rebooting
- **Action**: Terminate the rogue process and observe the immediate kernel block recovery:
  ```bash
  # Terminate rogue process
  kill -15 $LEAK_PID

  # Verify open file descriptors are released
  sudo lsof +L1 | grep "/srv/app" || echo "[OK] All deleted handles released!"
  ```
- **System Reaction**:
  When process `$LEAK_PID` terminates, the kernel invokes `exit(2)`, which automatically closes all open file descriptors for that process. The inode reference counter drops from `1` to `0`. The ext4 filesystem driver frees the data block bitmaps and returns the 200MB back to the free pool immediately!
- **Verification**:
  ```bash
  df -h /srv/app
  # The 200MB capacity is instantly reclaimed!
  ```

### 4. Query Structured Logs via `journalctl`
- **Action**: Filter authentication logs for failed login attempts and examine boot logs:
  ```bash
  # Check system error log messages from current boot
  sudo journalctl -b -p err..emerg -n 20

  # Query auth logs for failed login attempts
  sudo grep -i "failed" /var/log/auth.log | tail -n 10 || echo "Clean auth state."
  ```
- **System Reaction**:
  `journalctl` queries the binary structured database in `/run/log/journal/`. Because the journal is indexed by metadata fields (`_PID`, `_UID`, `_SYSTEMD_UNIT`, `PRIORITY`), lookups finish in milliseconds without linear file scanning.

---

## Part B: Admin Solo Drill (Unguided Mission)

Now complete an independent troubleshooting mission without answers provided.

### The Mission: Inode Saturation Triage & Incident Audit
A misbehaving script has flooded `/srv/app/tmp` with thousands of zero-byte session tokens, threatening an Inode exhaustion outage.

1. **Customization & Setup**:
   Simulate the issue by generating 5,000 empty session files inside `/srv/app/tmp`:
   ```bash
   sudo mkdir -p /srv/app/tmp
   sudo bash -c 'for i in $(seq 1 5000); do touch /srv/app/tmp/sess_$i.tmp; done'
   ```

2. **Acceptance Criteria**:
   - Check the inode consumption on `/srv/app` using `df -i`.
   - Identify which directory is consuming the excessive inode count without scanning the entire disk.
   - Safely purge all temporary session files (`*.tmp`) older than 0 minutes inside `/srv/app/tmp` without deleting the directory or affecting other files.
   - Generate an incident summary report in `/var/log/sysadmin/incident-report.txt` stating the timestamp, the number of files purged, and the current inode free percentage on `/srv/app`.

3. **Self-Verification**:
   Execute this check to validate your remediation:
   ```bash
   REPORT="/var/log/sysadmin/incident-report.txt"

   # Check 1: Inodes cleaned
   REMAINING=$(find /srv/app/tmp -type f -name "*.tmp" | wc -l)
   test "$REMAINING" -eq 0 && echo "[PASS] Inode exhauster files purged" || echo "[FAIL] Still $REMAINING files present!"

   # Check 2: Incident report generated
   test -s "$REPORT" && grep -E "INODE|PURGED" "$REPORT" >/dev/null && echo "[PASS] Incident report verified" || echo "[FAIL] Missing incident report"
   ```

---

## Milestone Checkpoint

Save your milestone snapshot from host PowerShell:

```powershell
Checkpoint-LabVM -Name "sysadmin-node" -SnapshotName "level-04-complete"
```

In [Level 05](../level-05-processes-systemd-and-signals/README.md), we will build a real production systemd service that runs under the `svc-app` service account (from Level 02), logs to `/var/log/app` on the storage volume (from Level 03), and handles POSIX process signals with automatic self-healing restart!

---

### Navigation
| [← Previous: Level 03: Directory Hierarchy & Storage](../level-03-directory-hierarchy-and-storage/README.md) | [Tier 1: Sysadmin Foundations](../README.md) | [Next: Level 05: Processes, Systemd & Signals →](../level-05-processes-systemd-and-signals/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V Tutorial 06: VM Lifecycle & Telemetry](../../hyperv-internals/06-vm-lifecycle-and-telemetry/README.md)).*
