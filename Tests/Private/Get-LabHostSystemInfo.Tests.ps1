BeforeAll {
    $script:privatePath = Join-Path $PSScriptRoot "..\..\Private\Get-LabHostSystemInfo.ps1"
    . $script:privatePath
}

Describe "Get-LabHostSystemInfo" {
    It "Returns host telemetry with logical CPU cores and memory" {
        $info = Get-LabHostSystemInfo
        $info | Should -Not -BeNullOrEmpty
        $info.LogicalCPUCores | Should -BeGreaterThan 0
        $info.TotalMemoryGB | Should -BeGreaterThan 0
        $info.TargetDriveLetter | Should -Be "C"
        $info.TargetFreeStorageGB | Should -BeGreaterThan 0
    }

    It "Discovers target drive when custom path is provided" {
        $info = Get-LabHostSystemInfo -TargetPath "C:\HyperV-LinuxLab"
        $info.TargetDriveLetter | Should -Be "C"
        $info.TargetFreeStorageGB | Should -BeGreaterThan 0
    }

    It "Gracefully falls back when CIM instances cannot be queried" {
        Mock Get-CimInstance { throw "CIM Access Denied" }
        $info = Get-LabHostSystemInfo -TargetPath "C:\"
        $info.LogicalCPUCores | Should -BeGreaterThan 0
        $info.TotalMemoryGB | Should -Be 0.0
    }
}
