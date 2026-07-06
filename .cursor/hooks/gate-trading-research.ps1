# preToolUse V18 — trading: deny synthese GEX/gamma sans github-inventory
$ErrorActionPreference = 'SilentlyContinue'
if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { '{"permission":"allow"}' | Write-Output; exit 0 }
try {
    . (Join-Path $PSScriptRoot '_hook-io.ps1')
    $raw = Read-HookInput
    if ([string]::IsNullOrWhiteSpace($raw)) { Out-Allow }
    try { $in = $raw | ConvertFrom-Json } catch { Out-Allow }
    $tool = $in.tool_name
    if ($tool -notin @('Write','StrReplace','EditNotebook')) { Out-Allow }
    $toolInput = $in.tool_input
    $target = ''
    if ($toolInput.PSObject.Properties['path']) { $target = $toolInput.path }
    elseif ($toolInput.PSObject.Properties['file_path']) { $target = $toolInput.file_path }
    if ([string]::IsNullOrWhiteSpace($target)) { Out-Allow }
    $root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { (Get-Location).Path })
    $norm = ($target -replace '/','\').ToLower()
    if (-not (Test-TradingResearchWritePath $norm)) { Out-Allow }
    if (-not (Test-BrainOkLoaded $root)) { Out-Allow }
    if (Test-GithubInventoryOk $root) { Out-Allow }
    $p = Read-ReflectionProof $root
    if ($p -and $p.external -and ($p.external.github -eq $true -or $p.external.web -eq $true)) { Out-Allow }
    Out-Deny 'Recherche externe requise' 'github-inventory.json (3+ repos) ou WebSearch/GitHub avant synthese gamma/GEX. Voir erreurs/trading-research-skipped-github.'
} catch { '{"permission":"allow"}' | Write-Output; exit 0 }
