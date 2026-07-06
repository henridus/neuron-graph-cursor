# stop V17 - audit post-action (non bloquant, fail-open)
# 1) confirme le cerveau (brain_ok/meta)  2) exige une TRACE de chemin sur tache non triviale
$ErrorActionPreference = 'SilentlyContinue'
$hookPipeline = ''
if ($input) {
    $parts = @($input | ForEach-Object { [string]$_ })
    if ($parts.Count -gt 0) { $hookPipeline = ($parts -join "`n").Trim() }
}
. (Join-Path $PSScriptRoot '_hook-io.ps1')
$inputRaw = if (-not [string]::IsNullOrWhiteSpace($hookPipeline)) { Select-HookJsonPayload $hookPipeline } else { Read-HookInput }
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
if ($loopCount -ge 2) { exit 0 }

$meta = Join-Path $projectRoot '.cursor\research\brain-digest-meta.json'
$gates = Join-Path $projectRoot '.cursor\agent-gates.json'
$reasons = @()
if (-not (Test-Path $meta)) { $reasons += 'brain-digest-meta absent (sessionStart?)' }
if (Test-Path $gates) {
    try { $g = Get-Content $gates -Raw | ConvertFrom-Json; if ($g.brain_ok -ne $true) { $reasons += 'brain_ok false' } }
    catch { $reasons += 'agent-gates illisible' }
} else { $reasons += 'agent-gates absent' }

# Trace de chemin : seulement si le texte de reponse est disponible et la tache non triviale
$traceReason = $null
if (-not [string]::IsNullOrWhiteSpace($assistantText)) {
    $len = $assistantText.Length
    $mentionsWork = ($assistantText -match '(?i)library_(traverse|shortest_path|read|write)|MAP-|erreurs/|sessions/')
    $nonTrivial = ($len -gt 600) -or $mentionsWork
    $hasTrace = ($assistantText -match '(?i)CHEMIN\s*:') -and ($assistantText -match '(?i)SKILL\s*:')
    if ($nonTrivial -and -not $hasTrace) { $traceReason = 'trace de chemin absente (attendu: CHEMIN / ERREURS_LUES / CONTRADICTION_REPO_VAULT / SKILL)' }
}

if ($reasons.Count -eq 0 -and -not $traceReason) { exit 0 }
$parts = @()
if ($reasons.Count -gt 0) { $parts += ('Cerveau: ' + ($reasons -join '; ')) }
if ($traceReason) { $parts += $traceReason }
$msg = 'Audit V17 (regle 49): ' + ($parts -join ' | ') + '. Entrer par un MAP, cheminer (library_traverse/shortest_path) et terminer par la TRACE.'
@{ followup_message = $msg } | ConvertTo-Json -Compress | Write-Output
exit 0
