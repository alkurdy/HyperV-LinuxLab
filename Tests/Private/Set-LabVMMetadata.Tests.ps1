BeforeAll {
    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $moduleRoot "HyperV-LinuxLab.psd1") -Force
}

Describe "Set-LabVMMetadata" {
    BeforeEach {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $testDir "node-meta-01") -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $testDir) {
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "Persists metadata to metadata.json in VM directory" {
        Mock -ModuleName HyperV-LinuxLab 'Hyper-V\Set-VM' { $true }

        $res = & (Get-Module HyperV-LinuxLab) {
            param($vm, $distro, $user, $pass, $ip, $dir)
            Set-LabVMMetadata -VMName $vm -Distro $distro -Username $user -Password $pass -IPv4 $ip -LabStoragePath $dir
        } "node-meta-01" "Debian12" "labadmin" "SecretPass123" "192.168.1.50" $testDir

        $res.Name | Should -Be "node-meta-01"
        $res.Distro | Should -Be "Debian12"
        $res.IPv4 | Should -Be "192.168.1.50"
        $res.SSH | Should -Be "ssh labadmin@192.168.1.50"

        $jsonPath = Join-Path $testDir "node-meta-01\metadata.json"
        (Test-Path $jsonPath) | Should -BeTrue

        $saved = Get-Content $jsonPath -Raw | ConvertFrom-Json
        $saved.Distro | Should -Be "Debian12"
        $saved.Password | Should -Be "SecretPass123"
    }

    It "Merges partial updates into existing metadata" {
        Mock -ModuleName HyperV-LinuxLab 'Hyper-V\Set-VM' { $true }

        # Initial write
        & (Get-Module HyperV-LinuxLab) {
            param($vm, $distro, $pass, $dir)
            Set-LabVMMetadata -VMName $vm -Distro $distro -Password $pass -LabStoragePath $dir
        } "node-meta-01" "AlmaLinux9" "MySecretPass" $testDir

        # Incremental update with new IP
        $updated = & (Get-Module HyperV-LinuxLab) {
            param($vm, $ip, $dir)
            Set-LabVMMetadata -VMName $vm -IPv4 $ip -LabStoragePath $dir
        } "node-meta-01" "10.0.0.99" $testDir

        $updated.Distro | Should -Be "AlmaLinux9"
        $updated.Password | Should -Be "MySecretPass"
        $updated.IPv4 | Should -Be "10.0.0.99"
        $updated.SSH | Should -Be "ssh labadmin@10.0.0.99"
    }
}
