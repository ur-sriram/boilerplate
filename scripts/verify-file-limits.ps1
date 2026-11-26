<#
.SYNOPSIS
    Verifies that all source code files satisfy strict file line count constraints (maximum 400 lines).
.DESCRIPTION
    Enforces the 400-line ceiling documented in .agents/rules/code-quality.md
    ("excluding blank lines and comments") and mirrored by .eslintrc.json
    ("max-lines": skipBlankLines + skipComments).

    This twin and verify-file-limits.sh MUST agree. They previously did not:
      - this twin never scanned .sh files,
      - the POSIX twin counted raw physical lines (wc -l),
      - this twin counted non-blank lines (Measure-Object -Line),
    so the same file could pass on Windows and fail on Linux.

    Excludes vendored/upstream trees (node_modules, .git, __pycache__,
    .specify, skills, dist, build) which are owned by third-party sources.
#>
[CmdletBinding()]
param(
    [string]$TargetDir = "",
    [int]$MaxLines = 400
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    if ($PSScriptRoot) {
        $ResolvedTarget = (Resolve-Path "$PSScriptRoot\..").Path
    } else {
        $ResolvedTarget = (Get-Location).Path
    }
} else {
    $ResolvedTarget = (Resolve-Path $TargetDir).Path
}

Write-Host "================================================="
Write-Host "Verifying File Line Count Constraints (Max: $MaxLines lines)"
Write-Host "Target: $ResolvedTarget"
Write-Host "================================================="

# Extensions scanned (identical list in both twins).
$Extensions = @(".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".py", ".ps1", ".sh")

# Folders excluded from the scan (identical list in both twins).
$ExcludeFolders = @("node_modules", ".git", "__pycache__", ".specify", "skills", "dist", "build")

$Files = Get-ChildItem -Path $ResolvedTarget -Recurse -File | Where-Object {
    $file = $_
    $ext = $file.Extension.ToLower()
    if ($Extensions -notcontains $ext) { return $false }

    foreach ($exclude in $ExcludeFolders) {
        if ($file.FullName -like "*\$exclude\*") { return $false }
    }
    return $true
}

# Count "effective" lines: non-blank and not a comment-only line.
# Mirrors ESLint's max-lines behaviour with skipBlankLines + skipComments.
function Get-EffectiveLineCount {
    param([Parameter(Mandatory = $true)][string]$Path)

    $count = 0
    foreach ($raw in [System.IO.File]::ReadLines($Path)) {
        $line = $raw.Trim()
        if ($line.Length -eq 0) { continue }
        if ($line.StartsWith('#')) { continue }
        if ($line.StartsWith('//')) { continue }
        if ($line.StartsWith('/*')) { continue }
        if ($line.StartsWith('*')) { continue }
        $count++
    }
    return $count
}

$Violations = @()
$PassedCount = 0

foreach ($file in $Files) {
    $lineCount = Get-EffectiveLineCount -Path $file.FullName
    if ($lineCount -gt $MaxLines) {
        $Violations += [PSCustomObject]@{
            File  = $file.FullName.Replace($ResolvedTarget, "").TrimStart("\")
            Lines = $lineCount
        }
    } else {
        $PassedCount++
    }
}

Write-Host "Files scanned: $($Files.Count)"
Write-Host "Passing files: $PassedCount"

if ($Violations.Count -gt 0) {
    Write-Host "[FAIL] Found $($Violations.Count) file(s) exceeding $MaxLines lines:" -ForegroundColor Red
    foreach ($v in $Violations) {
        Write-Host "  - $($v.File) ($($v.Lines) lines)" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "[PASS] All source files strictly comply with the $MaxLines lines limit!" -ForegroundColor Green
    exit 0
}
