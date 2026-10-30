BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Checkpoint and Restore Lab VM" {
    BeforeEach {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VM' -MockWith {
            return [PSCustomObject]@{
                Name  = 'node-checkpoint'
                State = 'Running'
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Checkpoint-VM' -MockWith {
            return [PSCustomObject]@{
                VMName             = 'node-checkpoint'
                Name               = $SnapshotName
                CreationTime       = (Get-Date)
                ParentSnapshotName = ''
            }
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Get-VMSnapshot' -MockWith {
            return @(
                [PSCustomObject]@{
                    VMName             = 'node-checkpoint'
                    Name               = 'snap-01-pre-docker'
                    CreationTime       = (Get-Date).AddMinutes(-30)
                    ParentSnapshotName = ''
                    SnapshotType       = 'Standard'
                },
                [PSCustomObject]@{
                    VMName             = 'node-checkpoint'
                    Name               = 'snap-02-pre-k8s'
                    CreationTime       = (Get-Date).AddMinutes(-5)
                    ParentSnapshotName = 'snap-01-pre-docker'
                    SnapshotType       = 'Standard'
                }
            )
        }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Restore-VMSnapshot' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Remove-VMSnapshot' -MockWith { }
    }

    It "Creates a checkpoint with custom name" {
        $result = Checkpoint-LabVM -Name "node-checkpoint" -SnapshotName "pre-k8s-init"
        $result | Should -Not -BeNullOrEmpty
        $result.VMName | Should -Be "node-checkpoint"
        $result.SnapshotName | Should -Be "pre-k8s-init"

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Checkpoint-VM' -Times 1 -ParameterFilter {
            $Name -eq "node-checkpoint" -and $SnapshotName -eq "pre-k8s-init"
        }
    }

    It "Queries checkpoints with Get-LabCheckpoint" {
        $snaps = Get-LabCheckpoint -Name "node-checkpoint"
        $snaps.Count | Should -Be 2
        $snaps[0].Name | Should -Be "snap-02-pre-k8s"
    }

    It "Restores to the most recent checkpoint when -SnapshotName is omitted" {
        $result = Restore-LabVM -Name "node-checkpoint" -Force
        $result | Should -Not -BeNullOrEmpty
        $result.VMName | Should -Be "node-checkpoint"
        $result.RestoredSnapshot | Should -Be "snap-02-pre-k8s"

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Restore-VMSnapshot' -Times 1 -ParameterFilter {
            $VMName -eq "node-checkpoint" -and $Name -eq "snap-02-pre-k8s"
        }
    }

    It "Restores to a specific named checkpoint" {
        $result = Restore-LabVM -Name "node-checkpoint" -SnapshotName "snap-01-pre-docker" -Force
        $result.RestoredSnapshot | Should -Be "snap-01-pre-docker"

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Restore-VMSnapshot' -Times 1 -ParameterFilter {
            $VMName -eq "node-checkpoint" -and $Name -eq "snap-01-pre-docker"
        }
    }

    It "Deletes a checkpoint with Remove-LabCheckpoint" {
        Remove-LabCheckpoint -Name "node-checkpoint" -SnapshotName "snap-01-pre-docker" -Force

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' 'Hyper-V\Remove-VMSnapshot' -Times 1 -ParameterFilter {
            $VMName -eq "node-checkpoint" -and $Name -eq "snap-01-pre-docker"
        }
    }
}
