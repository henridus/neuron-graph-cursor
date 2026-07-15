# postToolUse V21 - rappel cerveau PAR TOUR + refresh digest si stale.
# Seul point d'injection de contexte fiable par tour (doc Cursor : additional_context
# supporte uniquement par sessionStart et postToolUse). sessionStart ne se declenche
# qu'une fois par conversation -> sur sessions longues le digest fige. Ce hook :
#   1) rafraichit 00-brain-active.mdc (alwaysApply) si le digest est perime,
#   2) injecte un rappel actif court "traverse le cerveau avant de repondre",
# 1x par tour (reset au stop), non bloquant.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_hook-io.ps1')
try {
    $raw = Read-HookInput
    $root = (Get-Location).Path
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $in = $raw | ConvertFrom-Json; if ($in.cwd) { $root = $in.cwd } } catch { }
    }
    $root = Get-ProjectRoot $root
    if (-not (Test-BrainActive $root)) { exit 0 }

    # Anti-spam : 1x/tour (reset au stop) ; garde-fou temporel si le stop n'a pas fire
    $g = Read-Gates $root
    $already = $false
    if ($g -and $g.brain_injected_this_turn -eq $true) {
        $already = $true
        if ($g.brain_injected_at) {
            try { if (((Get-Date) - [datetime]::Parse([string]$g.brain_injected_at)).TotalSeconds -gt 600) { $already = $false } } catch { }
        }
    }
    if ($already) { exit 0 }

    # Refresh digest si stale -> 00-brain-active.mdc frais pour les tours suivants
    $refreshed = $false
    try { if (Test-BrainDigestStale $root 8) { $refreshed = Invoke-BrainDigestRefresh $root } } catch { }

    $entryMap = '00_INDEX (choisir un MAP-<domaine>)'
    $meta = Join-Path $root '.cursor\research\brain-digest-meta.json'
    if (Test-Path $meta) { try { $m = Get-Content $meta -Raw | ConvertFrom-Json; if ($m.entry_map) { $entryMap = [string]$m.entry_map } } catch { } }

    Write-Gates $root @{ brain_injected_this_turn = $true; brain_injected_at = (Get-Date -Format o) }

    $note = if ($refreshed) { ' (digest rafraichi car perime - re-lire MAP/erreurs)' } else { '' }
    $ctx = "RAPPEL CERVEAU (regle 49, ce tour$note): pour toute tache analytique/plan/debug/architecture/comparaison, traverser 'library_traverse' depuis $entryMap AVANT de repondre ou de chercher le web. Le digest de la regle 00-brain-active n'est PAS une traversee sur la question courante. Terminer une tache non triviale par la TRACE (CHEMIN / ERREURS_LUES / CONTRADICTION_REPO_VAULT / SKILL)."
    @{ additional_context = $ctx } | ConvertTo-Json -Compress | Write-Output
    exit 0
} catch { exit 0 }
