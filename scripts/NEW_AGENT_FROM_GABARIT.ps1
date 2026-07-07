# NEW_AGENT_FROM_GABARIT.ps1 - cree un nouvel agent depuis le canon 003 (cerveau-graphe V17).
# Le moteur de traversee est un serveur MCP GLOBAL (~/.cursor/mcp.json) partage: rien a installer par agent.
param(
    [Parameter(Mandatory = $true)][string]$AgentId,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [string[]]$Domaines = @('automation'),
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$src = 'C:\Users\henri\OneDrive\27_IA\00_Cursor\003_Agent V01 - Expert en code - V01'
$vault = 'C:\Users\henri\OneDrive\Obsidian\AgentMemory'

$copyRel = @(
    '.cursor\hooks', '.cursor\rules', '.agents\skills\brain-traverse',
    'tests\hooks\RUN_TERRAIN_BRAIN_V17.ps1', 'tests\hooks\test-skill-gate.ps1',
    'tests\hooks\probe-librarian-call.mjs', 'scripts\RECOVERY_UNLOCK_AGENT.ps1',
    'scripts\REBIND_AGENT.ps1'
)

Write-Host ("=== NEW AGENT {0} -> {1} ({2}) ===" -f $AgentId, $TargetPath, $(if ($DryRun) { 'DRY-RUN' } else { 'LIVE' }))
if (-not (Test-Path $TargetPath)) {
    if ($DryRun) { Write-Host "  [dry] mkdir $TargetPath" } else { New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null }
}

foreach ($rel in $copyRel) {
    $from = Join-Path $src $rel
    if (-not (Test-Path $from)) { Write-Host "  SKIP (absent) $rel"; continue }
    $to = Join-Path $TargetPath $rel
    $parent = Split-Path $to -Parent
    if ($DryRun) { Write-Host "  [dry] copy $rel"; continue }
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item $from $to -Recurse -Force
}

# hooks.json canon
$hj = Join-Path $src '.cursor\hooks.json'
if (-not $DryRun) { Copy-Item $hj (Join-Path $TargetPath '.cursor\hooks.json') -Force }

# memory.config.json : nouvel agentId, vault partage
$memSrc = Join-Path $src '.cursor\memory.config.json'
$mem = Get-Content $memSrc -Raw | ConvertFrom-Json
$mem.agentId = $AgentId
$mem.agentNote = "agents/$AgentId.md"
$mem.vaultPath = $vault
$mem.brainMode = 'central'
if (-not $DryRun) {
    $mem | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $TargetPath '.cursor\memory.config.json') -Encoding UTF8
} else { Write-Host "  [dry] memory.config.json agentId=$AgentId vault partage" }

# Note agent dans le vault + registre
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
if (-not $DryRun) {
    New-Item -ItemType Directory -Path (Split-Path $agentNote -Parent) -Force | Out-Null
    Set-Content -Path $agentNote -Value $noteBody -Encoding UTF8
    $registry = Join-Path $vault 'agents\00_REGISTRY.md'
    if (Test-Path $registry) {
        $line = "- [[${AgentId}]] - domaines: $($Domaines -join ', ')"
        if (-not (Select-String -Path $registry -Pattern ([regex]::Escape($AgentId)) -Quiet)) {
            Add-Content -Path $registry -Value $line -Encoding UTF8
        }
    }
} else { Write-Host "  [dry] note vault agents/$AgentId.md + registre" }

Write-Host "DONE (verifier: verify-brain-link.ps1, RUN_TERRAIN_BRAIN_V17.ps1)"
