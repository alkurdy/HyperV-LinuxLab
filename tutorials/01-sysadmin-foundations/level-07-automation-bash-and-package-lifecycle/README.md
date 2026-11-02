# Level 07: Automation, Bash Scripting & Software Lifecycle

> **[Tier 1: Sysadmin Foundations](../README.md)** • Grounded in *Learning the Bash Shell* & *Linux Command Line and Shell Scripting Bible*.

---

## Objective
Master software package management across distribution families (`apt` vs `dnf`), schedule recurring workloads with Cron, author bulletproof defensive Bash automation scripts using strict mode (`set -euo pipefail`), manipulate configuration files with `sed` and `awk`, and solve a full capstone break-fix operational scenario.

---

## 1. Enterprise Software Package Lifecycles

In Windows, applications are deployed via MSI/EXE installers, winget, or Chocolatey.
In Linux, software is managed via signed cryptographic repositories maintaining dependency resolution trees:

```
┌─────────────────────────────────┬─────────────────────────────────┐
│ Debian / Ubuntu (.deb)          │ Red Hat / CentOS / Alma (.rpm)  │
├─────────────────────────────────┼─────────────────────────────────┤
│ High-Level Tool: apt            │ High-Level Tool: dnf (or yum)   │
│ Low-Level Tool: dpkg            │ Low-Level Tool: rpm             │
│ Repos: /etc/apt/sources.list.d/ │ Repos: /etc/yum.repos.d/        │
└─────────────────────────────────┴─────────────────────────────────┘
```

### High-Yield Comparison Table

| Task | Debian / Ubuntu (`apt`) | RHEL / AlmaLinux (`dnf`) |
| :--- | :--- | :--- |
| **Refresh Repository Metadata** | `sudo apt update` | `sudo dnf check-update` |
| **Install Package & Dependencies**| `sudo apt install -y nginx` | `sudo dnf install -y nginx` |
| **Remove Package (Keep Config)** | `sudo apt remove nginx` | `sudo dnf remove nginx` |
| **Purge Package & Config Files** | `sudo apt purge nginx` | `sudo dnf remove nginx` |
| **Search Repository for Package** | `apt search htop` | `dnf search htop` |
| **Query Package Information** | `apt show nginx` | `dnf info nginx` |
| **Find Which Package Owns a File**| `dpkg -S /usr/bin/curl` | `dnf provides /usr/bin/curl` |
| **List All Installed Packages** | `dpkg -l` | `rpm -qa` |

### RHEL/AlmaLinux: `yum` vs `dnf` Nuances
On RHEL and AlmaLinux systems, `yum` is a symlink pointing to `dnf` (Dandified YUM), preserving backward compatibility:
- **`yum check-update`**: Scans repositories for available package updates without modifying local packages. Returns exit code `100` if updates exist, or `0` if packages are fully up to date.
- **`yum update`**: Updates installed packages to their newest compatible versions while preserving dependencies.
- **`yum upgrade`**: Similar to update, but also removes obsolete packages (in modern `dnf`, `update` and `upgrade` are functional aliases).
- **`yum clean all`**: Purges cached repository metadata, headers, and downloaded package files from `/var/cache/yum` or `/var/cache/dnf`. Essential when resolving repository checksum mismatches or broken metadata caches.

### Why Package Management Commands Require Root Privileges
Running `apt install` or `yum update` without `sudo` immediately terminates with a permission error. This is a foundational security boundary:
1. **Modifying System Binaries**: Package managers write executable binaries directly into `/usr/bin` and `/usr/sbin`.
2. **Shared Dynamic Libraries**: Libraries are installed into `/lib`, `/usr/lib`, or `/usr/lib64`. Tampering with shared libraries could subvert all running binaries on the host.
3. **Database Integrity**: Package managers update system transaction databases located in `/var/lib/dpkg/` or `/var/lib/rpm/`. Unprivileged users must not be permitted to corrupt the system's package state machine.

---

## 2. Recurring Task Scheduling: Cron

Cron executes automated jobs at defined intervals based on system time:

### The 5-Field Cron Syntax
```
┌───────────── Minute (0 - 59)
│ ┌─────────── Hour (0 - 23)
│ │ ┌───────── Day of Month (1 - 31)
│ │ │ ┌─────── Month (1 - 12)
│ │ │ │ ┌───── Day of Week (0 - 7, where 0 and 7 = Sunday)
│ │ │ │ │
* * * * *  /path/to/script.sh
```

### Common Cron Expressions
- `0 2 * * *`: Every night at 02:00 AM.
- `*/15 * * * *`: Every 15 minutes.
- `0 0 * * 1`: Every Monday at midnight.
- `0 12 1 * *`: Noon on the 1st of every month.

### Managing Cron
```bash
# Edit the current user's crontab (validates syntax on save)
crontab -e

# List scheduled jobs
crontab -l

# Drop-in cron files for system-wide administrative automation:
echo "0 3 * * * root /usr/local/bin/backup.sh > /var/log/backup.log 2>&1" | sudo tee /etc/cron.d/daily-backup
```

---

---

## 3. Structured JSON Processing with `jq`

Modern Linux systems administrators interact constantly with APIs, cloud metadata services, and structured configuration files formatted in JSON. The command-line utility `jq` is the standard JSON stream parser.

### Verifying and Installing `jq`
```bash
# Check if jq is installed and locate its binary
which jq

# Check installed version
jq --version

# Install on Debian/Ubuntu
sudo apt install -y jq

# Install on RHEL/AlmaLinux
sudo dnf install -y jq
```

### Passing Inline JSON via Here-Documents (`<<-EOF`)
A **here-document** (`<<-EOF ... EOF`) allows passing multi-line string input directly into a command's standard input:
```bash
cat <<- 'EOF' | jq .
{
  "datacenter": "us-east-hyperv",
  "employees": [
    {"name": "Alice", "role": "DevSecOps", "clearance": "TopSecret"},
    {"name": "Bob", "role": "Sysadmin", "clearance": "Secret"},
    {"name": "Charlie", "role": "PlatformEngineer", "clearance": "Secret"}
  ]
}
EOF
```

### The Core `jq` Filter Syntax
| Filter Expression | Operational Action | Output Example |
| :--- | :--- | :--- |
| `.` | Identity filter; pretty-prints incoming JSON | Full formatted JSON document |
| `.datacenter` | Extracts specific top-level key | `"us-east-hyperv"` |
| `.employees` | Extracts entire employees array | `[ { "name": ... }, ... ]` |
| `.employees[]` | Iterates and flattens array elements into individual objects | Individual JSON records |
| `.employees[].name` | Extracts the `name` attribute from every array element | `"Alice"`, `"Bob"`, `"Charlie"` |
| `.employees[] \| select(.role == "DevSecOps")` | Evaluates boolean condition and filters matching objects | `{"name": "Alice", "role": "DevSecOps", ...}` |
| `-r` flag (Raw output) | Strips JSON quotation marks for shell variable assignment | `Alice` instead of `"Alice"` |

### Real-World Sysadmin API Example
```bash
# Query an external REST API or cloud endpoint and extract specific values
LATEST_RELEASE=$(curl -s https://api.github.com/repos/stedolan/jq/releases/latest | jq -r '.tag_name')
echo "Latest verified jq release tag is: $LATEST_RELEASE"
```

## 4. Defensive Bash Scripting for Sysadmins

Fragile Bash scripts cause catastrophic outages. When writing infrastructure automation, **always enforce Defensive Strict Mode**:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

### Why Strict Mode is Mandatory
1. **`-e` (Exit on Error)**: Script terminates immediately if any command returns a non-zero exit code. Prevents compounding cascading failures.
2. **`-u` (No Unset Variables)**: Script terminates if you reference an undefined variable. Prevents disasters like `rm -rf /tmp/$SUBDIR/` deleting `/tmp/` if `$SUBDIR` is empty!
3. **`-o pipefail`**: The pipeline return code reflects the rightmost command that failed. Without this, `failing_cmd | grep "ok"` returns `0` (success) because `grep` succeeded!

### Production Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Trap unexpected exits and cleanup temporary files
cleanup() {
    rm -f /tmp/lock.pid
    echo "[$(date)] Execution finished."
}
trap cleanup EXIT
```

---

## 5. Text Stream Filtering: `sed` and `awk`

### `sed` (Stream Editor - Search and Replace)
```bash
# Substitute 'DEBUG' with 'INFO' in config.json
sed -i 's/DEBUG/INFO/g' /srv/app/config.json

# Delete comment lines starting with #
sed -i '/^#/d' /etc/app.conf
```

### `awk` (Column and Field Extraction)
```bash
# Extract column 1 (IP) and column 2 (Hostname) from /etc/hosts
awk '{print $1, $2}' /etc/hosts

# Print usernames whose UID is >= 1000 from /etc/passwd
awk -F: '$3 >= 1000 {print $1, $3}' /etc/passwd
```

---

## Hands-On Lab: Automation & The Grand Capstone Incident

We continue on **`sysadmin-node`** from Level 06. All layers (identity, storage, process, network, and firewall) are assembled.

Connect via SSH:
```powershell
ssh labadmin@<VM_IP>
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

In this drill, we install `jq` using `apt`, author a robust health-check automation script with strict error handling, and schedule it via cron.

### 1. Package Installation & Metadata Inspection
- **Action**: Update local repository metadata and install `jq` (command-line JSON parser):
  ```bash
  sudo apt update
  sudo apt install -y jq
  dpkg -S $(which jq)
  ```
- **System Reaction**:
  `apt update` downloads cryptographic InRelease index files from the distribution mirror and updates `/var/lib/apt/lists/`. `apt install` calculates the dependency DAG (Directed Acyclic Graph), extracts `.deb` archives via `dpkg`, and registers binaries in `/usr/bin/`.
- **Verification**:
  ```bash
  jq --version
  ```

### 2. Author Defensive Health-Check Automation
- **Action**: Author `/usr/local/bin/app-healthcheck.sh` implementing `set -euo pipefail`:
  ```bash
  cat << 'EOF' | sudo tee /usr/local/bin/app-healthcheck.sh
  #!/usr/bin/env bash
  set -euo pipefail

  LOG_TARGET="/var/log/app/healthcheck.log"

  log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_TARGET"
  }

  # 1. Verify systemd unit is active
  if ! systemctl is-active --quiet production-app.service; then
      log "WARNING: production-app.service is down! Attempting recovery..."
      systemctl restart production-app.service
      sleep 2
  fi

  # 2. Verify HTTP endpoint responds
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://localhost:8080 || echo "000")
  if [ "$HTTP_CODE" -eq 200 ]; then
      log "OK: Health check passed (HTTP $HTTP_CODE)"
  else
      log "CRITICAL: HTTP check returned $HTTP_CODE! Escalating..."
      exit 1
  fi
  EOF
  sudo chmod +x /usr/local/bin/app-healthcheck.sh
  ```
- **System Reaction**:
  The script utilizes standard exit codes. If `curl` fails or the service is inactive, it attempts self-healing before logging. If any unexpected unhandled command fails, `set -e` halts execution instantly.
- **Verification**:
  Run manually:
  ```bash
  sudo /usr/local/bin/app-healthcheck.sh
  cat /var/log/app/healthcheck.log
  ```

---

## Part B: Admin Solo Drill (Tier 1 Grand Capstone Mission)

Now face the ultimate systems administrator test. **No solutions or answers are provided.** You must diagnose, triage, and repair all layers using the knowledge and notes accumulated across Levels 01 through 06.

### The Incident: Simulated Production Multi-Layer Outage
A junior deployment script experienced an unhandled failure and clobbered multiple system configurations across `sysadmin-node`.

Trigger the multi-layer incident by running this fault-injection command:

```bash
# INJECT OUTAGE FAULTS
sudo umount /srv/app 2>/dev/null || true
sudo chmod 0000 /srv/app
sudo systemctl stop production-app.service
sudo ufw deny 8080/tcp comment "Clobbered rule" >/dev/null
```

### The Ticket (SEV-1):
> *"Production app is completely down! External clients receive timeout on port 8080. Internal developers report permission denied errors. The systemd service fails to start. Storage status is unknown."*

### Acceptance Criteria:
1. **Layer 1: Storage & Filesystem**  
   `/srv/app` must be actively mounted to its dedicated Ext4 storage volume from `/etc/fstab`.
2. **Layer 2: Permissions & SGID**  
   Ownership of `/srv/app` must be restored to `svc-app:appteam` with permissions `2775` (SGID active).
3. **Layer 3: Systemd Daemon**  
   `production-app.service` must be actively running (`active (running)`) under user `svc-app`.
4. **Layer 4: Perimeter Firewall**  
   The blocking UFW rule must be removed and port `8080/tcp` must be explicitly permitted.
5. **Layer 5: End-to-End Verification**  
   Executing `curl -I http://localhost:8080` must return HTTP `200 OK`.

### Self-Verification (The Grader):
When you believe you have repaired all 4 layers, execute this unguided validator script:

```bash
cat << 'EOF' > /tmp/validate-capstone.sh
#!/usr/bin/env bash
echo "=== TIER 1 CAPSTONE OPERATIONAL AUDIT ==="
FAILURES=0

# Test 1: Storage
if findmnt /srv/app >/dev/null 2>&1; then
    echo "[PASS] Layer 1: /srv/app filesystem is actively mounted."
else
    echo "[FAIL] Layer 1: /srv/app is NOT mounted!"
    FAILURES=$((FAILURES+1))
fi

# Test 2: Permissions & SGID
PERMS=$(stat -c "%a" /srv/app 2>/dev/null || echo "000")
GROUP=$(stat -c "%G" /srv/app 2>/dev/null || echo "unknown")
if [ "$PERMS" = "2775" ] && [ "$GROUP" = "appteam" ]; then
    echo "[PASS] Layer 2: Permissions (2775) and SGID (appteam) intact."
else
    echo "[FAIL] Layer 2: Permissions ($PERMS) or Group ($GROUP) incorrect!"
    FAILURES=$((FAILURES+1))
fi

# Test 3: Systemd Service
if systemctl is-active --quiet production-app.service; then
    echo "[PASS] Layer 3: production-app.service is active and running."
else
    echo "[FAIL] Layer 3: production-app.service is NOT running!"
    FAILURES=$((FAILURES+1))
fi

# Test 4: Firewall Port 8080
if sudo ufw status | grep -E "8080/tcp.*ALLOW" >/dev/null 2>&1; then
    echo "[PASS] Layer 4: UFW allows inbound 8080/tcp."
else
    echo "[FAIL] Layer 4: Port 8080/tcp is blocked in UFW!"
    FAILURES=$((FAILURES+1))
fi

# Test 5: HTTP End-to-End
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://localhost:8080 || echo "000")
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "[PASS] Layer 5: End-to-end HTTP response verified (200 OK)."
else
    echo "[FAIL] Layer 5: HTTP probe failed with status $HTTP_CODE!"
    FAILURES=$((FAILURES+1))
fi

echo "========================================="
if [ "$FAILURES" -eq 0 ]; then
    echo "[SUCCESS] CONGRATULATIONS: Tier 1 Sysadmin Foundations Mastered!"
else
    echo "[ACTION REQUIRED] $FAILURES layers still in failure state. Check your notes and logs."
fi
EOF
chmod +x /tmp/validate-capstone.sh
/tmp/validate-capstone.sh
```

---

## Tier 1 Completion & Milestone Checkpoint

Once all 5 validation checks pass, save your final Tier 1 snapshot from host PowerShell:

```powershell
Checkpoint-LabVM -Name "sysadmin-node" -SnapshotName "tier-1-complete"
```

Congratulations! You have completed **Tier 1: Sysadmin Foundations**! You have built, partitioned, secured, diagnosed, and automated an enterprise Linux server from the ground up.

Next, explore **[Tier 2: Advanced Systems Engineering](../../02-advanced-systems/README.md)** (LVM, RAID, Network Namespaces, SELinux, and Podman) or dive into **[Track 2: Hyper-V Internals](../../hyperv-internals/README.md)**!

---

### Navigation
| [← Previous: Level 06: Linux Networking & Connectivity](../level-06-networking-and-connectivity/README.md) | [Tier 1: Sysadmin Foundations](../README.md) | [Next: Tier 2: Advanced Systems Roadmap →](../../02-advanced-systems/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V Tutorial 05: VM Architecture & Cloud-Init](../../hyperv-internals/05-vm-architecture-and-cloud-init/README.md)).*
