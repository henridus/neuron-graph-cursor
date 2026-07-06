# RUN_TERRAIN_BRAIN_V17.ps1 - terrain cerveau-graphe sur l'agent courant.
# Valide: injection Tier-0 + entry_map (2 missions), gate skills curee, trace de sortie, closeout relie au MAP.
# Fail-open ailleurs, mais ce test RETOURNE exit=nb d'echecs (pour CI/propagation).
$ErrorActionPreference = 'SilentlyContinue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Push-Location $root
$fail = 0
function Check([string]$label, [bool]$ok) {
    if ($ok) { Write-Host ("[OK]   " + $label) } else { Write-Host ("[FAIL] " + $label); $script:fail++ }
}

$brainLoad = Join-Path $root '.cursor\hooks\brain-load.ps1'
$meta = Join-Path $root '.cursor\research\brain-digest-meta.json'
$brainActive = Join-Path $root '.cursor\rules\00-brain-active.mdc'

# --- Mission 1: domaine padel ---
$pl = @{ prompt = 'bug booking padel matchpoint minuit' } | ConvertTo-Json -Compress
& $brainLoad -Payload $pl | Out-Null
$m1 = Get-Content $meta -Raw | ConvertFrom-Json
Check "Mission padel: entry_map = MAP-padel" ($m1.entry_map -eq 'MAP-padel')
Check "Mission padel: digest injecte (>1000c)" ([int]$m1.digest_chars -gt 1000)
Check "00-brain-active.mdc contient bloc TRAVERSEE (Tier-0)" ((Get-Content $brainActive -Raw) -match 'TRAVERSEE \(Tier-0')

# --- Mission 2: hors-domaine (general) ---
$pl2 = @{ prompt = 'question generale sans domaine identifiable xyz' } | ConvertTo-Json -Compress
& $brainLoad -Payload $pl2 | Out-Null
$m2 = Get-Content $meta -Raw | ConvertFrom-Json
Check "Mission generale: domaine = general" ($m2.domain -eq 'general')
Check "Mission generale: entry_map pointe 00_INDEX" ($m2.entry_map -match '00_INDEX')

# --- Fichiers V17 presents ---
Check "regle 49-brain-traversal.mdc presente" (Test-Path (Join-Path $root '.cursor\rules\49-brain-traversal.mdc'))
Check "hook gate-skill-install.ps1 present" (Test-Path (Join-Path $root '.cursor\hooks\gate-skill-install.ps1'))
Check "skill brain-traverse presente" (Test-Path (Join-Path $root '.agents\skills\brain-traverse\SKILL.md'))

# --- Gate skills curee ---
$gt = Join-Path $root 'tests\hooks\test-skill-gate.ps1'
if (Test-Path $gt) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $gt | Out-Null
    Check "gate skills: PASS (curee=allow, non-curee=deny)" ($LASTEXITCODE -eq 0)
} else { Check "test-skill-gate.ps1 present" $false }

# --- Trace de sortie (stop-audit) ---
$audit = Join-Path $root '.cursor\hooks\stop-depth-audit.ps1'
$noTrace = (@{ status='completed'; loop_count=0; cwd=$root; text=('analyse via library_traverse MAP-padel et erreurs/padel '*20) } | ConvertTo-Json -Compress) | & powershell -NoProfile -ExecutionPolicy Bypass -File $audit
Check "stop-audit: followup si trace absente" ($noTrace -match 'followup_message')
$withTrace = (@{ status='completed'; loop_count=0; cwd=$root; text=('Fait. CHEMIN: MAP-padel -> padel -> solution. ERREURS_LUES: padel. CONTRADICTION_REPO_VAULT: non. SKILL: competence_deja_disponible. '*3) } | ConvertTo-Json -Compress) | & powershell -NoProfile -ExecutionPolicy Bypass -File $audit
Check "stop-audit: silencieux si trace presente" ([string]::IsNullOrWhiteSpace($withTrace))

# --- Closeout relie au MAP ---
$cfg = Get-Content (Join-Path $root '.cursor\memory.config.json') -Raw | ConvertFrom-Json
$vault = $cfg.vaultPath
$handoff = Join-Path $root '.cursor\hooks\brain-handoff.ps1'
$date = Get-Date -Format 'yyyy-MM-dd'
$sessTest = Join-Path $vault ("sessions\{0}-padel.md" -f $date)
$existedBefore = Test-Path $sessTest
if (-not $existedBefore) {
    $hp = @{ status='completed'; tool_calls=@(@{recipient_name='Write'},@{recipient_name='StrReplace'}); text='closeout padel matchpoint booking' } | ConvertTo-Json -Compress
    $hp | & powershell -NoProfile -ExecutionPolicy Bypass -File $handoff | Out-Null
    $linked = (Test-Path $sessTest) -and ((Get-Content $sessTest -Raw) -match '\[\[MAP-padel\]\]')
    Check "closeout: session padel reliee a [[MAP-padel]]" $linked
    Remove-Item $sessTest -Force -ErrorAction SilentlyContinue  # cleanup artefact de test
} else {
    Write-Host "[SKIP] closeout: une vraie session padel existe deja pour aujourd'hui (pas d'ecrasement)"
}

Pop-Location
Write-Host ("RESULT: {0}" -f $(if ($fail -eq 0) { 'PASS' } else { "FAIL ($fail)" }))
exit $fail
