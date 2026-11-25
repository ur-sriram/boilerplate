<#
.SYNOPSIS
    SessionStart Environment Validator Hook for Windows PowerShell.
    Validates presence of required runtime dependencies and confirms
    local project directory junctions and configuration integrity.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir "..\.."))

[Console]::WriteLine("=== Boilerplate Agent Session Initialization ===")
[Console]::WriteLine("Project Root: $ProjectRoot")

# Check runtimes
$Runtimes = @(
    @{ Name = "Git"; Command = "git"; Args = "--version" },
    @{ Name = "Node.js"; Command = "node"; Args = "--version" },
    @{ Name = "Python"; Command = "python"; Args = "--version" },
    @{ Name = "PowerShell"; Command = "powershell"; Args = "-NoProfile -Command `$PSVersionTable.PSVersion.ToString()" }
)

foreach ($rt in $Runtimes) {
    $cmd = Get-Command $rt.Command -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            $ver = & $rt.Command $rt.Args.Split(' ') 2>$null
            $verStr = ($ver -join ' ').Trim()
            [Console]::WriteLine("[OK] $($rt.Name): $verStr")
        } catch {
            [Console]::WriteLine("[OK] $($rt.Name): Present ($($cmd.Source))")
        }
    } else {
        [Console]::WriteLine("[WARN] $($rt.Name): Not found in PATH")
    }
}

# Check optional compression binary
$RtkCmd = Get-Command "rtk" -ErrorAction SilentlyContinue
if ($RtkCmd) {
    [Console]::WriteLine("[OK] rtk compressor: Present ($($RtkCmd.Source))")
} else {
    [Console]::WriteLine("[INFO] rtk compressor: Absent (graceful passthrough active)")
}

# Check skill directories and junctions
$SkillsDir = Join-Path $ProjectRoot ".agents\skills"
if (Test-Path $SkillsDir) {
    [Console]::WriteLine("[OK] Canonical Skills Store: Present (.agents/skills)")
} else {
    [Console]::WriteLine("[INFO] Canonical Skills Store: Pending curation (.agents/skills)")
}

$CodexSkills = Join-Path $ProjectRoot ".codex\skills"
if (Test-Path $CodexSkills) {
    $item = Get-Item $CodexSkills -Force -ErrorAction SilentlyContinue
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        [Console]::WriteLine("[OK] Codex Skills Junction: Verified link to .agents/skills")
    } else {
        [Console]::WriteLine("[OK] Codex Skills Directory: Present")
    }
}

$QoderSkills = Join-Path $ProjectRoot ".qoder\skills"
if (Test-Path $QoderSkills) {
    $item = Get-Item $QoderSkills -Force -ErrorAction SilentlyContinue
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        [Console]::WriteLine("[OK] Qoder Skills Junction: Verified link to .agents/skills")
    } else {
        [Console]::WriteLine("[OK] Qoder Skills Directory: Present")
    }
}

[Console]::WriteLine("=== Initialization Complete (Ready for Agent Tasks) ===")
exit 0
