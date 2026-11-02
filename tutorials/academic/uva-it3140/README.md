# UVA IT 3140: DevSecOps & Cloud Operations Lab Companion

[Tutorials Hub](../../README.md) • [Academic Bridges](../README.md) • UVA IT 3140 Companion

---

## Objective & Purpose

This guide bridges the **University of Virginia (UVA) IT 3140: DevSecOps & Cloud Operations** curriculum directly into **`HyperV-LinuxLab`**.

By utilizing this lab companion, students and systems engineers can execute the complete university lab syllabus locally on native Windows Hyper-V hardware. This eliminates recurring cloud hosting costs, bypasses cloud subscription quotas, and enables deep operating system introspection (kernel privilege rings, synthetic hypervisor VMBus drivers, systemd cgroups, and storage allocation) that are completely concealed behind commercial cloud abstractions.

---

## Curriculum Alignment Matrix

| Academic Week & Lab | University Curriculum Scope | HyperV-LinuxLab Native Implementation | Mapped Foundation Level |
| :--- | :--- | :--- | :--- |
| **Week 1: DSO Lab 1** | Linux System Administration (Labs 1–8: Files, Users, Permissions, Networking, Variables, Processes, `jq`, `yum`) | Ephemeral or Continuous `sysadmin-node` deployed with AlmaLinux 9 or Ubuntu 24.04 | [Tier 1: Levels 01–07](../../01-sysadmin-foundations/README.md) |
| **Week 2: DevSecOps** | SDLC Models, DevSecOps Culture, Threat Modeling & Policy as Code | Host-level pre-flight gatekeepers, validation test suites (`Invoke-Pester`) | [Hyper-V 01](../../hyperv-internals/01-prerequisites-and-hardware/README.md) |
| **Week 3: DSO Lab 2** | AWS EC2 Deployment via OpenTofu (IaC), Security Groups, SSH Keys | Declarative VM provisioning via PowerShell / OpenTofu local-exec or Hyper-V provider | [Hyper-V 05](../../hyperv-internals/05-vm-architecture-and-cloud-init/README.md) & [Level 06](../../01-sysadmin-foundations/level-06-networking-and-connectivity/README.md) |
| **Week 4: DSO Lab 4** | Git Version Control Essentials & Python Flask Microservice | Deploying multi-tier Flask services under dedicated systemd daemons and UFW firewalls | [Level 05](../../01-sysadmin-foundations/level-05-processes-systemd-and-signals/README.md) & [Level 06](../../01-sysadmin-foundations/level-06-networking-and-connectivity/README.md) |
| **Weeks 5–7: CI/CD** | Cloud Pipelines, AWS CodeBuild, CodePipeline, Automated Testing | Local Git hooks, build specifications (`buildspec.yml`), and automated self-healing scripts | [Level 07](../../01-sysadmin-foundations/level-07-automation-bash-and-package-lifecycle/README.md) |

---

## Lab Environment Deployment

To execute these labs locally, spin up a dedicated enterprise lab node from your host PowerShell console. Because UVA IT 3140 exercises utilize Enterprise Linux tools (`yum`, `dnf`, `shadow-utils`), we recommend deploying **AlmaLinux 9** (or Ubuntu 24.04):

```powershell
# Deploy an AlmaLinux 9 enterprise node
New-LabVM -Name "uva-node" -Distro AlmaLinux9 -MemoryGB 2 -CPUCount 2 -Start

# Or deploy an Ubuntu 24.04 LTS node
New-LabVM -Name "uva-node" -Distro Ubuntu2404 -MemoryGB 2 -CPUCount 2 -Start

# Connect via SSH
ssh labadmin@<VM_IP>
```

---

## DSO Lab 1: Linux Fundamentals Complete Execution Guide

### Lab 1: Organizing Files & Directories
**Systems Concept**: Understanding atomic pointer renames (`mv`) vs block allocation duplication (`cp`), directory traversal, and backup hygiene.

```bash
# 1. Build an organized project hierarchy
mkdir -p ~/projects/{docs,src,backups}
cd ~/projects

# 2. Create sample project assets
touch docs/project_plan.txt docs/budget.xlsx
echo "Production Configuration v1.0" > src/app.conf

# 3. Create a defensive timestamped backup copy (Standard Sysadmin Hygiene)
cp src/app.conf backups/app.conf.bak.$(date +%F)

# 4. Move and reorganize assets
mv docs/project_plan.txt src/

# 5. Continuous verification
ls -la src/
ls -la backups/
```

### Lab 2: Managing User Accounts & Group Memberships
**Systems Concept**: Local identity schemas (`/etc/passwd`, `/etc/group`), primary GID vs supplementary groups, and the critical `-a` append flag.

```bash
# 1. Create a dedicated project group
sudo groupadd projectteam

# 2. Create a user account with explicit home directory (-d)
sudo useradd -m -d /home/bryan -s /bin/bash -c "Bryan Cranston" bryan

# 3. Set account password
echo "bryan:Pass1234!" | sudo chpasswd

# 4. Append user to supplementary group (CRITICAL: NEVER OMIT -a!)
sudo usermod -a -G projectteam bryan

# 5. Inspect UID, primary GID, and supplementary memberships
id bryan
# Output: uid=1001(bryan) gid=1001(bryan) groups=1001(bryan),1002(projectteam)

# 6. Switch user context and verify session
sudo su - bryan
whoami  # Returns: bryan
exit    # Returns to original administrative session
```

### Lab 3: Configuring File Permissions & Ownership
**Systems Concept**: Three-tier POSIX permission evaluation (Owner -> Group -> Others), octal representation, and confidential file lockdown.

```bash
# 1. Create sensitive test files
echo "Confidential API Secrets" | sudo tee /srv/confidential.txt
echo "Public Notice" | sudo tee /srv/public.txt

# 2. Enforce strict confidential privacy (700 / 600)
# Owner has read/write; group and others have zero permissions
sudo chown bryan:projectteam /srv/confidential.txt
sudo chmod 600 /srv/confidential.txt

# 3. Enforce team collaboration access (660)
sudo chmod 660 /srv/public.txt
sudo chown bryan:projectteam /srv/public.txt

# 4. Verify file permissions and ownership in directory listing
ls -l /srv/
# Expected:
# -rw------- 1 bryan projectteam 24 Nov  2 12:00 confidential.txt
# -rw-rw---- 1 bryan projectteam 14 Nov  2 12:00 public.txt
```

### Lab 4: Network Diagnostics & Troubleshooting
**Systems Concept**: The 5-step systematic bottom-up network diagnostic order, session hostname changes vs persistent `/etc/hostname`, and DNS resolution.

```bash
# Step 1: Test local TCP/IP stack (Loopback sanity check)
ping -c 3 127.0.0.1

# Step 2: Test local interface and IP configuration
ip -br addr
ping -c 3 $(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# Step 3: Test default gateway routing
GATEWAY=$(ip route | grep default | awk '{print $3}')
ping -c 3 $GATEWAY

# Step 4: Test external internet reachability (Direct IP)
ping -c 3 1.1.1.1

# Step 5: Test DNS resolution pipeline
cat /etc/resolv.conf
nslookup google.com

# Inspect and update persistent hostname
hostnamectl status
sudo hostnamectl set-hostname uva-sysadmin-node
cat /etc/hostname
```

### Lab 5: Setting & Managing Environment Variables
**Systems Concept**: Memory space isolation, subshell inheritance via `export`, `$PATH` search lookup, and history expansion.

```bash
# 1. Local shell variable (child process cannot see this)
COURSE_NAME="IT_3140"
bash -c 'echo "Subshell sees: $COURSE_NAME"'  # Outputs empty line

# 2. Exported environment variable (inherited across fork/execve)
export COURSE_NAME="IT_3140"
bash -c 'echo "Subshell sees: $COURSE_NAME"'  # Outputs: Subshell sees: IT_3140

# 3. Audit environment block
env | grep COURSE_NAME

# 4. Unset environment variable
unset COURSE_NAME

# 5. Extend $PATH search variable
export PATH="$HOME/bin:$PATH"
echo $PATH

# 6. History recall
history | tail -n 5
# Execute previous command by line number: !<number>
```

### Lab 6: Process Monitoring & Job Control
**Systems Concept**: System V (`ps -ef`) vs BSD (`ps aux`) dialects, shell job control (`&`, `jobs`, `fg`), and signal delivery vs clean systemd management.

```bash
# 1. Audit processes using BSD syntax (resource focus)
ps aux | head -n 10

# 2. Audit processes using System V syntax (ancestry focus with PPID)
ps -ef | head -n 10

# 3. Search process table excluding grep itself
ps aux | grep [s]shd

# 4. Shell Job Control: launch long-running job in background
sleep 600 &
# Output: [1] 3412

# 5. List active background jobs
jobs -l

# 6. Bring job to foreground and suspend
fg %1
# Press Ctrl + Z to suspend (SIGSTOP)

# 7. Resume suspended job in background (SIGCONT)
bg %1

# 8. Terminate process via PID signal
kill -15 3412
```

### Lab 7: Structured JSON Processing with `jq`
**Systems Concept**: Stream filtering, multi-line here-documents (`<<-EOF`), and JSON array iteration.

```bash
# 1. Verify and install jq
which jq || sudo dnf install -y jq || sudo apt install -y jq
jq --version

# 2. Feed JSON data into jq via a Here-Document
cat <<- 'EOF' | jq .
{
  "university": "University of Virginia",
  "course": "IT 3140",
  "instructor": "DSO Faculty",
  "students": [
    {"name": "Aleksey", "role": "Lead Architect", "status": "Active"},
    {"name": "Bryan", "role": "DevOps Engineer", "status": "Active"},
    {"name": "Sarah", "role": "Security Analyst", "status": "Pending"}
  ]
}
EOF

# 3. Filter JSON attributes
cat <<- 'EOF' | jq '.students[].name'
{
  "students": [
    {"name": "Aleksey"},
    {"name": "Bryan"}
  ]
}
EOF
# Output:
# "Aleksey"
# "Bryan"

# 4. Parse live API responses
curl -s https://api.github.com/zen
```

### Lab 8: Enterprise Package Lifecycles (`yum` / `dnf`)
**Systems Concept**: Cryptographically signed repository metadata, caching, dependency resolution, and administrative permission boundaries.

```bash
# 1. Check for available package updates (returns exit code 100 if updates exist)
sudo dnf check-update || sudo yum check-update

# 2. List installed packages
rpm -qa | head -n 10

# 3. Clean repository metadata cache (resolves stale mirror issues)
sudo dnf clean all || sudo yum clean all

# 4. Refresh repository metadata
sudo dnf makecache || sudo yum makecache

# 5. Install utility package
sudo dnf install -y htop || sudo apt install -y htop
```

---

## Technical Review Questions & Systems Engineering Analysis

These questions reflect the core assessment areas of UVA IT 3140 DSO Lab 1, accompanied by deep systems explanations:

### Lab 1: File & Directory Management
1. **What is the difference between `mv` and `cp`?**
   - *Technical Answer*: On the same filesystem, `mv` performs an atomic pointer update in the directory's inode index table; file data blocks and inode numbers remain untouched ($O(1)$ performance). `cp` allocates new inodes and physical disk blocks, reading source data and writing a duplicate stream of blocks to the storage volume ($O(N)$ performance).
2. **Why is it useful to run `ls -l` after each file operation?**
   - *Technical Answer*: It allows immediate verification of file existence, file size (ensuring files are not empty or truncated), owner/group assignments, octal permissions, and modification timestamps.
3. **What does the `-l` flag add to the output of `ls`?**
   - *Technical Answer*: The long listing format reveals file type (directory, regular file, symlink), 9-character POSIX permission string, number of hard links, owning user, owning group, file size in bytes, and timestamp.
4. **Why do teams create backup copies of files during maintenance?**
   - *Technical Answer*: To provide an immediate, atomic rollback mechanism in case syntax errors, misconfigurations, or service incompatibilities occur.

### Lab 2: User Accounts & Groups
1. **What does the `-d` option do in `useradd`?**
   - *Technical Answer*: Specifies the custom filesystem path for the user's home directory instead of accepting the system default (`/home/<username>`).
2. **Why is the `-a` option important in `usermod -a -G`?**
   - *Technical Answer*: The `-a` flag **appends** the user to the specified supplementary group. If `-a` is omitted, `usermod -G` overwrites the user's supplementary group list, removing them from all other groups (including administrative groups like `wheel` or `sudo`).
3. **What is the difference between a user's primary group and supplementary groups?**
   - *Technical Answer*: A user has exactly one primary group, defined in `/etc/passwd`, which becomes the default owning group for any file created by that user. Supplementary groups are defined in `/etc/group` and grant additional permissions to resources.
4. **What is the purpose of `id`?**
   - *Technical Answer*: Queries the kernel security token for the active user, displaying UID (User ID), primary GID (Group ID), and all supplementary GID memberships.
5. **Why does typing `exit` after `su` return you to your previous account?**
   - *Technical Answer*: `su` forks and launches a child subshell running under the target user's UID. Typing `exit` terminates this child subshell process, returning control to the parent shell process.

### Lab 3: Permissions & Ownership
1. **In `700`, what access does each digit represent?**
   - *Technical Answer*: Digit 1 (Owner) = 7 (`rwx`: Read, Write, Execute). Digit 2 (Group) = 0 (`---`: No access). Digit 3 (Others) = 0 (`---`: No access).
2. **What is the difference between `660` and `664`?**
   - *Technical Answer*: `660` grants Read and Write to Owner and Group, with zero access for Others. `664` also grants Read permissions to the entire outside world (Others).
3. **In `chown bryan:projects confidential.txt`, what do `bryan` and `projects` refer to?**
   - *Technical Answer*: `bryan` is the new owning user; `projects` is the new owning group.
4. **How can you tell from `ls -l` whether a file is executable?**
   - *Technical Answer*: An `x` character appears in the owner, group, or other permission slots (e.g. `-rwxr-xr-x`).
5. **Why should confidential files have more restrictive permissions than public files?**
   - *Technical Answer*: To prevent unauthorized local users and background service daemons from reading sensitive credentials, keys, or proprietary data (Principle of Least Privilege).

### Lab 4: Network Diagnostics
1. **What is the difference between `hostname` and editing `/etc/hostname`?**
   - *Technical Answer*: `hostname <name>` modifies only the volatile running kernel hostname in memory (lost on reboot). Editing `/etc/hostname` (or using `hostnamectl set-hostname`) persists the hostname across reboots.
2. **Why does `/etc/hostname` require a reboot or service reload?**
   - *Technical Answer*: The file is read by systemd during kernel initialization at boot time.
3. **What information does `ifconfig` / `ip addr` display?**
   - *Technical Answer*: Network interface names, hardware MAC addresses, link states (UP/DOWN), assigned IPv4/IPv6 addresses, subnet masks, broadcast addresses, and MTU.
4. **What is the purpose of loopback `127.0.0.1`?**
   - *Technical Answer*: Tests the internal TCP/IP network protocol stack inside the kernel without transmitting frames across a physical network adapter.
5. **What does `/etc/resolv.conf` contain?**
   - *Technical Answer*: IP addresses of upstream DNS nameservers and local domain search paths used by the resolver library.

### Lab 5: Environment Variables
1. **What is the difference between an environment variable and a shell variable?**
   - *Technical Answer*: Shell variables exist only in the local memory of the current shell. Environment variables are marked for export and are copied into child processes during `fork()` and `execve()`.
2. **Why is `PATH` important?**
   - *Technical Answer*: Contains an ordered list of directories searched by the shell to find executable binaries when a command is entered without an absolute path.
3. **Does an `export` variable persist after closing the terminal?**
   - *Technical Answer*: No. Environment variables exist in process memory. To persist, they must be written to startup configuration files (`~/.bashrc` or `/etc/profile.d/`).
4. **What does `unset` do?**
   - *Technical Answer*: Removes a variable from the shell and environment block. Confirmed by checking `env` or `printenv`.
5. **How does `!N` history recall work?**
   - *Technical Answer*: The shell searches the command history table in memory and re-executes the command at line index `N`.

### Lab 6: Processes & Signals
1. **Difference between `ps aux` and `ps -ef`?**
   - *Technical Answer*: `ps aux` uses BSD syntax and focuses on CPU/memory resource consumption. `ps -ef` uses System V syntax and displays parent process IDs (`PPID`) for lineage auditing.
2. **What is a PID and why is it needed to terminate a process?**
   - *Technical Answer*: A Process ID is a unique integer assigned by the kernel to identify a running process in the kernel process table. Signals are routed to processes by PID.
3. **Why use `grep` with `ps`?**
   - *Technical Answer*: To filter the global process table for specific binary names or arguments.
4. **Difference between `kill` and `systemctl stop`?**
   - *Technical Answer*: `kill` delivers an uncoordinated raw signal directly to a PID. `systemctl stop` coordinates a graceful shutdown via systemd: executing `ExecStop=`, alerting dependents, waiting for timeouts, and unmounting cgroups.
5. **What does `systemctl status` report after a process is killed?**
   - *Technical Answer*: Reports that the service has failed or died, displaying the terminating signal (`status=15/SIGTERM` or `status=9/SIGKILL`) and restart counters.

### Lab 7: JSON & `jq`
1. **Why run `jq --version` before and after installation?**
   - *Technical Answer*: To verify whether the tool is already present, and to confirm successful installation and version compatibility.
2. **What does `which` do?**
   - *Technical Answer*: Searches directories in `$PATH` and returns the absolute path of the executable binary.
3. **What is a Here-Document (`<<-EOF ... EOF`)?**
   - *Technical Answer*: Shell syntax that redirects a multi-line inline text block directly into a command's standard input stream (`stdin`).
4. **In `.employees[].name`, what does each component do?**
   - *Technical Answer*: `.employees` accesses the employees key, `[]` iterates over array elements, and `.name` extracts the name attribute from each object.
5. **How is `jq` useful with APIs?**
   - *Technical Answer*: Filters, shapes, and extracts targeted values from large JSON responses returned by REST endpoints or cloud metadata services.

### Lab 8: Software Management (`yum` / `dnf`)
1. **Why keep software packages up to date?**
   - *Technical Answer*: To patch security vulnerabilities, resolve system bugs, and ensure library stability.
2. **Difference between `list installed` and `list available`?**
   - *Technical Answer*: `list installed` queries local RPM database for packages on disk. `list available` queries remote repositories for installable packages.
3. **Difference between `yum update` and `yum upgrade`?**
   - *Technical Answer*: `update` upgrades installed packages while preserving system configuration; `upgrade` also obsoletes and removes deprecated packages.
4. **Why might `yum update` report no packages to update?**
   - *Technical Answer*: All installed packages already match the latest versions present in the repository metadata cache.
5. **Why do package managers require administrative privileges?**
   - *Technical Answer*: They write system binaries to `/usr/bin`, libraries to `/usr/lib64`, and update system databases in `/var/lib/rpm`, which are restricted to root.

---

## Applied Bridge: Weeks 3 & 4 on Hyper-V

### Week 3: OpenTofu & Infrastructure as Code (IaC)
In Week 3, the UVA curriculum provisions an AWS EC2 instance using OpenTofu (`main.tf`).
You can execute OpenTofu directly on your Hyper-V host machine or inside a management VM:
- Define infrastructure declaratively.
- Use OpenTofu with local provisioners or test against AWS cloud sandboxes using keys configured inside your secure VM.
- Store state files locally without incurring ongoing AWS hourly compute fees.

### Week 4: Python Flask Microservice Architecture
In Week 4, students author a Flask web application and push to GitHub.
In `HyperV-LinuxLab`, you can take this microservice to enterprise production standards:
1. Create a dedicated system user `svc-flask` (from [Level 02](../../01-sysadmin-foundations/level-02-identity-users-and-permissions/README.md)).
2. Mount dedicated application storage to `/srv/flaskapp` (from [Level 03](../../01-sysadmin-foundations/level-03-directory-hierarchy-and-storage/README.md)).
3. Write a production systemd unit `/etc/systemd/system/flaskapp.service` (from [Level 05](../../01-sysadmin-foundations/level-05-processes-systemd-and-signals/README.md)).
4. Lock down external access via UFW firewall rules on port `5000` (from [Level 06](../../01-sysadmin-foundations/level-06-networking-and-connectivity/README.md)).
5. Automate self-healing health checks using `curl` and `jq` in defensive Bash (from [Level 07](../../01-sysadmin-foundations/level-07-automation-bash-and-package-lifecycle/README.md)).

---

### Navigation
| [Tutorials Hub](../../README.md) | [Tier 1: Sysadmin Foundations](../../01-sysadmin-foundations/README.md) | [Hyper-V Internals Track](../../hyperv-internals/README.md) |
| :--- | :---: | ---: |
