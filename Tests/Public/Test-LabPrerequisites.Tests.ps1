BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Test-LabPrerequisites" {
    It "Executes and returns a valid status object" {
        $result = Test-LabPrerequisites
        $result | Should -Not -BeNullOrEmpty
        $result.Status | Should -BeIn @("Ready", "Failed")
        $result.TargetFreeStorageGB | Should -BeGreaterThan 0
    }

    It "Returns detailed diagnostics when -Detailed is specified" {
        $result = Test-LabPrerequisites -Detailed
        $result.PSObject.Properties.Name | Should -Contain "AdministratorRights"
        $result.PSObject.Properties.Name | Should -Contain "WindowsEdition"
        $result.PSObject.Properties.Name | Should -Contain "HyperVSupported"
        $result.PSObject.Properties.Name | Should -Contain "HyperVModule"
        $result.PSObject.Properties.Name | Should -Contain "VirtualSwitch"
        $result.PSObject.Properties.Name | Should -Contain "LogicalCPUCores"
        $result.PSObject.Properties.Name | Should -Contain "TotalMemoryGB"
        $result.PSObject.Properties.Name | Should -Contain "TargetStoragePath"
        $result.PSObject.Properties.Name | Should -Contain "TargetFreeStorageGB"
        $result.PSObject.Properties.Name | Should -Contain "DiscoveredVolumes"
        $result.PSObject.Properties.Name | Should -Contain "RecommendedDrive"
        $result.PSObject.Properties.Name | Should -Contain "CloudImageAccess"
        $result.PSObject.Properties.Name | Should -Contain "Recommendation"
    }
}
