<#
.SYNOPSIS
    PreToolUse Guardrail Hook for Windows PowerShell.
    Prevents autonomous coding agents from writing to or modifying files outside the project root.

.DESCRIPTION
    Inspects incoming tool invocations (via JSON payload from standard input, pipeline, or arguments).
    Validates that the target path resides strictly within the project boundary.
    Blocks any writes to global user directories (%USERPROFILE%, %APPDATA%, ~/.gemini, etc.).
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline = $true)]
    [string]$InputPayload,

    [Parameter(Position = 0)]
    [string]$TargetPath,

    [Parameter(Position = 1)]
    [string]$ToolName
)

$ErrorActionPreference = 'Stop'

# Determine canonical project root (2 levels up from scripts/hooks/)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir "..\.."))

# Read from pipeline if TargetPath is not provided
if ([string]::IsNullOrWhiteSpace($TargetPath) -and [string]::IsNullOrWhiteSpace($InputPayload)) {
    if ($Input) {
        $InputPayload = ($Input | Out-String).Trim()
    }
}

# Parse JSON if payload provided
if (-not [string]::IsNullOrWhiteSpace($InputPayload)) {
    try {
        $parsed = $InputPayload | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($parsed) {
            if (-not $TargetPath) {
                if ($parsed.path) { $TargetPath = $parsed.path }
                elseif ($parsed.file) { $TargetPath = $parsed.file }
                elseif ($parsed.target) { $TargetPath = $parsed.target }
                elseif ($parsed.filePath) { $TargetPath = $parsed.filePath }
                elseif ($parsed.params) {
                    if ($parsed.params.path) { $TargetPath = $parsed.params.path }
                    elseif ($parsed.params.file) { $TargetPath = $parsed.params.file }
                    elseif ($parsed.params.target) { $TargetPath = $parsed.params.target }
                }
            }
            if (-not $ToolName) {
                if ($parsed.tool) { $ToolName = $parsed.tool }
                elseif ($parsed.tool_name) { $ToolName = $parsed.tool_name }
                elseif ($parsed.name) { $ToolName = $parsed.name }
            }
        }
    } catch {
        # If not JSON, check if input payload is a direct path
        if (-not $TargetPath -and (Test-Path $InputPayload -ErrorAction SilentlyContinue)) {
            $TargetPath = $InputPayload
        }
    }
}

# If no target path was supplied, allow operation (e.g. read-only status commands)
if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    exit 0
}

$TargetPath = $TargetPath.Trim()

# Expand leading tilde (~) to user profile before path resolution
$UserProfile = [Environment]::GetFolderPath('UserProfile')
if ([string]::IsNullOrWhiteSpace($UserProfile)) { $UserProfile = $env:USERPROFILE }
if ([string]::IsNullOrWhiteSpace($UserProfile)) { $UserProfile = $env:HOME }

if ($TargetPath -eq '~' -or $TargetPath.StartsWith('~/') -or $TargetPath.StartsWith('~\')) {
    if ([string]::IsNullOrWhiteSpace($UserProfile)) {
        [Console]::Error.WriteLine("[GUARDRAIL] Access Denied: Cannot resolve home directory for target path '$TargetPath'.")
        exit 1
    }
    $SubPath = $TargetPath.Substring(1).TrimStart('/', '\')
    if ([string]::IsNullOrEmpty($SubPath)) {
        $TargetPath = $UserProfile
    } else {
        $TargetPath = Join-Path $UserProfile $SubPath
    }
}

# Resolve target path relative to project root
try {
    if ([System.IO.Path]::IsPathRooted($TargetPath)) {
        $ResolvedTarget = [System.IO.Path]::GetFullPath($TargetPath)
    } else {
        $ResolvedTarget = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $TargetPath))
    }
} catch {
    [Console]::Error.WriteLine("[GUARDRAIL] Invalid target path format: $TargetPath")
    exit 1
}

# Check if target is strictly within ProjectRoot
$ProjectRootWithSlash = $ProjectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$IsInsideProject = $ResolvedTarget.StartsWith($ProjectRootWithSlash, [System.StringComparison]::OrdinalIgnoreCase) -or
                   ($ResolvedTarget.Equals($ProjectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase))

# Check for forbidden sensitive directories
$AppData = [Environment]::GetFolderPath('ApplicationData')
$ForbiddenRoots = @($UserProfile, $AppData) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$IsTargetingGlobal = $false
foreach ($forbidden in $ForbiddenRoots) {
    if ($ResolvedTarget.StartsWith($forbidden, [System.StringComparison]::OrdinalIgnoreCase) -and (-not $ResolvedTarget.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase))) {
        $IsTargetingGlobal = $true
        break
    }
}

if (-not $IsInsideProject -or $IsTargetingGlobal) {
    [Console]::Error.WriteLine("[GUARDRAIL] Access Denied: Target path '$ResolvedTarget' is outside project root '$ProjectRoot'.")
    exit 1
}

exit 0
