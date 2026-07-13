# RUN_TERRAIN_BRAIN_V20.ps1 - restauration tunnel V17 + L5 par-tour + staleness.
# Valide:
#   - gates Write/Shell DENY si brain_tunnel_ok=false (juste milieu V17 restaure)
#   - L5 followup si analytique SANS librarian_used_this_turn (meme si librarian_used session=true)
#   - silence si librarian_used_this_turn + TRACE
#   - refresh digest si brain_digest_at stale
$ErrorActionPreference = 'SilentlyContinue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Push-Location $root
$fail = 0
function Check([string]$label, [bool]$ok) {
    if ($ok) { Write-Host ("[OK]   " + $label) } else { Write-Host ("[FAIL] " + $label); $script:fail++ }
}
function Invoke-Hook([string]$script, [string]$json) {
    $env:CURSOR_HOOK_TEST_INPUT = $json
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $script 2>&1
        return (($out | Out-String).Trim())
    } finally {
        $ErrorActionPreference = $prev
        Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
    }
}

$gatesPath = Join-Path $root '.cursor\agent-gates.json'
$audit = Join-Path $root '.cursor\hooks\stop-depth-audit.ps1'
$gateWrite = Join-Path $root '.cursor\hooks\gate-write-unified.ps1'
$gateShell = Join-Path $root '.cursor\hooks\gate-shell-triage.ps1'
$brainActive = Join-Path $root '.cursor\rules\00-brain-active.mdc'

$backup = $null
$backupBrain = $null
if (Test-Path $gatesPath) { $backup = Get-Content $gatesPath -Raw }
if (Test-Path $brainActive) { $backupBrain = Get-Content $brainActive -Raw }
try {
    if (-not (Test-Path $brainActive)) { '{"alwaysApply":true}' | Set-Content $brainActive -Encoding UTF8 }
    $g = if ($backup) { $backup | ConvertFrom-Json } else { [pscustomobject]@{} }
    $g | Add-Member -NotePropertyName brain_ok -NotePropertyValue $true -Force
    $g | Add-Member -NotePropertyName brain_tunnel_ok -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName session_started -NotePropertyValue (Get-Date -Format o) -Force
    $g | Add-Member -NotePropertyName brain_digest_at -NotePropertyValue (Get-Date -Format o) -Force
    $g | Add-Member -NotePropertyName vault_index_read -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName erreurs_index_read -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName agent_note_read -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName biblio_index_read -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName skills_index_read -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName handoff_read -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName agents_md_read -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName spec_read -NotePropertyValue $false -Force
    $g | Add-Member -NotePropertyName read_timestamps -NotePropertyValue (@{}) -Force
    $g | ConvertTo-Json -Depth 6 | Set-Content $gatesPath -Encoding UTF8

    # --- Gate Write: tunnel false -> DENY (V20 restore) ---
    $wIn = @{ tool_name='Write'; cwd=$root; tool_input=@{ path='tools\_scratch_v20.txt' } } | ConvertTo-Json -Compress
    $wOut = Invoke-Hook $gateWrite $wIn
    Check "gate-write: DENY path ordinaire avec tunnel=false" ($wOut -match 'Tunnel cerveau incomplet|permission"\s*:\s*"deny')

    # --- Gate Shell: tunnel false -> DENY ---
    $sIn = @{ cwd=$root; command='Set-Content tools\_scratch_v20.txt "x"' } | ConvertTo-Json -Compress
    $sOut = Invoke-Hook $gateShell $sIn
    Check "gate-shell: DENY mutate avec tunnel=false" ($sOut -match 'Tunnel cerveau incomplet|permission"\s*:\s*"deny')

    # --- L5 par-tour: session librarian_used=true MAIS this_turn=false -> followup ---
    $g2 = Get-Content $gatesPath -Raw | ConvertFrom-Json
    $g2 | Add-Member -NotePropertyName librarian_used -NotePropertyValue $true -Force
    $g2 | Add-Member -NotePropertyName librarian_calls -NotePropertyValue 5 -Force
    $g2 | Add-Member -NotePropertyName librarian_used_this_turn -NotePropertyValue $false -Force
    $g2 | Add-Member -NotePropertyName brain_digest_at -NotePropertyValue (Get-Date -Format o) -Force
    $g2 | ConvertTo-Json -Depth 6 | Set-Content $gatesPath -Encoding UTF8
    $analytique = 'Verdict: cet outil vaut-il le coup pour ton architecture ? Voici une analyse comparative complete de la solution et de son approche. ' * 4
    $aIn = @{ status='completed'; loop_count=0; cwd=$root; text=$analytique } | ConvertTo-Json -Compress
    $aOut = Invoke-Hook $audit $aIn
    Check "stop-audit L5: followup si analytique SANS this_turn (meme si session used)" ($aOut -match 'followup_message' -and $aOut -match 'CE TOUR|this_turn|librarian_used_this_turn')

    # --- L5: this_turn=true + TRACE -> silence ---
    $g3 = Get-Content $gatesPath -Raw | ConvertFrom-Json
    $g3 | Add-Member -NotePropertyName librarian_used_this_turn -NotePropertyValue $true -Force
    $g3 | Add-Member -NotePropertyName brain_digest_at -NotePropertyValue (Get-Date -Format o) -Force
    $g3 | ConvertTo-Json -Depth 6 | Set-Content $gatesPath -Encoding UTF8
    $traced = 'Fait. CHEMIN: MAP-automation -> erreurs -> solution. ERREURS_LUES: x. CONTRADICTION_REPO_VAULT: non. SKILL: competence_deja_disponible. ' * 3
    $tIn = @{ status='completed'; loop_count=0; cwd=$root; text=$traced } | ConvertTo-Json -Compress
    $tOut = Invoke-Hook $audit $tIn
    Check "stop-audit: silence si this_turn + TRACE" ([string]::IsNullOrWhiteSpace($tOut))

    # --- Staleness: brain_digest_at hier -> followup refresh ---
    $g4 = Get-Content $gatesPath -Raw | ConvertFrom-Json
    $yesterday = (Get-Date).AddDays(-2).ToString('o')
    $g4 | Add-Member -NotePropertyName brain_digest_at -NotePropertyValue $yesterday -Force
    $g4 | Add-Member -NotePropertyName brain_loaded_at -NotePropertyValue $yesterday -Force
    $g4 | Add-Member -NotePropertyName session_started -NotePropertyValue $yesterday -Force
    $g4 | Add-Member -NotePropertyName librarian_used_this_turn -NotePropertyValue $true -Force
    $g4 | ConvertTo-Json -Depth 6 | Set-Content $gatesPath -Encoding UTF8
    $staleIn = @{ status='completed'; loop_count=0; cwd=$root; text='Ok CHEMIN: MAP-automation -> x. ERREURS_LUES: y. CONTRADICTION_REPO_VAULT: non. SKILL: competence_deja_disponible.' } | ConvertTo-Json -Compress
    $staleOut = Invoke-Hook $audit $staleIn
    Check "stop-audit: followup si digest stale" ($staleOut -match 'followup_message' -and $staleOut -match 'rafraichi|perime')
    $gAfter = Get-Content $gatesPath -Raw | ConvertFrom-Json
    $freshOk = $false
    try {
        $dat = [datetime]::Parse([string]$gAfter.brain_digest_at)
        $freshOk = ($dat.Date -eq (Get-Date).Date)
    } catch { }
    Check "stop-audit: brain_digest_at rafraichi apres stale" $freshOk

    # --- Trivial court (digest frais) -> silence ---
    $g5 = Get-Content $gatesPath -Raw | ConvertFrom-Json
    $g5 | Add-Member -NotePropertyName brain_digest_at -NotePropertyValue (Get-Date -Format o) -Force
    $g5 | Add-Member -NotePropertyName session_started -NotePropertyValue (Get-Date -Format o) -Force
    $g5 | Add-Member -NotePropertyName librarian_used_this_turn -NotePropertyValue $false -Force
    $g5 | ConvertTo-Json -Depth 6 | Set-Content $gatesPath -Encoding UTF8
    $triv = @{ status='completed'; loop_count=0; cwd=$root; text='Ok, fait.' } | ConvertTo-Json -Compress
    $trOut = Invoke-Hook $audit $triv
    Check "stop-audit: silence si trivial court" ([string]::IsNullOrWhiteSpace($trOut))

    # --- Anti-boucle ---
    $loopIn = @{ status='completed'; loop_count=2; cwd=$root; text=$analytique } | ConvertTo-Json -Compress
    $loopOut = Invoke-Hook $audit $loopIn
    Check "stop-audit: anti-boucle loop_count>=2 silence" ([string]::IsNullOrWhiteSpace($loopOut))
}
finally {
    if ($backup) { Set-Content $gatesPath $backup -Encoding UTF8 }
    if ($backupBrain) { Set-Content $brainActive $backupBrain -Encoding UTF8 }
    Remove-Item (Join-Path $root 'tools\_scratch_v20.txt') -Force -ErrorAction SilentlyContinue
}

Pop-Location
Write-Host ("RESULT: {0}" -f $(if ($fail -eq 0) { 'PASS' } else { "FAIL ($fail)" }))
exit $fail
