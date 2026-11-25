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

# 3. Create zero-elevation NTFS Directory Junctions
$JunctionTargets = @(
    @{ Path = (Join-Path $ProjectRoot ".codex\skills"); Name = ".codex\skills" },
    @{ Path = (Join-Path $ProjectRoot ".qoder\skills"); Name = ".qoder\skills" }
)

foreach ($junc in $JunctionTargets) {
    $targetPath = $junc.Path
    $targetName = $junc.Name

    $recreate = $false
    if (Test-Path -LiteralPath $targetPath) {
        $item = Get-Item -LiteralPath $targetPath -Force
        $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        if ($Force -or -not $isReparse) {
            Write-Host "[INFO] Removing existing link/directory at $targetName..." -ForegroundColor Gray
            if ($isReparse) {
                [System.IO.Directory]::Delete($targetPath)
            } else {
                Remove-Item -LiteralPath $targetPath -Recurse -Force
            }
            $recreate = $true
        } else {
            Write-Host "[OK] Existing junction verified at $targetName" -ForegroundColor Green
            continue
        }
    } else {
        $recreate = $true
    }

    if ($recreate) {
        Write-Host "[INFO] Establishing NTFS Directory Junction: $targetName -> .agents\skills..." -ForegroundColor Cyan
        $junctionCreated = $false

        # Attempt 1: mklink /J via cmd.exe
        try {
            $prevEAP = $ErrorActionPreference
            $ErrorActionPreference = "SilentlyContinue"
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "cmd.exe"
            $pinfo.Arguments = "/c mklink /J `"$targetPath`" `"$CanonicalSkillsDir`""
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError = $true
            $pinfo.UseShellExecute = $false
            $pinfo.CreateNoWindow = $true
            $proc = [System.Diagnostics.Process]::Start($pinfo)
            [void]$proc.WaitForExit(5000)
            $ErrorActionPreference = $prevEAP

            if ($proc.ExitCode -eq 0 -and (Test-Path -LiteralPath $targetPath)) {
                $junctionCreated = $true
            }
        } catch {
            $junctionCreated = $false
        }

        # Attempt 2: New-Item -ItemType Junction if mklink failed
        if (-not $junctionCreated) {
            try {
                $prevEAP = $ErrorActionPreference
                $ErrorActionPreference = "SilentlyContinue"
                New-Item -ItemType Junction -Path $targetPath -Target $CanonicalSkillsDir -Force -ErrorAction SilentlyContinue | Out-Null
                $ErrorActionPreference = $prevEAP
                if (Test-Path -LiteralPath $targetPath) {
                    $junctionCreated = $true
                }
            } catch {
                $junctionCreated = $false
            }
        }

        if ($junctionCreated) {
            Write-Host "[OK] Junction established for $targetName" -ForegroundColor Green
        } else {
            Write-Host "[WARN] NTFS Junction not permitted in current security context. Falling back to directory mirror..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            if (Test-Path -LiteralPath $CanonicalSkillsDir) {
                Copy-Item -Path (Join-Path $CanonicalSkillsDir "*") -Destination $targetPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Host "[OK] Mirrored folder created for $targetName with .gitignore protection" -ForegroundColor Green
        }
    }
}

# 4. Verify boundary coherence (.gitignore includes secondary agent skills)
$GitIgnorePath = Join-Path $ProjectRoot ".gitignore"
if (Test-Path -LiteralPath $GitIgnorePath) {
    $gitIgnoreContent = Get-Content -LiteralPath $GitIgnorePath -Raw
    $needsCodex = $gitIgnoreContent -notmatch "(?m)^\.codex/skills/?$"
    $needsQoder = $gitIgnoreContent -notmatch "(?m)^\.qoder/skills/?$"
    if ($needsCodex -or $needsQoder) {
        Write-Host "[INFO] Registering secondary skill directories in .gitignore..." -ForegroundColor Yellow
        Add-Content -LiteralPath $GitIgnorePath -Value "`n# Secondary Agent Mirrored Skills`n.codex/skills/`n.qoder/skills/"
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
