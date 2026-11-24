# Tier 4: Ansible Infrastructure Automation (Levels 01 – 05)

> **[Learning Hub](../INDEX.md)** • Master Track for Declarative Fleet Automation on Ephemeral Differencing Disks.

---

## Curriculum Overview: Continuous Fleet Automation

In this track, you operate a continuous 4-node heterogeneous cluster: **`ansible-fleet`**.

Using a dedicated control node running `ansible-core`, you automate configuration, security hardening, service orchestration, and drift remediation across Ubuntu, Debian, and AlmaLinux managed targets.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   CONTINUOUS LAB FLEET: ansible-fleet                            │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Controller Node: ansible-ctrl (Ubuntu 24.04, Profile: AnsibleController)        │
│ Managed Targets: web-01 (Ubuntu 24.04), db-01 (Debian 12), app-01 (AlmaLinux 9) │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Level 01: Control Node Architecture & Ad-Hoc Execution                           │
│           ├── Agentless push pipeline, OpenSSH key trust, inventory.ini          │
│           └── Ad-hoc command execution (ping, command, shell, setup facts)       │
│                                   │                                              │
│ Level 02: Playbook Foundations, State & Idempotency Invariants                   │
│           ├── Declarative YAML tasks vs Imperative Bash scripts                  │
│           └── Cross-distro packages (package/apt/dnf), services & dry-runs       │
│                                   │                                              │
│ Level 03: Variables, Facts & Dynamic Jinja2 Templating                           │
│           ├── Host fact discovery (ansible_facts), loops, conditionals           │
│           └── Dynamic Nginx load balancer templates & event-driven handlers      │
│                                   │                                              │
│ Level 04: Modular DRY Architecture: Roles & Collections                          │
│           ├── Standard role directory architecture (tasks, handlers, templates)  │
│           └── Reusable common_baseline role, yamllint, and ansible-lint          │
│                                   │                                              │
│ Level 05: Enterprise Security: Ansible Vault & Drift Remediation                 │
│           ├── Encrypting variables with ansible-vault, scoped sudoers rules       │
│           └── Live drift simulation, auto-remediation & sub-2s node resets       │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## Fleet Topology Manifest

Deploy the entire 4-node heterogeneous fleet with a single command from host PowerShell:

```powershell
New-LabCluster -Path .\examples\ansible-fleet.json
```

| Node Name | Distro | Role | Hardware | Profile |
| :--- | :--- | :--- | :--- | :--- |
| **`ansible-ctrl`** | Ubuntu 24.04 | Control Node | 2 vCPU, 2 GB RAM | `AnsibleController` |
| **`web-01`** | Ubuntu 24.04 | Web Tier | 1 vCPU, 1 GB RAM | `Minimal` |
| **`db-01`** | Debian 12 | Database Tier | 1 vCPU, 1 GB RAM | `Minimal` |
| **`app-01`** | AlmaLinux 9 | Backend App | 1 vCPU, 1 GB RAM | Custom |

---

## Progressive Curriculum Directory

1. [Level 01: Control Node Architecture & Ad-Hoc Execution](level-01-control-node-and-adhoc/README.md)
2. Level 02: Playbook Foundations, State & Idempotency Invariants *(Coming Next)*
3. Level 03: Variables, Facts & Dynamic Jinja2 Templating *(Planned)*
4. Level 04: Modular DRY Architecture: Roles & Collections *(Planned)*
5. Level 05: Enterprise Security: Ansible Vault & Drift Remediation *(Planned)*
