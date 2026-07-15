# RUN_TERRAIN_SESSION_REAL.ps1 - test HONNETE bout-en-bout (zero flag pose a la main).
#
# Contrairement a RUN_HOOK_TESTS / RUN_TERRAIN_BRAIN_V20 qui posent les flags synthetiquement,
# ce test cree un projet temoin isole, lance la VRAIE session-start.ps1 (comme Cursor au
# demarrage d'une conversation), puis verifie l'etat reel des gates SANS jamais toucher
# un flag. Il reproduit le bug "read_timestamps < session_started -> brain_tunnel_ok=false".
#
# Attendu AVANT fix (L3) : FAIL (tunnel faux des le demarrage = brique latente).
# Attendu APRES fix (L3) : PASS (session nait tunnel=true, digest frais, zero unlock manuel).

$ErrorActionPreference = 'SilentlyContinue'
$canon = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$fail = 0
function Check([string]$label, [bool]$ok) {
    if ($ok) { Write-Host ("[OK]   " + $label) } else { Write-Host ("[FAIL] " + $label); $script:fail++ }
}
function Invoke-Hook([string]$script, [string]$json) {
    $env:CURSOR_HOOK_TEST_INPUT = $json
    try { return ((& $script 2>&1) | Out-String).Trim() }
    finally { Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue }
}

$tmp = Join-Path $env:TEMP ("terrain-session-real-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
$tmpCursor = Join-Path $tmp '.cursor'
$tmpHooks = Join-Path $tmpCursor 'hooks'
$tmpRules = Join-Path $tmpCursor 'rules'
New-Item -ItemType Directory -Path $tmpHooks -Force | Out-Null
New-Item -ItemType Directory -Path $tmpRules -Force | Out-Null

try {
    # 1. Projet temoin isole = copie des hooks + config reels (vault reel, lecture seule)
    Copy-Item (Join-Path $canon '.cursor\hooks\*.ps1') $tmpHooks -Force
    Copy-Item (Join-Path $canon '.cursor\hooks.json') $tmpCursor -Force
    Copy-Item (Join-Path $canon '.cursor\memory.config.json') $tmpCursor -Force

    # 2. Lancer la VRAIE session-start.ps1 comme Cursor (cwd = projet temoin)
    Push-Location $tmp
    try {
        $sessionStart = Join-Path $tmpHooks 'session-start.ps1'
        $env:CURSOR_HOOK_TEST_INPUT = (@{ cwd = $tmp } | ConvertTo-Json -Compress)
        $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $sessionStart 2>&1
        Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
    } finally {
        Pop-Location
    }

    # 3. Verifier l'etat REEL, sans toucher aucun flag
    $gatesPath = Join-Path $tmpCursor 'agent-gates.json'
    Check "session-start a ecrit agent-gates.json" (Test-Path $gatesPath)
    $g = $null
    if (Test-Path $gatesPath) { $g = Get-Content $gatesPath -Raw | ConvertFrom-Json }

    Check "brain_ok=true apres session reelle" ($g -and $g.brain_ok -eq $true)

    # Digest frais (aujourd'hui)
    $digestFresh = $false
    if ($g -and $g.brain_digest_at) {
        try { $digestFresh = ([datetime]::Parse([string]$g.brain_digest_at).Date -eq (Get-Date).Date) } catch { }
    }
    Check "brain_digest_at frais (aujourd'hui) apres session reelle" $digestFresh

    # 00-brain-active.mdc regenere
    $brainActive = Join-Path $tmpRules '00-brain-active.mdc'
    Check "00-brain-active.mdc regenere par session reelle" (Test-Path $brainActive)

    # INVARIANT CENTRAL (le bug) : tunnel vrai des le demarrage, via la vraie logique Test-BrainTunnelOk
    . (Join-Path $tmpHooks '_hook-io.ps1')
    $tunnelReal = Test-BrainTunnelOk $tmp
    Check "brain_tunnel_ok=true des le demarrage (zero unlock manuel)" $tunnelReal

    # Detail diagnostic : read_timestamps >= session_started pour chaque flag tunnel
    $freshReads = $true
    if ($g -and $g.session_started -and $g.read_timestamps) {
        try {
            $sessionAt = [datetime]::Parse([string]$g.session_started)
            foreach ($flag in (Get-BrainTunnelFlagNames $tmp)) {
                $ts = $null
                if ($g.read_timestamps.PSObject.Properties[$flag]) { $ts = $g.read_timestamps.$flag }
                if (-not $ts) { $freshReads = $false; break }
                if ([datetime]::Parse([string]$ts) -lt $sessionAt) { $freshReads = $false; break }
            }
        } catch { $freshReads = $false }
    } else { $freshReads = $false }
    Check "read_timestamps >= session_started (flags estampilles a la session)" $freshReads

    # --- L1 : injection cerveau per-turn (postToolUse) ---
    $inject = Join-Path $tmpHooks 'inject-brain-turn.ps1'
    $injIn = (@{ tool_name = 'Read'; cwd = $tmp } | ConvertTo-Json -Compress)
    $inj1 = Invoke-Hook $inject $injIn
    Check "inject-brain-turn: additional_context au 1er outil du tour" ($inj1 -match 'additional_context' -and $inj1 -match 'RAPPEL CERVEAU')
    $inj2 = Invoke-Hook $inject $injIn
    Check "inject-brain-turn: silence au 2e outil (anti-spam 1x/tour)" ([string]::IsNullOrWhiteSpace($inj2))
    # Simuler fin de tour : clear via stop helper
    . (Join-Path $tmpHooks '_hook-io.ps1')
    Clear-BrainInjectedThisTurn $tmp
    $inj3 = Invoke-Hook $inject $injIn
    Check "inject-brain-turn: re-injecte au tour suivant (apres clear stop)" ($inj3 -match 'RAPPEL CERVEAU')

    # Le tunnel reste vrai apres injections (ne re-brique pas)
    Check "brain_tunnel_ok reste vrai apres injections per-turn" (Test-BrainTunnelOk $tmp)
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ("RESULT: {0}" -f $(if ($fail -eq 0) { 'PASS' } else { "FAIL ($fail)" }))
exit $fail
