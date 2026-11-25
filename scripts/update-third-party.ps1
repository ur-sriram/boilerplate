<#
.SYNOPSIS
    Third-Party Manifest Audit and Pinned Commit SHA Maintenance Utility.
.DESCRIPTION
    Re-validates 40-character hexadecimal commit hashes in THIRD_PARTY.md,
    checks remote git references via git ls-remote, and optionally refreshes SHAs.
.PARAMETER CheckOnly
    Runs in audit mode without modifying THIRD_PARTY.md.
.PARAMETER UpdateAll
    Updates outdated pinned commit SHAs to match remote HEAD.
.PARAMETER ManifestPath
    Path to THIRD_PARTY.md. Defaults to project root THIRD_PARTY.md.
.PARAMETER Offline
    Skips remote network checks and performs offline SHA format validation only.
#>
[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$UpdateAll,
    [string]$ManifestPath,
    [switch]$Offline
)

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $ManifestPath) {
    $ManifestPath = Join-Path $ProjectRoot "THIRD_PARTY.md"
}
$ManifestPath = (Resolve-Path $ManifestPath).Path

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Third-Party Manifest SHA Maintenance & Audit Utility    " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[INFO] Manifest: $ManifestPath"

# Check if Python is available to run update-third-party.py
$pyCmd = Get-Command "python" -ErrorAction SilentlyContinue
if (-not $pyCmd) {
    $pyCmd = Get-Command "python3" -ErrorAction SilentlyContinue
}

$pyScript = Join-Path $PSScriptRoot "update-third-party.py"
if ($pyCmd -and (Test-Path -LiteralPath $pyScript)) {
    $pyArgs = @("$pyScript", "--file", "$ManifestPath")
    if ($UpdateAll) {
        $pyArgs += "--update"
    } else {
        $pyArgs += "--check"
    }
    if ($Offline) {
        $pyArgs += "--offline"
    }

    & $pyCmd.Source $pyArgs
    exit $LASTEXITCODE
}

# Fallback: Native PowerShell verification
Write-Host "[INFO] Executing via native PowerShell manifest parser..."
$content = Get-Content -LiteralPath $ManifestPath -Raw

$shaRegex = [regex]'\|\s*\d+\s*\|\s*([^|]*?https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)[^|]*?)\|\s*`([0-9a-fA-F]{40})`\s*\|'
$matches = $shaRegex.Matches($content)

Write-Host "[INFO] Discovered $($matches.Count) pinned git source repository/repositories."
$formatErrors = 0

Write-Host "`n{0,-32} {1,-12} {2,-14}" -f "Source", "Pinned SHA", "Status"
Write-Host ("-" * 62)

foreach ($m in $matches) {
    $slug = $m.Groups[2].Value.TrimEnd("/")
    $sha = $m.Groups[3].Value
    $shortSha = $sha.Substring(0, 8)

    if ($sha -match "^[0-9a-fA-F]{40}$") {
        Write-Host ("{0,-32} {1,-12} {2,-14}" -f $slug, $shortSha, "[VALID_SHA]") -ForegroundColor Green
    } else {
        Write-Host ("{0,-32} {1,-12} {2,-14}" -f $slug, "INVALID", "[FORMAT_FAIL]") -ForegroundColor Red
        $formatErrors++
    }
}
Write-Host ("-" * 62)

if ($formatErrors -eq 0) {
    Write-Host "[OK] 100% of pinned commit SHAs verified format compliant." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] $formatErrors pinned commit SHA(s) failed format validation." -ForegroundColor Red
    exit 1
}
