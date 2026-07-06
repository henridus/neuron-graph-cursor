# track-triage-read — V15 read-proof autorite + sync gates (beforeReadFile / postToolUse Read)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_hook-io.ps1')
$sw = [Diagnostics.Stopwatch]::StartNew()
$eventName = if ($env:HOOK_TRACK_EVENT) { $env:HOOK_TRACK_EVENT } else { 'readTrack' }
try {
    $raw = Read-HookInput
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try {
            $in = $raw | ConvertFrom-Json
            $path = ''
            if ($in.tool_input) {
                if ($in.tool_input.PSObject.Properties['file_path']) { $path = $in.tool_input.file_path }
                elseif ($in.tool_input.PSObject.Properties['path']) { $path = $in.tool_input.path }
            }
            if ([string]::IsNullOrWhiteSpace($path) -and $in.PSObject.Properties['file_path']) { $path = $in.file_path }
            elseif ([string]::IsNullOrWhiteSpace($path) -and $in.PSObject.Properties['path']) { $path = $in.path }
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $norm = $path -replace '/', '\'
                $root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { (Get-Location).Path })
                $flags = Get-ReadFlagsForPath $norm
                if ($flags.Count -gt 0) {
                    Append-ReadProof $root $norm $flags
                    Sync-GatesFromReadProof $root
                }
                Write-HookTelemetryLog $root $eventName $raw 'Read' $norm 'allow' $sw.ElapsedMilliseconds
            }
        } catch { }
    }
} catch { }
Out-Allow

