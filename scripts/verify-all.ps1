<#
.SYNOPSIS
    Unified Verification Suite Runner for Multi-Agent Boilerplate.
.DESCRIPTION
    Executes all verification suites sequentially in standardized order:
    1. verify-tools.ps1   - Runtime prerequisites & MCP command resolution
    2. verify-scripts.ps1 - Script AST syntax & executable hook dry-runs
    3. verify-links.py    - Markdown link and anchor integrity
    4. test-bootstrap.ps1 - Isolated sandbox bootstrap & boundary assertions
.PARAMETER ProjectRoot
    Optional path to the repository root directory.
.PARAMETER StopOnFirstFailure
    Stops execution immediately if any suite fails.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$StopOnFirstFailure
)

if (-not $ProjectRoot) {
    if ($PSScriptRoot) {
        $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    } else {
        $ProjectRoot = (Get-Location).Path
    }
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Multi-Agent Project Boilerplate: Unified Verification    " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[INFO] Project root: $ProjectRoot"
Write-Host "[INFO] Execution timestamp: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC'))"

$ScriptsDir = Join-Path $ProjectRoot "scripts"

$Suites = @(
    @{
        Name    = "1. verify-tools"
        Type    = "powershell"
        Path    = (Join-Path $ScriptsDir "verify-tools.ps1")
        Desc    = "Validates Git, Node, Python, PowerShell runtimes and MCP resolution"
    },
    @{
        Name    = "2. verify-scripts"
        Type    = "powershell"
        Path    = (Join-Path $ScriptsDir "verify-scripts.ps1")
        Desc    = "AST syntax validation of .ps1, .sh, .py and hook dry-runs"
    },
    @{
        Name    = "3. verify-file-limits"
        Type    = "powershell"
        Path    = (Join-Path $ScriptsDir "verify-file-limits.ps1")
        Desc    = "Enforces <= 400 lines per source file"
        Args    = @("-TargetDir", "$ProjectRoot")
    },
    @{
        Name    = "4. verify-links"
        Type    = "python"
        Path    = (Join-Path $ScriptsDir "verify-links.py")
        Desc    = "Code-block aware markdown link & anchor resolution validator"
    },
    @{
        Name    = "5. sync-agent-adapters"
        Type    = "powershell"
        Path    = (Join-Path $ScriptsDir "sync-agent-adapters.ps1")
        Desc    = "Verifies 13+ universal agent adapters and 6 skill junctions"
        Args    = @("-ProjectRoot", "$ProjectRoot", "-VerifyOnly")
    },
    @{
        Name    = "6. test-bootstrap"
        Type    = "powershell"
        Path    = (Join-Path $ScriptsDir "test-bootstrap.ps1")
        Desc    = "Isolated sandbox clone, zero global writes assertion, and limits"
    }
)

$Results = @()
$OverallFailed = $false
$TotalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($suite in $Suites) {
    Write-Host "`n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor DarkCyan
    Write-Host ">>> RUNNING: $($suite.Name) - $($suite.Desc)" -ForegroundColor Cyan
    Write-Host ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" -ForegroundColor DarkCyan

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = 0

    if (-not (Test-Path -LiteralPath $suite.Path)) {
        Write-Host "[FAIL] Suite file not found: $($suite.Path)" -ForegroundColor Red
        $exitCode = 1
    } else {
        if ($suite.Type -eq "powershell") {
            if ($suite.ContainsKey("Args")) {
                $argList = $suite.Args
                & powershell -NoProfile -NonInteractive -InputFormat None -ExecutionPolicy Bypass -File "$($suite.Path)" @argList
            } else {
                & powershell -NoProfile -NonInteractive -InputFormat None -ExecutionPolicy Bypass -File "$($suite.Path)" -ProjectRoot "$ProjectRoot"
            }
            $exitCode = $LASTEXITCODE
        } elseif ($suite.Type -eq "python") {
            & python "$($suite.Path)" "$ProjectRoot"
            $exitCode = $LASTEXITCODE
        }
    }
    $sw.Stop()
    $duration = [math]::Round($sw.Elapsed.TotalSeconds, 2)

    $status = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }
    if ($exitCode -ne 0) {
        $OverallFailed = $true
    }

    $Results += [PSCustomObject]@{
        Suite    = $suite.Name
        Status   = $status
        Duration = "${duration}s"
        ExitCode = $exitCode
    }

    if ($exitCode -ne 0 -and $StopOnFirstFailure) {
        Write-Host "`n[FATAL] Stopping verification early due to failure in $($suite.Name)" -ForegroundColor Red
        break
    }
}

$TotalStopwatch.Stop()
$totalDuration = [math]::Round($TotalStopwatch.Elapsed.TotalSeconds, 2)

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "               VERIFICATION SUITE SUMMARY                   " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

foreach ($r in $Results) {
    $color = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
    $statStr = "[$($r.Status)]"
    Write-Host (" {0,-25} {1,-10} ({2})" -f $r.Suite, $statStr, $r.Duration) -ForegroundColor $color
}

Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host " Total Duration: ${totalDuration}s" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan

if (-not $OverallFailed) {
    Write-Host " ALL $($Results.Count) VERIFICATION SUITES PASSED (100% GREEN) " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host " VERIFICATION FAILED: One or more suites encountered errors. " -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 1
}
