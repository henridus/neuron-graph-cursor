# Verification skills-first tunnel - 003 Expert Code
# Domaine: automation multi-agents | Spec: 02_Base/00_INDEX_PROJET.md | MDC: 11-enforcement-gates.mdc, 43-library-first.mdc, 44-memory-obsidian.mdc

param(
    [string]$ProjectRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$hooksJson = Join-Path $ProjectRoot '.cursor\hooks.json'
$memoryConfig = Join-Path $ProjectRoot '.cursor\memory.config.json'
$libraryRule = Join-Path $ProjectRoot '.cursor\rules\43-library-first.mdc'
$gateRule = Join-Path $ProjectRoot '.cursor\rules\11-enforcement-gates.mdc'
$skillsRule = Join-Path $ProjectRoot '.cursor\rules\46-skills-first-tunnel.mdc'

if (-not (Test-Path $hooksJson)) { Write-Host 'Missing hooks.json'; exit 1 }
if (-not (Test-Path $memoryConfig)) { Write-Host 'Missing memory.config.json'; exit 1 }

$hooksRaw = Get-Content $hooksJson -Raw
$config = Get-Content $memoryConfig -Raw | ConvertFrom-Json
$vault = $config.vaultPath
$indexPath = Join-Path $vault 'domains\cursor-skills\INDEX.md'

$brainLoad = Join-Path $ProjectRoot '.cursor\hooks\brain-load.ps1'
$sessionStart = Join-Path $ProjectRoot '.cursor\hooks\session-start.ps1'
$brainLoadRaw = if (Test-Path $brainLoad) { Get-Content $brainLoad -Raw } else { '' }
$sessionRaw = if (Test-Path $sessionStart) { Get-Content $sessionStart -Raw } else { '' }
$skillsRuleRaw = if (Test-Path $skillsRule) { Get-Content $skillsRule -Raw } else { '' }

$checks = [ordered]@{
    BrainLoadMentionsSkillsIndex = ($brainLoadRaw -match 'cursor-skills')
    SessionStartTrustBrain = ($sessionRaw -match 'trust_brain')
    SkillsRuleMentionsDecisionTokens = ($skillsRuleRaw -match 'competence_deja_disponible') -and ($skillsRuleRaw -match 'skill_a_adapter')
    VaultExists = (Test-Path $vault)
    SkillsIndexExists = (Test-Path $indexPath)
    LibraryRuleUpdated = (Test-Path $libraryRule) -and ((Get-Content $libraryRule -Raw) -match 'cursor-skills')
    GateRuleUpdated = (Test-Path $gateRule) -and ((Get-Content $gateRule -Raw) -match 'Tunnel competences')
    SkillsRuleExists = (Test-Path $skillsRule)
}

$score = ($checks.Values | Where-Object { $_ }).Count
Write-Host "Skills-first tunnel verification: $score/7"
foreach ($key in $checks.Keys) {
    $ok = if ($checks[$key]) { 'PASS' } else { 'FAIL' }
    Write-Host "  $key : $ok"
}
if ($score -lt 7) { exit 1 }
exit 0
