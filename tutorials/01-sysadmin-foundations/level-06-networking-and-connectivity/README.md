# Level 06: Linux Networking & Remote Connectivity Diagnostics

> **[Tier 1: Sysadmin Foundations](../README.md)** • Grounded in *Computer Networking: A Top-Down Approach* & *CompTIA Network+*.

---

## Objective
Master modern Linux networking using the `iproute2` suite (`ip`, `ss`), navigate DNS resolution through `systemd-resolved`, configure static and DHCP interfaces (Netplan & NetworkManager), inspect active socket listeners, and administer host firewalls (`ufw` and `firewalld`).

---

## 1. The `iproute2` Revolution: Retiring Legacy `net-tools`

If you are using `ifconfig`, `netstat`, `route`, or `arp`, **stop immediately**. These utilities were declared deprecated over a decade ago. Modern Linux uses the high-performance **`iproute2`** suite interacting directly with the kernel's `netlink` socket subsystem:

```
┌─────────────────────────┬─────────────────────────┬─────────────────────────┐
│ Deprecated (net-tools)  │ Modern Standard         │ Description             │
├─────────────────────────┼─────────────────────────┼─────────────────────────┤
│ ifconfig                │ ip address (or ip a)    │ IP addresses, netmasks  │
│ ifconfig eth0 up/down   │ ip link set eth0 up/down│ Interface link state    │
│ route -n                │ ip route (or ip r)      │ Kernel routing table    │
│ arp -an                 │ ip neighbor (or ip n)   │ ARP cache & MAC table   │
│ netstat -tulpn          │ ss -tulpn               │ Socket statistics & PIDs│
└─────────────────────────┴─────────────────────────┴─────────────────────────┘
```

---

## 2. IP Addressing & Interface Management

```bash
# 1. Brief overview of all interfaces, link state (UP/DOWN), and IPv4/IPv6
ip -br addr

# 2. Detailed view of interface eth0
ip addr show dev eth0

# 3. View the kernel IPv4 routing table (shows Default Gateway)
ip route show

# 4. Temporarily assign a secondary IP address to eth0 (lost on reboot)
sudo ip addr add 192.168.1.200/24 dev eth0

# 5. Remove an assigned IP address
sudo ip addr del 192.168.1.200/24 dev eth0

# 6. Flush ARP cache for a specific neighbor
sudo ip neigh flush dev eth0
```

---

## 3. Persistent Network Configuration: Netplan vs NetworkManager

Different Linux distributions manage persistent interface configurations through different abstractions:

### Ubuntu 24.04 / 22.04: Netplan (`/etc/netplan/*.yaml`)
Ubuntu uses declarative YAML files parsed by Netplan:

```yaml
# /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
```

```bash
# Test and apply Netplan configuration without locking yourself out:
# 'netplan try' automatically rolls back after 120 seconds if you lose SSH connection!
sudo netplan try

# Apply configuration immediately
sudo netplan apply
```

### RHEL 9 / AlmaLinux 9: NetworkManager (`nmcli`)
RHEL-based distributions use NetworkManager:

```bash
# Show active network connections
nmcli connection show

# Configure static IPv4 address, gateway, and DNS
sudo nmcli con mod "eth0" ipv4.addresses "192.168.1.50/24"
sudo nmcli con mod "eth0" ipv4.gateway "192.168.1.1"
sudo nmcli con mod "eth0" ipv4.dns "8.8.8.8,1.1.1.1"
sudo nmcli con mod "eth0" ipv4.method manual

# Re-activate connection to apply
sudo nmcli con up "eth0"
```

---

## 4. The Linux DNS Resolution Pipeline

When an application calls `getaddrinfo()` to resolve a domain (e.g. `api.github.com`), the resolution pipeline flows through:

```
  /etc/nsswitch.conf (Defines resolver order: files, resolve, dns)
           │
           ├─► 1. /etc/hosts (Static local IP-to-Hostname mappings)
           │
           └─► 2. systemd-resolved (Local caching stub listener: 127.0.0.53:53)
                       │
                       └─► Upstream DNS Servers (Configured in DHCP/Netplan)
```

### Diagnostic Commands
```bash
# 1. Query the active upstream DNS servers and cache hit statistics
resolvectl status

# 2. Query name resolution using the native NSS pipeline (tests what apps actually see)
getent hosts google.com

# 3. Low-level DNS inspection using dig (bypasses local cache to query upstream)
dig +short @8.8.8.8 google.com

# 4. Flush the systemd-resolved DNS cache
sudo resolvectl flush-caches
```

---

## 5. Socket Statistics & Port Diagnostics: `ss`

To find out what ports are open, which IP addresses they are bound to, and which process PID owns them:

```bash
# -t (TCP) -u (UDP) -l (Listening only) -p (Show Process Name & PID) -n (Numeric ports)
sudo ss -tulpn
```

### Analyzing `ss` Output:
```text
Netid  State   Recv-Q  Send-Q  Local Address:Port   Peer Address:Port  Process
tcp    LISTEN  0       128           0.0.0.0:22          0.0.0.0:*      users:(("sshd",pid=840,fd=3))
tcp    LISTEN  0       511         127.0.0.1:6379        0.0.0.0:*      users:(("redis-server",pid=1120,fd=6))
```

- **`0.0.0.0:22`**: SSH is bound to **ALL interfaces** (`INADDR_ANY`). Anyone on the network can connect.
- **`127.0.0.1:6379`**: Redis is bound strictly to the **Loopback interface**. It is unreachable from outside the machine, even if there is no firewall!

---

## 6. Host Firewalls: UFW vs Firewalld

Both front-ends interact with the kernel's **nftables** / **netfilter** subsystem:

### Ubuntu: UFW (Uncomplicated FireWall)
```bash
# View active firewall rules and numbered list
sudo ufw status numbered

# Default policies: block incoming, allow outgoing
sudo ufw default deny incoming
sudo ufw default allow outgoing

# CRITICAL RULE: Allow SSH before enabling to prevent instant lockout!
sudo ufw allow 22/tcp

# Allow application port 8080
sudo ufw allow 8080/tcp

# Enable firewall (rules persist across reboots)
sudo ufw enable
```

---

## Hands-On Lab: Exposing & Hardening Application Services

We continue on **`sysadmin-node`** from Level 05. In Level 05, we built our background service. Now, we bind an HTTP listener, inspect socket tables with `ss`, trace routes, and secure the server with UFW.

Connect via SSH:
```powershell
ssh labadmin@<VM_IP>
```

---

## Part A: Guided Architectural Drill (Action & Reaction)

In this drill, we bind an HTTP service to port `8080`, verify TCP socket states, test DNS and routing, and configure stateful firewall rules with UFW.

### 1. Upgrade App Service to Bind Port 8080
- **Action**: Update `/srv/app/bin/worker.sh` to serve a lightweight HTTP response on port 8080 using Python, and restart the systemd service:
  ```bash
  cat << 'EOF' | sudo tee /srv/app/bin/worker.sh
  #!/usr/bin/env bash
  echo "[$(date)] Starting HTTP service on port 8080 as $(whoami)..." >> /var/log/app/worker.log
  exec python3 -m http.server 8080 --directory /srv/app
  EOF
  sudo chmod +x /srv/app/bin/worker.sh
  sudo systemctl restart production-app.service
  ```
- **System Reaction**:
  The kernel allocates a TCP socket data structure, binds it to port `8080` on `0.0.0.0` (`INADDR_ANY`), and transitions the socket state from `CLOSED` to `LISTEN`. Systemd transitions the unit status and assigns the process to its cgroup.
- **Verification**:
  ```bash
  sudo ss -tulpn | grep 8080
  # Notice: Local Address is 0.0.0.0:8080, owned by python3 with PID of production-app.service
  ```

### 2. Verify TCP Handshake & Outbound DNS Resolution
- **Action**: Test the HTTP socket listener locally and query outbound DNS:
  ```bash
  # Test local HTTP handshake
  curl -Iv http://localhost:8080

  # Query DNS resolver and upstream default route
  resolvectl status | grep -E "Current DNS Server|DNS Servers"
  ip route show default
  ```
- **System Reaction**:
  `curl` initiates a standard TCP 3-way handshake (`SYN` -> `SYN-ACK` -> `ACK`). The kernel loopback driver routes packets through the `lo` interface. `resolvectl` queries the caching stub listener on `127.0.0.53:53`.
- **Verification**:
  ```bash
  curl -s http://localhost:8080 | head -n 5
  ```

### 3. Lock Down Perimeter Defense with UFW
- **Action**: Configure UFW to enforce a default-deny posture, allow SSH (22) and app (8080), and enable the firewall:
  ```bash
  # 1. Set default policies
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  # 2. Allow SSH (PORT 22) - NEVER SKIP THIS STEP
  sudo ufw allow 22/tcp comment "Management SSH"

  # 3. Allow Application Port 8080
  sudo ufw allow 8080/tcp comment "Production Web API"

  # 4. Enable UFW
  sudo ufw --force enable
  ```
- **System Reaction**:
  UFW compiles the high-level rules into low-level `nftables` chains in the kernel's `netfilter` table. The kernel matches incoming packets against the chains in numbered order. Unsolicited incoming packets on any port other than 22 and 8080 are dropped immediately with zero TCP RST acknowledgment.
- **Verification**:
  ```bash
  sudo ufw status verbose
  ```

---

## Part B: Admin Solo Drill (Unguided Mission)

Now complete an independent network security mission without answers provided.

### The Mission: Subnet-Restricted Metrics Listener
Operations needs a secondary metrics listener running on a custom port, but security policy requires that it be completely unreachable by the public, restricted strictly to local localhost requests.

1. **Customization**:
   - Choose your own metrics port (e.g. `9090`, `9100`, or `8443`).
   - Launch a background listener on that port bound strictly to loopback `127.0.0.1` (e.g. using `python3 -m http.server <port> --bind 127.0.0.1 &`).

2. **Acceptance Criteria**:
   - The listener is actively running and verified via `ss -tulpn`.
   - The local address in `ss` output must show `127.0.0.1:<port>` (NOT `0.0.0.0:<port>`).
   - Configure a UFW rule allowing access to that specific port only from `127.0.0.1`.
   - Confirm via `curl` that queries from localhost succeed.

3. **Self-Verification**:
   Execute this test suite to validate your implementation:
   ```bash
   # Replace with your chosen metrics port
   METRICS_PORT=9090

   echo "--- Validating Restricted Listener on Port $METRICS_PORT ---"
   # Test 1: Active listener on loopback
   sudo ss -tulpn | grep "127.0.0.1:$METRICS_PORT" >/dev/null 2>&1 && echo "[PASS] Bound strictly to loopback" || echo "[FAIL] Not bound to 127.0.0.1!"

   # Test 2: Local HTTP response
   curl -s --connect-timeout 2 "http://127.0.0.1:$METRICS_PORT" >/dev/null 2>&1 && echo "[PASS] Local HTTP reachability confirmed" || echo "[FAIL] HTTP connection failed!"
   ```

---

## Milestone Checkpoint

Save your milestone snapshot from host PowerShell:

```powershell
Checkpoint-LabVM -Name "sysadmin-node" -SnapshotName "level-06-complete"
```

In [Level 07](../level-07-automation-bash-and-package-lifecycle/README.md), you will face the **Tier 1 Grand Capstone Drill**! You will write defensive self-healing automation, package management scripts, and resolve an unguided multi-layer production outage spanning permissions, storage mounts, systemd services, and firewalls!

---

### Navigation
| [← Previous: Level 05: Processes, Systemd & Signals](../level-05-processes-systemd-and-signals/README.md) | [Tier 1: Sysadmin Foundations](../README.md) | [Next: Level 07: Automation, Bash & Capstone →](../level-07-automation-bash-and-package-lifecycle/README.md) |
| :--- | :---: | ---: |

*(Related topic: See [Hyper-V Tutorial 03: Virtual Networking & Guest IP Routing](../../hyperv-internals/03-virtual-networking/README.md)).*
