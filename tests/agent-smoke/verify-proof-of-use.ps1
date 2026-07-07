# Verification proof-of-use tunnel - 003 Expert Code
# Domaine: automation multi-agents | Spec: 02_Base/00_INDEX_PROJET.md | MDC: 48-proof-of-use.mdc, 47-brain-first-audit.mdc

param(
    [string]$ProjectRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$hooksJson = Join-Path $ProjectRoot '.cursor\hooks.json'
$rule48 = Join-Path $ProjectRoot '.cursor\rules\48-proof-of-use.mdc'
$rule11 = Join-Path $ProjectRoot '.cursor\rules\11-enforcement-gates.mdc'
$rule44 = Join-Path $ProjectRoot '.cursor\rules\44-memory-obsidian.mdc'
$hooksRaw = Get-Content $hooksJson -Raw
$rule48Raw = Get-Content $rule48 -Raw
$rule11Raw = Get-Content $rule11 -Raw
$rule44Raw = Get-Content $rule44 -Raw

$checks = [ordered]@{
    Rule48Exists = (Test-Path $rule48)
    Rule48MentionsMemoire = ($rule48Raw -match 'memoire_consultee')
    Rule48MentionsSignal = ($rule48Raw -match 'signal_contradictoire')
    HookMentionsProofOfUse = (Test-Path (Join-Path $ProjectRoot '.cursor\hooks\brain-load.ps1')) -and ($rule48Raw -match 'correction_de_trajectoire')
    GateMentionsProof = ($rule11Raw -match 'Gate preuve d''usage')
    MemoryRuleMentionsDecision = ($rule44Raw -match 'decision concrete')
}

$score = ($checks.Values | Where-Object { $_ }).Count
Write-Host "Proof-of-use verification: $score/6"
foreach ($key in $checks.Keys) {
    $ok = if ($checks[$key]) { 'PASS' } else { 'FAIL' }
    Write-Host "  $key : $ok"
}
if ($score -lt 6) { exit 1 }
exit 0
