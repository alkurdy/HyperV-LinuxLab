function Install-LabHyperV {
    <#
    .SYNOPSIS
        Validates hardware virtualization and enables the Hyper-V role and management tools.
    .DESCRIPTION
        Checks firmware/BIOS VT-x/AMD-V virtualization, Windows edition compatibility,
        and coexisting hypervisors before enabling the Microsoft-Hyper-V Windows Optional Feature.
        Handles pending reboot detection and optional automated system restart.
    .PARAMETER Restart
        Automatically restarts the computer if the feature installation requires a reboot.
    .PARAMETER Force
        Overrides non-fatal hardware and co-existing hypervisor warnings.
    .EXAMPLE
        Install-LabHyperV
    .EXAMPLE
        Install-LabHyperV -Restart
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [switch]$Restart,
        [switch]$Force
    )

    Assert-Administrator

    # 1. Windows Edition compatibility
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $regEdition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).EditionID
    $caption = if ($os) { $os.Caption } else { "Unknown" }
    $isHomeEdition = ($caption -match '\bHome\b') -or ($regEdition -match '^Core')

    if ($isHomeEdition) {
        throw "Windows Home edition does not support Hyper-V natively. Windows Pro, Enterprise, Education, or Server is required."
    }

    # 2. BIOS / Hardware Virtualization (VT-x / AMD-V)
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $isHypervisorPresent = if ($cs -and $null -ne $cs.HypervisorPresent) { [bool]$cs.HypervisorPresent } else { $false }

    $firmwareEnabled = $true
    if (-not $isHypervisorPresent) {
        $processors = @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue)
        if ($processors.Count -gt 0) {
            $firmwareEnabled = [bool]($processors[0].VirtualizationFirmwareEnabled)
        }
    }

    if (-not $firmwareEnabled -and -not $isHypervisorPresent -and -not $Force) {
        throw "Hardware virtualization (Intel VT-x or AMD-V) is disabled in BIOS/UEFI. Please reboot into firmware settings and enable virtualization before installing Hyper-V. Pass -Force to override at your own risk."
    }

    # 3. Third-party hypervisor detection
    $competing = @()
    if (Get-Process -Name "VBoxSVC" -ErrorAction SilentlyContinue) { $competing += "Oracle VirtualBox" }
    if (Get-Process -Name "vmware-vmx" -ErrorAction SilentlyContinue) { $competing += "VMware Workstation" }
    if ($competing.Count -gt 0) {
        Write-Warning "Co-existing hypervisor detected: $($competing -join ', '). Ensure modern WHVP compatibility is enabled."
    }

    # 4. Pending reboot check
    $rebootPending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                     (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')

    # 5. Check current Hyper-V feature state
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -ErrorAction SilentlyContinue
    $isFeatureEnabled = ($feature -and $feature.State -eq 'Enabled')
    $hasHyperVModule = ($null -ne (Get-Command 'Hyper-V\New-VM' -ErrorAction SilentlyContinue))
    $vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
    $isVmmsRunning = ($vmms -and $vmms.Status -eq 'Running')

    if ($isFeatureEnabled -and $hasHyperVModule -and $isVmmsRunning) {
        $banner = Format-LabBanner -Title "[OK] Hyper-V Role Already Active" -Content "Hyper-V hypervisor, VMMS service, and PowerShell management tools are installed and operational."
        Write-Information $banner -InformationAction Continue
        return [PSCustomObject]@{
            FeatureState       = "Enabled"
            HypervisorRunning  = $true
            RestartNeeded      = $false
            Status             = "Ready"
        }
    }

    if ($isFeatureEnabled -and (-not $isVmmsRunning -or $rebootPending)) {
        Write-Warning "Hyper-V feature is enabled, but a system restart is required before the hypervisor becomes active."
        if ($Restart -and $PSCmdlet.ShouldProcess("Local Computer", "Restart Computer to complete Hyper-V initialization")) {
            Restart-Computer -Force:$Force
        }
        return [PSCustomObject]@{
            FeatureState      = "Enabled"
            HypervisorRunning = $false
            RestartNeeded     = $true
            Status            = "RebootRequired"
        }
    }

    # 6. Enable Hyper-V feature
    if ($PSCmdlet.ShouldProcess("Microsoft-Hyper-V-All", "Enable Hyper-V Optional Feature")) {
        Write-Information "--- Enabling Hyper-V Feature and Management Tools ---" -InformationAction Continue
        $result = try {
            Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V" -All -NoRestart -ErrorAction Stop
        } catch {
            throw "Failed to enable Hyper-V feature: $($_.Exception.Message)"
        }

        $needsRestart = [bool]($result.RestartNeeded -or $rebootPending)

        if ($needsRestart) {
            $banner = Format-LabBanner -Title "[ACTION REQUIRED] System Restart Required" -Content "Hyper-V has been successfully enabled, but the computer must be restarted to initialize the hypervisor microkernel."
            Write-Warning $banner

            if ($Restart -and $PSCmdlet.ShouldProcess("Local Computer", "Restart Computer to activate Hyper-V")) {
                Restart-Computer -Force:$Force
            }
        } else {
            $banner = Format-LabBanner -Title "[OK] Hyper-V Installed Successfully" -Content "Hyper-V feature and management tools are now enabled."
            Write-Information $banner -InformationAction Continue
        }

        return [PSCustomObject]@{
            FeatureState      = if ($result.State) { $result.State.ToString() } else { "Enabled" }
            HypervisorRunning = (-not $needsRestart)
            RestartNeeded     = $needsRestart
            Status            = if ($needsRestart) { "RebootRequired" } else { "Ready" }
        }
    }
}
