# preToolUse Task V16 — anti-brick
$ErrorActionPreference = 'SilentlyContinue'
if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { '{"permission":"allow"}' | Write-Output; exit 0 }
try {
    . (Join-Path $PSScriptRoot '_hook-io.ps1')
    $root = Get-ProjectRoot (Get-Location).Path
    if (-not (Test-BrainActive $root)) { Out-Deny 'Brain non charge' 'sessionStart avant Task.' }
    if (-not (Test-BrainOkLoaded $root)) { Out-Deny 'Brain non charge' 'Digest cerveau requis.' }
    Out-Allow
} catch { '{"permission":"allow"}' | Write-Output; exit 0 }