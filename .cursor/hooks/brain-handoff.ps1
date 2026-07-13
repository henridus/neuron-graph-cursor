$ErrorActionPreference = 'SilentlyContinue'
$hookPipeline = ''
if ($input) {
    $parts = @($input | ForEach-Object { [string]$_ })
    if ($parts.Count -gt 0) { $hookPipeline = ($parts -join "`n").Trim() }
}
. (Join-Path $PSScriptRoot '_hook-io.ps1')
$inputRaw = if (-not [string]::IsNullOrWhiteSpace($hookPipeline)) { Select-HookJsonPayload $hookPipeline } else { Read-HookInput }
if ([string]::IsNullOrWhiteSpace($inputRaw)) { exit 0 }

try { $payload = $inputRaw | ConvertFrom-Json } catch { exit 0 }

$projectRoot = Get-Location
$configPath = Join-Path $projectRoot '.cursor\memory.config.json'
if (-not (Test-Path $configPath)) { exit 0 }

$cfg = Get-Content $configPath -Raw | ConvertFrom-Json
$vault = $cfg.vaultPath
if (-not (Test-Path $vault)) { exit 0 }

$agentId = $cfg.agentId
$agentNote = if ($cfg.agentNote) { $cfg.agentNote } else { "agents/$agentId.md" }
$date = Get-Date -Format 'yyyy-MM-dd'
$json = $inputRaw.ToLower()
$multiFile = $false
if ($json -match 'write|strreplace|editnotebook') { $multiFile = $true }
if ($payload.tool_calls -and $payload.tool_calls.Count -gt 1) { $multiFile = $true }
if ($payload.edits -and $payload.edits.Count -gt 1) { $multiFile = $true }
# V05 (spec 056): documenter aussi les tours analytiques (traversee cerveau sans multi-Write)
$librarianTurn = $false
try {
    $gatesPath = Join-Path $projectRoot '.cursor\agent-gates.json'
    if (Test-Path $gatesPath) {
        $gg = Get-Content $gatesPath -Raw | ConvertFrom-Json
        if ($gg.librarian_used -eq $true) { $librarianTurn = $true }
        elseif ($gg.librarian_calls -and [int]$gg.librarian_calls -gt 0) { $librarianTurn = $true }
    }
} catch { }
if (-not $multiFile -and -not $librarianTurn) { exit 0 }

$domain = 'general'
if ($json -match 'homelab|raspberry|flash|pihole|usbip|tailscale') { $domain = 'homelab' }
elseif ($json -match 'moonlight|sunshine|xbox|portable|streaming') { $domain = 'moonlight' }
elseif ($json -match 'gaming|pbo|corecycler|testmem|ryzen|ladder') { $domain = 'gaming' }
elseif ($json -match 'padel|matchpoint|booking') { $domain = 'padel' }
elseif ($json -match 'pricing|prix|devis|forfait|quote') { $domain = 'pricing' }
elseif ($json -match 'trading|whisper|gamma|vwap|sierra') { $domain = 'trading' }
elseif ($json -match 'automation|hook|enforcement|gate|cerveau|brain|mdc') { $domain = 'automation' }

$topic = if ($domain -eq 'general') { 'session' } else { $domain }
$knownDomains = @('automation','gaming','homelab','moonlight','padel','pricing','trading')
$mapLink = if ($knownDomains -contains $domain) { "[[MAP-$domain]]" } else { '[[00_INDEX]]' }
$sessionDir = Join-Path $vault 'sessions'
New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null
$sessionPath = Join-Path $sessionDir ("{0}-{1}.md" -f $date, $topic)
$handoffPath = Join-Path $sessionDir '_HANDOFF.md'

$tools = @()
if ($payload.tool_calls) {
    foreach ($call in $payload.tool_calls) {
        if ($call.recipient_name) { $tools += $call.recipient_name }
    }
}
$tools = $tools | Select-Object -Unique

$yaml = @(
    '---',
    'type: session',
    "agentId: $agentId",
    "domaine: $domain",
    "date: $date",
    'status: draft',
    'blocage: none',
    'tags:',
    '  - multi-fichiers',
    '---'
) -join "`n"

$sessionBody = @(
    $yaml,
    '',
    "# Session $date - $topic",
    '',
    "- agentId: $agentId",
    "- domaine: $domain",
    "- note agent: $agentNote",
    '',
    '## Resume',
    '- Session multi-fichiers detectee par hook stop.',
    '- L agent doit continuer automatiquement la prochaine phase tant qu aucun blocage reel ne l empeche.',
    '',
    '## Phases',
    '- Phase terminee : a completer',
    '- Prochaine phase : a lancer automatiquement si possible',
    '- Blocage reel : none / a completer',
    '',
    '## Preuves',
    '- Commandes verification : a completer',
    '- Resultats factuels : a completer',
    '',
    '## Outils utilises',
    $(if ($tools.Count -gt 0) { ($tools | ForEach-Object { "- $_" }) } else { '- (aucun detail)' }),
    '',
    '## Neurones lies',
    "- Domaine : $mapLink",
    '- Erreurs : `erreurs/INDEX.md`',
    '- Remonter : [[00_INDEX]]',
    ''
) -join "`n"

[System.IO.File]::WriteAllText($sessionPath, $sessionBody, [System.Text.UTF8Encoding]::new($false))

$handoffYaml = @(
    '---',
    'type: handoff',
    "agentId: $agentId",
    "domaine: $domain",
    "date: $date",
    'status: actif',
    'blocage: none',
    '---'
) -join "`n"

$handoffBody = @(
    $handoffYaml,
    '',
    '# HANDOFF - derniere session agent',
    "agentId: $agentId",
    "date: $date",
    "domaine: $domain",
    '',
    '## Fait',
    '- Session multi-fichiers executee ; voir note session datee.',
    '',
    '## Prochaine phase',
    '- Continuer automatiquement sauf blocage reel.',
    '',
    '## Blocages',
    '- Aucun par defaut ; documenter seulement un vrai blocage.',
    '',
    '## Rapport final',
    '- Ne conclure qu apres verification et perimetre termine.',
    '',
    '## Refs',
    "- sessions/$(Split-Path $sessionPath -Leaf)",
    "- $agentNote"
) -join "`n"

[System.IO.File]::WriteAllText($handoffPath, $handoffBody, [System.Text.UTF8Encoding]::new($false))

$syncScript = Join-Path $projectRoot '.cursor\hooks\sync-obsidian-to-souvenir.ps1'
if (Test-Path $syncScript) {
    powershell -NoProfile -ExecutionPolicy Bypass -File $syncScript | Out-Null
}