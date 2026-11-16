# HyperV-LinuxLab Root Module
$moduleRoot = $PSScriptRoot

# 1. Dot-source Private helper functions
$privateFiles = Get-ChildItem -Path (Join-Path $moduleRoot "Private") -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $privateFiles) {
    . $file.FullName
}

# 2. Dot-source Public cmdlets
$publicFiles = Get-ChildItem -Path (Join-Path $moduleRoot "Public") -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $publicFiles) {
    . $file.FullName
}

# 3. Explicitly export Public cmdlets
$functionsToExport = $publicFiles | ForEach-Object { $_.BaseName }
Export-ModuleMember -Function $functionsToExport

# 4. Auto-sync agent skill silently if agent directories exist
Install-LabAgentSkill -ErrorAction SilentlyContinue
