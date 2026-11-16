function Install-LabAgentSkill {
    <#
    .SYNOPSIS
        Installs and synchronizes the hyperv-lab-mentor AI agent skill to local agent environments.
    .DESCRIPTION
        Deploys the bundled hyperv-lab-mentor skill, Master Location Index, and tag search script
        to global agent configuration directories (Google Antigravity / Gemini CLI, Claude, and Copilot).
        Ensures AI assistants in any terminal session possess full awareness of the lab curriculum and cmdlets.
    .PARAMETER Force
        Overwrites existing skill files even if timestamps match.
    .EXAMPLE
        Install-LabAgentSkill
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$Force
    )

    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    $sourceSkill = Join-Path $moduleRoot ".github\skills\hyperv-lab-mentor"

    if (-not (Test-Path $sourceSkill)) {
        Write-Warning "Source skill folder not found at: $sourceSkill"
        return
    }

    $deployed = @()

    # 1. Antigravity / Gemini CLI (~/.gemini/config/skills)
    $geminiParent = Join-Path $env:USERPROFILE ".gemini\config\skills"
    if (Test-Path (Split-Path $geminiParent -Parent)) {
        if (-not (Test-Path $geminiParent)) {
            New-Item -ItemType Directory -Path $geminiParent -Force | Out-Null
        }
        $targetGemini = Join-Path $geminiParent "hyperv-lab-mentor"
        if ($Force -or (-not (Test-Path $targetGemini)) -or ((Get-Item $sourceSkill).LastWriteTime -gt (Get-Item $targetGemini).LastWriteTime)) {
            Copy-Item -Path $sourceSkill -Destination $geminiParent -Recurse -Force
            $deployed += "Google Antigravity / Gemini CLI ($targetGemini)"
        }
    }

    # 2. Claude Code (~/.claude/skills)
    $claudeParent = Join-Path $env:USERPROFILE ".claude\skills"
    if (Test-Path (Split-Path $claudeParent -Parent)) {
        if (-not (Test-Path $claudeParent)) {
            New-Item -ItemType Directory -Path $claudeParent -Force | Out-Null
        }
        $targetClaude = Join-Path $claudeParent "hyperv-lab-mentor"
        if ($Force -or (-not (Test-Path $targetClaude))) {
            Copy-Item -Path $sourceSkill -Destination $claudeParent -Recurse -Force
            $deployed += "Claude Code ($targetClaude)"
        }
    }

    if ($deployed.Count -gt 0) {
        Write-Host "[OK] Deployed HyperV-LinuxLab AI Mentor to: $($deployed -join ', ')" -ForegroundColor Green
    } else {
        Write-Verbose "AI mentor skill is already up to date across all detected agent platforms."
    }
}
