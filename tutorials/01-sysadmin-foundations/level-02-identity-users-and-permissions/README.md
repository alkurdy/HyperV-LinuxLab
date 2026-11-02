# Level 02: Identity Management, Users, Groups & POSIX Permissions

> **Tier 1: Sysadmin Foundations** • Grounded in *Linux Cookbook* (Schroder) & *CompTIA Linux+ Study Guide*.

---

## 🎯 Objective
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

# Set account password
sudo passwd sconnor

# Create a secondary group for engineering
sudo groupadd engineering

# Add sconnor to engineering group (Supplementary: -aG = Append Group)
# WARNING: Omitting '-a' removes the user from all other supplementary groups!
sudo usermod -aG engineering sconnor

# Verify effective UID and GIDs
id sconnor
# uid=1001(sconnor) gid=1001(sconnor) groups=1001(sconnor),1002(engineering)
```

### Password Aging & Account Locking (Equivalent to Windows Account Policies)
```bash
# View password expiration and aging policy
sudo chage -l sconnor

# Force password change at next interactive login
sudo chage -d 0 sconnor

# Lock account immediately (prepends '!' to password hash in /etc/shadow)
sudo usermod -L sconnor

# Unlock account
sudo usermod -U sconnor
```

---

## 3. Privilege Escalation: The Sudo Architecture

In Windows, administrators belong to the `BUILTIN\Administrators` group and use UAC (User Account Control).
In Linux, administrators log in as unprivileged users and escalate privileges on demand via `sudo` (SuperUser DO).

### The Sudo Configuration Hierarchy
- The master configuration file is `/etc/sudoers`.
- **CRITICAL RULE**: Never edit `/etc/sudoers` directly with `nano` or `vim`. Always use `visudo`. `visudo` locks the file and parses syntax before saving. A single typo in `/etc/sudoers` will lock everyone out of root privileges!
- **Drop-in Configuration**: Place custom administrative grants in `/etc/sudoers.d/<filename>`.

```bash
# Safe syntax validation check for all sudoers files
sudo visudo -c

# Grant passwordless sudo to engineering team for web service restarts only
echo "%engineering ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl status nginx" | sudo tee /etc/sudoers.d/99-engineering-web

# Validate file permissions (sudoers files MUST be 0440 or 0400)
sudo chmod 0440 /etc/sudoers.d/99-engineering-web
```

---

## 4. Standard POSIX File Permissions: Octal & Symbolic

Every file and directory in Linux has an owner, an owning group, and a 9-bit permission triplet:

```
  -   r w x   r - x   r - -
  │   └──┬──┘ └──┬──┘ └──┬──┘
 Type   User    Group   Others
```

### Binary to Octal Mathematics
Each permission bit represents a power of 2:
- **`r` (Read)**: `4` (Binary `100`)
- **`w` (Write)**: `2` (Binary `010`)
- **`x` (Execute)**: `1` (Binary `001`)

```
rwx = 4 + 2 + 1 = 7 (Full Access)
rw- = 4 + 2 + 0 = 6 (Read and Write)
r-x = 4 + 0 + 1 = 5 (Read and Execute)
r-- = 4 + 0 + 0 = 4 (Read Only)
--- = 0 + 0 + 0 = 0 (No Access)
```

### The Critical "Directory Execute" Difference
For a **file**: `x` allows running the file as a binary program or script.  
For a **directory**: `x` allows **entering / traversing** the directory (`cd` or opening files inside it).
- If a directory is `r--` without `x`, a user can list the filenames (`ls`), but cannot open, read, or inspect their file contents!

### Changing Ownership & Permissions
```bash
# Change owner to sconnor and group to engineering recursively
sudo chown -R sconnor:engineering /srv/app

# Set file permissions using Octal notation (Owner: rw, Group: r, Other: None)
chmod 640 /srv/app/config.json

# Set directory permissions using Symbolic notation
# (Add execute to user, remove write from group and others)
chmod u+x,go-w /srv/app/scripts
```

### Umask: The Default Permission Mask
When a process creates a file or directory, default permissions are determined by the `umask` (subtraction mask):
- Base Directory default: `0777`
- Base File default: `0666` (Linux never assigns execute permission to new files by default)
- Standard Umask `0022`:
  - New directories: `0777 - 0022 = 0755` (`rwxr-xr-x`)
  - New files: `0666 - 0022 = 0644` (`rw-r--r--`)
- Hardened Umask `0027`:
  - New directories: `0750` (`rwxr-x---`)
  - New files: `0640` (`rw-r-----`)

---

## 5. Special Permission Bits: SUID, SGID & Sticky Bit

Beyond standard `rwx`, Linux provides three specialized privilege bits:

| Bit | Octal | Applies To | Behavior |
| :--- | :---: | :--- | :--- |
| **SUID (Set User ID)** | `4000` | Executable File | Process executes with the permissions of the file owner (e.g. `/usr/bin/passwd` runs as root to update `/etc/shadow`). |
| **SGID (Set Group ID)** | `2000` | Directory | All new files created inside inherit the **group ownership of the parent directory**, rather than the primary group of the user creating the file. Essential for shared team folders! |
| **Sticky Bit** | `1000` | Directory | Users can only delete or rename files they own, even if the directory has world-write permissions (`777`). Exemplified by `/tmp`. |

```bash
# Configure shared collaboration folder:
# 1. Create directory and assign group
sudo mkdir /srv/engineering
sudo chown root:engineering /srv/engineering

# 2. Assign SGID bit (2) so all new files inherit 'engineering' group
sudo chmod 2775 /srv/engineering

# Verify permissions (Notice the 's' in group permissions)
ls -ld /srv/engineering
# drwxrwsr-x 2 root engineering 4096 /srv/engineering

# Inspect the Sticky Bit on /tmp (Notice the 't' in others)
ls -ld /tmp
# drwxrwxrwt 12 root root 4096 /tmp
```

---

## 6. Granular Access: POSIX Access Control Lists (ACLs)

Standard `User/Group/Other` permissions only allow **one** user and **one** group. What if you need to grant read-write access to a second group or a backup service account without modifying existing ownership?
Use POSIX ACLs (equivalent to Windows NTFS DACLs):

```bash
# View existing ACL entries on a sensitive database file
getfacl /srv/db/production.db

# Grant explicit Read-Write permissions to user 'backupuser'
sudo setfacl -m u:backupuser:rw /srv/db/production.db

# Grant explicit Read-Only permissions to group 'auditors'
sudo setfacl -m g:auditors:r /srv/db/production.db

# Set Default ACLs on a directory (automatically inherited by all future child files)
sudo setfacl -d -m g:engineering:rwx /srv/engineering

# Remove all extended ACLs and restore pure POSIX mode
sudo setfacl -b /srv/db/production.db
```

---

## 🛠️ Hands-On Lab Drill: Secure Team Collaboration Space

Deploy or reuse your lab VM (`New-LabVM -Name "drill-02" -Start`):

> [!TIP]
> **Safety Net: Snapshot Before Modifying Permissions & Sudoers**  
> Before practicing permission lockouts or sudoers edits, take a snapshot from host PowerShell:
> ```powershell
> Checkpoint-LabVM -Name "drill-02" -SnapshotName "pre-permissions-drill"
> ```
> If you make a mistake and lock yourself out of root, revert in 2 seconds:
> ```powershell
> Restore-LabVM -Name "drill-02" -SnapshotName "pre-permissions-drill" -Force
> ```
> Once verified, merge and consolidate deltas:
> ```powershell
> Remove-LabCheckpoint -Name "drill-02" -All -Force
> ```

```bash
# 1. Create two test users: 'dev-alice' and 'qa-bob'
sudo useradd -m -s /bin/bash dev-alice
sudo useradd -m -s /bin/bash qa-bob
sudo groupadd devs

# 2. Add dev-alice to devs
sudo usermod -aG devs dev-alice

# 3. Create a team folder /data/shared
sudo mkdir -p /data/shared
sudo chown root:devs /data/shared

# 4. Set permissions: Owner (root) full, Group (devs) full, Others none, SGID enabled
sudo chmod 2770 /data/shared

# 5. Test SGID behavior as dev-alice
sudo -u dev-alice touch /data/shared/alice_file.txt
ls -l /data/shared/alice_file.txt
# Notice: Group owner is 'devs', NOT alice's primary group!

# 6. Test boundary isolation: qa-bob should be rejected
sudo -u qa-bob ls /data/shared
# Returns: Permission denied!

# 7. Grant qa-bob explicit Read-Only access using ACLs
sudo setfacl -m u:qa-bob:rx /data/shared
sudo -u qa-bob ls /data/shared
# Now succeeds!
```
