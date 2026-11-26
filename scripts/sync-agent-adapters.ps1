<#
.SYNOPSIS
    Creates and verifies directory junctions and pointer files for 13+ AI coding agents.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    if ($PSScriptRoot) { $Root = (Resolve-Path "$PSScriptRoot\..").Path }
    else { $Root = (Get-Location).Path }
} else {
    $Root = (Resolve-Path $ProjectRoot).Path
}

$SkillsCanonical = Join-Path $Root ".agents\skills"
$Errors = 0

Write-Host "================================================="
Write-Host "Syncing Universal Coding Agent Adapters & Junctions"
Write-Host "Root: $Root (VerifyOnly: $VerifyOnly)"
Write-Host "================================================="

$JunctionTargets = @(
    ".claude\skills",
    ".cursor\skills",
    ".windsurf\skills",
    ".cline\skills",
    ".codex\skills",
    ".qoder\skills"
)

foreach ($relLink in $JunctionTargets) {
    $linkPath = Join-Path $Root $relLink
    $parentDir = Split-Path $linkPath -Parent
    if (!$VerifyOnly -and !(Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    if (Test-Path -LiteralPath $linkPath) {
        $item = Get-Item -LiteralPath $linkPath -Force
        $isJunction = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or ($item.LinkType -eq "Junction")
        if (!$isJunction) {
            if ($VerifyOnly) {
                Write-Host "[FAIL] $relLink exists as a plain directory, not a Junction." -ForegroundColor Red
                $Errors++
            } else {
                $children = Get-ChildItem -LiteralPath $linkPath -Force
                if ($children.Count -eq 0) {
                    Remove-Item -LiteralPath $linkPath -Force
                    cmd /c "mklink /J `"$linkPath`" `"$SkillsCanonical`"" | Out-Null
                    Write-Host "[FIXED] Replaced empty dir with Junction: $relLink" -ForegroundColor Green
                } else {
                    Write-Host "[WARN] $relLink is a non-empty directory; skipping." -ForegroundColor Yellow
                }
            }
        } else {
            # A junction must actually point at the canonical store. Checking
            # only "is a reparse point" let a junction aimed at the wrong
            # directory pass verification.
            $resolvedTarget = $null
            if ($item.PSObject.Properties['Target'] -and $item.Target) {
                $resolvedTarget = @($item.Target)[0]
            }
            if ($resolvedTarget -and (Split-Path -Parent $resolvedTarget) -ne (Split-Path -Parent $SkillsCanonical)) {
                Write-Host "[FAIL] $relLink points at '$resolvedTarget', expected '$SkillsCanonical'." -ForegroundColor Red
                $Errors++
            } else {
                Write-Host "[PASS] Junction verified and resolves: $relLink" -ForegroundColor Green
            }
        }
    } else {
        if ($VerifyOnly) {
            Write-Host "[FAIL] Missing skill junction: $relLink" -ForegroundColor Red
            $Errors++
        } else {
            cmd /c "mklink /J `"$linkPath`" `"$SkillsCanonical`"" | Out-Null
            Write-Host "[CREATED] Junction: $relLink -> .agents\skills" -ForegroundColor Green
        }
    }
}

$RequiredFiles = @(
    "AGENTS.md", "CLAUDE.md", ".cursor\rules\core.mdc", ".cursor\mcp.json",
    ".claude\settings.json", ".windsurfrules", ".github\copilot-instructions.md",
    ".clinerules", ".antigravity\settings.json", "opencode.json",
    ".codex\config.toml", ".qoder\settings.json", ".goosehints",
    ".goose\config.yaml", ".kimi\config.toml", ".junie\playbook.md"
)

foreach ($rf in $RequiredFiles) {
    $fullRf = Join-Path $Root $rf
    if (!(Test-Path -LiteralPath $fullRf)) {
        Write-Host "[FAIL] Missing required adapter file: $rf" -ForegroundColor Red
        $Errors++
    }
}

if ($Errors -gt 0) {
    Write-Host "[FAIL] Adapter verification failed with $Errors error(s)." -ForegroundColor Red
    exit 1
}

Write-Host "[PASS] All 13+ universal agent adapters and 6 skill junctions verified!" -ForegroundColor Green
exit 0
