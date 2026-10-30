# Contributing to HyperV-LinuxLab

Thank you for your interest in contributing!

## Development Guidelines

1. **PowerShell Best Practices**:
   - Follow standard `Verb-Noun` naming conventions approved by PowerShell (`Get-Verb`).
   - Use full cmdlet names; do not use aliases in production code.
   - All state-modifying functions must implement `SupportsShouldProcess` (`-WhatIf` and `-Confirm`).
2. **Code Linting**:
   - Run `Invoke-ScriptAnalyzer -Path .\ -Recurse` before committing.
   - All code must pass with 0 Errors and 0 Warnings.
3. **Unit Testing**:
   - Write unit tests in `Tests/` using Pester 5.x.
   - Ensure all Hyper-V commands are mocked so tests run without bare-metal hypervisor dependencies.
   - Run `Invoke-Pester -Path .\Tests\` to verify all tests pass.

## Pull Request Process

1. Fork the repository and create a feature branch (`git checkout -b feature/my-enhancement`).
2. Implement your changes, documentation, and corresponding Pester tests.
3. Verify tests pass locally.
4. Submit a Pull Request targeting `main`.
