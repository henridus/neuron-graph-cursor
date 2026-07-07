# Verification bibliotheque fluide - 003 Expert Code
# Domaine: automation multi-agents | Spec: 02_Base/00_INDEX_PROJET.md | MDC: 43-library-first.mdc, 47-brain-first-audit.mdc

param(
    [string]$ProjectRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$rule43 = Join-Path $ProjectRoot '.cursor\rules\43-library-first.mdc'
$rule47 = Join-Path $ProjectRoot '.cursor\rules\47-brain-first-audit.mdc'
$brainLoad = Join-Path $ProjectRoot '.cursor\hooks\brain-load.ps1'
$memoryConfig = Join-Path $ProjectRoot '.cursor\memory.config.json'
$config = Get-Content $memoryConfig -Raw | ConvertFrom-Json
$vault = $config.vaultPath
$biblioIndex = Join-Path $vault 'domains\bibliotheque\INDEX.md'
$skillsIndex = Join-Path $vault 'domains\cursor-skills\INDEX.md'

$rule43Raw = Get-Content $rule43 -Raw
$rule47Raw = Get-Content $rule47 -Raw
$brainLoadRaw = Get-Content $brainLoad -Raw
$biblioRaw = Get-Content $biblioIndex -Raw
$skillsRaw = Get-Content $skillsIndex -Raw

$checks = [ordered]@{
    BibliothequeIndexExists = (Test-Path $biblioIndex)
    BibliothequeHasCanonicalPath = ($biblioRaw -match 'C:\\Users\\henri\\OneDrive\\27_IA\\00_Cursor\\00_Bibliothèque')
    BibliothequeMentionsSecondLevel = ($biblioRaw -match 'second niveau')
    Rule43MentionsIfNeeded = ($rule43Raw -match 'si la solution reste floue')
    Rule47MentionsBibliotheque = ($rule47Raw -match 'domains/bibliotheque/INDEX.md')
    SkillsIndexBridgeExists = ($skillsRaw -match 'Si aucune skill ne suffit')
    BrainLoadHasBibliothequeRouter = ($brainLoadRaw -match 'Get-BibliothequeSnippet')
}

$score = ($checks.Values | Where-Object { $_ }).Count
Write-Host "Bibliotheque fluidity verification: $score/7"
foreach ($key in $checks.Keys) {
    $ok = if ($checks[$key]) { 'PASS' } else { 'FAIL' }
    Write-Host "  $key : $ok"
}
if ($score -lt 7) { exit 1 }
exit 0
