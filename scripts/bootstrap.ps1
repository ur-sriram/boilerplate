<#
.SYNOPSIS
    Project Bootstrap Script for Autonomous Coding Agents.
.DESCRIPTION
    Establishes zero-elevation NTFS Directory Junctions on Windows (.codex\skills, .qoder\skills -> .agents\skills),
    verifies local runtime dependencies, and initializes project boundaries without modifying global user configs.
.PARAMETER Force
    Forces re-creation of junctions/symlinks if they already exist.
.PARAMETER SkipChecks
    Skips environment prerequisite checks.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipChecks
)

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $ProjectRoot

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Multi-Agent Project Boilerplate Bootstrap Initialization  " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[INFO] Project root: $ProjectRoot"

# 1. Ensure canonical skill store directory exists
$CanonicalSkillsDir = Join-Path $ProjectRoot ".agents\skills"
if (-not (Test-Path -LiteralPath $CanonicalSkillsDir)) {
    Write-Host "[INFO] Creating canonical skill store at .agents\skills..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $CanonicalSkillsDir -Force | Out-Null
}

# 2. Setup secondary agent directories
$SecondaryDirs = @(
    (Join-Path $ProjectRoot ".codex"),
    (Join-Path $ProjectRoot ".qoder")
)
foreach ($dir in $SecondaryDirs) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# 3. Establish zero-elevation NTFS Directory Junctions for every supported agent.
#    Delegated to sync-agent-adapters.ps1 so the junction logic lives in ONE place.
#    The previous inline copy only created .codex and .qoder, which left Claude
#    Code, Cursor, Windsurf and Cline with zero access to the skill store.
Write-Host "[INFO] Establishing skill junctions for all supported agents..." -ForegroundColor Cyan
try {
    & (Join-Path $ProjectRoot "scripts\sync-agent-adapters.ps1") -ProjectRoot $ProjectRoot
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Skill junctions established for all supported agents." -ForegroundColor Green
    } else {
        Write-Host "[WARN] Some skill junctions could not be established; run scripts\sync-agent-adapters.ps1 manually." -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARN] Adapter sync failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 4. Verify boundary coherence (.gitignore includes secondary agent skills)
$GitIgnorePath = Join-Path $ProjectRoot ".gitignore"
if (Test-Path -LiteralPath $GitIgnorePath) {
    $gitIgnoreContent = Get-Content -LiteralPath $GitIgnorePath -Raw
    $mirroredSkillDirs = @(".claude/skills/", ".cline/skills/", ".codex/skills/", ".cursor/skills/", ".qoder/skills/", ".windsurf/skills/")
    $missingDirs = @($mirroredSkillDirs | Where-Object { $gitIgnoreContent -notmatch "(?m)^$([regex]::Escape($_))?$" })
    if ($missingDirs.Count -gt 0) {
        Write-Host "[INFO] Registering secondary skill directories in .gitignore..." -ForegroundColor Yellow
        Add-Content -LiteralPath $GitIgnorePath -Value ("`n# Secondary Agent Mirrored Skills`n" + ($missingDirs -join "`n"))
    }
}

# 5. Environment Runtime Verification
if (-not $SkipChecks) {
    Write-Host "`n--- Verifying Local Environment Runtimes ---" -ForegroundColor Cyan
    
    # Git
    try {
        $gitVersion = (& git --version 2>$null)
        Write-Host "[OK] Git: $gitVersion" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Git not detected in PATH" -ForegroundColor Yellow
    }

    # Node.js
    try {
        $nodeVersion = (& node --version 2>$null)
        Write-Host "[OK] Node.js: $nodeVersion" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Node.js not detected in PATH" -ForegroundColor Yellow
    }

    # Python
    try {
        $pyVersion = (& python --version 2>$null)
        Write-Host "[OK] Python: $pyVersion" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Python not detected in PATH" -ForegroundColor Yellow
    }

    # PowerShell
    $psVer = $PSVersionTable.PSVersion.ToString()
    Write-Host "[OK] PowerShell: $psVer" -ForegroundColor Green
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "   Bootstrap Complete: 0 global files modified              " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
exit 0
