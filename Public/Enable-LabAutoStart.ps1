function Enable-LabAutoStart {
    <#
    .SYNOPSIS
        Configures Hyper-V Linux lab virtual machines to start automatically upon computer startup.
    .DESCRIPTION
        Enables computer startup auto-boot for lab VMs using native Hyper-V
        AutomaticStartAction (recommended, zero-dependency, boots before user logon),
        a Windows Scheduled Task, or both.
    .PARAMETER Name
        Names or wildcard patterns of specific lab VMs to configure.
    .PARAMETER Path
        Path to a cluster topology JSON file defining target nodes.
    .PARAMETER Mode
        Auto-start mechanism to configure:
        - 'HyperV': Configures native Hyper-V VM AutomaticStartAction = 'Start' (default).
        - 'ScheduledTask': Registers a Windows Scheduled Task executing 'Start-Lab -Wait'.
        - 'Both': Configures both native hypervisor actions and the scheduled task.
    .PARAMETER DelaySeconds
        Stagger delay in seconds before starting VMs upon host startup (default: 0).
    .PARAMETER Trigger
        Trigger type when using ScheduledTask mode: 'AtStartup' (default) or 'AtLogOn'.
    .EXAMPLE
        Enable-LabAutoStart
    .EXAMPLE
        Enable-LabAutoStart -Mode HyperV -DelaySeconds 10
    .EXAMPLE
        Enable-LabAutoStart -Path .\examples\k8s-3node-cluster.json -Mode Both
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true, Position = 0)]
        [string]$Path,

        [ValidateSet('HyperV', 'ScheduledTask', 'Both')]
        [string]$Mode = 'HyperV',

        [int]$DelaySeconds = 0,

        [ValidateSet('AtStartup', 'AtLogOn')]
        [string]$Trigger = 'AtStartup'
    )

    begin {
        Assert-Administrator
    }

    process {
        $targetVMs = @(Get-LabTargetVM -Name $Name -Path $Path)
        if ($targetVMs.Count -eq 0 -and $Mode -ne 'ScheduledTask') {
            Write-Warning "No Hyper-V Linux lab virtual machines were found."
            return @()
        }

        Write-Information "--- Enabling Lab Auto-Start (Mode: $Mode) ---" -InformationAction Continue

        $results = @()

        # 1. Native Hyper-V AutomaticStartAction
        if ($Mode -in @('HyperV', 'Both')) {
            foreach ($vm in $targetVMs) {
                $vmName = $vm.Name
                if ($PSCmdlet.ShouldProcess($vmName, "Set AutomaticStartAction to 'Start' (Delay: ${DelaySeconds}s)")) {
                    Hyper-V\Set-VM -Name $vmName `
                        -AutomaticStartAction Start `
                        -AutomaticStartDelay $DelaySeconds `
                        -AutomaticStopAction ShutDown | Out-Null

                    Write-Information "[OK] VM '$vmName' configured: AutomaticStartAction=Start, Delay=${DelaySeconds}s, AutomaticStopAction=ShutDown" -InformationAction Continue

                    $results += [PSCustomObject]@{
                        Target               = $vmName
                        Type                 = "HyperV-VM"
                        AutomaticStartAction = "Start"
                        DelaySeconds         = $DelaySeconds
                        AutomaticStopAction  = "ShutDown"
                        Status               = "Enabled"
                    }
                }
            }
        }

        # 2. Windows Scheduled Task
        if ($Mode -in @('ScheduledTask', 'Both')) {
            $taskName = "HyperV-LinuxLab-AutoStart"
            if ($PSCmdlet.ShouldProcess($taskName, "Register Scheduled Task to launch 'Start-Lab -Wait' on $Trigger")) {
                $psExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
                    (Get-Command pwsh.exe).Source
                } else {
                    Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
                }

                $scriptCmd = if ($Path) {
                    "Import-Module HyperV-LinuxLab; Start-Lab -Path '$Path' -Wait"
                } else {
                    "Import-Module HyperV-LinuxLab; Start-Lab -Wait"
                }

                $action = New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$scriptCmd`""

                $taskTrigger = if ($Trigger -eq 'AtStartup') {
                    New-ScheduledTaskTrigger -AtStartup
                } else {
                    New-ScheduledTaskTrigger -AtLogOn
                }

                $principal = if ($Trigger -eq 'AtStartup') {
                    New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                } else {
                    New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
                }

                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

                $null = Register-ScheduledTask -TaskName $taskName `
                    -Action $action `
                    -Trigger $taskTrigger `
                    -Principal $principal `
                    -Settings $settings `
                    -Force

                Write-Information "[OK] Registered Scheduled Task '$taskName' ($Trigger, RunLevel: Highest)" -InformationAction Continue

                $results += [PSCustomObject]@{
                    Target               = $taskName
                    Type                 = "ScheduledTask"
                    AutomaticStartAction = $Trigger
                    DelaySeconds         = 0
                    AutomaticStopAction  = "N/A"
                    Status               = "Registered"
                }
            }
        }

        # Standardized Terminal Summary Box
        $tableOutput = ($results | Format-Table Target, Type, AutomaticStartAction, DelaySeconds, Status | Out-String).Trim()

        Write-Information @"

============================================================
 [OK] Lab Auto-Start Enabled (Mode: $Mode)
------------------------------------------------------------
$tableOutput
============================================================
"@ -InformationAction Continue

        return $results
    }
}
