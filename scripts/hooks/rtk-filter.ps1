<#
.SYNOPSIS
    PostToolUse Output Compressor Hook for Windows PowerShell.
    Filters command output using the `rtk` (Rust Token Killer) binary if available.
    Gracefully echoes raw input unchanged if `rtk` is absent.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline = $true)]
    [string]$InputText,

    [Parameter(Position = 0)]
    [string]$RawOutput
)

begin {
    $ErrorActionPreference = 'SilentlyContinue'
    $PipelineItems = [System.Collections.Generic.List[string]]::new()
}

process {
    if ($PSCmdlet.MyInvocation.ExpectingInput) {
        if ($null -ne $InputText) {
            $PipelineItems.Add($InputText)
        }
    } elseif (-not [string]::IsNullOrEmpty($InputText)) {
        $PipelineItems.Add($InputText)
    }
}

end {
    # Accumulate input from argument, pipeline, or $Input fallback
    $Content = ""
    if (-not [string]::IsNullOrEmpty($RawOutput)) {
        $Content = $RawOutput
    } elseif ($PipelineItems.Count -gt 0) {
        $Content = ($PipelineItems -join [Environment]::NewLine) + [Environment]::NewLine
    } elseif ($Input) {
        $Content = ($Input | Out-String)
    }

    if ([string]::IsNullOrEmpty($Content)) {
        exit 0
    }

    # Check if rtk binary is installed and executable
    $RtkCommand = Get-Command "rtk" -ErrorAction SilentlyContinue

    if ($RtkCommand) {
        try {
            $Filtered = $Content | & $RtkCommand.Source filter 2>$null
            if ($LASTEXITCODE -eq 0 -and $null -ne $Filtered) {
                $FilteredText = if ($Filtered -is [array]) { ($Filtered -join [Environment]::NewLine) } else { [string]$Filtered }
                if (-not [string]::IsNullOrEmpty($FilteredText)) {
                    [Console]::Out.Write($FilteredText)
                    exit 0
                }
            }
        } catch {
            # Fallback to raw output on any filter failure
        }
    }

    # Graceful passthrough: echo raw input unchanged
    [Console]::Out.Write($Content)
    exit 0
}
