# BUILD_CURSOR_BRAIN_GRAPH_TEMPLATE.ps1 — extrait template open-source anonymise
param(
    [string]$CanonRoot = 'C:\Users\henri\OneDrive\27_IA\00_Cursor\003_Agent V01 - Expert en code - V01',
    [string]$OutRoot = 'C:\Users\henri\OneDrive\27_IA\00_Cursor\cursor-brain-graph'
)
$ErrorActionPreference = 'Stop'

$hasGit = Test-Path (Join-Path $OutRoot '.git')
if (Test-Path $OutRoot) {
    if ($hasGit) {
        # Preserve .git — sync into existing clone (republication V20+)
        Get-ChildItem $OutRoot -Force | Where-Object { $_.Name -ne '.git' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Remove-Item $OutRoot -Recurse -Force
        New-Item -ItemType Directory -Path $OutRoot -Force | Out-Null
    }
} else {
    New-Item -ItemType Directory -Path $OutRoot -Force | Out-Null
}

function Copy-Rel([string]$rel) {
    $from = Join-Path $CanonRoot $rel
    if (-not (Test-Path $from)) { Write-Host "SKIP $rel"; return }
    $to = Join-Path $OutRoot $rel
    $parent = Split-Path $to -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item $from $to -Force
    Write-Host "COPY $rel"
}

# Hooks (path-free runtime)
Get-ChildItem (Join-Path $CanonRoot '.cursor\hooks') -Filter '*.ps1' | ForEach-Object {
    Copy-Rel (Join-Path '.cursor\hooks' $_.Name)
}
Copy-Rel '.cursor\hooks.json'

# Rules socle
@(
    '11-enforcement-gates.mdc',
    '40-spec-driven-workflow.mdc',
    '42-autonomous-execution-loop.mdc',
    '43-library-first.mdc',
    '44-memory-obsidian.mdc',
    '45-token-compression.mdc',
    '46-skills-first-tunnel.mdc',
    '47-brain-first-audit.mdc',
    '49-brain-traversal.mdc'
) | ForEach-Object { Copy-Rel (Join-Path '.cursor\rules' $_) }

Copy-Rel '.agents\skills\brain-traverse\SKILL.md'
Copy-Rel 'tests\hooks\RUN_HOOK_TESTS.ps1'
Copy-Rel 'tests\hooks\SIMULATE_LIBRARIAN_TERRAIN.ps1'
Copy-Rel 'tests\hooks\RUN_TERRAIN_BRAIN_V17.ps1'
Copy-Rel 'tests\hooks\RUN_TERRAIN_BRAIN_V18.ps1'
Copy-Rel 'tests\hooks\RUN_TERRAIN_BRAIN_V20.ps1'
Copy-Rel 'tests\hooks\test-skill-gate.ps1'
Copy-Rel 'template\README.md'
Copy-Rel 'template\LICENSE'
Copy-Rel 'template\.gitignore'

# Example config (no personal paths)
@'
{
    "brainMode": "central",
    "vaultPath": "{{VAULT_PATH}}",
    "agentId": "{{AGENT_ID}}",
    "agentNote": "agents/{{AGENT_ID}}.md",
    "fallbackPath": "01_Souvenir",
    "requiredReads": [
        "00_INDEX.md",
        "erreurs/INDEX.md",
        "domains/cursor-skills/INDEX.md",
        "agents/{{AGENT_ID}}.md"
    ],
    "sessionNotePattern": "sessions/{date}-{topic}.md"
}
'@ | Set-Content (Join-Path $OutRoot '.cursor\memory.config.example.json') -Encoding UTF8

# Vault starter (minimal public structure)
$vs = Join-Path $OutRoot 'vault-starter'
New-Item -ItemType Directory -Path (Join-Path $vs 'domains\example') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $vs 'erreurs') -Force | Out-Null

@'
---
type: map
domaine: example
status: actif
---
# MAP Example

Neurone d entree domaine **example**. Cheminer via librarian avant action.

## Erreurs (lire avant debug)

- [[example-error]]

## Remonter

- [[00_INDEX]]
'@ | Set-Content (Join-Path $OutRoot 'vault-starter\domains\example\MAP-example.md') -Encoding UTF8

@'
---
type: erreur
domaine: example
status: actif
---
# Example error neuron

Lecon exemple : toujours traverser le MAP avant de coder.
'@ | Set-Content (Join-Path $OutRoot 'vault-starter\erreurs\example-error.md') -Encoding UTF8

@'
---
type: hub
status: actif
---
# AgentMemory Hub (starter)

Point d entree vault. Domaines : [[MAP-example]]
'@ | Set-Content (Join-Path $OutRoot 'vault-starter\00_INDEX.md') -Encoding UTF8

@'
# Obsidian vault example (not included — create your own)
*
!.gitignore
!README.md
!domains/
domains/**
!domains/example/
!domains/example/**
'@ | Set-Content (Join-Path $vs '.gitignore') -Encoding UTF8

Write-Host "TEMPLATE built: $OutRoot"
