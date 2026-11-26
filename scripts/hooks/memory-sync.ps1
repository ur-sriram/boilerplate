# ==============================================================================
# Claude-Mem Episodic Memory Sync Hook (Windows / PowerShell)
#
# Windows twin of scripts/hooks/memory-sync.sh. It invokes the same CLI, so
# both platforms recall the same episodes in the same format.
#
# The hook is ADVISORY: it never blocks a session and never fails it.
# ==============================================================================
[CmdletBinding()]
param([string]$ProjectRoot = "")

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $Root = (Resolve-Path "$PSScriptRoot\..\..").Path
} else {
    $Root = (Resolve-Path $ProjectRoot).Path
}

$Node = Get-Command node -ErrorAction SilentlyContinue
if (-not $Node) {
    Write-Host "[MEMORY] node runtime not found; claude-mem episodic sync skipped"
    exit 0
}

$Cli = Join-Path $Root "src\features\claude-mem\cli.ts"
& $Node.Source $Cli sync --root $Root
exit 0
