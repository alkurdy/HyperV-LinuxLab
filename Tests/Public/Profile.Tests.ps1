BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
    $script:testDir = Join-Path $TestDrive "ProfileTests"
    New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
}

Describe "Lab Toolchain Profiles" {
    It "Discovers built-in profiles with Get-LabProfile" {
        $profiles = Get-LabProfile
        $profiles.Count | Should -BeGreaterOrEqual 3
        $names = $profiles | ForEach-Object { $_.Name }
        $names | Should -Contain "Minimal"
        $names | Should -Contain "Container"
        $names | Should -Contain "Kubernetes"
    }

    It "Creates a custom profile with New-LabProfile" {
        $custom = New-LabProfile -Name "SecurityLab" `
            -Description "Penetration testing and packet analysis" `
            -Packages @("nmap", "wireshark", "tcpdump") `
            -DestinationPath $script:testDir

        $custom | Should -Not -BeNullOrEmpty
        Test-Path $custom.Path | Should -BeTrue

        $loaded = Get-Content $custom.Path -Raw | ConvertFrom-Json
        $loaded.Name | Should -Be "SecurityLab"
        $loaded.Packages | Should -Contain "nmap"
    }

    It "Applies built-in profile to Cloud-Init ISO generation" {
        $iso = New-LabCloudInitISO -Name "container-node" `
            -Profile "Container" `
            -DestinationPath $script:testDir

        $iso | Should -Not -BeNullOrEmpty
        $iso.Profile | Should -Be "Container"
        Test-Path $iso.ISOPath | Should -BeTrue
    }
}
