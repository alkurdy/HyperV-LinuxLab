function Assert-Administrator {
    <#
    .SYNOPSIS
        Validates whether the current PowerShell process has administrative privileges.
    .DESCRIPTION
        Throws an actionable error if the user is running unprivileged, as Hyper-V
        management operations require local Administrator permissions.
    #>
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Administrator privileges required. Please reopen PowerShell as Administrator to manage Hyper-V lab environments."
    }
}
