<#
.SYNOPSIS
    Dynamic MCP Profile Switcher (Windows wrapper).

.DESCRIPTION
    The implementation lives in scripts/mcp-profile.py so the POSIX and Windows
    paths can never drift. The previous inline .ps1 version only updated
    `opencode.json` and `.antigravity/*`, leaving six other adapter configs on
    the wrong profile.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Profile = "core"
)

$ErrorActionPreference = "Stop"

$ScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptsDir "..")).Path
$Script = Join-Path $ScriptsDir "mcp-profile.py"

$Python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $Python) { $Python = Get-Command python -ErrorAction SilentlyContinue }
if (-not $Python) {
    Write-Host "[FAIL] Python is required to switch MCP profiles." -ForegroundColor Red
    exit 1
}

& $Python.Source $Script $Profile
exit $LASTEXITCODE
