# Level 06: Linux Networking & Remote Connectivity Diagnostics

> **Tier 1: Sysadmin Foundations** • Grounded in *Computer Networking: A Top-Down Approach* & *CompTIA Network+*.

---

## 🎯 Objective
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
# The Canonical Sysadmin Command:
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

# Allow inbound SSH on port 22
sudo ufw allow 22/tcp

# Allow traffic from a specific subnet to PostgreSQL
sudo ufw allow from 10.0.0.0/24 to any port 5432 proto tcp

# Delete rule #2
sudo ufw delete 2

# Enable firewall (rules persist across reboots)
sudo ufw enable
```

### RHEL / AlmaLinux: Firewalld (`firewall-cmd`)
```bash
# Query active zone and allowed services
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all

# Allow HTTPS permanently and reload
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload
```

---

## 🛠️ Hands-On Lab Drill: Diagnostic Network Connectivity Triage

Deploy or reuse your lab VM (`New-LabVM -Name "drill-06" -Start`):

> [!TIP]
> **Safety Net: Snapshot Before Modifying Firewalls & Netplan**  
> Running `ufw enable` before allowing port 22 immediately severs your SSH session and locks you out. Snapshot first:
> ```powershell
> Checkpoint-LabVM -Name "drill-06" -SnapshotName "pre-network-drill"
> ```
> Locked out? Revert in 2 seconds:
> ```powershell
> Restore-LabVM -Name "drill-06" -SnapshotName "pre-network-drill" -Force
> ```
> Consolidate when finished:
> ```powershell
> Remove-LabCheckpoint -Name "drill-06" -All -Force
> ```

```bash
# 1. Inspect interface topography
ip -br addr

# 2. Trace outbound routing and identify the default gateway
ip route show default

# 3. Test HTTP handshake and timing without downloading payload
curl -Iv https://www.google.com

# 4. Test remote TCP port reachability using netcat (nc)
# (Test if port 443 is open on github.com with a 2-second timeout)
nc -zvw 2 github.com 443
# Returns: Connection to github.com 443 port [tcp/https] succeeded!

# 5. Spin up an ad-hoc Python web server and verify listener
python3 -m http.server 9090 &
SERVER_PID=$!

# Confirm port 9090 is actively listening
sudo ss -tulpn | grep 9090

# Clean up
kill $SERVER_PID
```
