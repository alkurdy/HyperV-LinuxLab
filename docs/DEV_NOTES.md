# HyperV-LinuxLab Development & Refactoring Notes

*Created: 2026-10-31T21:58:30-04:00*  
*Last Updated: 2026-11-01T22:15:00-05:00*

## Current Machine State & Next Session Hand-off
- **Hyper-V Feature State**: `Enabled` & Active in Ring -1 (`HypervisorPresent: True`, `vmms` running).
- **Windows CBS State**: Clean, no pending reboot.
- **Lab Storage**: Configured to `D:\HyperV-LinuxLab` (942 GB free).
- **Golden Base Images**: Ubuntu 24.04 LTS cached and read-only.
- **Git State**: Clean, working tree synchronized with remote.
- **Test Suite Health**: 98/98 unit tests passing (100%). PSScriptAnalyzer 0 issues.

---

## Index

- [0. Active Kanban Sprint Board](#0-active-kanban-sprint-board)
- [1. Architectural & DRY Tracking](#1-architectural--dry-tracking)
- [2. Linux Distro Expansion Catalog](#2-linux-distro-expansion-catalog)
- [3. Documentation & Secondary Updates Backlog](#3-documentation--secondary-updates-backlog)
- [4. Completed & Archived Work Log](#4-completed--archived-work-log)

---

## 0. Active Kanban Sprint Board

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            INTERNAL KANBAN BOARD                            │
├─────────────────────┬───────────────────────────┬───────────────────────────┤
│ BACKLOG             │ IN PROGRESS               │ DONE (RECENTLY SHIPPED)   │
├─────────────────────┼───────────────────────────┼───────────────────────────┤
│ • Multi-NIC Lab     │ • PHASE-11: Windows Guest │ • Clean Install End-to-End│
│   Topologies (DMZ,  │   Node Support (WinRM,    │   Validation on Win 11 Pro│
│   isolated vSwitch) │   OpenSSH & Ansible)      │ • Win 11 Auto Checkpoint  │
│ • Tier 2 Curriculum │ • Tier 2 Advanced Linux   │   (.avhdx) trap resolution│
│   Script Automation │   Systems Engineering     │ • Test-LabPrerequisites   │
│ • Dynamic Ansible   │   Module Expansion        │   module-load fix & banner│
│   Inventory Export  │                           │ • Unsynced Curriculum Hub │
│ • Tier 3 Expert SRE │                           │   (Tier 1: 7 Levels done, │
│   Hands-on Drills   │                           │   Tiers 2 & 3 Roadmapped) │
└─────────────────────┴───────────────────────────┴───────────────────────────┘
```

### Detailed Column Breakdown:

#### 📋 Backlog
- [ ] **Multi-NIC Custom Lab Topologies**: Support secondary private internal virtual switches alongside Default Switch for isolated DMZ or backend DB networks.
- [ ] **Ansible Dynamic Inventory Integration**: Generate native YAML/INI Ansible inventory from `Get-LabVM` runtime telemetry.
- [ ] **Tier 2 Interactive Script Automation**: Author automated validation scripts for LVM resizing, software RAID failure simulation, and PAM lockout drills.
- [ ] **Tier 3 Expert Chaos Lab Scripts**: Automated injection scripts for kernel memory pressure, network dropped packets (`tc`), and GRUB repair drills.

#### 🚧 In Progress
- [ ] **[PHASE-11] Windows Guest Node Support (Ansible & Hybrid Labs)**:
  - Base Image: Microsoft official evaluation VHDX (Windows Server 2022 / 2025 Eval 180-day).
  - Unattended Config: Build `Private\New-LabUnattendISO.ps1` generating `autounattend.xml` on virtual ISO.
  - Ansible Telemetry: Auto-configure WinRM (HTTP/HTTPS) and Windows OpenSSH server on first boot.
  - Routing & VM Creation: Update `New-LabVM` to branch between Cloud-Init (`cidata.iso`) and Unattend (`unattend.iso`).
  - Inventory: Surface `WinRM` endpoint (`http://<ip>:5985`) in `Get-LabVM` and `metadata.json`.
- [ ] **Tier 2 Advanced Systems Engineering Expansion**: Authoring interactive exercises for LVM thin provisioning and Linux network namespaces.

#### ✅ Done (Recently Shipped)
- [x] **End-to-End Clean Install Validation & Hyper-V Role Reinstallation**: Tested zero-state machine, enabled `Microsoft-Hyper-V-All`, rebooted host, verified microkernel presence in Ring -1, pulled base image, and provisioned VM live.
- [x] **Windows 11 Automatic Checkpoints (`.avhdx`) Resolution**: Disabled `AutomaticCheckpointsEnabled` on newly provisioned VMs in `New-LabVM.ps1`; hardened `Reset-LabVM.ps1` to traverse AVHDX chains back to root differencing disk.
- [x] **`Test-LabPrerequisites` Diagnostic Hardening**: Suppressed engine-level module autoload errors when Hyper-V is absent; enhanced pending reboot warning banner.
- [x] **Enterprise Linux Systems Engineering Curriculum**: Created unsynced `curriculum/` repository with Tier 1 (7 complete levels), Tier 2 (7 modules roadmapped), and Tier 3 (7 modules roadmapped) grounded in `D:\Books\IT\`.

---

## 1. Architectural & DRY Tracking

| Pattern | Status | Implementation Details |
| :--- | :--- | :--- |
| Hardware discovery (CIM) | **Refactored** | Centralized in `Private\Get-LabHostSystemInfo.ps1`. Eliminated duplicate CIM queries across prerequisites and cluster checks. |
| IP extraction regex | **Refactored** | Centralized in `Private\Get-LabVMIPAddress.ps1` with `-TimeoutSeconds 0` instant non-blocking check. Removed duplicate code in `Get-LabVM` and `Start-Lab`. |
| Credential conversions | **Refactored** | Extracted `ConvertTo-LabSecureString` and `ConvertFrom-LabSecureString` in `Private\Convert-LabSecureString.ps1`. |
| Cluster node name resolving | **Refactored** | Centralized in `Private\Get-LabClusterNodeName.ps1`. Removed duplicate prefixing logic from `Get-LabTargetVM`, `New-LabCluster`, `Remove-LabCluster`, and `Test-LabCluster`. |
| Terminal banner formatting | **Refactored** | Centralized in `Private\Format-LabBanner.ps1`. Removed redundant ASCII box string literals across 7 cmdlets. |
| VM metadata & recall | **Refactored** | Centralized in `Private\Set-LabVMMetadata.ps1` and `Private\Get-LabVMMetadata.ps1`. Dual-write to `<LabStoragePath>\LabVMs\<name>\metadata.json` and Hyper-V VM Notes. |

---

## 3. Linux Distro Expansion Catalog

Available distributions in `New-LabBaseImage`:
1. **Ubuntu 24.04 LTS (Noble)**:
   - Upstream Azure cloud image archive (`noble-server-cloudimg-amd64-azure.vhd.tar.gz`).
2. **Ubuntu 22.04 LTS (Jammy)**:
   - Upstream Azure cloud image archive (`jammy-server-cloudimg-amd64-azure.vhd.tar.gz`).
3. **Debian 12 (Bookworm)**:
   - Upstream GenericCloud archive (`debian-12-genericcloud-amd64.tar.xz`).
4. **AlmaLinux 9**:
   - Upstream Azure VHD (`AlmaLinux-9-Azure-latest.x86_64.vhd`), downloaded directly without archive extraction.

### 3.1 Planned Windows Guest Catalog & Ansible Integration
- **Target OS**: Windows Server 2022 / 2025 Datacenter Evaluation (free official 180-day Microsoft evaluation VHD/VHDX).
- **Provisioning Mechanism**: Virtual `unattend.iso` containing `autounattend.xml` with `<FirstLogonCommands>`.
- **Ansible Automation Hooks**:
  - Auto-executes `Configure-WinRM.ps1` on first boot.
  - Opens ports 5985 (HTTP) and 5986 (HTTPS).
  - Installs/enables native Windows OpenSSH Server for SSH-based Ansible control.
  - Sets Administrator password and suppresses Network Location prompts.
- **Integration Telemetry**:
  - Hyper-V KVP reports Windows IP automatically via built-in Integration Services.
  - `Get-LabVM` surfaces `WinRM: http://<ip>:5985` and `ansible_connection: winrm`.

---

## 4. Documentation & Secondary Updates Backlog

- [x] Update `docs/CMDLET_REFERENCE.md` with new `-Distro` parameters (`Debian12`, `AlmaLinux9`) and `Install-LabHyperV`.
- [x] Update `README.md` distro support section and cmdlet table.

---

## 5. Completed & Archived Work Log

### [2026-10-31T22:01:00-04:00] PHASE 1: Hardware Telemetry Unification
- **Files Created**: `Private/Get-LabHostSystemInfo.ps1`, `Tests/Private/Get-LabHostSystemInfo.Tests.ps1`
- **Files Modified**: `Public/Test-LabPrerequisites.ps1`, `Public/Test-LabCluster.ps1`
- **Summary**: Centralized CIM querying for CPU cores, RAM, and fixed disk volumes into `Get-LabHostSystemInfo`. Fixed hardcoded drive `C:` evaluation bug in `Test-LabCluster.ps1` to properly respect configured `StoragePath`.
- **Tests Added**: 3 new tests. 100% passing.

### [2026-10-31T22:02:00-04:00] PHASE 2: IP Address Discovery DRY Unification
- **Files Modified**: `Private/Get-LabVMIPAddress.ps1`, `Public/Get-LabVM.ps1`, `Public/Start-Lab.ps1`
- **Files Created**: `Tests/Private/Get-LabVMIPAddress.Tests.ps1`
- **Summary**: Enhanced `Get-LabVMIPAddress` to support single-pass non-blocking lookup (`-TimeoutSeconds 0`). Removed duplicate adapter iteration and regex IP filtering from `Get-LabVM` and `Start-Lab`.
- **Tests Added**: 3 new tests. 100% passing.

### [2026-10-31T22:02:50-04:00] PHASE 3: Credential Handling Helper
- **Files Created**: `Private/Convert-LabSecureString.ps1`, `Tests/Private/Convert-LabSecureString.Tests.ps1`
- **Files Modified**: `Public/New-LabVM.ps1`, `Public/New-LabCluster.ps1`, `Public/New-LabCloudInitISO.ps1`
- **Summary**: Built `ConvertTo-LabSecureString` and `ConvertFrom-LabSecureString`. Replaced redundant character loop appending and manual credential unwrapping.
- **Tests Added**: 2 new tests. 100% passing.

### [2026-10-31T22:05:40-04:00] PHASE 4: Error Handling & Fault Recovery
- **Files Modified**: `Public/New-LabBaseImage.ps1`, `Private/Resolve-LabProfile.ps1`, `Public/Start-LabVM.ps1`, `Public/Stop-LabVM.ps1`
- **Summary**:
  - `New-LabBaseImage.ps1`: Added try/catch around `Invoke-WebRequest` with actionable network error reporting. Ensured intermediate `.vhd` is purged in `finally` block if conversion fails.
  - `Resolve-LabProfile.ps1`: Added JSON parsing guard with file context if profile JSON is malformed.
  - `Start-LabVM.ps1` & `Stop-LabVM.ps1`: Wrapped hypervisor calls in try/catch to capture and report hypervisor exceptions gracefully with `Write-Error`.
- **Tests Added**: Error recovery tests added in `BaseImage.Tests.ps1`, `Resolve-LabProfile.Tests.ps1`, and `Start-Stop-LabVM.Tests.ps1`.

### [2026-10-31T22:07:00-04:00] PHASE 5: Multi-Distro Base Image Support
- **Files Modified**: `Public/New-LabBaseImage.ps1`, `Public/Get-LabBaseImage.ps1`, `Tests/Public/BaseImage.Tests.ps1`
- **Summary**:
  - Expanded `$imageCatalog` and parameter `ValidateSet` to support `Debian12` and `AlmaLinux9`.
  - Added support for both archive-based (`.tar.gz`, `.tar.xz`) and direct `.vhd` downloads.
  - Scoped Ubuntu-specific EFI GRUB patch to `Ubuntu*` distros.
- **Tests Added**: 2 new tests for multi-distro discovery and direct VHD conversion.

### [2026-10-31T22:07:50-04:00] PHASE 6: Cluster Node Name Resolution
- **Files Created**: `Private/Get-LabClusterNodeName.ps1`, `Tests/Private/Get-LabClusterNodeName.Tests.ps1`
- **Files Modified**: `Private/Get-LabTargetVM.ps1`, `Public/New-LabCluster.ps1`, `Public/Remove-LabCluster.ps1`, `Public/Test-LabCluster.ps1`
- **Summary**: Created `Get-LabClusterNodeName` to eliminate 4x duplicate cluster node name prefix checking.
- **Tests Added**: 3 new tests. 100% passing.

### [2026-10-31T22:08:40-04:00] PHASE 7: Private Function Unit Test Suite
- **Files Created**:
  - `Tests/Private/Assert-Administrator.Tests.ps1`
  - `Tests/Private/Assert-LabDiskSpace.Tests.ps1`
  - `Tests/Private/Get-LabDefaultSwitch.Tests.ps1`
  - `Tests/Private/Get-LabStoragePath.Tests.ps1`
  - `Tests/Private/Get-LabTargetVM.Tests.ps1`
- **Summary**: Created dedicated unit test coverage for every private helper.
- **Pester Results**: 81 tests total (up from 50), 0 failed, 0 skipped. Zero PSScriptAnalyzer errors or warnings.

### [2026-10-31T22:14:00-04:00] PHASE 8: Terminal Banner DRY & Documentation
- **Files Created**: `Private/Format-LabBanner.ps1`, `Tests/Private/Format-LabBanner.Tests.ps1`
- **Files Modified**: `Public/Start-Lab.ps1`, `Public/Stop-Lab.ps1`, `Public/Start-LabVM.ps1`, `Public/New-LabVM.ps1`, `Public/Enable-LabAutoStart.ps1`, `Public/Disable-LabAutoStart.ps1`, `Public/Get-LabAutoStart.ps1`, `docs/CMDLET_REFERENCE.md`, `README.md`
- **Summary**: Standardized CLI box formatting into `Format-LabBanner`. Updated cmdlet documentation and README with new distro support.
- **Pester Results**: 84 tests total, 0 failed, 0 skipped. Zero PSScriptAnalyzer errors or warnings.

### [2026-10-31T22:35:00-04:00] PHASE 9: Hyper-V Role Lifecycle & Automated Provisioning
- **Files Created**: `Public/Install-LabHyperV.ps1`, `Tests/Public/Install-LabHyperV.Tests.ps1`
- **Files Modified**: `Public/Test-LabPrerequisites.ps1`, `HyperV-LinuxLab.psd1`, `Tests/Module.Tests.ps1`, `docs/CMDLET_REFERENCE.md`, `README.md`
- **Summary**:
  - Built `Install-LabHyperV` cmdlet with hardware virtualization validation (VT-x/AMD-V vs `HypervisorPresent`), Windows edition enforcement, third-party hypervisor conflict warning, and reboot handling (`-Restart`).
  - Updated `Test-LabPrerequisites` with `PendingReboot` detection and guidance.
  - Exported `Install-LabHyperV` in module manifest (28 public cmdlets).
- **Pester Results**: 90 tests total (up from 84), 0 failed, 0 skipped. Zero PSScriptAnalyzer errors or warnings.

### [2026-10-31T23:18:00-04:00] PHASE 10: Multi-Distro Coexistence & Local VM Metadata Persistence
- **Files Created**:
  - `Private/Set-LabVMMetadata.ps1`: Dual-write metadata persistence (`metadata.json` + Hyper-V Notes).
  - `Private/Get-LabVMMetadata.ps1`: Metadata retrieval with fallback parsing from Hyper-V Notes.
  - `Tests/Private/Set-LabVMMetadata.Tests.ps1`: Unit tests for setting and updating VM metadata.
  - `Tests/Private/Get-LabVMMetadata.Tests.ps1`: Unit tests for reading metadata from disk and Hyper-V Notes.
  - `examples/multi-distro-cluster.json`: Declarative topology demonstrating Ubuntu 24.04, Debian 12, and AlmaLinux 9 coexisting on the same virtual switch.
- **Files Modified**:
  - `Public/New-LabCloudInitISO.ps1`: Added `wheel` group alongside `sudo` in cloud-config to ensure instant root sudo access across Debian, Ubuntu, and AlmaLinux/RHEL guests.
  - `Public/New-LabVM.ps1`: Added `-Distro` parameter (aliased to `BaseImage`), auto-download per requested distro, and metadata persistence.
  - `Public/New-LabCluster.ps1`: Implemented heterogeneous multi-distro cluster provisioning with per-node `Distro` overrides.
  - `Public/Test-LabCluster.ps1`: Added catalog validation for distro definitions across cluster nodes.
  - `Public/Get-LabVM.ps1`: Surfaced `Distro`, `Username`, `Password`, and `SSH` connection string in output object.
  - `Public/Start-LabVM.ps1` & `Public/Start-Lab.ps1`: Integrated metadata update on dynamic IP acquisition.
  - `Tests/Public/New-LabVM.Tests.ps1`, `Tests/Public/Get-LabVM.Tests.ps1`, `Tests/Public/Cluster.Tests.ps1`: Added unit tests for multi-distro standup and metadata inspection.
- **Pester Results**: 98 tests total (up from 90), 0 failed, 0 skipped. Zero PSScriptAnalyzer errors or warnings.

### [2026-10-31T23:56:00-04:00] PHASE 12: Tutorials Hub Directory Hierarchy, Interactive Navigation & PowerShell Module Qualification
- **Directory Structure Created**:
  - `tutorials/linux/` (Track 1 Hub)
    - `01-deployment-and-ssh/README.md`
    - `02-linux-mental-model-and-filesystems/README.md`
    - `03-processes-systemd-and-networking/README.md`
    - `04-snapshots-and-disaster-recovery/README.md`
    - `05-multi-distro-clusters/README.md`
  - `tutorials/hyperv/` (Track 2 Hub)
    - `01-prerequisites-and-hardware/README.md`
    - `02-installation-and-removal/README.md`
    - `03-virtual-networking/README.md`
    - `04-storage-and-differencing-disks/README.md`
    - `05-vm-architecture-and-cloud-init/README.md`
    - `06-vm-lifecycle-and-telemetry/README.md`
  - `tutorials/README.md`: Master curriculum index and concept quick-jump matrix.
- **Files Removed**:
  - Flat markdown files in `tutorials/` and legacy drafts in `docs/` migrated into dedicated directories.
- **Files Modified**:
  - `README.md`: Updated tutorial index links to directory paths.
  - `docs/SPECIFICATION.md`: Added Section 3.5 documenting PowerShell Module Qualification & Collision Defense (`Hyper-V\<Cmdlet>`).
- **Summary**:
  - Restructured all 11 tutorials into dedicated directories with auto-rendering `README.md` on GitHub.
  - Provided track-level hubs (`tutorials/linux/README.md`, `tutorials/hyperv/README.md`) and a master hub (`tutorials/README.md`).
  - Added bidirectional navigation headers and cross-track reference links.
  - Documented PowerShell Module Qualification (`Hyper-V\New-VMSwitch`, `Hyper-V\Get-VM`) across tutorials and specification to explain collision prevention with third-party tools like VMware PowerCLI.
  - 100% internal markdown links verified, zero machine-specific paths committed.
- **Pester Results**: 98 tests total, 0 failed, 0 skipped. Zero PSScriptAnalyzer errors or warnings.

### [2026-11-02T10:33:00-05:00] PHASE 13: Tutorial Navigation Encoding Repair & Emoji Minimization
- **Issue**:
  - Legacy double-encoded UTF-8 bytes and BOM in `tutorials/hyperv-internals/` caused mojibake glitches (`â€¢`, `â†`, `ðŸ“‘`, `ðŸ§­`).
  - Outdated cross-track links pointed to removed `../../linux/0*` paths.
- **Resolution**:
  - Stripped decorative emojis (`📑`, `🧭`) from breadcrumbs, headings, and navigation tables across all Hyper-V internals tutorials.
  - Replaced corrupted arrows and bullets with clean UTF-8 text symbols (`←`, `→`, `•`).
  - Fixed cross-track breadcrumb links to align with unified `01-sysadmin-foundations/` hierarchy.
  - Saved all markdown files as standard UTF-8 without BOM.
- **Files Modified**:
  - `tutorials/hyperv-internals/README.md`
  - `tutorials/hyperv-internals/01-prerequisites-and-hardware/README.md`
  - `tutorials/hyperv-internals/02-installation-and-removal/README.md`
  - `tutorials/hyperv-internals/03-virtual-networking/README.md`
  - `tutorials/hyperv-internals/04-storage-and-differencing-disks/README.md`
  - `tutorials/hyperv-internals/05-vm-architecture-and-cloud-init/README.md`
  - `tutorials/hyperv-internals/06-vm-lifecycle-and-telemetry/README.md`
- **Pester Results**: 98 tests total, 0 failed, 0 skipped. Zero PSScriptAnalyzer errors or warnings.

### [2026-11-02T10:41:00-05:00] PHASE 14: Tier 1 Layered Continuous Server Curriculum Architecture & Unguided Solo Drills
- **Pedagogical Redesign**:
  - Replaced isolated throwaway drill VMs (`drill-01`, `drill-02`, etc.) with a single continuous enterprise Linux server lifecycle (`sysadmin-node`).
  - Structured every level into a two-part learning architecture:
    - **Part A (Guided Architectural Drill)**: Explicit **Action & System Reaction** sections explaining what the Linux kernel, VFS, systemd, or network stack is doing under the surface, paired with verification commands.
    - **Part B (Admin Solo Drill)**: Unguided missions with customizable parameters (usernames, directories, ports), explicit acceptance criteria, zero copy-paste solution scripts, and automated self-verification validator scripts.
  - Layered lifecycle across all 7 levels:
    - Level 01: Audit host bare metal baseline, kernel VFS, create admin profile on `sysadmin-node`.
    - Level 02: Build `appteam`, `svc-app`, provision `/srv/app` and `/var/log/app` with SGID (`2775`) & default POSIX ACLs.
    - Level 03: Partition dedicated block disk, format Ext4, mount persistently to `/srv/app` via UUID in `/etc/fstab`, enable swap.
    - Level 04: Simulate and triage live unlinked open file handle leak on `/srv/app` (`lsof +L1`), recover blocks without reboot.
    - Level 05: Deploy production systemd unit under `svc-app` writing to `/var/log/app`, test SIGKILL self-healing restart, author systemd timer.
    - Level 06: Bind HTTP listener to port 8080, inspect sockets with `ss -tulpn`, verify DNS/routes, lock down UFW firewall.
    - Level 07: Defensive Bash automation (`set -euo pipefail`), unguided multi-layer break-fix capstone across storage, permissions, systemd, and firewall.
- **Files Modified**:
  - `tutorials/README.md`
  - `tutorials/01-sysadmin-foundations/README.md`
  - `tutorials/01-sysadmin-foundations/level-01-mental-model-and-architecture/README.md`
  - `tutorials/01-sysadmin-foundations/level-02-identity-users-and-permissions/README.md`
  - `tutorials/01-sysadmin-foundations/level-03-directory-hierarchy-and-storage/README.md`
  - `tutorials/01-sysadmin-foundations/level-04-troubleshooting-logs-and-diagnostics/README.md`
  - `tutorials/01-sysadmin-foundations/level-05-processes-systemd-and-signals/README.md`
  - `tutorials/01-sysadmin-foundations/level-06-networking-and-connectivity/README.md`
  - `tutorials/01-sysadmin-foundations/level-07-automation-bash-and-package-lifecycle/README.md`
- **Pester Results**: 98 tests total, 0 failed, 0 skipped. Zero PSScriptAnalyzer errors or warnings.


