# Verification brain-first audit tunnel - 003 Expert Code
# Domaine: automation multi-agents | Spec: 02_Base/00_INDEX_PROJET.md | MDC: 47-brain-first-audit.mdc, 44-memory-obsidian.mdc

param(
    [string]$ProjectRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$hooksJson = Join-Path $ProjectRoot '.cursor\hooks.json'
$rule47 = Join-Path $ProjectRoot '.cursor\rules\47-brain-first-audit.mdc'
$rule44 = Join-Path $ProjectRoot '.cursor\rules\44-memory-obsidian.mdc'
$memoryConfig = Join-Path $ProjectRoot '.cursor\memory.config.json'

$hooksRaw = Get-Content $hooksJson -Raw
$rule47Raw = Get-Content $rule47 -Raw
$rule44Raw = Get-Content $rule44 -Raw
$config = Get-Content $memoryConfig -Raw | ConvertFrom-Json
$vault = $config.vaultPath
$skillsIndex = Join-Path $vault 'domains\cursor-skills\INDEX.md'

$checks = [ordered]@{
    AuditGateTargetsTaskOnly = ($hooksRaw -match '"matcher":\s*"Task"')
    AuditGateNoBroadReadShell = ($hooksRaw -notmatch 'Read\|Task\|Shell')
    Rule47MentionsNoBlindBlock = ($rule47Raw -match 'Read` et `Shell` de verification legitimes doivent rester possibles')
    Rule44MentionsAuditPlan = ($rule44Raw -match 'Audit/plan multi-fichiers')
    VaultExists = (Test-Path $vault)
    SkillsIndexExists = (Test-Path $skillsIndex)
}

$score = ($checks.Values | Where-Object { $_ }).Count
Write-Host "Brain-first audit verification: $score/6"
foreach ($key in $checks.Keys) {
    $ok = if ($checks[$key]) { 'PASS' } else { 'FAIL' }
    Write-Host "  $key : $ok"
}
if ($score -lt 6) { exit 1 }
exit 0
