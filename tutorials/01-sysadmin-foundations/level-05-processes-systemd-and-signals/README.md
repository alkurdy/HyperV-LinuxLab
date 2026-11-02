# Level 05: Process Lifecycle, Signals & Systemd Service Management

> **[Tier 1: Sysadmin Foundations](../README.md)** • Grounded in *Operating Systems: Internals and Design Principles* (Stallings) & *Linux Cookbook* (Schroder).

---

## Objective
Master process creation, process states, and process termination mechanics. Understand POSIX inter-process signals (`SIGTERM`, `SIGKILL`, `SIGHUP`), control daemon units with `systemctl`, write production-grade `systemd` service files, and implement systemd timers.

---

## 1. Process Hierarchy & Process States

In Windows, processes run under the Session Manager subsystem (`smss.exe`) and Services Control Manager (`services.exe`).
In modern Linux, **every process traces its lineage to PID 1 (`systemd`)**:

```
                              systemd (PID 1)
             ┌──────────────────────┼──────────────────────┐
             ▼                      ▼                      ▼
         sshd (PID 840)      chronyd (PID 720)       cron (PID 710)
             ▼
        sshd [priv]
             ▼
        sshd: labadmin
             ▼
         bash (PID 1820)
             ▼
         top (PID 2410)
```

### The 5 Core Process Execution States
When viewing processes with `ps aux` or `top`, the `STAT` column displays:
- **`R` (Running / Runnable)**: Actively executing instructions on a CPU core or sitting in the CPU scheduler runqueue.
- **`S` (Interruptible Sleep)**: Waiting for an event, timer, network packet, or user input. Can be woken up by a signal.
- **`D` (Uninterruptible Sleep - D-State)**: Waiting on hardware I/O (usually an NFS timeout, failing SATA controller, or synchronous disk flush). **A process in D-state CANNOT be killed, even with `kill -9`!** It only terminates when the kernel device driver completes or times out the I/O request.
- **`Z` (Zombie Process)**: The process has terminated its code, but its entry remains in the kernel process table because its parent has not yet called `wait()` to read its exit code. Zombies consume no RAM or CPU, but consume PID table slots!
- **`T` (Stopped / Traced)**: Paused by a signal (e.g., `SIGSTOP` or `Ctrl+Z` in the shell) or attached to a debugger like `gdb` or `strace`.

---

## 2. Process Inspection Arsenal

```bash
# Display full process tree with PIDs (visually exposes parent-child ancestry)
pstree -p

# Standard POSIX snapshot: User, PID, %CPU, %MEM, Virtual Size, Resident Size, State, Command
ps aux | head -n 15

# View process hierarchy in ASCII tree with parent PIDs (PPID)
ps -ef --forest

# Find PID of a service by name
pgrep -l sshd

# Sort processes by memory consumption (Resident Set Size - RSS)
ps aux --sort=-%mem | head -n 10
```

---

## 3. POSIX Signals: Talking to Running Processes

Processes communicate asynchronously via integer **Signals**. Administrators use `kill` (or `pkill`) to deliver signals:

| Signal Name | Number | Keyboard | Purpose & Behavior |
| :--- | :---: | :---: | :--- |
| **`SIGTERM`** | `15` | None | **Default graceful termination request**. Tells application to finish current transactions, flush disk buffers, close database sockets, and exit cleanly. |
| **`SIGKILL`** | `9` | None | **Unconditional kernel destruction**. Does NOT notify the application. Kernel tears down memory pages immediately. Used when an application is frozen or unresponsive to SIGTERM. |
| **`SIGHUP`** | `1` | None | **Hangup / Configuration Reload**. Tells daemons (like `sshd`, `nginx`, `systemd`) to reload configuration files from disk without dropping existing active connections. |
| **`SIGINT`** | `2` | `Ctrl + C` | **Interrupt**. Politely interrupts the current foreground terminal task. |
| **`SIGSTOP`** | `19` | `Ctrl + Z` | **Freeze / Pause**. Suspends process execution; resume later with `SIGCONT` (18) or `fg`. |

```bash
# Request graceful shutdown of a rogue process
kill -15 2840

# Force immediate termination of a frozen process
kill -9 2840

# Signal a service to reload its configuration files without downtime
sudo pkill -1 nginx
# Equivalent systemd command:
sudo systemctl reload nginx
```

---

## 4. Systemd Architecture & Unit Management

`systemd` manages system initialization, services (`.service`), storage mount points (`.mount`), network sockets (`.socket`), and timers (`.timer`).

### The Systemd Command Dictionary

```bash
# Query detailed service status, active state, recent logs, and cgroup PID list
sudo systemctl status ssh

# Start, Stop, and Restart units
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx

# Reload service configuration without stopping connections
sudo systemctl reload nginx

# Enable service to start automatically on system boot
sudo systemctl enable nginx

# Enable and start immediately in a single command
sudo systemctl enable --now nginx

# Disable automatic boot startup
sudo systemctl disable nginx

# Check if a service is actively running (returns 0 if running, non-zero if stopped)
systemctl is-active nginx
```

---

## 5. Authoring Production Systemd Service Units

Custom units belong in `/etc/systemd/system/`. Never edit vendor unit files in `/usr/lib/systemd/system/` (they are overwritten during package upgrades!).

```ini
[Unit]
Description=My Enterprise Application Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=svc-app
Group=appteam
WorkingDirectory=/srv/app
ExecStart=/usr/bin/python3 /srv/app/bin/app.py
Restart=always
RestartSec=3s
Environment=PORT=8080
StandardOutput=journal
StandardError=journal

# Hardening Directives
ProtectSystem=full
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

### The Three Service Deployment Commands
Whenever you create or modify a `.service` file:
```bash
# 1. Inform systemd of changes on disk (CRITICAL STEP)
sudo systemctl daemon-reload

# 2. Enable service at boot
sudo systemctl enable myapp.service

# 3. Start the service
sudo systemctl start myapp.service
```

---

## Hands-On Lab: Deploying a Self-Healing Service

We continue on **`sysadmin-node`** from Level 04. In Level 02, we provisioned `svc-app` and `appteam`. In Level 03, we mounted dedicated storage to `/srv/app`. Now, we build a production systemd daemon running under that service user, logging to `/var/log/app`, and testing its self-healing reaction under process failure.

Connect via SSH:
```powershell
ssh labadmin@<VM_IP>
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

In this drill, we author an application daemon, wrap it in a systemd service, verify user isolation and cgroup confinement, and crash the process to observe systemd's automatic self-healing resurrection.

### 1. Create the Application Daemon Script
- **Action**: Author an application worker script inside `/srv/app/bin/` running under our `appteam` permissions:
  ```bash
  sudo mkdir -p /srv/app/bin
  cat << 'EOF' | sudo tee /srv/app/bin/worker.sh
  #!/usr/bin/env bash
  echo "[$(date)] Worker initialized under PID $$ as user $(whoami)" >> /var/log/app/worker.log
  while true; do
      echo "[$(date)] Heartbeat from PID $$" >> /var/log/app/worker.log
      sleep 2
  done
  EOF
  sudo chmod +x /srv/app/bin/worker.sh
  sudo chown -R svc-app:appteam /srv/app/bin
  ```
- **System Reaction**:
  The script resides on the persistent Ext4 partition mounted at `/srv/app` from Level 03. Ownership belongs to `svc-app:appteam` with SGID inheritance.
- **Verification**:
  ```bash
  ls -l /srv/app/bin/worker.sh
  ```

### 2. Author the Production Systemd Service Unit
- **Action**: Create `/etc/systemd/system/production-app.service` configured with `User=svc-app`, working directory `/srv/app`, and automatic restart:
  ```bash
  cat << 'EOF' | sudo tee /etc/systemd/system/production-app.service
  [Unit]
  Description=Production Enterprise App Daemon
  After=network.target

  [Service]
  Type=simple
  User=svc-app
  Group=appteam
  WorkingDirectory=/srv/app
  ExecStart=/srv/app/bin/worker.sh
  Restart=always
  RestartSec=2s
  StandardOutput=journal
  StandardError=journal

  [Install]
  WantedBy=multi-user.target
  EOF
  ```
- **System Reaction**:
  Creating the file in `/etc/systemd/system/` registers an administrator-level unit definition with precedence over package vendor defaults in `/usr/lib/systemd/system/`.

### 3. Register and Start the Daemon
- **Action**: Notify systemd of the new unit on disk and start the service:
  ```bash
  sudo systemctl daemon-reload
  sudo systemctl enable --now production-app.service
  ```
- **System Reaction**:
  - `systemctl daemon-reload` causes systemd (PID 1) to parse all unit files, rebuild its dependency graph, and create in-memory unit objects.
  - `systemctl enable` creates a symbolic link in `/etc/systemd/system/multi-user.target.wants/`.
  - `systemctl start` forks a child process from PID 1, drops root privileges to `svc-app` (`setuid/setgid`), creates a dedicated Control Group (cgroup) slice, and executes the binary.
- **Verification**:
  Inspect status, cgroup slice, and log output:
  ```bash
  sudo systemctl status production-app.service
  tail -n 5 /var/log/app/worker.log
  ```

### 4. Test Self-Healing Resilience: Crash with `SIGKILL`
- **Action**: Discover the worker process PID and kill it abruptly with `kill -9` (`SIGKILL`):
  ```bash
  # Identify PID
  INITIAL_PID=$(pgrep -f "worker.sh")
  echo "Current active PID: $INITIAL_PID"

  # Crash the process with SIGKILL (unconditional kernel kill)
  sudo kill -9 $INITIAL_PID

  # Pause 3 seconds to let systemd react
  sleep 3

  # Re-check status
  NEW_PID=$(pgrep -f "worker.sh")
  echo "Resurrected PID: $NEW_PID"
  ```
- **System Reaction**:
  When `$INITIAL_PID` receives `SIGKILL`, the kernel destroys its memory pages without warning. Systemd's `epoll` listener detects the death of its child process via the Linux cgroup controller. Recognizing `Restart=always`, systemd waits 2 seconds (`RestartSec=2s`), forks a new worker process, and updates journald with the recovery event!
- **Verification**:
  ```bash
  test "$INITIAL_PID" -ne "$NEW_PID" && echo "[OK] Self-healing verified! PID shifted from $INITIAL_PID to $NEW_PID"
  journalctl -u production-app.service -n 5
  ```

---

## Part B: Admin Solo Drill (Unguided Mission)

Now complete an independent systemd automation mission without answers provided.

### The Mission: Housekeeping Daemon & Systemd Timer
Operations requires an automated scheduled maintenance task to archive stale logs in `/var/log/app` every few minutes, managed via a modern **Systemd Timer** (`.timer`) instead of legacy cron.

1. **Customization & Setup**:
   - Create a maintenance script `/srv/app/bin/maintenance.sh` that appends a timestamped heartbeat to `/var/log/app/maintenance.log` and prunes any `*.tmp` files from `/srv/app/tmp`.
   - Ensure the script is executable and owned by `svc-app:appteam`.

2. **Acceptance Criteria**:
   - Create a companion oneshot service `/etc/systemd/system/app-maintenance.service` (`Type=oneshot`, `User=svc-app`, `ExecStart=/srv/app/bin/maintenance.sh`).
   - Create a timer unit `/etc/systemd/system/app-maintenance.timer` that triggers the companion service periodically (e.g. `OnUnitActiveSec=2m` or `OnCalendar=*:0/2`).
   - Reload systemd and enable/start the timer (`app-maintenance.timer`).
   - The timer must appear in `systemctl list-timers` in an `active (waiting)` state with a scheduled countdown.

3. **Self-Verification**:
   Execute this test suite to validate your systemd timer implementation:
   ```bash
   echo "--- Validating Systemd Timer Deployment ---"
   # Test 1: Service file exists
   test -f /etc/systemd/system/app-maintenance.service && echo "[PASS] Service unit present" || echo "[FAIL] Service unit missing"

   # Test 2: Timer active
   systemctl is-active app-maintenance.timer >/dev/null 2>&1 && echo "[PASS] Timer is actively running" || echo "[FAIL] Timer is not active!"

   # Test 3: Listed in systemd scheduler
   systemctl list-timers | grep "app-maintenance.timer" >/dev/null 2>&1 && echo "[PASS] Timer scheduled in systemd" || echo "[FAIL] Timer not in schedule list!"
   ```

---

## Milestone Checkpoint

Save your milestone snapshot from host PowerShell:

```powershell
Checkpoint-LabVM -Name "sysadmin-node" -SnapshotName "level-05-complete"
```

In [Level 06](../level-06-networking-and-connectivity/README.md), our running application service will need network connectivity! We will bind listening sockets, inspect network states with `ss`, trace routes, and lock down the perimeter firewall with UFW!

---

### Navigation
| [← Previous: Level 04: Troubleshooting, Logging & Diagnostics](../level-04-troubleshooting-logs-and-diagnostics/README.md) | [Tier 1: Sysadmin Foundations](../README.md) | [Next: Level 06: Linux Networking & Connectivity →](../level-06-networking-and-connectivity/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V Tutorial 03: Virtual Networking](../../hyperv-internals/03-virtual-networking/README.md)).*
