<#
.SYNOPSIS
    Deploys a single Ubuntu 24.04 Linux node using Hyper-V differencing disks.
.DESCRIPTION
    Demonstrates the end-to-end flow:
    1. Validate host prerequisites
    2. Ensure base cloud image is cached
    3. Provision a Gen2 VM in seconds
    4. Discover IP address and test connectivity
    5. Clean reset VM back to pristine factory state
#>

[CmdletBinding()]
param(
    [string]$NodeName = "linux-lab-01",
    [int]$MemoryGB = 2,
    [int]$CPUCount = 2
)

# Import module
Import-Module HyperV-LinuxLab -Force

# 1. Check prerequisites
Write-Information "--- Checking Hyper-V Host Readiness ---" -InformationAction Continue
$prereqs = Test-LabPrerequisites
if ($prereqs.Status -ne "Ready") {
    throw "Host prerequisites failed. Ensure you are running as Administrator with Hyper-V enabled."
}

# 2. Cache Ubuntu 24.04 LTS Base Image (skipped if already cached)
Write-Information "--- Ensuring Ubuntu 24.04 Base Image is Cached ---" -InformationAction Continue
$base = New-LabBaseImage -Distro "Ubuntu2404"
Write-Information "Using base image: $($base.Path)" -InformationAction Continue

# 3. Provision Gen2 VM with Differencing Disk & Cloud-Init
Write-Information "--- Provisioning Differencing VM '$NodeName' ---" -InformationAction Continue
$vm = New-LabVM -Name $NodeName `
    -BaseImage $base.Path `
    -MemoryGB $MemoryGB `
    -CPUCount $CPUCount `
    -Packages @("curl", "git", "jq", "htop") `
    -Start `
    -Verbose

Write-Information "Node online at IP: $($vm.IPv4)" -InformationAction Continue

# 4. View VM Status & Differencing Disk Size (< 10MB)
Get-LabVM -Name $NodeName | Format-Table Name, State, IPv4, DifferencingDiskMB, ParentBase

# 5. Example: Instant Reset to Clean State
# Uncomment below to trigger sub-5-second reset:
# Write-Information "--- Testing Instant 3-Second Reset ---" -InformationAction Continue
# Reset-LabVM -Name $NodeName -Force
