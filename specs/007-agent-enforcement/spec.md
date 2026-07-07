# Agent Enforcement — Coque V11 (fleet)

**Domaine** : gouvernance agent  
**Statut** : actif juil. 2026  
**Canon** : 003-expert-code | **Fleet** : PROPAGATE V11 (22 agents)

## Probleme terrain juil. 2026

Test agent : StrReplace `spec.md` allow sans Read vault ni reflection — V10 clos prematurement.

## Correctifs V11

| ID | Fuite | Correctif |
|----|-------|-----------|
| L21 | TypoCarveOut bypass spec | `Test-ProtectedWritePath` + ordre gate |
| L22 | brain-load dump | Pointeurs chemins uniquement |
| L23 | cross-workspace Write | `Test-WorkspaceWritePath` |
| L24 | lockout tests | trap + restore gates |
| L25 | cloture sans terrain | `terrain-test-*.json` obligatoire |
| L26 | doc desalignee | HOOKS/LEAK_MATRIX V11 |

## Architecture Write (3 couches)

1. **Reflexion** : spec.md, plan.md, docs/, AGENTS.md → reflection-proof
2. **Spec** : tasks.md, .mdc → brain_tunnel_ok
3. **Code** : reste → brain_tunnel_ok

StrReplace = Write. TypoCarveOut uniquement hors chemins proteges, apres tunnel OK.

## Definition of done

| # | Preuve |
|---|--------|
| 1 | RUN_HOOK_TESTS H1-H29 PASS |
| 2 | RUN_CALIBRATION_AGENT V11 PASS |
| 3 | Test terrain 6/6 + `record-terrain-test.ps1 -Score 6` |
| 4 | brain-load sans dump texte requiredReads |
| 5 | vault erreur RESOLU seulement apres #3 |

## Refs

- `02_Base/HOOKS_ENFORCEMENT.md`
- `reports/LEAK_MATRIX_V11.md`
- `docs/TERRAIN_TEST_PROTOCOL.md`
- Vault : `domains/automation/CONTRAT_PROFONDEUR.md`
