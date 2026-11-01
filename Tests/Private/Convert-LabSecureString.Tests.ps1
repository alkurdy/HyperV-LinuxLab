BeforeAll {
    $script:privatePath = Join-Path $PSScriptRoot "..\..\Private\Convert-LabSecureString.ps1"
    . $script:privatePath
}

Describe "Convert-LabSecureString" {
    It "Converts plaintext to read-only SecureString" {
        $sec = ConvertTo-LabSecureString -PlainText "TestSecretPass123"
        $sec | Should -BeOfType [System.Security.SecureString]
        $sec.IsReadOnly() | Should -Be $true
    }

    It "Converts SecureString back to plaintext" {
        $original = "MyP@ssw0rd!#42"
        $sec = ConvertTo-LabSecureString -PlainText $original
        $unwrapped = ConvertFrom-LabSecureString -SecureString $sec
        $unwrapped | Should -Be $original
    }
}
