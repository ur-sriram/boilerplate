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

# Resolve a path to its physical location (following symlinks/junctions).
# Returns $null when the path cannot be resolved, so callers can fall back
# to lexical comparison. Mirrors the POSIX twin's `realpath -m` behaviour:
# both the project root and the target must be compared in the same space,
# otherwise a checkout behind a symlink blocks every legitimate write.
function Resolve-PhysicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

        # PowerShell 7.1+: ResolvedTarget is the definitive physical target.
        if ($item.PSObject.Properties['ResolvedTarget'] -and $item.ResolvedTarget) {
            return $item.ResolvedTarget.FullName
        }

        # Windows PowerShell 5.1: ReparsePoint target is exposed via .Target.
        if ($item.PSObject.Properties['Target'] -and $item.Target) {
            $target = @($item.Target)[0]
            if ($target -is [string]) {
                if (-not [System.IO.Path]::IsPathRooted($target)) {
                    $target = Join-Path (Split-Path -Parent $item.FullName) $target
                }
                return [System.IO.Path]::GetFullPath($target)
            }
        }

        return $item.FullName
    } catch {
        return $null
    }
}

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
                # Key set MUST match the POSIX twin (protect-config.sh) exactly:
                #   path | file | target | target_path | filePath | params.*
                # Missing 'target_path' here is what caused the Claude Code hook
                # payload to fall through to the raw-blob branch and block
                # legitimate in-scope writes.
                foreach ($key in @('path', 'file', 'target', 'target_path', 'filePath')) {
                    if ($parsed.PSObject.Properties[$key] -and $parsed.$key) {
                        $TargetPath = $parsed.$key
                        break
                    }
                }
                if (-not $TargetPath -and $parsed.params) {
                    foreach ($key in @('path', 'file', 'target', 'target_path', 'filePath')) {
                        if ($parsed.params.PSObject.Properties[$key] -and $parsed.params.$key) {
                            $TargetPath = $parsed.params.$key
                            break
                        }
                    }
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

# Physical (symlink-resolved) forms of root and target. When both are
# available they must agree, otherwise compare lexically.
$PhysicalRoot = Resolve-PhysicalPath -Path $ProjectRoot
$PhysicalTarget = Resolve-PhysicalPath -Path $ResolvedTarget

$ProjectRootWithSlash = $ProjectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$IsInsideProject = $ResolvedTarget.StartsWith($ProjectRootWithSlash, [System.StringComparison]::OrdinalIgnoreCase) -or
                   ($ResolvedTarget.Equals($ProjectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase))

if (-not $IsInsideProject -and $PhysicalRoot -and $PhysicalTarget) {
    $PhysicalRootWithSlash = $PhysicalRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $IsInsideProject = $PhysicalTarget.StartsWith($PhysicalRootWithSlash, [System.StringComparison]::OrdinalIgnoreCase) -or
                       ($PhysicalTarget.Equals($PhysicalRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase))
}

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
