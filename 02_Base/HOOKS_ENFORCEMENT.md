# Enforcement hooks — fleet V14

## Capacites Cursor retenues

| Evenement | Usage V14 | Fiabilite |
|-----------|-----------|-----------|
| `preToolUse` Write/StrReplace | enforcement principal | haute |
| `beforeShellExecution` | garde-fou shell | moyenne |
| `beforeReadFile` / `postToolUse Read` | observabilite uniquement | faible |

## Modele Write (gate-write-unified)
1. boundary workspace obligatoire
2. surfaces gouvernance (`specs/**`, `docs/**`, `AGENTS.md`, `.cursor/rules/**`, `.cursor/hooks/**`, `tests/hooks/**`) -> **unlock externe requis**
3. observabilite (`.cursor/research/**`, certains `reports/`) -> writable mais **sans autorite**
4. reflexion (`spec.md`, `plan.md`, `docs/`, `AGENTS.md`) -> unlock externe + reflection-proof minimal
5. `StrReplace = Write`
6. stdin vide (bug Cursor) -> `allow_failopen` ; enforcement complet si payload JSON present

## Ce qui n'est plus autoritaire
- `read-proof.json`
- `reflection-proof.json`
- `terrain-test-*.json`
- `agent-gates.json`

Ces fichiers restent des **logs / traces**, jamais des preuves suffisantes pour debloquer seuls une action.

## Unlock externe
- chemin hors workspace agent : `%LOCALAPPDATA%\\CursorGovernanceUnlocks\\<agentId>-unlock.json`
- contient `root`, `expires_at`, `scope`
- scope limite aux cibles gouvernance voulues
- break-glass separe : `scripts/RECOVERY_UNLOCK_AGENT.ps1`

## Shell
- `preToolUse Shell` : retire
- `beforeShellExecution` : `gate-shell-triage.ps1`
- bootstrap permissif retire ; maintenance shell => unlock externe ou `ENFORCEMENT_MAINTENANCE=1`

## Lecture sensible
- protection prioritaire via `.cursorignore`
- hooks `Read` reserves a l'observabilite / telemetry, jamais comme pilier de securite

## Telemetry
- `.cursor/research/hook-telemetry-YYYY-MM-DD.jsonl`
- `scripts/ANALYZE_HOOK_TELEMETRY.ps1`

## Tests
- `RUN_HOOK_TESTS.ps1` (unitaires hooks)
- `RUN_ANTI_LOCKOUT.ps1`
- `RUN_TERRAIN_E2E_V13.ps1` a refondre vers V14 (simulation labo)
- terrain reel : `docs/TERRAIN_TEST_PROTOCOL.md`

## Propagation
`PROPAGATE_HOOKS_FLEET.ps1` — seulement apres terrain reel PASS
