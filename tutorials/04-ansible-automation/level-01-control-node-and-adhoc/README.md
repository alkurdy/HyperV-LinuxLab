# Level 01: Control Node Architecture & Ad-Hoc Execution

> **Track:** [Tier 4: Ansible Automation](../README.md)  
> **Topology:** [examples/ansible-fleet.json](../../../examples/ansible-fleet.json)  
> **Continuous Control Node:** `ansible-ctrl`  
> **Managed Nodes:** `web-01`, `db-01`, `app-01`  

---

## 1. Architectural Mental Model: The Agentless Push Model

Most legacy configuration managers require an agent daemon running on every client machine listening on a custom TCP port.

**Ansible requires no custom agent.** It operates via the standard **OpenSSH** transport layer already running on enterprise Linux systems:

```
┌────────────────────────┐                    ┌────────────────────────┐
│      ansible-ctrl      │                    │      Managed Node      │
│                        │                    │   (web-01 / db-01)     │
│  ┌──────────────────┐  │   SSH Port 22      │  ┌──────────────────┐  │
│  │ Playbook / Task  │  ├───────────────────►│  │ OpenSSH (sshd)   │  │
│  └────────┬─────────┘  │                    │  └────────┬─────────┘  │
│           │            │                    │           ▼            │
│  ┌────────▼─────────┐  │   SFTP / SCP       │  ┌──────────────────┐  │
│  │ Python Zip Engine│──┼───────────────────►│  │/tmp/.ansible/tmp/│  │
│  └──────────────────┘  │                    │  └────────┬─────────┘  │
│                        │                    │           ▼            │
│                        │   JSON Stdout      │  ┌──────────────────┐  │
│                        │◄───────────────────┤  │/usr/bin/python3  │  │
│                        │                    │  └──────────────────┘  │
└────────────────────────┘                    └────────────────────────┘
```

### The 4 Execution Phases:
1. **Compilation**: The control node packages the Python module code, arguments, and execution wrapper into a self-contained ZIP archive.
2. **Transfer**: The payload is pushed to `/tmp/.ansible/tmp/...` on the managed node via SFTP.
3. **Execution**: The managed node's Python interpreter unpacks and runs the module, emitting a JSON status object.
4. **Cleanup**: Sshd terminates and Ansible deletes the temporary payload from `/tmp`.

---

## 2. Inventory Architecture (`inventory.ini`)

Ansible determines which hosts to target using an inventory file.

```ini
# /home/labadmin/ansible-lab/inventory.ini

[control]
ansible-ctrl ansible_connection=local

[webservers]
web-01 ansible_host=172.20.190.160

[databases]
db-01 ansible_host=172.20.190.161

[backend]
app-01 ansible_host=172.20.190.162

[fleet:children]
webservers
databases
backend

[fleet:vars]
ansible_user=labadmin
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

---

## 3. Hands-On Lab: Fleet Onboarding

### Step 1: Deploy Fleet from Host PowerShell
```powershell
New-LabCluster -Path .\examples\ansible-fleet.json
```

### Step 2: Connect to Controller
```powershell
ssh labadmin@<ANSIBLE_CTRL_IP>
cd ~/ansible-lab
```

### Step 3: Populate Inventory with Discovered IPs
Edit `~/ansible-lab/inventory.ini` with the actual IP addresses assigned by Hyper-V Default Switch.

### Step 4: Ad-Hoc Connectivity Drill
Verify SSH transport and Python runtime across all nodes:
```bash
# Ping test across all nodes
ansible fleet -m ping

# Run arbitrary command
ansible fleet -m command -a "uptime"

# Gather hardware and OS facts
ansible webservers -m setup -a "filter=ansible_distribution*"
```

---

## 4. Acceptance Criteria
- [ ] Controller can run `ansible fleet -m ping` returning `SUCCESS` for all 3 targets.
- [ ] `ansible fleet -m setup -a "filter=ansible_os_family"` correctly identifies `Debian` for `web-01`/`db-01` and `RedHat` for `app-01`.
- [ ] No manual SSH host key prompts (`StrictHostKeyChecking=no` active in `ansible.cfg`).
