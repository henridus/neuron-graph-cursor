# REBIND_AGENT.ps1 - relie un agent DUPLIQUE manuellement au cerveau-graphe partage.
# Usage (depuis le nouveau dossier, apres duplication + renommage):
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\REBIND_AGENT.ps1 -AgentId 020-mon-agent -Domaines padel,automation
# Si -AgentId omis: derive du nom de dossier.
param(
    [string]$AgentId = '',
    [string]$TargetPath = (Get-Location).Path,
    [string[]]$Domaines = @('automation')
)
$ErrorActionPreference = 'Stop'
$vault = 'C:\Users\henri\OneDrive\Obsidian\AgentMemory'

# Racine = dossier contenant .cursor
$root = $TargetPath
for ($i = 0; $i -lt 6; $i++) {
    if (Test-Path (Join-Path $root '.cursor\memory.config.json')) { break }
    $parent = Split-Path $root -Parent
    if (-not $parent -or $parent -eq $root) { break }
    $root = $parent
}
$cfgPath = Join-Path $root '.cursor\memory.config.json'
if (-not (Test-Path $cfgPath)) { throw "memory.config.json introuvable sous $TargetPath - lancer depuis le dossier de l'agent duplique." }

if ([string]::IsNullOrWhiteSpace($AgentId)) {
    $leaf = Split-Path $root -Leaf
    $AgentId = ($leaf.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
}
Write-Host ("=== REBIND {0} (root: {1}) ===" -f $AgentId, $root)

# 1) memory.config : id + vault partage + brain central
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$cfg.agentId = $AgentId
$cfg.agentNote = "agents/$AgentId.md"
$cfg.vaultPath = $vault
$cfg.brainMode = 'central'
$cfg | ConvertTo-Json -Depth 8 | Set-Content $cfgPath -Encoding UTF8
Write-Host "  memory.config: agentId=$AgentId, vault partage, brainMode=central"

# 2) Reset des gates de session (evite d'heriter d'un etat du gabarit)
$gates = Join-Path $root '.cursor\agent-gates.json'
if (Test-Path $gates) { Remove-Item $gates -Force -ErrorAction SilentlyContinue; Write-Host "  agent-gates.json reset" }

# 3) Note agent dans le vault + registre
$agentNote = Join-Path $vault "agents\$AgentId.md"
$domList = ($Domaines | ForEach-Object { "  - $_" }) -join "`n"
$mapLinks = ($Domaines | ForEach-Object { "[[MAP-$_]]" }) -join ' '
$noteBody = @"
---
agentId: $AgentId
type: agent
status: actif
domaines:
$domList
---
# Agent $AgentId

Coquille rattachee au cerveau-graphe partage (librarian-mcp). Entrer par un MAP de domaine.

## Domaines
$mapLinks

## Remonter
- [[00_INDEX]] | [[00_REGISTRY]]
"@
New-Item -ItemType Directory -Path (Split-Path $agentNote -Parent) -Force | Out-Null
Set-Content -Path $agentNote -Value $noteBody -Encoding UTF8
Write-Host "  note vault: agents/$AgentId.md"
$registry = Join-Path $vault 'agents\00_REGISTRY.md'
if (Test-Path $registry) {
    if (-not (Select-String -Path $registry -Pattern ([regex]::Escape($AgentId)) -Quiet)) {
        Add-Content -Path $registry -Value ("- [[${AgentId}]] - domaines: " + ($Domaines -join ', ')) -Encoding UTF8
        Write-Host "  registre: entree ajoutee"
    } else { Write-Host "  registre: deja present" }
}

# 4) Verif presence des briques V17
$need = @('.cursor\rules\49-brain-traversal.mdc', '.cursor\hooks\gate-skill-install.ps1', '.cursor\hooks\brain-load.ps1', '.agents\skills\brain-traverse\SKILL.md')
$missing = $need | Where-Object { -not (Test-Path (Join-Path $root $_)) }
if ($missing.Count -gt 0) {
    Write-Host "  ATTENTION briques V17 absentes (relancer PROPAGATE ou dupliquer depuis un agent V17):" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host ("    - " + $_) }
} else { Write-Host "  briques V17: OK" }

Write-Host "DONE. Recharger la fenetre Cursor de cet agent pour declencher sessionStart."
