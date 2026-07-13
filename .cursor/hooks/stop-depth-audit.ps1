# stop V20 - audit post-action (non bloquant, fail-open)
# 1) confirme le cerveau (brain_ok/meta)
# 2) rafraichit digest si stale (sessions longues)
# 3) exige TRACE + L5 par-tour (librarian_used_this_turn)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_hook-io.ps1')
# Prefer env test harness / Read-HookInput — ne pas enumerer $input (peut bloquer stdin)
$inputRaw = Read-HookInput
if ([string]::IsNullOrWhiteSpace($inputRaw)) { exit 0 }
$projectRoot = (Get-Location).Path
$loopCount = 0
$status = 'completed'
$assistantText = ''
try {
    $payload = $inputRaw | ConvertFrom-Json
    if ($payload.loop_count -ne $null) { $loopCount = [int]$payload.loop_count }
    if ($payload.status) { $status = [string]$payload.status }
    if ($payload.cwd) { $projectRoot = $payload.cwd }
    foreach ($k in 'text','last_message','assistant_message','message','response') {
        if ($payload.PSObject.Properties[$k] -and -not [string]::IsNullOrWhiteSpace([string]$payload.$k)) { $assistantText = [string]$payload.$k; break }
    }
    if ([string]::IsNullOrWhiteSpace($assistantText) -and $payload.messages) {
        try { $assistantText = (@($payload.messages) | ForEach-Object { [string]$_.content }) -join "`n" } catch { }
    }
} catch { exit 0 }
if ($status -eq 'aborted') { exit 0 }
if ($loopCount -ge 2) {
    try { Clear-LibrarianUsedThisTurn $projectRoot } catch { }
    exit 0
}

$meta = Join-Path $projectRoot '.cursor\research\brain-digest-meta.json'
$gates = Join-Path $projectRoot '.cursor\agent-gates.json'
$reasons = @()
$staleReason = $null

# V20: digest stale sur session longue -> refresh + followup
try {
    if (Test-BrainDigestStale $projectRoot 12) {
        $ok = Invoke-BrainDigestRefresh $projectRoot
        if ($ok) {
            $staleReason = 'cerveau rafraichi (digest sessionStart perime) — re-lire MAP/erreurs avant de continuer'
        } else {
            $staleReason = 'digest cerveau perime mais refresh a echoue — relancer sessionStart'
        }
    }
} catch { }

if (-not (Test-Path $meta)) { $reasons += 'brain-digest-meta absent (sessionStart?)' }
if (Test-Path $gates) {
    try { $g = Get-Content $gates -Raw | ConvertFrom-Json; if ($g.brain_ok -ne $true) { $reasons += 'brain_ok false' } }
    catch { $reasons += 'agent-gates illisible' }
} else { $reasons += 'agent-gates absent' }

$traceReason = $null
$l5Reason = $null
if (-not [string]::IsNullOrWhiteSpace($assistantText)) {
    $len = $assistantText.Length
    $mentionsWork = ($assistantText -match '(?i)library_(traverse|shortest_path|read|write)|MAP-|erreurs/|sessions/')
    $nonTrivial = ($len -gt 600) -or $mentionsWork
    $hasTrace = ($assistantText -match '(?i)CHEMIN\s*:') -and ($assistantText -match '(?i)SKILL\s*:')
    if ($nonTrivial -and -not $hasTrace) { $traceReason = 'trace de chemin absente (attendu: CHEMIN / ERREURS_LUES / CONTRADICTION_REPO_VAULT / SKILL)' }

    # V20 — L5 par-tour : librarian_used_this_turn (pas le flag session)
    $analytique = ($len -gt 400) -or ($assistantText -match '(?i)vaut(-| )le coup|architecture|audit|compare|comparaison|meilleur|faut-il|devrait-on|est-ce que.*(mieux|utile|pertinent)|outil|solution|approche')
    $librarianThisTurn = $false
    try { $librarianThisTurn = Test-LibrarianUsedThisTurn $projectRoot } catch { }
    if ($analytique -and -not $librarianThisTurn -and -not $hasTrace) {
        $l5Reason = 'question analytique repondue sans traversee cerveau CE TOUR (librarian_used_this_turn=false)'
    }
}

# Reset flag tour pour le prochain stop
try { Clear-LibrarianUsedThisTurn $projectRoot } catch { }

if ($reasons.Count -eq 0 -and -not $traceReason -and -not $l5Reason -and -not $staleReason) { exit 0 }
$parts = @()
if ($staleReason) { $parts += $staleReason }
if ($reasons.Count -gt 0) { $parts += ('Cerveau: ' + ($reasons -join '; ')) }
if ($l5Reason) { $parts += $l5Reason }
if ($traceReason) { $parts += $traceReason }
$msg = 'Audit V20 (regle 49): ' + ($parts -join ' | ') + '. Entrer par un MAP, cheminer (library_traverse/shortest_path), croiser avec erreurs/ et terminer par la TRACE. Voir erreurs/agent-repond-sans-cerveau-chat.'
@{ followup_message = $msg } | ConvertTo-Json -Compress | Write-Output
exit 0
