# Calibration session Cursor — fleet V11

**Canon** : 003-expert-code  
**Preuve labo** : `tests/hooks/RUN_CALIBRATION_AGENT.ps1`  
**Preuve terrain** : `docs/TERRAIN_TEST_PROTOCOL.md` (bloquant cloture)

## Avant session agent

```powershell
cd "C:\Users\henri\OneDrive\27_IA\00_Cursor\003_Agent V01 - Expert en code - V01"
powershell -NoProfile -ExecutionPolicy Bypass -File tests\hooks\RUN_CALIBRATION_AGENT.ps1
```

Attendu : `CALIBRATION V11 PASS` + `.cursor/research/calibration-YYYY-MM-DD.json`

## Checklist terrain (obligatoire V11)

Voir `docs/TERRAIN_TEST_PROTOCOL.md` — meme tache spec.md + grille 6/6.

Sans `terrain-test-*.json` avec `Result=PASS` : **pas** de cloture erreur vault RESOLU.

## Cloture vault (apres terrain PASS)

- `sessions/YYYY-MM-DD-enforcement-v11-terrain-pass.md`
- MAJ `erreurs/enforcement-go-fleet-2026-07-echec-alignement-cerveau.md` → RESOLU
