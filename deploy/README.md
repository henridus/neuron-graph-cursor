# Deploy pack — Atlas Hermes + cerveau

Prepare la stack **locale** puis **Oracle**. Meme vault OneDrive AgentMemory, meme librarian-mcp (MIT), Hermes client MCP natif.

## Refs cerveau

- Vault : `C:\Users\henri\OneDrive\Obsidian\AgentMemory`
- Gabarit : <https://github.com/henridus/neuron-graph-cursor>
- Spec : `specs/002-hermes-oracle/`
- OpenLoop (profondeur verify, fleet) : voir vault `erreurs/openloop-pas-hook-maison` + `CONTRAT_PROFONDEUR` — **N:** reinventer un hook maison

## Ordre

| Etape | Ou | Artefact |
|-------|-----|----------|
| 1 Docs | repo | `.env.example`, `docs/secrets-setup.md`, `RUNBOOK.md` |
| 2 Templates | ce dossier | `hermes/env.example`, `hermes/config.yaml.example` |
| 3 Local WSL | machine Henri | install Hermes + FreeLLM + librarian → AgentMemory |
| 4 Pack Oracle | `oracle/` | scripts + checklists (sans VM encore) |
| 5 Apply Oracle | VM | quand IP SSH dispo ; test **PC eteint** |

## Contraintes

- **N:** tunnel MCP vers le PC Windows
- **A:** FreeLLMAPI 24/7 sur Oracle (ou URL distante)
- **A:** librarian process **local** sur la machine Hermes
- Preuves = `hermes doctor` / `hermes chat` / lecture neurone — pas `SIMULATE_*`

## Contenu

```text
deploy/
  README.md
  hermes/
    env.example
    config.yaml.example
  oracle/
    01-harden.sh
    02-install-hermes.sh
    03-sync-vault.md
    04-librarian-arm64.md
    05-checklist.md
```
