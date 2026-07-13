# Delete V20 — tunnel requis (E1)
$ErrorActionPreference = 'SilentlyContinue'
if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { '{"permission":"allow"}' | Write-Output; exit 0 }
try {
    . (Join-Path $PSScriptRoot '_hook-io.ps1')
    $raw = Read-HookInput
    if ([string]::IsNullOrWhiteSpace($raw)) { Out-Allow }
    $in = $raw | ConvertFrom-Json
    if ($in.tool_name -ne 'Delete') { Out-Allow }
    $t = if ($in.tool_input.path) { $in.tool_input.path } else { '' }
    if (Test-DeleteAllowPath $t) { Out-Allow }
    $root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { (Get-Location).Path })
    if (-not (Test-BrainActive $root)) { Out-Deny 'Brain non charge' 'sessionStart requis.' }
    # V20: restore tunnel Read session (juste milieu V17)
    if (-not (Test-BrainTunnelOk $root)) { Out-Deny 'Tunnel cerveau incomplet' 'Lire requiredReads vault avant Delete.' }
    if (-not (Test-BrainOkLoaded $root)) { Out-Deny 'Brain non charge' 'sessionStart requis.' }
    Out-Deny 'Delete non autorise' 'hors carve-out'
} catch { '{"permission":"allow"}' | Write-Output; exit 0 }
