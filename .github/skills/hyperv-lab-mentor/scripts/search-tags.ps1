<#
.SYNOPSIS
    Fast tag and keyword search engine for the HyperV-LinuxLab repository.
.DESCRIPTION
    Scans markdown tutorials, documentation, and PowerShell cmdlets in HyperV-LinuxLab
    for specified tags, topics, cmdlets, or keywords, returning clean line-numbered matches.
.PARAMETER Query
    The tag or keyword to search (e.g., 'cgroups', 'fstab', 'differencing-disk', 'cloud-init').
.PARAMETER Path
    Optional root path of the HyperV-LinuxLab repository. Defaults to C:\Users\alkur\OneDrive\Documents\HyperV-LinuxLab.
.EXAMPLE
    .\search-tags.ps1 -Query "cgroups"
    .\search-tags.ps1 -Query "cloud-init" -Category "tutorials"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query,

    [Parameter(Mandatory = $false)]
    [string]$Path = "C:\Users\alkur\OneDrive\Documents\HyperV-LinuxLab",

    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Tutorials", "Cmdlets", "Docs")]
    [string]$Category = "All"
)

if (-not (Test-Path $Path)) {
    Write-Error "HyperV-LinuxLab path not found at: $Path"
    exit 1
}

$searchFolders = switch ($Category) {
    "Tutorials" { @(Join-Path $Path "tutorials") }
    "Cmdlets"   { @(Join-Path $Path "Public") }
    "Docs"      { @(Join-Path $Path "docs") }
    default     { @(Join-Path $Path "tutorials"), (Join-Path $Path "Public"), (Join-Path $Path "docs") }
}

Write-Host "Searching HyperV-LinuxLab for: [$Query]..." -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($folder in $searchFolders) {
    if (-not (Test-Path $folder)) { continue }
    $files = Get-ChildItem -Path $folder -Recurse -File -Include *.md, *.ps1, *.psd1

    foreach ($file in $files) {
        $matches = Select-String -Path $file.FullName -Pattern $Query -SimpleMatch -CaseSensitive:$false
        foreach ($m in $matches) {
            $relPath = $file.FullName.Replace($Path, "").TrimStart("\/")
            $results.Add([PSCustomObject]@{
                File = $relPath
                Line = $m.LineNumber
                Text = $m.Line.Trim()
            })
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "No matches found for '$Query'." -ForegroundColor Yellow
} else {
    Write-Host "Found $($results.Count) matches across $($results | Select-Object -ExpandProperty File -Unique | Measure-Object | Select-Object -ExpandProperty Count) files:`n" -ForegroundColor Green
    $results | Group-Object File | ForEach-Object {
        Write-Host "📁 $($_.Name)" -ForegroundColor Magenta
        foreach ($item in $_.Group) {
            $snippet = if ($item.Text.Length -gt 100) { $item.Text.Substring(0, 97) + "..." } else { $item.Text }
            Write-Host "   Line $($item.Line): " -NoNewline -ForegroundColor DarkGray
            Write-Host $snippet -ForegroundColor White
        }
        Write-Host ""
    }
}
