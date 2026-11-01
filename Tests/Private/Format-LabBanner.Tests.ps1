BeforeAll {
    $script:privatePath = Join-Path $PSScriptRoot "..\..\Private\Format-LabBanner.ps1"
    . $script:privatePath
}

Describe "Format-LabBanner" {
    It "Renders a formatted ASCII banner with title and body" {
        $banner = Format-LabBanner -Title "[OK] Test Title" -Content "Sample line 1`nSample line 2"
        $banner | Should -Match "={60}"
        $banner | Should -Match " \[OK\] Test Title"
        $banner | Should -Match "-{60}"
        $banner | Should -Match "Sample line 1"
        $banner | Should -Match "Sample line 2"
    }

    It "Renders a title-only banner when content is empty" {
        $banner = Format-LabBanner -Title "[INFO] Empty Box"
        $banner | Should -Match "={60}"
        $banner | Should -Match " \[INFO\] Empty Box"
        $banner | Should -Not -Match "-{60}"
    }

    It "Respects custom Width parameter" {
        $banner = Format-LabBanner -Title "Custom Width" -Width 40
        $banner | Should -Match "={40}"
    }
}
