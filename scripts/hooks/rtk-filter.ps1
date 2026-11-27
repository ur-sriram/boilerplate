<#
.SYNOPSIS
    rtk Output Filter Hook for Windows PowerShell - thin wrapper.
.DESCRIPTION
    The filter itself lives in scripts/hooks/rtk-filter.mjs, which is the one
    implementation shared by this script, its POSIX twin, the cross-platform
    dispatcher and the OpenCode plugin. They cannot disagree about the payload
    shape, the redaction rules or the runtime requirement.

    A PostToolUse hook receives the agent's hook payload on stdin, which for
    Claude Code, Codex, Goose and Qoder is a JSON envelope - not terminal text.
    The implementation extracts the terminal text from that envelope before
    handing it to rtk.

    Graceful degradation: without Node, or without rtk, the input is emitted
    unchanged. The filter never swallows output and never fails a session.
#>

$Filter = Join-Path $PSScriptRoot "rtk-filter.mjs"

$Node = Get-Command "node" -ErrorAction SilentlyContinue
if (-not $Node -or -not (Test-Path -LiteralPath $Filter)) {
    # No runtime: emit the payload unchanged.
    $Input | Out-String | Write-Output
    exit 0
}

& $Node.Source $Filter
exit 0
