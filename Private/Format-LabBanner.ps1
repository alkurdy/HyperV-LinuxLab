function Format-LabBanner {
    <#
    .SYNOPSIS
        Formats a standardized terminal status banner with ASCII borders.
    .DESCRIPTION
        Generates a consistent bordered ASCII box around title and body content
        for terminal progress and status summaries.
    .PARAMETER Title
        Header title to display inside the box (e.g. '[OK] Linux Lab VM Ready!').
    .PARAMETER Content
        Body string or multiline text block.
    .PARAMETER Width
        Width of the border in characters. Default is 60.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string]$Content = "",

        [Parameter(Mandatory = $false)]
        [int]$Width = 60
    )

    $top = "=" * $Width
    $sep = "-" * $Width
    $trimmedContent = if ($Content) { "$Content".Trim() } else { "" }

    if ($trimmedContent) {
        return @"

$top
 $Title
$sep
$trimmedContent
$top
"@
    } else {
        return @"

$top
 $Title
$top
"@
    }
}
