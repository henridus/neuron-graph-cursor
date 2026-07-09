param([string]$Payload = '{}')
$ErrorActionPreference = 'Stop'
function Resolve-VaultPath {
    param([string]$ConfiguredPath)
    foreach ($c in @($ConfiguredPath, (Join-Path $HOME 'OneDrive\Obsidian\AgentMemory'), (Join-Path $env:OneDrive 'Obsidian\AgentMemory'))) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $ConfiguredPath
}
function Get-DomainHint($PayloadObj) {
    $t = ($PayloadObj | ConvertTo-Json -Compress).ToLower()
    if ($t -match 'homelab|pi-hole|pihole|raspberry|\bpi\b|usbip') { return 'homelab' }
    if ($t -match 'moonlight|sunshine|xbox') { return 'moonlight' }
    if ($t -match 'gaming|pbo|corecycler|testmem|ryzen|ladder') { return 'gaming' }
    if ($t -match 'padel|matchpoint|booking') { return 'padel' }
    if ($t -match 'pricing|devis|forfait|quote') { return 'pricing' }
    if ($t -match 'trading|whisper|gamma|vwap|sierra') { return 'trading' }
    if ($t -match 'hook|enforcement|gate|cerveau|brain|mdc|rule') { return 'automation' }
    return 'general'
}
function Get-DomainMap([string]$Domain) {
    $known = 'automation','gaming','homelab','moonlight','padel','pricing','trading'
    if ($known -contains $Domain) { return "MAP-$Domain" }
    return '00_INDEX (choisir un MAP-<domaine>)'
}
function Truncate-BrainText([string]$Text, [int]$Max = 2200) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $t = $Text.Trim()
    if ($t.Length -le $Max) { return $t }
    return $t.Substring(0, $Max) + "`n...[tronque]"
}
function Read-BrainSection([string]$Vault, [string]$Rel, [int]$Max = 2200) {
    $full = Join-Path $Vault ($Rel -replace '/','\')
    if (-not (Test-Path $full)) { return '' }
  try { return Truncate-BrainText (Get-Content $full -Raw -Encoding UTF8) $Max } catch { return '' }
}
$payload = try { $Payload | ConvertFrom-Json } catch { @{} }
$projectRoot = Get-Location
$cfg = Get-Content (Join-Path $projectRoot '.cursor\memory.config.json') -Raw | ConvertFrom-Json
$vaultPath = Resolve-VaultPath $cfg.vaultPath
$agentId = $cfg.agentId
$agentNote = if ($cfg.agentNote) { $cfg.agentNote } else { "agents/$agentId.md" }
$domainHint = Get-DomainHint $payload
$entryMap = Get-DomainMap $domainHint
$tier0 = @"
## TRAVERSEE (Tier-0 - regle 49)
Cerveau = graphe Obsidian, moteur MCP 'librarian'. Ne pas lire en vrac : cheminer.
ENTREE domaine detecte ($domainHint) : library_traverse { start: "$entryMap", depth: 1 }
Outils: library_traverse(start,depth) | library_shortest_path(from,to) | library_search(query) | library_read(path) | library_write(path,content)
Etapes: MAP -> lire erreurs AVANT debug -> shortest_path vers lecon -> si absent: library-first + GitHub + find-skills -> resoudre -> closeout relie au MAP.
Regles: repo > vault si contradiction ; noms de notes uniques ; ne pas ecrire _backup/.
Sortie tache non triviale = TRACE: CHEMIN / ERREURS_LUES / CONTRADICTION_REPO_VAULT / SKILL.
"@
$sections = @()
$sections += "## INDEX`n" + (Read-BrainSection $vaultPath '00_INDEX.md' 1500)
$sections += "## PROFIL`n" + (Read-BrainSection $vaultPath 'users/henri-dusonchet.md' 800)
$sections += "## ERREURS`n" + (Read-BrainSection $vaultPath 'erreurs/INDEX.md' 1500)
$sections += "## AGENT`n" + (Read-BrainSection $vaultPath $agentNote 1000)
$sections += "## cursor-skills`n" + (Read-BrainSection $vaultPath 'domains/cursor-skills/INDEX.md' 800)
$handoff = Join-Path $vaultPath 'sessions\_HANDOFF.md'
if (Test-Path $handoff) {
    $hf = Get-Item $handoff
    if ($hf.Length -lt 50000) { $sections += "## HANDOFF`n" + (Read-BrainSection $vaultPath 'sessions/_HANDOFF.md' 1200) }
    else { $sections += '## HANDOFF`n(fichier volumineux - lire sessions/_HANDOFF.md)' }
}
$digest = ($sections | Where-Object { $_ -and $_.Trim().Length -gt 10 }) -join "`n`n---`n`n"
$digest = Truncate-BrainText $digest 4500
$rulePath = Join-Path $projectRoot '.cursor\rules\00-brain-active.mdc'
$ruleLines = @(
    '---','alwaysApply: true','description: "Brain V17 - traversee graphe + digest injecte sessionStart"','---','',
    "# Brain Active - $agentId",'',"Domaine detecte: $domainHint (entree: $entryMap)", '',
    $tier0, '',
    '## Regle V17','Cerveau-graphe (librarian-mcp). Entrer par un MAP, cheminer, tracer le chemin (regle 49).',
    'Hooks anti-brick: fail-open, pas de tunnel Read. Audit trace au stop.', '',
    "## Vault: $vaultPath", '', '## Digest (extrait)', $digest
)
[System.IO.File]::WriteAllText($rulePath, ($ruleLines -join "`n"), [Text.UTF8Encoding]::new($false))
$metaDir = Join-Path $projectRoot '.cursor\research'
if (-not (Test-Path $metaDir)) { New-Item -ItemType Directory -Path $metaDir -Force | Out-Null }
@{ agentId=$agentId; domain=$domainHint; entry_map=$entryMap; at=(Get-Date -Format o); digest_chars=$digest.Length; vault_ok=(Test-Path $vaultPath) } |
    ConvertTo-Json -Compress | Set-Content (Join-Path $metaDir 'brain-digest-meta.json') -Encoding UTF8
$ctx = "BRAIN V17 graphe agentId=$agentId domaine=$domainHint entree=$entryMap`n`n$tier0`n`n$digest"
@{ continue = $true; additional_context = $ctx; load_status = @{ vault_ok = (Test-Path $vaultPath); digest_injected = $true; entry_map = $entryMap } } | ConvertTo-Json -Compress -Depth 4 | Write-Output