#
# Module manifest for module 'HyperV-LinuxLab'
#
@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'HyperV-LinuxLab.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = '8c3d9b44-904e-45ac-96f5-10cac88b9992'

    # Author of this module
    Author = 'alkurdy'

    # Company or vendor of this module
    CompanyName = 'alkurdy'

    # Copyright statement for this module
    Copyright = '(c) 2026 alkurdy. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Lightweight PowerShell module to provision, test, and instantly reset ephemeral Linux virtual machines on Hyper-V using differencing disks and Cloud-Init.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module, for best performance, do not use wildcards
    FunctionsToExport = @(
        'Checkpoint-LabVM',
        'Get-LabBaseImage',
        'Get-LabCheckpoint',
        'Get-LabConfiguration',
        'Get-LabProfile',
        'Get-LabVM',
        'New-LabBaseImage',
        'New-LabCloudInitISO',
        'New-LabCluster',
        'New-LabProfile',
        'New-LabVM',
        'Remove-LabCheckpoint',
        'Remove-LabCluster',
        'Remove-LabVM',
        'Reset-LabVM',
        'Restore-LabVM',
        'Set-LabConfiguration',
        'Start-LabVM',
        'Stop-LabVM',
        'Test-LabCluster',
        'Test-LabPrerequisites'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Hyper-V', 'Linux', 'Cloud-Init', 'DifferencingDisk', 'DevOps', 'Kubernetes', 'Ubuntu', 'Lab', 'IaC')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/alkurdy/HyperV-LinuxLab/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/alkurdy/HyperV-LinuxLab'
        }
    }
}
