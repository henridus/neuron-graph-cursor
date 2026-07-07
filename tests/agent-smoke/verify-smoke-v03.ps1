# Verification structurelle smoke tests V03 - 003 Expert Code
# Domaine: automation multi-agents | Spec: 02_Base/00_INDEX_PROJET.md | MDC: 43-library-first.mdc, 44-memory-obsidian.mdc

param(
    [string]$ProjectRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$rules = Join-Path $ProjectRoot ".cursor\rules"
$errors = @()

function Test-PathRule($name) {
    $p = Join-Path $rules $name
    if (-not (Test-Path $p)) { $script:errors += "Missing rule: $name" }
}

@(
    '00-dispatcher.mdc', '11-enforcement-gates.mdc', '43-library-first.mdc',
    '44-memory-obsidian.mdc', '45-token-compression.mdc', '46-skills-first-tunnel.mdc', '47-brain-first-audit.mdc', '48-proof-of-use.mdc'
) | ForEach-Object { Test-PathRule $_ }

$hooksJson = Join-Path $ProjectRoot '.cursor\hooks.json'
$memoryConfig = Join-Path $ProjectRoot '.cursor\memory.config.json'
$ag = Join-Path $ProjectRoot 'AGENTS.md'
$skillsTest = Join-Path $ProjectRoot 'tests\agent-smoke\verify-skills-tunnel.ps1'
$auditTest = Join-Path $ProjectRoot 'tests\agent-smoke\verify-brain-first-audit.ps1'
$proofUseTest = Join-Path $ProjectRoot 'tests\agent-smoke\verify-proof-of-use.ps1'
$biblioTest = Join-Path $ProjectRoot 'tests\agent-smoke\verify-bibliotheque-fluidity.ps1'

$hooksRaw = if (Test-Path $hooksJson) { Get-Content $hooksJson -Raw } else { '' }
$config = if (Test-Path $memoryConfig) { Get-Content $memoryConfig -Raw | ConvertFrom-Json } else { $null }
$vault = if ($config) { $config.vaultPath } else { $null }
$skillsIndex = if ($vault) { Join-Path $vault 'domains\cursor-skills\INDEX.md' } else { $null }

$brainLoad = Join-Path $ProjectRoot '.cursor\hooks\brain-load.ps1'
$sessionStart = Join-Path $ProjectRoot '.cursor\hooks\session-start.ps1'
$gateShell = Join-Path $ProjectRoot '.cursor\hooks\gate-shell-triage.ps1'
$gateWrite = Join-Path $ProjectRoot '.cursor\hooks\gate-write-triage.ps1'
$brainLoadRaw = if (Test-Path $brainLoad) { Get-Content $brainLoad -Raw } else { '' }
$sessionRaw = if (Test-Path $sessionStart) { Get-Content $sessionStart -Raw } else { '' }
$hookIoRaw = if (Test-Path (Join-Path $ProjectRoot '.cursor\hooks\_hook-io.ps1')) {
    Get-Content (Join-Path $ProjectRoot '.cursor\hooks\_hook-io.ps1') -Raw
} else { '' }

$checks = [ordered]@{
    T1 = (Test-Path $hooksJson)
    T2 = ($hooksRaw -match 'gate-write-unified\.ps1') -and ($hooksRaw -match 'gate-shell-triage\.ps1') -and ($brainLoadRaw -match 'cursor-skills')
    T3 = ($sessionRaw -notmatch 'trust_brain') -and ($sessionRaw -match 'brain_ok') -and (Test-Path $gateShell) -and (Test-Path (Join-Path $rules '46-skills-first-tunnel.mdc'))
    T4 = (Test-Path $memoryConfig) -and (Test-Path $vault)
    T5 = ($skillsIndex) -and (Test-Path $skillsIndex)
    T6 = (Test-Path (Join-Path $rules '46-skills-first-tunnel.mdc'))
    T7 = (Test-Path (Join-Path $rules '47-brain-first-audit.mdc'))
    T8 = (Test-Path $skillsTest)
    T9 = (Test-Path $auditTest)
    T10 = (Test-Path $proofUseTest)
    T11 = (Test-Path $biblioTest)
    T12 = (Test-Path $ag) -and ((Get-Content $ag -Raw) -match 'domains/cursor-skills/INDEX\.md')
    T13 = ($hookIoRaw -notmatch 'trust_brain') -and ($hookIoRaw -match 'Test-ShellMutatesFile')
}

$score = ($checks.Values | Where-Object { $_ }).Count
Write-Host "Smoke structural verification (003 Expert Code): $score/13"
foreach ($k in $checks.Keys) {
    $ok = if ($checks[$k]) { 'PASS' } else { 'FAIL' }
    Write-Host "  $k : $ok"
}
if ($errors.Count -gt 0) {
    Write-Host 'Errors:'
    $errors | ForEach-Object { Write-Host "  $_" }
    exit 1
}
if ($score -lt 13) { exit 1 }
exit 0

