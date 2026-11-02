# Level 07: Automation, Bash Scripting & Software Lifecycle

> **Tier 1: Sysadmin Foundations** • Grounded in *Learning the Bash Shell* & *Linux Command Line and Shell Scripting Bible*.

---

## 🎯 Objective
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
# Place individual job files in /etc/cron.d/my-backup-job
echo "0 3 * * * root /usr/local/bin/backup.sh > /var/log/backup.log 2>&1" | sudo tee /etc/cron.d/daily-backup
```

---

## 3. Defensive Bash Scripting for Sysadmins

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

# 1. Variables and Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/sysadmin_audit.log"
readonly THRESHOLD=80

# 2. Logging Function with Timestamps
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}" | sudo tee -a "${LOG_FILE}"
}

# 3. Defensive Elevation Check
if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be executed as root (or via sudo)." >&2
    exit 1
fi

log "INFO" "Starting automated disk capacity audit..."

# 4. Command Substitution & Text Parsing
CURRENT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

log "INFO" "Root partition utilization: ${CURRENT_USAGE}%"

# 5. Conditional Logic
if [[ "${CURRENT_USAGE}" -gt "${THRESHOLD}" ]]; then
    log "WARN" "Disk usage exceeds threshold (${THRESHOLD}%). Purging apt cache..."
    apt-get clean
else
    log "INFO" "Disk capacity is within acceptable operational parameters."
fi

log "INFO" "Audit completed successfully."
exit 0
```

---

## 4. Text Stream Manipulation: `sed` and `awk`

In Linux, you rarely modify configuration files manually in automated deployments. Use `sed` (stream editor) and `awk` (pattern scanning):

### `sed` (Find & Replace in Config Files)
```bash
# Substitute 'Port 22' with 'Port 2222' in sshd_config in-place (-i)
sudo sed -i 's/^#*Port 22/Port 2222/' /etc/ssh/sshd_config

# Delete all blank lines and comment lines starting with '#'
sed -i '/^[[:space:]]*#/d; /^[[:space:]]*$/d' /tmp/sample.conf
```

### `awk` (Column and Field Extraction)
```bash
# Extract column 1 (IP) and column 2 (Hostname) from /etc/hosts
awk '{print $1, $2}' /etc/hosts

# Print usernames whose UID is greater than or equal to 1000 from /etc/passwd
awk -F: '$3 >= 1000 {print $1, $3}' /etc/passwd
```

---

## 🛠️ Hands-On Capstone Break-Fix Drill (Levels 01 - 07 Mastery)

Deploy a fresh node using your `HyperV-LinuxLab` module:

```powershell
New-LabVM -Name "capstone-node" -MemoryGB 2 -CPUCount 2 -Start
```

> [!TIP]
> **Safety Net: Milestone Checkpoints During Capstone Multi-Stage Drills**  
> As you complete each stage (packages installed, SGID folder configured, systemd service active), snapshot your progress:
> ```powershell
> Checkpoint-LabVM -Name "capstone-node" -SnapshotName "stage-1-nginx-ready"
> ```
> If a test script corrupts configuration files in Stage 4, roll back to Stage 1 without re-installing packages:
> ```powershell
> Restore-LabVM -Name "capstone-node" -SnapshotName "stage-1-nginx-ready" -Force
> ```
> When all stages are completed and verified, consolidate:
> ```powershell
> Remove-LabCheckpoint -Name "capstone-node" -All -Force
> ```

SSH into the machine (`ssh labadmin@<VM_IP>`) and complete this end-to-end operational assignment:

### The Mission:
1. **User & Identity**: Create a service group `webops` and service user `deployer` (no interactive shell, member of `webops`).
2. **Directory & Permissions**: Create `/var/www/app`. Assign ownership to `deployer:webops`. Set permissions so all newly created files inherit group `webops` automatically (SGID).
3. **Software & Listener**: Install `nginx`. Verify port `80` is listening via `ss -tulpn`.
4. **Automation Script**: Author a script `/usr/local/bin/healthcheck.sh` that checks if `nginx` is running. If down, restart it and log an alert to `/var/log/healthcheck.log`.
5. **Systemd Service**: Wrap the healthcheck in a self-healing systemd service or timer.

### Solution Script:
```bash
# 1. Identity
sudo groupadd webops
sudo useradd -r -s /usr/sbin/nologin -g webops deployer

# 2. Storage & SGID
sudo mkdir -p /var/www/app
sudo chown deployer:webops /var/www/app
sudo chmod 2775 /var/www/app

# 3. Package & Listener
sudo apt update && sudo apt install -y nginx
sudo ss -tulpn | grep :80

# 4. Automation Script
cat << 'EOF' | sudo tee /usr/local/bin/healthcheck.sh
#!/usr/bin/env bash
set -euo pipefail
if ! systemctl is-active --quiet nginx; then
    echo "[$(date)] ALERT: Nginx down. Attempting recovery..." >> /var/log/healthcheck.log
    systemctl restart nginx
fi
EOF
sudo chmod +x /usr/local/bin/healthcheck.sh

# 5. Test
sudo /usr/local/bin/healthcheck.sh
cat /var/log/healthcheck.log 2>/dev/null || echo "Nginx was already healthy!"
```

Once completed, reset the node:
```powershell
Reset-LabVM -Name "capstone-node" -Force
```
