<#
.SYNOPSIS
    Verifies that all source code files satisfy strict file line count constraints (maximum 400 lines).
.DESCRIPTION
    Scans TypeScript, JavaScript, Python, and PowerShell files in src/, scripts/, and .agents/.
    Excludes external skill caches or vendored modules.
    Fails with exit code 1 if any file exceeds 400 lines.
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

$Extensions = @(".ts", ".tsx", ".js", ".jsx", ".py", ".ps1")
$ExcludeFolders = @("node_modules", ".git", "survey_cache", "cache", "__pycache__", ".specify", "skills")

$Files = Get-ChildItem -Path $ResolvedTarget -Recurse -File | Where-Object {
    $file = $_
    $ext = $file.Extension.ToLower()
    if ($Extensions -notcontains $ext) { return $false }
    
    foreach ($exclude in $ExcludeFolders) {
        if ($file.FullName -like "*\$exclude\*") { return $false }
    }
    return $true
}

$Violations = @()
$PassedCount = 0

foreach ($file in $Files) {
    $lineCount = (Get-Content -Path $file.FullName | Measure-Object -Line).Lines
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
