# HyperV-LinuxLab Development & Refactoring Notes

*Created: 2026-10-31T21:58:30-04:00*  
*Last Updated: 2026-10-31T23:51:00-04:00*

## Current Machine State & Next Session Hand-off
- **Hyper-V Feature State**: `Disabled` (via `Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart`).
- **Windows CBS State**: `PendingReboot: True` in `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`.
- **Lab Storage**: Completely wiped on target drives. Non-lab VMs preserved intact.
- **Git State**: Clean working tree on `main`, synchronized with remote.
- **Immediate Step On Resume**: Reboot host (`Restart-Computer`) to unload `hvix64.sys` microkernel, then run validation runbook below.

---

## Index

- [0. Next Session Priority: End-to-End Hyper-V Role Lifecycle Validation](#0-next-session-priority-end-to-end-hyper-v-role-lifecycle-validation)
- [1. Active Sprint Backlog](#1-active-sprint-backlog)
- [2. Architectural & DRY Tracking](#2-architectural--dry-tracking)
- [3. Linux Distro Expansion Catalog](#3-linux-distro-expansion-catalog)
- [4. Documentation & Secondary Updates Backlog](#4-documentation--secondary-updates-backlog)
- [5. Completed & Archived Work Log](#5-completed--archived-work-log)

---

## 0. Next Session Priority: End-to-End Hyper-V Role Lifecycle Validation

**Goal**: Validate complete uninstallation of Hyper-V from host, reboot, and reinstallation via `Install-LabHyperV` to verify real-world hardware virtualization check, DISM provisioning, reboot detection, and lab bringup.

### Validation Runbook:

```powershell
# 1. Host Restart (Unload hypervisor microkernel)
Restart-Computer

# 2. Post-Uninstall Verification (In elevated PowerShell 7 or 5.1)
Import-Module .\HyperV-LinuxLab.psd1 -Force
$pre = Test-LabPrerequisites -Detailed
# Expected:
#   $pre.Status == 'Failed'
#   $pre.HyperVModule == $false
#   $pre.PendingReboot == $false
#   Recommendation recommends running Install-LabHyperV

# 3. Execute Role Installation via Lab Tool
Install-LabHyperV -Restart
# Expected:
#   - Validates firmware VT-x/AMD-V
#   - Validates Windows Edition (Pro/Enterprise/Server)
#   - Checks third-party hypervisors (VirtualBox, VMware)
#   - Enables Microsoft-Hyper-V-All feature
#   - Detects pending reboot state and reboots computer automatically

# 4. Post-Reinstall Verification (After Automated Reboot)
Import-Module .\HyperV-LinuxLab.psd1 -Force
Test-LabPrerequisites -Detailed
# Expected: Status == 'Ready'

# 5. End-to-End Lab Deployment Test
# Spin up 3-node heterogeneous cluster (Ubuntu + Debian + AlmaLinux)
New-LabCluster -Path .\examples\multi-distro-cluster.json -AutoDownload

# Verify metadata, IPs, and credentials recall
Get-LabVM
Test-LabCluster -Path .\examples\multi-distro-cluster.json

# Clean Teardown
Remove-LabCluster -Path .\examples\multi-distro-cluster.json -Force
```

---

## 1. Active Sprint Backlog

- [ ] **[PHASE-11] Windows Guest Node Support (Ansible & Hybrid Labs)**:
  - Base Image: Microsoft official evaluation VHDX (Windows Server 2022 / 2025 Eval 180-day).
  - Unattended Config: Build `Private\New-LabUnattendISO.ps1` generating `autounattend.xml` on virtual ISO.
  - Ansible Telemetry: Auto-configure WinRM (HTTP/HTTPS) and Windows OpenSSH server on first boot.
  - Routing & VM Creation: Update `New-LabVM` to branch between Cloud-Init (`cidata.iso`) and Unattend (`unattend.iso`).
  - Inventory: Surface `WinRM` endpoint (`http://<ip>:5985`) in `Get-LabVM` and `metadata.json`.
- [x] **[PHASE-10] Multi-Distro Coexistence & Local VM Metadata Persistence** *(Archived: 2026-10-31T23:18:00-04:00)*
- [x] **[PHASE-9] Hyper-V Role Lifecycle & Automated Provisioning (`Install-LabHyperV.ps1`)** *(Archived: 2026-10-31T22:35:00-04:00)*

---

## 2. Architectural & DRY Tracking

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

### [2026-10-31T23:51:00-04:00] PHASE 12: Tutorials Hub Standardization, Interactive Navigation & PowerShell Module Qualification
- **Files Created**:
  - `tutorials/lab-01-deployment-and-ssh.md`: Lab 01 hands-on deployment, Scream test, key/passphrase login.
  - `tutorials/lab-02-linux-mental-model-and-filesystems.md`: Lab 02 Linux mental model, `/proc`/`/sys`, permissions, `strace`.
  - `tutorials/lab-03-processes-systemd-and-networking.md`: Lab 03 PID 1 ancestry, `systemctl`, `journalctl`, pipes, `iproute2`.
  - `tutorials/lab-04-snapshots-and-disaster-recovery.md`: Lab 04 break-fix drills, 2s snapshot rollback, 3s differencing reset.
  - `tutorials/lab-05-multi-distro-clusters.md`: Lab 05 heterogeneous multi-distro cluster coexistence, `sudo` vs `wheel`.
  - `tutorials/hyperv-01-prerequisites-and-hardware.md`: Hyper-V 01 silicon, SKU gating, WHVP, module qualification.
  - `tutorials/hyperv-02-installation-and-removal.md`: Hyper-V 02 DISM features, clean removal, CBS log debugging.
  - `tutorials/hyperv-03-virtual-networking.md`: Hyper-V 03 WinNAT, vSwitches, VMBus, module qualification callout.
  - `tutorials/hyperv-04-storage-and-differencing-disks.md`: Hyper-V 04 VHDX blocks, pointer chains, Scream test.
  - `tutorials/hyperv-05-vm-architecture-and-cloud-init.md`: Hyper-V 05 Gen2 UEFI, Secure Boot CA, NoCloud ISO9660.
  - `tutorials/hyperv-06-vm-lifecycle-and-telemetry.md`: Hyper-V 06 native power states, non-blocking telemetry, metadata.
- **Files Removed**:
  - `docs/01_DEPLOYMENT_AND_SSH_LOGIN.md`, `docs/02_LINUX_ESSENTIALS_OVERVIEW.md`, `docs/TUTORIAL_LEARNING_LINUX.md` (consolidated into `tutorials/`).
  - `tutorials/01-prerequisites-and-hardware.md` through `tutorials/06-vm-lifecycle-and-telemetry.md` (renamed with standardized `hyperv-` prefix).
- **Files Modified**:
  - `tutorials/README.md`: Built comprehensive curriculum hub with interactive quick-jump matrix, visual tracks, and reading guidance.
  - `README.md`: Updated tutorial index links to new track structure.
  - `docs/SPECIFICATION.md`: Added Section 3.5 documenting PowerShell Module Qualification & Collision Defense (`Hyper-V\<Cmdlet>`).
- **Summary**:
  - Consolidated all repository tutorials into a unified `tutorials/` hub with two distinct tracks (Track 1: Hands-On Linux Lab, Track 2: Hyper-V Systems Engineering).
  - Added top and bottom navigation bars across all 11 tutorials for seamless reading on GitHub.
  - Documented PowerShell Module Qualification (`Hyper-V\New-VMSwitch`, `Hyper-V\Get-VM`) across tutorials and specification to explain collision prevention with third-party tools like VMware PowerCLI.
  - 100% internal markdown links verified, zero machine-specific paths committed.
- **Pester Results**: 98 tests total, 0 failed, 0 skipped. Zero PSScriptAnalyzer errors or warnings.
