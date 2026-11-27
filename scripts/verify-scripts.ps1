<#
.SYNOPSIS
    Script Syntax & AST Verification Suite for Autonomous Coding Agents.
.DESCRIPTION
    Validates AST syntax of all .ps1, .sh, and .py scripts (including scripts/hooks/*)
    and executes non-destructive dry-run validation tests.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot
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
Write-Host "   Script Syntax & AST Integrity Verification Suite         " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[INFO] Project root: $ProjectRoot"

$Excludes = @("node_modules", ".cache", ".git", "dist", "build", ".venv", "venv", "env", "ENV", "__pycache__", ".pytest_cache", "sandbox", ".sandbox")

# Enumerate repository files WITHOUT descending into the excluded directories.
#
# `Get-ChildItem -Recurse` followed by a `Where-Object` filter still WALKS
# every file inside node_modules and the project-local .cache/ tree (the uv
# and npm package caches - hundreds of thousands of files), which made these
# suites take minutes instead of seconds. The POSIX twin uses `find -prune`
# for the same reason; the exclusion lists must stay identical.
function Get-RepoFiles {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string[]]$Excludes
    )

    $results = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $stack = New-Object System.Collections.Stack
    $stack.Push($Root)

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        try {
            foreach ($item in Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue) {
                if ($item.PSIsContainer) {
                    if ($Excludes -notcontains $item.Name -and $item.Name -notlike "boilerplate_smoke_*") {
                        $stack.Push($item.FullName)
                    }
                } elseif ($item.Name -notlike "boilerplate_smoke_*") {
                    $results.Add($item)
                }
            }
        } catch {
            # Unreadable directory: skip it rather than fail the suite.
        }
    }

    return $results
}

# Gather all scripts
$allFiles = Get-RepoFiles -Root $ProjectRoot -Excludes $Excludes

$ps1Files = $allFiles | Where-Object { $_.Extension -eq ".ps1" }
$pyFiles  = $allFiles | Where-Object { $_.Extension -eq ".py" }
$shFiles  = $allFiles | Where-Object { $_.Extension -eq ".sh" }

$totalErrors = 0

# 1. PowerShell AST Parsing
Write-Host "`n--- Validating $($ps1Files.Count) PowerShell Script(s) via AST Parser ---" -ForegroundColor Cyan
foreach ($file in $ps1Files) {
    $relPath = $file.FullName.Substring($ProjectRoot.Length).TrimStart("\/")
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        Write-Host "[FAIL] $relPath has $($parseErrors.Count) syntax error(s):" -ForegroundColor Red
        foreach ($err in $parseErrors) {
            Write-Host "       Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
            $totalErrors++
        }
    } else {
        Write-Host "[PASS] $relPath (AST Valid)" -ForegroundColor Green
    }
}

# 2. Python Script Syntax Validation (py_compile)
Write-Host "`n--- Validating $($pyFiles.Count) Python Script(s) via py_compile ---" -ForegroundColor Cyan
foreach ($file in $pyFiles) {
    $relPath = $file.FullName.Substring($ProjectRoot.Length).TrimStart("\/")
    try {
        $compileOutput = & python -m py_compile "$($file.FullName)" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] $relPath (Compilation failed):" -ForegroundColor Red
            Write-Host "       $compileOutput" -ForegroundColor Red
            $totalErrors++
        } else {
            Write-Host "[PASS] $relPath (Bytecode Clean)" -ForegroundColor Green
        }
    } catch {
        Write-Host "[FAIL] $($relPath): Could not execute python compiler ($($_))" -ForegroundColor Red
        $totalErrors++
    }
}

# 3. Shell Script Syntax Validation
Write-Host "`n--- Validating $($shFiles.Count) Shell Script(s) ---" -ForegroundColor Cyan
$bashAvailable = $false
try {
    $testBash = & bash -c "true" 2>&1
    if ($LASTEXITCODE -eq 0) { $bashAvailable = $true }
} catch {
    $bashAvailable = $false
}

foreach ($file in $shFiles) {
    $relPath = $file.FullName.Substring($ProjectRoot.Length).TrimStart("\/")
    if ($bashAvailable) {
        $bashOutput = & bash -n "$($file.FullName)" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] $relPath (bash -n failed): $bashOutput" -ForegroundColor Red
            $totalErrors++
        } else {
            Write-Host "[PASS] $relPath (Bash AST Valid)" -ForegroundColor Green
        }
    } else {
        # High-precision Python shlex & shebang validation
        $shValidation = & python -c "
import sys, re, shlex
from pathlib import Path
path = Path(sys.argv[1])
content = path.read_text(encoding='utf-8', errors='replace')
first_line = content.splitlines()[0] if content.splitlines() else ''
shebang_re = re.compile(r'^#!\s*(?:/(?:usr/)?bin/env\s+(?:bash|sh)|/bin/(?:bash|sh))')
if not shebang_re.match(first_line):
    sys.exit(f'Invalid shebang: {first_line}')
try:
    shlex.split(content, comments=True)
except Exception as e:
    sys.exit(f'Lexer error: {e}')
" "$($file.FullName)" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] $relPath ($shValidation)" -ForegroundColor Red
            $totalErrors++
        } else {
            Write-Host "[PASS] $relPath (Shell AST & Shebang Valid)" -ForegroundColor Green
        }
    }
}

# 4. Executable Hook Dry-Run Checks
$hooksDir = Join-Path $ProjectRoot "scripts\hooks"
if (Test-Path -LiteralPath $hooksDir) {
    Write-Host "`n--- Executing Non-Destructive Hook Dry-Run Checks ---" -ForegroundColor Cyan
    
    # 4a. Protect-config hook check
    $protectHook = Join-Path $hooksDir "protect-config.ps1"
    if (Test-Path -LiteralPath $protectHook) {
        # Safe test: in-scope target
        $safeOutput = & powershell -NoProfile -NonInteractive -InputFormat None -ExecutionPolicy Bypass -File "$protectHook" -TargetPath "test.txt" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[PASS] protect-config.ps1 permitted in-scope target" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] protect-config.ps1 incorrectly blocked in-scope target" -ForegroundColor Red
            $totalErrors++
        }

        # Danger test: out-of-scope target
        $unsafeOutput = & powershell -NoProfile -NonInteractive -InputFormat None -ExecutionPolicy Bypass -File "$protectHook" -TargetPath "C:\Users\VICTUS\.gemini\evil.txt" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[PASS] protect-config.ps1 successfully blocked out-of-scope target" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] protect-config.ps1 failed to block out-of-scope target!" -ForegroundColor Red
            $totalErrors++
        }

        # Danger test: tilde home-relative out-of-scope target
        $tildeOutput = & powershell -NoProfile -NonInteractive -InputFormat None -ExecutionPolicy Bypass -File "$protectHook" -TargetPath "~/.gemini" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[PASS] protect-config.ps1 successfully blocked tilde out-of-scope target" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] protect-config.ps1 failed to block tilde out-of-scope target!" -ForegroundColor Red
            $totalErrors++
        }
    }

    # 4b. RTK-filter hook check
    $rtkHook = Join-Path $hooksDir "rtk-filter.ps1"
    if (Test-Path -LiteralPath $rtkHook) {
        $testText = "Test log output for rtk filter"
        $filterOutput = $testText | & powershell -NoProfile -ExecutionPolicy Bypass -File $rtkHook 2>&1
        if ($LASTEXITCODE -eq 0 -and $filterOutput) {
            Write-Host "[PASS] rtk-filter.ps1 executed cleanly with graceful fallback" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] rtk-filter.ps1 crashed or failed to return output" -ForegroundColor Red
            $totalErrors++
        }

        # Multi-line pipeline preservation check
        $multiOutput = @("Line 1", "Line 2", "Line 3") | & powershell -NoProfile -ExecutionPolicy Bypass -File $rtkHook 2>&1
        if ($LASTEXITCODE -eq 0 -and ($multiOutput -contains "Line 1") -and ($multiOutput -contains "Line 2") -and ($multiOutput -contains "Line 3")) {
            Write-Host "[PASS] rtk-filter.ps1 preserved all multi-line pipeline items" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] rtk-filter.ps1 truncated multi-line pipeline input!" -ForegroundColor Red
            $totalErrors++
        }

        # A PostToolUse hook receives the agent's hook payload, not terminal
        # text - for Claude Code, Codex, Goose and Qoder that is a JSON
        # envelope. The filter must extract the output from it instead of
        # handing the envelope to rtk and echoing it back.
        $rtkPayload = '{"tool_name":"Bash","tool_response":{"stdout":"REAL TERMINAL OUTPUT"}}'
        $payloadOutput = $rtkPayload | & powershell -NoProfile -ExecutionPolicy Bypass -File $rtkHook 2>&1
        if ($LASTEXITCODE -eq 0 -and (($payloadOutput -join "`n") -match "REAL TERMINAL OUTPUT")) {
            Write-Host "[PASS] rtk-filter.ps1 extracted the terminal output from the hook payload" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] rtk-filter.ps1 did not extract the terminal output from the hook payload" -ForegroundColor Red
            $totalErrors++
        }

        # The "rtk is installed" case is proven by the POSIX suite with a fake
        # rtk on PATH: the filter itself is the shared scripts/hooks/rtk-filter.mjs
        # on both platforms, so this twin only has to prove that it invokes it.
    }

    # 4c. Session-start hook check
    $sessionHook = Join-Path $hooksDir "session-start.ps1"
    if (Test-Path -LiteralPath $sessionHook) {
        $sessionOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $sessionHook 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[PASS] session-start.ps1 executed cleanly" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] session-start.ps1 failed: $sessionOutput" -ForegroundColor Red
            $totalErrors++
        }
    }

    # 4d. Claude-mem episodic memory hook check.
    # The hook used to be a mkdir+echo stub that no adapter ever registered,
    # so it passed every check while persisting nothing. It is now exercised
    # for real: it must recall the episodic store without failing.
    $memoryHook = Join-Path $hooksDir "memory-sync.ps1"
    if (Test-Path -LiteralPath $memoryHook) {
        $memoryOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $memoryHook 2>&1
        if ($LASTEXITCODE -eq 0 -and ($memoryOutput -join "`n") -match "\[MEMORY\]") {
            Write-Host "[PASS] memory-sync.ps1 recalled the episodic store" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] memory-sync.ps1 did not report the episodic store" -ForegroundColor Red
            $totalErrors++
        }
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($totalErrors -eq 0) {
    Write-Host "   Script Verification Complete: 100% Passed                " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "   Script Verification FAILED with $totalErrors error(s)    " -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 1
}
