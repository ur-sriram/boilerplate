[CmdletBinding()]
param([string]$ProjectRoot = "")
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $Root = (Resolve-Path "$PSScriptRoot\..\..").Path
} else {
    $Root = (Resolve-Path $ProjectRoot).Path
}
$MemDir = Join-Path $Root ".agents\memory"
if (!(Test-Path $MemDir)) { New-Item -ItemType Directory -Force -Path $MemDir | Out-Null }
Write-Host "[MEMORY] claude-mem episodic store verified at $MemDir"
exit 0
