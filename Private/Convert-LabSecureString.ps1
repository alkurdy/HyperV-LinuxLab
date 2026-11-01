function ConvertTo-LabSecureString {
    <#
    .SYNOPSIS
        Converts a plaintext string to a read-only SecureString.
    .DESCRIPTION
        Safely instantiates and seals a System.Security.SecureString instance.
    .PARAMETER PlainText
        The plaintext string to convert.
    #>
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainText
    )

    $sec = [System.Security.SecureString]::new()
    foreach ($c in $PlainText.ToCharArray()) {
        $sec.AppendChar($c)
    }
    $sec.MakeReadOnly()
    return $sec
}

function ConvertFrom-LabSecureString {
    <#
    .SYNOPSIS
        Extracts the plaintext string from a SecureString.
    .DESCRIPTION
        Unwraps a System.Security.SecureString instance via NetworkCredential.
    .PARAMETER SecureString
        The SecureString to unwrap.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$SecureString
    )

    return [System.Net.NetworkCredential]::new('', $SecureString).Password
}
