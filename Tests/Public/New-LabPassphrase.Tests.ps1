BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "..\..\HyperV-LinuxLab.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "New-LabPassphrase" {
    It "Generates default passphrase with 2 words, hyphen separator, and number" {
        $phrase = New-LabPassphrase
        $phrase | Should -Not -BeNullOrEmpty
        $parts = $phrase -split '-'
        $parts.Count | Should -Be 3
        [int]$parts[2] | Should -BeGreaterOrEqual 10
        [int]$parts[2] | Should -BeLessOrEqual 99
    }

    It "Generates unique passphrases on consecutive calls" {
        $phrase1 = New-LabPassphrase
        $phrase2 = New-LabPassphrase
        $phrase1 | Should -Not -Be $phrase2
    }

    It "Respects custom WordCount, Separator, and IncludeNumber" {
        $phrase = New-LabPassphrase -WordCount 3 -Separator "_" -IncludeNumber $false
        $parts = $phrase -split '_'
        $parts.Count | Should -Be 3
    }

    It "Supports single-word passphrases without appending a number" {
        $phrase = New-LabPassphrase -WordCount 1 -IncludeNumber $false
        $phrase | Should -Not -BeNullOrEmpty
        $phrase.Contains('-') | Should -BeFalse
    }

    It "Returns System.Security.SecureString when -AsSecureString is passed" {
        $sec = New-LabPassphrase -AsSecureString
        $sec | Should -BeOfType [System.Security.SecureString]
        $sec.Length | Should -BeGreaterThan 0
    }
}
