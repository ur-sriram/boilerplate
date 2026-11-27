<#
.SYNOPSIS
    Isolated Sandbox Bootstrap & Structural Integrity Smoke Test Suite.
.DESCRIPTION
    1. Copies the repository into an isolated temporary directory.
    2. Executes the bootstrap sequence.
    3. Programmatically asserts:
       - 0 files modified outside the temp directory (asserts no writes to ~/.gemini, ~/.claude, ~/.config, etc.)
       - 100% of JSON/TOML/YAML configuration files parse without syntax errors.
       - AGENTS.md line count <= 120 lines and character count <= 9,000 characters.
       - 100% of skills in .agents/skills/ are wired to at least one rule file.
       - 100% of .aiignore patterns are mirrored in .gitignore.
.PARAMETER ProjectRoot
    Path to repository root. Defaults to parent of scripts/.
.PARAMETER KeepTemp
    Preserves the isolated temporary directory after test completion for debugging.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$KeepTemp
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
Write-Host "   Sandbox Bootstrap & Boundary Assertion Test Suite        " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[INFO] Source repository: $ProjectRoot"

$TotalErrors = 0
$TempRoot = [System.IO.Path]::GetTempPath()
$SandboxDir = Join-Path $TempRoot ("boilerplate_smoke_" + [System.Guid]::NewGuid().ToString("N"))

Write-Host "[INFO] Creating isolated sandbox at: $SandboxDir"
New-Item -ItemType Directory -Path $SandboxDir -Force | Out-Null

# ----------------------------------------------------------------------
# Snapshot Sensitive External Directories Before Bootstrap
# ----------------------------------------------------------------------
Write-Host "`n--- Snapshotting Sensitive Global Directories ---" -ForegroundColor Cyan
$MonitoredRoots = @()
$userProf = [Environment]::GetFolderPath('UserProfile')
$appData = [Environment]::GetFolderPath('ApplicationData')

$candidateDirs = @(
    (Join-Path $userProf ".gemini"),
    (Join-Path $userProf ".claude"),
    (Join-Path $userProf ".config"),
    (Join-Path $userProf ".codex"),
    (Join-Path $userProf ".qoder"),
    (Join-Path $userProf ".goose"),
    (Join-Path $appData "Codebuff")
)

foreach ($d in $candidateDirs) {
    try {
        if (Test-Path -LiteralPath $d -ErrorAction SilentlyContinue) {
            $MonitoredRoots += $d
        }
    } catch {}
}

function IsAgentRuntimeFile([string]$path) {
    # Exclude active AI agent platform execution logs, transcripts, and internal databases
    return ($path -like "*\.gemini\antigravity\*" -or
            $path -like "*\AppData\Local\Temp\*" -or
            $path -like "*\AppData\Local\Microsoft\*" -or
            $path -like "*\AppData\Local\Google\*")
}

$ExternalSnapshot = @{}
foreach ($dir in $MonitoredRoots) {
    try {
        Get-ChildItem -Path $dir -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not (IsAgentRuntimeFile $_.FullName)) {
                $ExternalSnapshot[$_.FullName] = @{
                    LastWrite = $_.LastWriteTimeUtc
                    Length    = $_.Length
                }
            }
        }
    } catch {}
}
Write-Host "[INFO] Snapshotted $($ExternalSnapshot.Count) file(s) across $($MonitoredRoots.Count) sensitive directory/directories."

# ----------------------------------------------------------------------
# Replicate Repository to Sandbox
# ----------------------------------------------------------------------
Write-Host "`n--- Replicating Repository into Isolated Sandbox ---" -ForegroundColor Cyan
$copySuccess = $false

# Fast copy with robocopy if available.
# `.cache` is excluded on purpose: it holds the project-local uv/npm package
# caches (hundreds of megabytes), and copying them into the sandbox made this
# suite unusably slow. The POSIX twin excludes the same directory.
$roboCmd = Get-Command "robocopy" -ErrorAction SilentlyContinue
if ($roboCmd) {
    $roboOut = & robocopy "$ProjectRoot" "$SandboxDir" /E /XD .git .cache node_modules .venv venv dist build __pycache__ temp tmp sandbox .sandbox /XF *.log *.tmp 2>&1
    if ($LASTEXITCODE -lt 8) {
        $copySuccess = $true
    }
}

if (-not $copySuccess) {
    # Fallback to PowerShell recursive copy
    $excludes = @(".git", ".cache", "node_modules", ".venv", "venv", "dist", "build", "__pycache__")
    Get-ChildItem -Path $ProjectRoot -Force | Where-Object { $excludes -notcontains $_.Name } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $SandboxDir -Recurse -Force
    }
}
Write-Host "[OK] Sandbox populated successfully." -ForegroundColor Green

# ----------------------------------------------------------------------
# Execute Bootstrap Sequence in Sandbox
# ----------------------------------------------------------------------
Write-Host "`n--- Executing Bootstrap Sequence in Sandbox ---" -ForegroundColor Cyan
$bootstrapScript = Join-Path $SandboxDir "scripts\bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrapScript)) {
    Write-Host "[FAIL] bootstrap.ps1 missing in replicated sandbox: $bootstrapScript" -ForegroundColor Red
    $TotalErrors++
} else {
    $bootProc = & powershell -NoProfile -NonInteractive -InputFormat None -ExecutionPolicy Bypass -File "$bootstrapScript" -SkipChecks 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Sandbox bootstrap execution failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host $bootProc -ForegroundColor Red
        $TotalErrors++
    } else {
        Write-Host "[PASS] Bootstrap sequence executed cleanly inside sandbox." -ForegroundColor Green
    }
}

# ----------------------------------------------------------------------
# Assertion 1: 0 Files Modified Outside Temp Directory
# ----------------------------------------------------------------------
Write-Host "`n--- Assertion 1: 0 Files Modified Outside Temp Directory ---" -ForegroundColor Cyan
$ExternalViolations = @()

foreach ($dir in $MonitoredRoots) {
    try {
        $currentFiles = Get-ChildItem -Path $dir -Recurse -File -Force -ErrorAction SilentlyContinue
        foreach ($file in $currentFiles) {
            $fpath = $file.FullName
            if (IsAgentRuntimeFile $fpath) {
                continue
            }
            if (-not $ExternalSnapshot.ContainsKey($fpath)) {
                $ExternalViolations += "New file created outside sandbox: $fpath"
            } else {
                $snap = $ExternalSnapshot[$fpath]
                if ($file.LastWriteTimeUtc -gt $snap.LastWrite -or $file.Length -ne $snap.Length) {
                    $ExternalViolations += "File modified outside sandbox: $fpath"
                }
            }
        }
    } catch {}
}

if ($ExternalViolations.Count -eq 0) {
    Write-Host "[PASS] 0 files modified outside sandbox directory (Zero pollution to ~/.config, ~/.claude, ~/.gemini, %USERPROFILE%)." -ForegroundColor Green
} else {
    Write-Host "[FAIL] External writes detected outside sandbox ($($ExternalViolations.Count) violation(s)):" -ForegroundColor Red
    foreach ($v in $ExternalViolations) {
        Write-Host "       $v" -ForegroundColor Red
    }
    $TotalErrors++
}

# ----------------------------------------------------------------------
# Assertion 2: 100% Configuration Files Parse Without Syntax Errors
# ----------------------------------------------------------------------
Write-Host "`n--- Assertion 2: 100% Config Files (JSON/TOML/YAML) Parse Cleanly ---" -ForegroundColor Cyan
$configFiles = Get-ChildItem -Path $SandboxDir -Recurse -File | Where-Object {
    $_.Extension -match "^\.(json|toml|ya?ml)$" -and
    $_.FullName -notmatch "[\\/](node_modules|\.venv|venv|dist|build|\.agents[\\/]skills|\.claude[\\/]skills|\.cursor[\\/]skills|\.codex[\\/]skills|\.qoder[\\/]skills|\.cline[\\/]skills|\.windsurf[\\/]skills)[\\/]"
}

$configErrors = 0
Write-Host "[INFO] Scanning $($configFiles.Count) configuration file(s)..."

foreach ($cf in $configFiles) {
    $rel = $cf.FullName.Substring($SandboxDir.Length).TrimStart("\/")
    $ext = $cf.Extension.ToLower()

    if ($ext -eq ".json") {
        try {
            Get-Content -LiteralPath $cf.FullName -Raw | ConvertFrom-Json | Out-Null
            Write-Host "[PASS] $rel (Valid JSON)" -ForegroundColor Green
        } catch {
            Write-Host "[FAIL] $rel : Invalid JSON syntax ($_)" -ForegroundColor Red
            $configErrors++
        }
    } elseif ($ext -eq ".toml") {
        $tomlCheck = & python -c "
import sys, tomllib
from pathlib import Path
try:
    with open(sys.argv[1], 'rb') as f:
        tomllib.load(f)
    sys.exit(0)
except Exception as e:
    sys.exit(str(e))
" "$($cf.FullName)" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[PASS] $rel (Valid TOML)" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] $rel : Invalid TOML syntax ($tomlCheck)" -ForegroundColor Red
            $configErrors++
        }
    } elseif ($ext -eq ".yaml" -or $ext -eq ".yml") {
        $yamlCheck = & python -c "
import sys, yaml
from pathlib import Path
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        yaml.safe_load(f)
    sys.exit(0)
except Exception as e:
    sys.exit(str(e))
" "$($cf.FullName)" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[PASS] $rel (Valid YAML)" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] $rel : Invalid YAML syntax ($yamlCheck)" -ForegroundColor Red
            $configErrors++
        }
    }
}

if ($configErrors -eq 0) {
    Write-Host "[PASS] 100% of configuration files ($($configFiles.Count)/$($configFiles.Count)) parsed successfully." -ForegroundColor Green
} else {
    Write-Host "[FAIL] $configErrors configuration file(s) failed syntax parsing." -ForegroundColor Red
    $TotalErrors++
}

# ----------------------------------------------------------------------
# Layer 1 context budget for AGENTS.md (must match the POSIX twin and the
# documentation in .specify/memory/constitution.md).
$MaxAgentsLines = 120
$MaxAgentsChars = 9000

# Assertion 3: AGENTS.md Size & Structure
# ----------------------------------------------------------------------
Write-Host "`n--- Assertion 3: AGENTS.md Size & Structure ---" -ForegroundColor Cyan
$agentsPath = Join-Path $SandboxDir "AGENTS.md"
if (-not (Test-Path -LiteralPath $agentsPath)) {
    Write-Host "[FAIL] AGENTS.md not found in sandbox: $agentsPath" -ForegroundColor Red
    $TotalErrors++
} else {
    $rawContent = Get-Content -LiteralPath $agentsPath -Raw
    $lineCount = (Get-Content -LiteralPath $agentsPath).Count
    $charCount = $rawContent.Length

    Write-Host "[INFO] AGENTS.md metrics: $lineCount lines, $charCount characters (budget: $MaxAgentsLines lines / $MaxAgentsChars chars)."

    # The budget is ENFORCED, not merely reported. AGENTS.md is loaded into
    # every agent turn, so an unbounded file silently inflates every request.
    if ($lineCount -gt $MaxAgentsLines) {
        Write-Host "[FAIL] AGENTS.md is $lineCount lines (max $MaxAgentsLines). Move detail into .agents/rules/." -ForegroundColor Red
        $TotalErrors++
    } elseif ($charCount -gt $MaxAgentsChars) {
        Write-Host "[FAIL] AGENTS.md is $charCount characters (max $MaxAgentsChars). Move detail into .agents/rules/." -ForegroundColor Red
        $TotalErrors++
    } else {
        Write-Host "[PASS] AGENTS.md within budget ($lineCount/$MaxAgentsLines lines, $charCount/$MaxAgentsChars chars)." -ForegroundColor Green
    }
}

# ----------------------------------------------------------------------
# Assertion 4: 100% Skills in .agents/skills/ Wired to Rule Files
# ----------------------------------------------------------------------
Write-Host "`n--- Assertion 4: 100% Skill Wiring Coverage ---" -ForegroundColor Cyan
$skillsBaseDir = Join-Path $SandboxDir ".agents\skills"
$rulesBaseDir  = Join-Path $SandboxDir ".agents\rules"

if (-not (Test-Path -LiteralPath $skillsBaseDir)) {
    Write-Host "[FAIL] Skills directory missing: $skillsBaseDir" -ForegroundColor Red
    $TotalErrors++
} elseif (-not (Test-Path -LiteralPath $rulesBaseDir)) {
    Write-Host "[FAIL] Rules directory missing: $rulesBaseDir" -ForegroundColor Red
    $TotalErrors++
} else {
    # Find all skills (directories containing SKILL.md)
    $skillFiles = Get-ChildItem -Path $skillsBaseDir -Recurse -File | Where-Object { $_.Name -eq "SKILL.md" }
    $ruleFiles  = Get-ChildItem -Path $rulesBaseDir -File | Where-Object { $_.Extension -eq ".md" }

    # Concatenate all rule content
    $allRulesText = ($ruleFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

    $unwiredSkills = @()
    foreach ($sf in $skillFiles) {
        $skillDirName = $sf.Directory.Name
        # Search for skill directory name in rule markdown
        if ($allRulesText -notmatch [regex]::Escape($skillDirName)) {
            $unwiredSkills += $skillDirName
        }
    }

    Write-Host "[INFO] Verified $($skillFiles.Count) integrated skill(s) against $($ruleFiles.Count) rule file(s)."
    if ($unwiredSkills.Count -eq 0) {
        Write-Host "[PASS] 100% of skills ($($skillFiles.Count)/$($skillFiles.Count)) are wired to at least one rule file." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Found $($unwiredSkills.Count) orphan skill(s) not wired to any rule file:" -ForegroundColor Red
        foreach ($u in $unwiredSkills) {
            Write-Host "       - $u" -ForegroundColor Red
        }
        $TotalErrors++
    }
}

# ----------------------------------------------------------------------
# Assertion 5: 100% .aiignore Patterns Mirrored in .gitignore
# ----------------------------------------------------------------------
Write-Host "`n--- Assertion 5: 100% .aiignore Patterns Mirrored in .gitignore ---" -ForegroundColor Cyan
$aiIgnorePath  = Join-Path $SandboxDir ".aiignore"
$gitIgnorePath = Join-Path $SandboxDir ".gitignore"

if (-not (Test-Path -LiteralPath $aiIgnorePath)) {
    Write-Host "[FAIL] .aiignore missing in sandbox: $aiIgnorePath" -ForegroundColor Red
    $TotalErrors++
} elseif (-not (Test-Path -LiteralPath $gitIgnorePath)) {
    Write-Host "[FAIL] .gitignore missing in sandbox: $gitIgnorePath" -ForegroundColor Red
    $TotalErrors++
} else {
    $aiPatterns = Get-Content -LiteralPath $aiIgnorePath | Where-Object {
        $t = $_.Trim()
        $t.Length -gt 0 -and (-not $t.StartsWith("#"))
    } | ForEach-Object { $_.Trim() }

    $gitPatterns = Get-Content -LiteralPath $gitIgnorePath | Where-Object {
        $t = $_.Trim()
        $t.Length -gt 0 -and (-not $t.StartsWith("#"))
    } | ForEach-Object { $_.Trim() }

    $missingPatterns = @()
    foreach ($pat in $aiPatterns) {
        # Check direct or slash-normalized match
        $normPat = $pat.TrimEnd("/\")
        $matched = $false
        foreach ($g in $gitPatterns) {
            $normG = $g.TrimEnd("/\")
            if ($normPat -eq $normG -or $pat -eq $g) {
                $matched = $true
                break
            }
        }
        if (-not $matched) {
            $missingPatterns += $pat
        }
    }

    Write-Host "[INFO] Evaluated $($aiPatterns.Count) boundary pattern(s) from .aiignore against .gitignore."
    if ($missingPatterns.Count -eq 0) {
        Write-Host "[PASS] 100% of .aiignore patterns ($($aiPatterns.Count)/$($aiPatterns.Count)) are strictly mirrored in .gitignore." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Found $($missingPatterns.Count) pattern(s) in .aiignore missing from .gitignore:" -ForegroundColor Red
        foreach ($m in $missingPatterns) {
            Write-Host "       - $m" -ForegroundColor Red
        }
        $TotalErrors++
    }
}

# ----------------------------------------------------------------------
# Assertion 6: claude-mem Episodic Memory Is Wired, Not Just Described
# ----------------------------------------------------------------------
Write-Host "`n--- Assertion 6: claude-mem Episodic Memory Round-Trip + Hook Wiring ---" -ForegroundColor Cyan
$memoryCli = Join-Path $SandboxDir ".repo\claude-mem\run.mjs"

if (-not (Test-Path -LiteralPath $memoryCli)) {
    Write-Host "[FAIL] claude-mem CLI missing in sandbox: $memoryCli" -ForegroundColor Red
    $TotalErrors++
} else {
    & node $memoryCli remember --type discovery `
        --title "Bootstrap probe episode" `
        --body "The episodic store round-trips inside the sandbox." `
        --tags bootstrap `
        --root $SandboxDir | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[PASS] claude-mem wrote an episode into the sandbox store." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] claude-mem could not write an episode." -ForegroundColor Red
        $TotalErrors++
    }

    $recallOut = & node $memoryCli recall --text "Bootstrap probe" --root $SandboxDir 2>&1
    if (($recallOut -join "`n") -match "Bootstrap probe episode") {
        Write-Host "[PASS] claude-mem recalled the episode it wrote." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] claude-mem did not recall the episode it wrote." -ForegroundColor Red
        $TotalErrors++
    }

    # The store must stay inside the sandbox (the only sanctioned write
    # outside a project root).
    $memoryStore = Join-Path $SandboxDir ".agents\memory\episodes.jsonl"
    if (Test-Path -LiteralPath $memoryStore) {
        Write-Host "[PASS] claude-mem store lives inside the project root (.agents\memory\)." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] claude-mem store missing at .agents\memory\episodes.jsonl." -ForegroundColor Red
        $TotalErrors++
    }
}

$unwiredMemory = @()
foreach ($cfg in @(".claude\settings.json", ".codex\config.toml", ".goose\hooks.json",
                    ".qoder\settings.json", ".antigravity\hooks.json")) {
    $cfgPath = Join-Path $SandboxDir $cfg
    if (Test-Path -LiteralPath $cfgPath) {
        $cfgText = Get-Content -LiteralPath $cfgPath -Raw
        if ($cfgText -notmatch "memory-sync") {
            $unwiredMemory += $cfg
        }
    }
}
$openCodeMemory = Join-Path $SandboxDir ".opencode\plugins\memory-sync.js"
if (-not (Test-Path -LiteralPath $openCodeMemory)) {
    $unwiredMemory += ".opencode\plugins\memory-sync.js"
}

if ($unwiredMemory.Count -eq 0) {
    Write-Host "[PASS] memory-sync hook registered in every hook-capable adapter." -ForegroundColor Green
} else {
    Write-Host "[FAIL] memory-sync hook not wired in:" -ForegroundColor Red
    foreach ($m in $unwiredMemory) {
        Write-Host "       - $m" -ForegroundColor Red
    }
    $TotalErrors++
}

# ----------------------------------------------------------------------
# Teardown & Exit
# ----------------------------------------------------------------------
if (-not $KeepTemp) {
    Write-Host "`n[INFO] Cleaning up sandbox directory: $SandboxDir"
    try {
        # Remove any junctions first to avoid recursively deleting target contents
        Get-ChildItem -Path $SandboxDir -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
            ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        } | ForEach-Object {
            try { [System.IO.Directory]::Delete($_.FullName) } catch {}
        }
        Remove-Item -LiteralPath $SandboxDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "[WARN] Sandbox cleanup encountered minor warning: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[INFO] Sandbox preserved at: $SandboxDir (-KeepTemp specified)" -ForegroundColor Yellow
}

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($TotalErrors -eq 0) {
    Write-Host "   Sandbox Bootstrap Verification: 100% PASSED               " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "   Sandbox Bootstrap Verification FAILED with $TotalErrors error(s)  " -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 1
}
