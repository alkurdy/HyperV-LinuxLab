# Level 05: Process Lifecycle, Signals & Systemd Service Management

> **Tier 1: Sysadmin Foundations** • Grounded in *Operating Systems: Internals and Design Principles* (Stallings) & *Linux Cookbook* (Schroder).

---

## 🎯 Objective
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
pgrep -l nginx

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

# Signal Nginx to reload its configuration files without downtime
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

# Enable or Disable service startup at system boot
sudo systemctl enable nginx
sudo systemctl disable nginx

# Combine Enable and Start in a single command
sudo systemctl enable --now nginx

# THE MASK COMMAND (Preventing accidental start):
# Masking symlinks the unit file to /dev/null. It CANNOT be started by any user,
# dependency, or script until unmasked!
sudo systemctl mask apache2
sudo systemctl unmask apache2

# List all failed units on the host
systemctl --failed
```

---

## 5. Writing a Production Systemd Service File

Place custom unit files in `/etc/systemd/system/<servicename>.service`. Never edit vendor unit files in `/lib/systemd/system/` (package updates overwrite them).

```ini
[Unit]
Description=Enterprise Telemetry Collector Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=telemetry
Group=telemetry
WorkingDirectory=/opt/telemetry
ExecStart=/usr/bin/python3 /opt/telemetry/collector.py --port 8080
ExecReload=/bin/kill -HUP $MAINPID

# Auto-Recovery Configuration
Restart=always
RestartSec=5s

# Security Hardening & Resource Limits
LimitNOFILE=65535
PrivateTmp=true
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

## 6. Systemd Timers: The Modern Replacement for Cron

Systemd timers (`.timer`) provide microsecond precision, monotonic scheduling, and dependency guarantees over traditional cron:

```bash
# List all active systemd timers across the host
systemctl list-timers --all
```

---

## 🛠️ Hands-On Lab Drill: Building a Self-Healing Service

Deploy or reuse your lab VM (`New-LabVM -Name "drill-05" -Start`):

```bash
# 1. Create a simulated long-running background worker script
sudo mkdir -p /opt/labservice
cat << 'EOF' | sudo tee /opt/labservice/worker.sh
#!/usr/bin/env bash
echo "Worker daemon initialized with PID $$"
while true; do
    echo "Heartbeat at $(date)"
    sleep 3
done
EOF
sudo chmod +x /opt/labservice/worker.sh

# 2. Write a production systemd unit file with automatic restart
cat << 'EOF' | sudo tee /etc/systemd/system/lab-worker.service
[Unit]
Description=Hands-on Self Healing Worker

[Service]
Type=simple
ExecStart=/opt/labservice/worker.sh
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

# 3. Register and start the unit
sudo systemctl daemon-reload
sudo systemctl enable --now lab-worker.service

# 4. Verify running state
sudo systemctl status lab-worker.service

# 5. TEST SELF-HEALING: Crash the process with SIGKILL (kill -9)
WORKER_PID=$(pgrep -f "worker.sh")
echo "Killing PID $WORKER_PID with SIGKILL..."
sudo kill -9 $WORKER_PID

# 6. Check status immediately: systemd detects death and resurrects it with a new PID!
sleep 3
sudo systemctl status lab-worker.service
```
