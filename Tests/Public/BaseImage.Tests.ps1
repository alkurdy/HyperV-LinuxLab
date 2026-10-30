BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Get-LabBaseImage" {
    BeforeEach {
        $script:testBaseDir = Join-Path $TestDrive "BaseImages"
        if (Test-Path $script:testBaseDir) {
            Remove-Item $script:testBaseDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:testBaseDir -Force | Out-Null
    }

    It "Returns empty array when directory does not exist or has no vhdx" {
        $result = Get-LabBaseImage -Path (Join-Path $TestDrive "nonexistent")
        $result | Should -BeNullOrEmpty
    }

    It "Discovers cached vhdx base images" {
        $img = Join-Path $script:testBaseDir "ubuntu-24.04-server-cloudimg-amd64.vhdx"
        New-Item -ItemType File -Path $img -Force | Out-Null

        $result = Get-LabBaseImage -Path $script:testBaseDir
        $result | Should -Not -BeNullOrEmpty
        $result.Distro | Should -Be "Ubuntu2404"
        $result.Name | Should -Be "ubuntu-24.04-server-cloudimg-amd64.vhdx"
    }
}

Describe "New-LabBaseImage" {
    BeforeEach {
        $script:testBaseDir = Join-Path $TestDrive "BaseImages"
        if (Test-Path $script:testBaseDir) {
            # In case previous test set ReadOnly on files inside, unlock them before removing
            Get-ChildItem -Path $script:testBaseDir -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.PSIsContainer -eq $false) { $_.IsReadOnly = $false }
            }
            Remove-Item $script:testBaseDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:testBaseDir -Force | Out-Null

        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-Administrator' -MockWith { }
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Assert-LabDiskSpace' -MockWith { return $true }
    }

    It "Returns cached record if VHDX already exists without Force" {
        $targetFile = Join-Path $script:testBaseDir "ubuntu-24.04-server-cloudimg-amd64.vhdx"
        New-Item -ItemType File -Path $targetFile -Force | Out-Null

        $result = New-LabBaseImage -Distro "Ubuntu2404" -DestinationPath $script:testBaseDir
        $result.Status | Should -Be "Cached"
        $result.Distro | Should -Be "Ubuntu2404"
    }

    It "Downloads, extracts, and converts image when not cached" {
        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Invoke-WebRequest' -MockWith {
            param($OutFile)
            New-Item -ItemType File -Path $OutFile -Force | Out-Null
        }

        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'tar.exe' -MockWith {
            $vhd = Join-Path $script:testBaseDir "livecd.ubuntu-cpc.azure.vhd"
            New-Item -ItemType File -Path $vhd -Force | Out-Null
            $global:LASTEXITCODE = 0
            return ""
        }

        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'fsutil' -MockWith {
            return ""
        }

        Mock -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Convert-VHD' -MockWith {
            param($Path, $DestinationPath, [switch]$DeleteSource)
            New-Item -ItemType File -Path $DestinationPath -Force | Out-Null
            if ($DeleteSource -and (Test-Path $Path)) {
                Remove-Item $Path -Force -ErrorAction SilentlyContinue
            }
        }

        $result = New-LabBaseImage -Distro "Ubuntu2404" -DestinationPath $script:testBaseDir
        $result | Should -Not -BeNullOrEmpty
        $result.Distro | Should -Be "Ubuntu2404"
        $result.Status | Should -Be "Downloaded"
        $result.IsReadOnly | Should -Be $true

        Assert-MockCalled -ModuleName 'HyperV-LinuxLab' -CommandName 'Hyper-V\Convert-VHD' -Times 1
    }
}
