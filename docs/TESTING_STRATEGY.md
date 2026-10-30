# HyperV-LinuxLab - Testing & Quality Strategy

Comprehensive automated testing strategy utilizing **Pester 5.x** and **PSScriptAnalyzer** to ensure 100% CI reproducibility without requiring bare-metal nested virtualization.

---

## 1. Testing Architecture Overview

Testing is partitioned into two decoupled tiers:

```
+--------------------------------------------------------------------------+
| TIER 1: Offline Unit Testing (CI-Ready, Mocked Hyper-V)                  |
| Executed on GitHub Actions (windows-latest) & Local Developer Terminals  |
| * Tests: Parameter validation, Cloud-Init YAML syntax, differencing      |
|   disk paths, ISO 9660 volume labeling, error handling, pipeline support |
| * Tooling: Pester 5.6+, PSScriptAnalyzer                                 |
| * Hyper-V Mocking: Mocks Hyper-V\New-VM, New-VHD, Stop-VM, Get-VM       |
+--------------------------------------------------------------------------+
                                     │
                                     ▼
+--------------------------------------------------------------------------+
| TIER 2: Live Integration Testing (Privileged Host with Hyper-V)          |
| Executed locally on Windows 11 with Hyper-V enabled                      |
| * Tests: Real VHDX differencing creation, live UEFI Secure Boot,         |
|   cloud-init guest user creation, KVP IP resolution, sub-5-second reset  |
| * Target: Disposable VM 'pester-integration-vm'                         |
+--------------------------------------------------------------------------+
```

---

## 2. Unit Testing Strategy (Tier 1: Mocked)

### Why Mocking is Required in CI
GitHub-hosted runner environments (`windows-latest`) execute inside standard Azure virtual machines without nested virtualization enabled by default. Trying to call hardware `Hyper-V\New-VM` directly would fail in CI.

By abstracting and mocking the underlying Hyper-V cmdlets in Tier 1:
1. All parameter validation, business logic, differencing calculations, and pipeline mechanics are verified on every push and pull request.
2. Cloud-Init `meta-data` and `user-data` formatting is strictly validated against YAML specifications.
3. Code quality and syntax conformity are validated across Windows PowerShell 5.1 and PowerShell Core 7.x.

### Core Mocking Patterns

```powershell
Describe "New-LabVM Unit Tests" {
    BeforeAll {
        # Import module under test
        Import-Module (Join-Path $PSScriptRoot "../../HyperV-LinuxLab.psd1") -Force
    }

    Context "Parameter Validation and Differencing Disk Creation" {
        BeforeEach {
            # Mock Hyper-V native commands
            Mock -CommandName 'Hyper-V\Get-VM' -MockWith { return $null }
            Mock -CommandName 'Hyper-V\New-VM' -MockWith {
                return [PSCustomObject]@{
                    Name = $Name
                    Id   = [guid]::NewGuid()
                }
            }
            Mock -CommandName 'New-VHD' -MockWith {
                return [PSCustomObject]@{
                    Path       = $Path
                    ParentPath = $ParentPath
                    VhdType    = 'Differencing'
                }
            }
            Mock -CommandName 'Set-VMFirmware' -MockWith { return $null }
            Mock -CommandName 'Set-VMProcessor' -MockWith { return $null }
        }

        It "Creates differencing disk pointing to base image" {
            $result = New-LabVM -Name "test-vm" -BaseImage "C:\Base.vhdx" -MemoryGB 2 -DryRun
            Assert-MockCalled New-VHD -Times 1 -ParameterFilter {
                $ParentPath -eq "C:\Base.vhdx" -and $VhdType -eq "Differencing"
            }
        }

        It "Configures Gen2 UEFI with Microsoft Linux Secure Boot Authority" {
            New-LabVM -Name "test-vm" -BaseImage "C:\Base.vhdx"
            Assert-MockCalled Set-VMFirmware -Times 1 -ParameterFilter {
                $EnableSecureBoot -eq $true -and $SecureBootTemplate -eq "MicrosoftUEFICertificateAuthority"
            }
        }
    }
}
```

---

## 3. Cloud-Init Schema Verification

Unit tests for `New-LabCloudInitISO` validate that the injected `user-data` adheres to cloud-init standards:

1. **Header Validation**: Must begin with `#cloud-config`.
2. **YAML Parsability**: Validates that passwords, SSH keys, package arrays, and runcmd strings parse as clean YAML.
3. **NoCloud Labeling**: Validates that generated ISO metadata contains volume label `cidata` in uppercase (mandatory for cloud-init discovery).

---

## 4. Reset Performance Contract Test

`Reset-LabVM` enforces a strict performance boundary:
```powershell
It "Completes differencing disk reset within 5 seconds" {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Reset-LabVM -Name "test-vm" -Force
    $stopwatch.Stop()
    $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
}
```

---

## 5. PSScriptAnalyzer Rules & Static Code Analysis

Every file in the module is subjected to strict PSScriptAnalyzer linting:

| Rule Name | Severity | Enforcement |
| :--- | :--- | :--- |
| `PSUseApprovedVerbs` | Error | All public cmdlets must strictly use approved verbs (`New`, `Get`, `Reset`, `Remove`, `Start`, `Stop`, `Test`). |
| `PSAvoidUsingCmdletAliases` | Warning | Aliases like `dir`, `echo`, `cat`, or `kill` are banned in production code. |
| `PSUseDeclaredVarsMoreThanAssignments` | Warning | No unused or dangling variables. |
| `PSAvoidUsingEmptyCatchBlock` | Error | All catch blocks must explicitly handle, log, or re-throw exceptions. |
| `PSUseShouldProcessForStateChangingFunctions` | Warning | Functions modifying state (`New`, `Reset`, `Remove`) must support `-WhatIf` and `-Confirm`. |

---

## 6. GitHub Actions CI Matrix

The continuous integration workflow `.github/workflows/ci.yml` runs on:
- **Operating System**: `windows-latest`
- **PowerShell Shells**:
  - `pwsh` (PowerShell 7.x)
  - `powershell` (Windows PowerShell 5.1)
- **Steps**:
  1. Checkout repository.
  2. Install `Pester` (v5.6+) and `PSScriptAnalyzer`.
  3. Execute `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning`.
  4. Execute `Invoke-Pester -Configuration $config`.
  5. Publish test results artifact (NUnit XML).
