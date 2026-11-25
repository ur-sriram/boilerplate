<#
.SYNOPSIS
    Dynamic MCP Profile Switcher for Windows PowerShell.
    Switches active MCP servers across agent configurations without global side effects.

.DESCRIPTION
    Toggles between:
    - 'core' (default): graphify enabled (<= 350 tokens)
    - 'ui': graphify + ui-registry enabled (~750 tokens)
    - 'compression': graphify + headroom enabled (~650 tokens)
    - 'all': graphify + ui-registry + headroom enabled (~1,050 tokens)

.PARAMETER Profile
    Target profile name: core, ui, compression, all. Default is 'core'.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [ValidateSet('core', 'ui', 'compression', 'all')]
    [string]$Profile = 'core'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))

Write-Host "Switching MCP profile to '$Profile' in $ProjectRoot..." -ForegroundColor Cyan

# Determine server states
$GraphifyActive = $true
$UiActive = ($Profile -eq 'ui' -or $Profile -eq 'all')
$HeadroomActive = ($Profile -eq 'compression' -or $Profile -eq 'all')

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# 1. Update opencode.json
$OpencodePath = Join-Path $ProjectRoot "opencode.json"
if (Test-Path $OpencodePath) {
    try {
        $json = Get-Content $OpencodePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($json.mcp) {
            if ($json.mcp.graphify) { $json.mcp.graphify.enabled = $GraphifyActive }
            if ($json.mcp.'ui-registry') { $json.mcp.'ui-registry'.enabled = $UiActive }
            if ($json.mcp.headroom) { $json.mcp.headroom.enabled = $HeadroomActive }
            $jsonStr = $json | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($OpencodePath, $jsonStr, $Utf8NoBom)
            Write-Host "[OK] Updated opencode.json" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to update opencode.json: $_"
    }
}

# 2. Update .antigravity/mcp_config.json
$AntigravityMcpPath = Join-Path $ProjectRoot ".antigravity\mcp_config.json"
if (Test-Path $AntigravityMcpPath) {
    try {
        $json = Get-Content $AntigravityMcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($json.mcpServers) {
            if ($json.mcpServers.graphify) { $json.mcpServers.graphify.disabled = (-not $GraphifyActive) }
            if ($json.mcpServers.'ui-registry') { $json.mcpServers.'ui-registry'.disabled = (-not $UiActive) }
            if ($json.mcpServers.headroom) { $json.mcpServers.headroom.disabled = (-not $HeadroomActive) }
            $jsonStr = $json | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($AntigravityMcpPath, $jsonStr, $Utf8NoBom)
            Write-Host "[OK] Updated .antigravity/mcp_config.json" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to update .antigravity/mcp_config.json: $_"
    }
}

# 3. Update .antigravity/settings.json
$AntigravitySettingsPath = Join-Path $ProjectRoot ".antigravity\settings.json"
if (Test-Path $AntigravitySettingsPath) {
    try {
        $json = Get-Content $AntigravitySettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($json.context) {
            $json.context.mcp_profile = $Profile
            $jsonStr = $json | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($AntigravitySettingsPath, $jsonStr, $Utf8NoBom)
            Write-Host "[OK] Updated .antigravity/settings.json" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to update .antigravity/settings.json: $_"
    }
}

# Summary output
$tokenEstimate = switch ($Profile) {
    'core' { '<= 350 tokens' }
    'ui' { '~750 tokens' }
    'compression' { '~650 tokens' }
    'all' { '~1,050 tokens' }
}

Write-Host "Successfully applied MCP Profile: '$Profile' (Estimated context cost: $tokenEstimate)" -ForegroundColor Green
exit 0
