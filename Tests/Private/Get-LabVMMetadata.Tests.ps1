BeforeAll {
    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $moduleRoot "HyperV-LinuxLab.psd1") -Force
}

Describe "Get-LabVMMetadata" {
    BeforeEach {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $testDir "node-getmeta") -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $testDir) {
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "Reads metadata from metadata.json when present" {
        $meta = @{
            Name     = "node-getmeta"
            Distro   = "Ubuntu2204"
            Username = "superadmin"
            Password = "SecurePassword456"
            IPv4     = "172.16.0.22"
            SSH      = "ssh superadmin@172.16.0.22"
            Profile  = "K8sNode"
        }
        $meta | ConvertTo-Json | Set-Content (Join-Path $testDir "node-getmeta\metadata.json") -Encoding UTF8

        $res = & (Get-Module HyperV-LinuxLab) {
            param($vm, $dir)
            Get-LabVMMetadata -VMName $vm -LabStoragePath $dir
        } "node-getmeta" $testDir

        $res.Name | Should -Be "node-getmeta"
        $res.Distro | Should -Be "Ubuntu2204"
        $res.Username | Should -Be "superadmin"
        $res.Password | Should -Be "SecurePassword456"
        $res.IPv4 | Should -Be "172.16.0.22"
        $res.Profile | Should -Be "K8sNode"
    }

    It "Falls back to Hyper-V Notes when metadata.json is absent" {
        $fakeNotes = "Distro: AlmaLinux9`nUser: labadmin`nPassword: PassFromNotes`nIPv4: 192.168.1.100`nSSH: ssh labadmin@192.168.1.100"
        Mock -ModuleName HyperV-LinuxLab 'Hyper-V\Get-VM' {
            [PSCustomObject]@{
                Name  = "node-getmeta"
                Notes = $fakeNotes
            }
        }

        # Point to a path without metadata.json
        $emptyDir = Join-Path $testDir "empty"
        $res = & (Get-Module HyperV-LinuxLab) {
            param($vm, $dir)
            Get-LabVMMetadata -VMName $vm -LabStoragePath $dir
        } "node-getmeta" $emptyDir

        $res.Distro | Should -Be "AlmaLinux9"
        $res.Username | Should -Be "labadmin"
        $res.Password | Should -Be "PassFromNotes"
        $res.IPv4 | Should -Be "192.168.1.100"
        $res.SSH | Should -Be "ssh labadmin@192.168.1.100"
    }
}
