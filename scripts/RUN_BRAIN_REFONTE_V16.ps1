# RUN_BRAIN_REFONTE_V16.ps1 — reapplique refonte anti-brick (idempotent)
# Usage: powershell -NoProfile -EP Bypass -File scripts\RUN_BRAIN_REFONTE_V16.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$vault = 'C:\Users\henri\OneDrive\Obsidian\AgentMemory'
$hooks = Join-Path $root '.cursor\hooks'
Set-Location $root

Write-Host '=== Fix syntaxe _hook-io.ps1 ===' -ForegroundColor Cyan
$io = Join-Path $hooks '_hook-io.ps1'
$c = Get-Content $io -Raw
$c = $c -replace '(?m)^ Write-HookTelemetryLog\(', 'function Write-HookTelemetryLog('
if ($c -notmatch 'function Test-RepairSurfacePath') {
    $c += @'

function Test-RepairSurfacePath([string]$NormPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    $p = ($NormPath -replace '/', '\').ToLower()
    return ($p -match '(^|\\)\.cursor\\hooks\\') -or ($p -match '(^|\\)\.cursor\\rules\\') -or
        ($p -match 'agent-gates\.json$') -or ($p -match '(^|\\)scripts\\run_brain_refonte') -or
        ($p -match '(^|\\)tests\\hooks\\')
}
function Test-BrainOkLoaded([string]$Root) {
    $g = Read-Gates $Root
    return ($g -and $g.brain_ok -eq $true)
}
'@
}
Set-Content $io $c -Encoding UTF8

Write-Host '=== Test V16 ===' -ForegroundColor Cyan
& powershell -NoProfile -EP Bypass -File (Join-Path $root 'tests\hooks\RUN_TERRAIN_BRAIN_V16.ps1')
if ($LASTEXITCODE -ne 0) { throw 'RUN_TERRAIN_BRAIN_V16 FAIL' }

Write-Host '=== OK refonte V16 verifiee ===' -ForegroundColor Green
