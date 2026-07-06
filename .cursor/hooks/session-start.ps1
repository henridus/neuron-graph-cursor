# sessionStart V16 â€” brain digest + brain_ok
$ErrorActionPreference = 'SilentlyContinue'
if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { exit 0 }
try { . (Join-Path $PSScriptRoot '_hook-io.ps1') } catch { }
$root = (Get-Location).Path
$brainScript = Join-Path $PSScriptRoot 'brain-load.ps1'
$hookIn = ''
try { if (Test-Path (Join-Path $PSScriptRoot '_hook-io.ps1')) { . (Join-Path $PSScriptRoot '_hook-io.ps1'); $hookIn = Read-HookInput } } catch { }
$payload = if ($hookIn -and $hookIn.Trim().Length -gt 0) { $hookIn } else { '{}' }
$brainOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $brainScript -Payload $payload 2>&1 | Out-String).Trim()
try {
    . (Join-Path $PSScriptRoot '_hook-io.ps1')
    Write-Gates $root @{ librarian_used = $false; librarian_calls = 0; brain_ok = $true; session_started = (Get-Date -Format o); brain_loaded_at = (Get-Date -Format o); brain_digest_at = (Get-Date -Format o) }
} catch { }
if ($brainOut) {
    $lastLine = ($brainOut -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Last 1)
    if ($lastLine) { Write-Output $lastLine }
}
