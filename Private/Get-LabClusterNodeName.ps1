function Get-LabClusterNodeName {
    <#
    .SYNOPSIS
        Resolves the fully-qualified virtual machine name for a cluster node.
    .DESCRIPTION
        Prefixes the node name with the cluster name if not already prefixed, ensuring
        consistent node naming across deployment, validation, and teardown workflows.
    .PARAMETER ClusterName
        Name of the cluster specification.
    .PARAMETER NodeName
        Unqualified or partially-qualified node name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ClusterName,

        [Parameter(Mandatory = $true)]
        [string]$NodeName
    )

    if ($ClusterName -and -not $NodeName.StartsWith($ClusterName, [System.StringComparison]::OrdinalIgnoreCase)) {
        return "$ClusterName-$NodeName"
    }
    return $NodeName
}
