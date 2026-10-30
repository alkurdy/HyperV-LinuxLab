[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
    $script:testTempDir = Join-Path $TestDrive "CloudInitTest"
}

Describe "New-LabCloudInitISO" {
    BeforeEach {
        if (-not (Test-Path $script:testTempDir)) {
            New-Item -ItemType Directory -Path $script:testTempDir -Force | Out-Null
        }
    }

    AfterEach {
        if (Test-Path $script:testTempDir) {
            Remove-Item -Path $script:testTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "Generates a valid Cloud-Init NoCloud ISO with default parameters" {
        $result = New-LabCloudInitISO -Name "pester-test-node" -DestinationPath $script:testTempDir
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be "pester-test-node"
        Test-Path $result.ISOPath | Should -BeTrue
        $result.SizeKB | Should -BeGreaterThan 0
        $result.Username | Should -Be "labadmin"
    }

    It "Includes custom packages and credentials" {
        $secPass = ConvertTo-SecureString "TestLabPass123!" -AsPlainText -Force
        $result = New-LabCloudInitISO -Name "custom-node" `
            -Username "devops" `
            -Password $secPass `
            -Packages @("git", "curl", "vim") `
            -RunCommands @("echo 'pester test' > /tmp/pester.log") `
            -DestinationPath $script:testTempDir

        $result | Should -Not -BeNullOrEmpty
        $result.Username | Should -Be "devops"
        Test-Path $result.ISOPath | Should -BeTrue
    }
}
