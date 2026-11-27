<#
.SYNOPSIS
    Runtime Prerequisites & MCP Tool Resolution Verification Suite.
.DESCRIPTION
    Validates required runtime environments (Git, Node.js, Python, PowerShell)
    and verifies command resolution for configured Model Context Protocol (MCP) servers.
.PARAMETER ProjectRoot
    Optional path to the project root directory. Defaults to parent of scripts/.
.PARAMETER Strict
    Treats optional warnings as fatal errors.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$Strict
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
Write-Host "   Runtime Prerequisites & MCP Tool Verification Suite      " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[INFO] Project root: $ProjectRoot"

$CriticalErrors = 0
$Warnings = 0

# ----------------------------------------------------------------------
# 1. Core Runtime Prerequisites Validation
# ----------------------------------------------------------------------
Write-Host "`n--- Checking Core Runtime Prerequisites ---" -ForegroundColor Cyan

# 1a. Git
$gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
if ($gitCmd) {
    try {
        $gitVer = (& git --version 2>&1).Trim()
        Write-Host "[OK] Git: $gitVer ($($gitCmd.Source))" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Git command found at $($gitCmd.Source) but failed to execute: $_" -ForegroundColor Red
        $CriticalErrors++
    }
} else {
    Write-Host "[FAIL] Git was not found in PATH." -ForegroundColor Red
    Write-Host "       Diagnostic: Install Git from https://git-scm.com/ or via winget install Git.Git" -ForegroundColor Gray
    $CriticalErrors++
}

# 1b. Node.js
$nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
if ($nodeCmd) {
    try {
        $nodeVer = (& node --version 2>&1).Trim()
        Write-Host "[OK] Node.js: $nodeVer ($($nodeCmd.Source))" -ForegroundColor Green

        # Node 22.18.0 is the first release that strips TypeScript types by
        # default. The test suite, the claude-mem CLI and every hook that runs
        # a .ts file need it. On an older runtime they die with an opaque
        # ERR_UNKNOWN_FILE_EXTENSION, so the version is checked here instead.
        $parts = ($nodeVer -replace '^v', '').Split('.')
        $maj = [int]$parts[0]
        $min = [int]$parts[1]
        if ($maj -gt 22 -or ($maj -eq 22 -and $min -ge 18)) {
            Write-Host "[OK] Node.js is new enough for TypeScript type stripping (>= 22.18.0)." -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Node.js $nodeVer is too old: TypeScript type stripping needs Node >= 22.18.0." -ForegroundColor Red
            Write-Host "       Diagnostic: Upgrade Node.js (https://nodejs.org/). The test suite, the claude-mem CLI and the lifecycle hooks all run .ts files directly." -ForegroundColor Gray
            $CriticalErrors++
        }
    } catch {
        Write-Host "[FAIL] Node.js command found at $($nodeCmd.Source) but failed to execute: $_" -ForegroundColor Red
        $CriticalErrors++
    }
} else {
    Write-Host "[FAIL] Node.js was not found in PATH." -ForegroundColor Red
    Write-Host "       Diagnostic: Install Node.js LTS (>= 22.18.0) from https://nodejs.org/" -ForegroundColor Gray
    $CriticalErrors++
}

# 1c. Python
$pyCmd = Get-Command "python" -ErrorAction SilentlyContinue
if (-not $pyCmd) {
    $pyCmd = Get-Command "python3" -ErrorAction SilentlyContinue
}
if ($pyCmd) {
    try {
        $pyVer = (& $pyCmd.Source --version 2>&1).Trim()
        Write-Host "[OK] Python: $pyVer ($($pyCmd.Source))" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Python command found at $($pyCmd.Source) but failed to execute: $_" -ForegroundColor Red
        $CriticalErrors++
    }
} else {
    Write-Host "[FAIL] Python (python / python3) was not found in PATH." -ForegroundColor Red
    Write-Host "       Diagnostic: Install Python (>= 3.10) from https://www.python.org/" -ForegroundColor Gray
    $CriticalErrors++
}

# 1d. PowerShell
try {
    $psVer = $PSVersionTable.PSVersion.ToString()
    Write-Host "[OK] PowerShell: $psVer (Host: $($Host.Name))" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Unable to determine PowerShell environment version." -ForegroundColor Red
    $CriticalErrors++
}

# ----------------------------------------------------------------------
# 2. Package Managers & MCP Launchers
# ----------------------------------------------------------------------
Write-Host "`n--- Checking MCP Launchers & CLI Package Managers ---" -ForegroundColor Cyan

# 2a. npx (Node Package Executable)
$npxCmd = Get-Command "npx" -ErrorAction SilentlyContinue
if ($npxCmd) {
    try {
        $npxVer = (& npx --version 2>&1).Trim()
        Write-Host "[OK] npx: v$npxVer ($($npxCmd.Source))" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] npx found at $($npxCmd.Source) but failed to execute: $_" -ForegroundColor Yellow
        $Warnings++
    }
} else {
    Write-Host "[FAIL] npx was not found in PATH (required for ui-registry-mcp and shadcn CLI)." -ForegroundColor Red
    $CriticalErrors++
}

# 2b. uvx / uv (Fast Python Package & Tool Runner)
$uvxCmd = Get-Command "uvx" -ErrorAction SilentlyContinue
$uvCmd = Get-Command "uv" -ErrorAction SilentlyContinue
if ($uvxCmd) {
    try {
        $uvxVer = (& uvx --version 2>&1).Trim()
        Write-Host "[OK] uvx: $uvxVer ($($uvxCmd.Source))" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] uvx found at $($uvxCmd.Source) but execution failed: $_" -ForegroundColor Yellow
        $Warnings++
    }
} elseif ($uvCmd) {
    try {
        $uvVer = (& uv --version 2>&1).Trim()
        Write-Host "[OK] uv: $uvVer (uvx available via 'uv tool run')" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] uv found but execution failed: $_" -ForegroundColor Yellow
        $Warnings++
    }
} else {
    Write-Host "[WARN] uv / uvx not detected in PATH." -ForegroundColor Yellow
    Write-Host "       Diagnostic: uvx is required for graphify and headroom MCP servers." -ForegroundColor Gray
    Write-Host "       Install via: 'pip install uv' or 'powershell -c \"irm https://astral.sh/uv/install.ps1 | iex\"'" -ForegroundColor Gray
    if ($Strict) {
        $CriticalErrors++
    } else {
        $Warnings++
    }
}

# ----------------------------------------------------------------------
# 3. Project MCP Server Configuration & Command Resolution
# ----------------------------------------------------------------------
Write-Host "`n--- Resolving Configured MCP Servers ---" -ForegroundColor Cyan

$mcpConfigPath = Join-Path $ProjectRoot ".mcp.json"
if (-not (Test-Path -LiteralPath $mcpConfigPath)) {
    $mcpConfigPath = Join-Path $ProjectRoot ".agents\mcp.json"
}

if (Test-Path -LiteralPath $mcpConfigPath) {
    Write-Host "[INFO] Reading MCP manifest from $mcpConfigPath"
    try {
        $mcpContent = Get-Content -LiteralPath $mcpConfigPath -Raw | ConvertFrom-Json
        $servers = $mcpContent.mcpServers
        if ($servers) {
            $serverNames = $servers.PSObject.Properties | Select-Object -ExpandProperty Name
            Write-Host "[INFO] Found $($serverNames.Count) configured MCP server(s): $($serverNames -join ', ')"
            
            foreach ($sName in $serverNames) {
                $serverObj = $servers.$sName
                $cmdName = $serverObj.command
                if (-not $cmdName) {
                    Write-Host "[FAIL] MCP server '$sName' has no 'command' field specified." -ForegroundColor Red
                    $CriticalErrors++
                    continue
                }

                $resolvedCmd = Get-Command $cmdName -ErrorAction SilentlyContinue
                if ($resolvedCmd) {
                    Write-Host "[PASS] MCP server '$sName': command '$cmdName' -> $($resolvedCmd.Source)" -ForegroundColor Green
                } else {
                    Write-Host "[FAIL] MCP server '$sName': command '$cmdName' cannot be resolved in PATH." -ForegroundColor Red
                    if ($cmdName -eq "uvx" -or $cmdName -eq "npx") {
                        Write-Host "       Diagnostic: Please ensure '$cmdName' is installed and added to system PATH." -ForegroundColor Gray
                    }
                    $CriticalErrors++
                }
            }
        } else {
            Write-Host "[WARN] No 'mcpServers' object found in $mcpConfigPath" -ForegroundColor Yellow
            $Warnings++
        }
    } catch {
        Write-Host "[FAIL] Failed to parse $mcpConfigPath as valid JSON: $_" -ForegroundColor Red
        $CriticalErrors++
    }
} else {
    Write-Host "[WARN] No .mcp.json file found in project root." -ForegroundColor Yellow
    $Warnings++
}

# ----------------------------------------------------------------------
# 4. Summary & Exit Code
# ----------------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Cyan
if ($CriticalErrors -eq 0) {
    if ($Warnings -gt 0) {
        Write-Host "   Verification Passed with $Warnings warning(s).                 " -ForegroundColor Green
    } else {
        Write-Host "   Runtime & MCP Tool Verification 100% Passed               " -ForegroundColor Green
    }
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "   Verification FAILED: $CriticalErrors critical error(s), $Warnings warning(s)." -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Cyan
    exit 1
}
