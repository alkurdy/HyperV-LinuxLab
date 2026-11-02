# Level 02: Identity Management, Users, Groups & POSIX Permissions

> **[Tier 1: Sysadmin Foundations](../README.md)** • Grounded in *Linux Cookbook* (Schroder) & *CompTIA Linux+ Study Guide*.

---

## Objective
Master the Linux identity and security model from a Windows/Active Directory perspective. Understand local account databases, sudo privilege escalation architecture, standard POSIX octal/symbolic permissions, special bits (SUID/SGID/Sticky), and POSIX Access Control Lists (ACLs).

---

## 1. Identity Mental Model: Windows SID vs Linux UID/GID

In Windows, every user, group, and computer object is identified by a Security Identifier (SID, e.g. `S-1-5-21-...-1001`).
In Linux, identity is purely numerical:
- **UID (User ID)**: An integer identifying the user account.
  - `UID 0`: **root** (Superuser). Root has zero capability restrictions in standard POSIX; permission bits do not stop root.
  - `UID 1 - 999`: System / Daemon service accounts (e.g., `systemd-network`, `sshd`, `www-data`). These accounts have no login shell (`/usr/sbin/nologin`).
  - `UID 1000+`: Interactive human user accounts.
- **GID (Group ID)**: An integer identifying group membership. Every user has a **Primary Group** and zero or more **Supplementary / Secondary Groups**.

### The 3 Core Local Identity Files
Linux stores local identity in three plaintext colon-delimited flat files in `/etc/`:

```
┌─────────────────┬─────────────────────────────────────────────────────────────┐
│ File            │ Schema & Description                                        │
├─────────────────┼─────────────────────────────────────────────────────────────┤
│ /etc/passwd     │ username:password_flag:UID:GID:GECOS:home_dir:shell         │
│                 │ (World-readable; password_flag is 'x', pointing to shadow)  │
├─────────────────┼─────────────────────────────────────────────────────────────┤
│ /etc/shadow     │ username:hashed_pw:last_changed:min:max:warn:inact:expire   │
│                 │ (Read-only by root: 0640 permissions; holds sha512/yescrypt)│
├─────────────────┼─────────────────────────────────────────────────────────────┤
│ /etc/group      │ groupname:password_flag:GID:member_user_list                │
│                 │ (World-readable; defines supplementary group memberships)   │
└─────────────────┴─────────────────────────────────────────────────────────────┘
```

---

## 2. Managing Users, Groups & Password Lifecycles

### Creating Accounts
```bash
# Create a dedicated system service account with no home dir and no interactive shell
sudo useradd -r -s /usr/sbin/nologin -d /var/lib/mydaemon mydaemon

# Create a standard human developer account with auto-created home dir and bash shell
sudo useradd -m -s /bin/bash -c "Sarah Connor - Systems Lead" sconnor

# Set or reset password
echo "sconnor:SecurePassword123!" | sudo chpasswd

# Assign supplementary groups
sudo usermod -aG sudo,docker sconnor
```

---

## 3. Sudo Architecture & Privilege Escalation (`visudo`)

In Windows, you right-click and choose *Run as Administrator* (UAC token split).
In Linux, administrators log in as unprivileged accounts and prefix commands with `sudo` (SuperUser DO).

### The Sudoers File (`/etc/sudoers` & `/etc/sudoers.d/`)
**Rule of Engineering**: NEVER edit `/etc/sudoers` directly with a normal text editor. A syntax typo in `/etc/sudoers` corrupts the elevation stack and locks all administrators out of root permanently. Always use `visudo` or drop verified rule files into `/etc/sudoers.d/`:

```text
# User/Group  Host=(RunAsUser:RunAsGroup)  Commands
root          ALL=(ALL:ALL)                ALL
%sudo         ALL=(ALL:ALL)                ALL

# Scoped rule: allow ops team to restart nginx without a password prompt
%ops          ALL=(root)                   NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl status nginx
```

---

## 4. Standard POSIX Permissions (Octal & Symbolic)

Every file and directory in Linux has an owner (`u`), an owning group (`g`), and world/others (`o`).
Permissions are evaluated in strict order: **Owner match? -> Group match? -> Others**.

### The Permission Bits
- `r` (Read = 4): View file contents (`cat`) or list directory contents (`ls`).
- `w` (Write = 2): Modify file contents or create/delete files inside a directory.
- `x` (Execute = 1): Run binary/script as a process, or **traverse / enter** a directory (`cd`).

> [!IMPORTANT]
> **Directory `x` Traversal Trap**: In Windows, reading a file requires Read permissions. In Linux, to read `/data/finance/budget.xlsx`, you must have **`x` (Execute) permissions on every parent directory** (`/`, `/data`, `/data/finance`) in addition to Read permissions on the file itself!

---

## 5. Special Bits: SUID, SGID & The Sticky Bit

When standard `rwx` is not enough, Linux provides three special permission bits:

```
┌──────┬───────┬─────────────────────────────────────────────────────────────────┐
│ Bit  │ Octal │ Operational Function                                            │
├──────┼───────┼─────────────────────────────────────────────────────────────────┤
│ SUID │ 4000  │ File executes with the privileges of the file owner (e.g. /bin/passwd)│
│ SGID │ 2000  │ Files created inside directory inherit the directory's group    │
│      │       │ (Essential for multi-user team collaboration spaces)           │
│ Sticky 1000  │ Only the file owner or root can delete files inside directory  │
│      │       │ (Used on shared directories like /tmp)                          │
└──────┴───────┴─────────────────────────────────────────────────────────────────┘
```

---

## 6. POSIX Access Control Lists (ACLs: `getfacl` / `setfacl`)

When a directory needs multiple groups with differing permissions (e.g. `developers` = Read-Write, `auditors` = Read-Only), standard three-tier POSIX permissions break down. **POSIX ACLs** provide granular NTFS-style access:

```bash
# View active extended ACLs
getfacl /srv/app

# Grant explicit Read-Write permissions to user 'backupuser'
sudo setfacl -m u:backupuser:rw /srv/app

# Set Default ACLs on a directory (automatically inherited by all future child files)
sudo setfacl -d -m g:engineering:rwx /srv/app
```

---

## Hands-On Lab: Building the Production Application Tree

We continue on **`sysadmin-node`** from Level 01. Connect via SSH:
```powershell
ssh labadmin@<VM_IP>
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

In this drill, we provision the enterprise identity groups, service accounts, and application folder hierarchy that will serve as the foundation for the storage, service, and networking layers in subsequent levels.

### 1. Provision Service Account & Developer User
- **Action**: Create system service user `svc-app` (no login shell) and developer user `dev-alice` (interactive bash shell) in group `appteam`:
  ```bash
  # 1. Create team group
  sudo groupadd appteam

  # 2. Create service account (system user, no interactive login)
  sudo useradd -r -s /usr/sbin/nologin -d /srv/app svc-app

  # 3. Create interactive developer account
  sudo useradd -m -s /bin/bash dev-alice
  sudo usermod -aG appteam dev-alice
  ```
- **System Reaction**:
  - The kernel updates `/etc/passwd` and `/etc/group`.
  - Notice `svc-app` receives a UID below `1000`, while `dev-alice` receives UID >= `1000` with home directory `/home/dev-alice`.
- **Verification**:
  ```bash
  id svc-app
  id dev-alice
  grep appteam /etc/group
  ```

### 2. Configure Application Directory with SGID
- **Action**: Create the application tree `/srv/app` and logging directory `/var/log/app`, assigning ownership to `svc-app:appteam` and applying SGID (`2775`):
  ```bash
  sudo mkdir -p /srv/app /var/log/app
  sudo chown -R svc-app:appteam /srv/app /var/log/app
  sudo chmod 2775 /srv/app /var/log/app
  ```
- **System Reaction**:
  The `2` in `2775` sets the `setgid` bit on the directory inode (`drwxrwsr-x`). When any user in the `appteam` group creates a file inside `/srv/app`, the VFS forces the new file's owning group to `appteam` rather than the user's personal primary group.
- **Verification**:
  Simulate file creation as `dev-alice`:
  ```bash
  sudo -u dev-alice touch /srv/app/config.json
  ls -l /srv/app/config.json
  # Notice: Owning group is automatically 'appteam', NOT 'dev-alice'!
  ```

### 3. Configure Default POSIX ACL Inheritance
- **Action**: Ensure all future files created by any process automatically grant `rwx` permissions to the `appteam` group:
  ```bash
  sudo setfacl -d -m g:appteam:rwx /srv/app
  sudo setfacl -d -m g:appteam:rwx /var/log/app
  ```
- **System Reaction**:
  The filesystem stores the default ACL in the extended attribute block of the inode. When a child file is created via `open(O_CREAT)`, the kernel copies the default ACL into the child's effective permissions table.
- **Verification**:
  ```bash
  getfacl /srv/app
  ```

### 4. Scoped Sudoers Privilege Rule
- **Action**: Grant `dev-alice` scoped sudo rights to view system service status without exposing full root:
  ```bash
  cat << 'EOF' | sudo tee /etc/sudoers.d/99-appteam
  # Allow members of appteam to inspect services without root password
  %appteam ALL=(ALL) NOPASSWD: /usr/bin/systemctl status *, /usr/bin/journalctl *
  EOF
  sudo chmod 0440 /etc/sudoers.d/99-appteam
  ```
- **System Reaction**:
  Sudo reads `/etc/sudoers.d/` in lexical order. Setting permissions to `0440` satisfies sudo's strict security check (rejects writeable sudoer configs).
- **Verification**:
  Test that `dev-alice` can run `systemctl status` without password:
  ```bash
  sudo -u dev-alice sudo systemctl status cron
  ```

---

## Part B: Admin Solo Drill (Unguided Mission)

Now complete this operational mission without step-by-step answers. Consult your notes or man pages as needed.

### The Mission: Contractor Onboarding & Security Boundary Lockdown
A security auditing contractor is joining the project. They require read-only access to inspect configuration files in `/srv/app/configs`, but must NEVER have access to application logs in `/var/log/app` or write access to `/srv/app`.

1. **Customization**:
   - Choose your own contractor username (e.g. `auditor-bob` or `sec-analyst`).
   - Create a subfolder `/srv/app/configs` with a test configuration file `app.conf`.

2. **Acceptance Criteria**:
   - Contractor user is created with a home directory and `/bin/bash` shell.
   - Contractor is NOT a member of the `appteam` or `sudo` groups.
   - Contractor can traverse into `/srv/app/configs` and read `app.conf`.
   - Contractor CANNOT create, modify, or delete files in `/srv/app` or `/srv/app/configs` (`Permission denied`).
   - Contractor CANNOT read or list files inside `/var/log/app` (`Permission denied`).
   - Contractor has zero sudo escalation privileges (`sudo -l` reports user is not allowed to run sudo).

3. **Self-Verification**:
   Execute this test suite under your contractor's identity to validate your security boundaries:
   ```bash
   # Replace AUDITOR_USER with your chosen username
   AUDITOR_USER="auditor-bob"

   echo "--- Testing Security Boundaries for $AUDITOR_USER ---"
   # Test 1: Can read configs
   sudo -u "$AUDITOR_USER" cat /srv/app/configs/app.conf >/dev/null 2>&1 && echo "[PASS] Config read permitted" || echo "[FAIL] Cannot read configs"

   # Test 2: Cannot write to configs
   ! sudo -u "$AUDITOR_USER" touch /srv/app/configs/hack.txt >/dev/null 2>&1 && echo "[PASS] Config write blocked" || echo "[FAIL] Write allowed!"

   # Test 3: Cannot read logs
   ! sudo -u "$AUDITOR_USER" ls /var/log/app >/dev/null 2>&1 && echo "[PASS] Log access blocked" || echo "[FAIL] Log access allowed!"

   # Test 4: Cannot run sudo
   ! sudo -u "$AUDITOR_USER" sudo -n true >/dev/null 2>&1 && echo "[PASS] Sudo elevation blocked" || echo "[FAIL] Sudo elevation active!"
   ```

---

## Milestone Checkpoint

Save your milestone snapshot from host PowerShell:

```powershell
Checkpoint-LabVM -Name "sysadmin-node" -SnapshotName "level-02-complete"
```

In [Level 03](../level-03-directory-hierarchy-and-storage/README.md), `/srv/app` will outgrow the root disk! We will partition a dedicated block device, format it with Ext4, migrate `/srv/app`, and mount it persistently using `/etc/fstab` and UUIDs!

---

### Navigation
| [← Previous: Level 01: Mental Model & Architecture](../level-01-mental-model-and-architecture/README.md) | [Tier 1: Sysadmin Foundations](../README.md) | [Next: Level 03: Directory Hierarchy & Storage →](../level-03-directory-hierarchy-and-storage/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V Tutorial 02: Installation & Clean Removal](../../hyperv-internals/02-installation-and-removal/README.md)).*
