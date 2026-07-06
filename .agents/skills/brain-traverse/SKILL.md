---
name: brain-traverse
description: Traverser le cerveau-graphe Obsidian partage (librarian-mcp) pour resoudre une tache - entrer par un MAP de domaine, cheminer de neurone en neurone (erreurs, sessions, capsules), relier le probleme a une lecon existante A->B, et tracer le chemin. Utiliser des qu une tache technique non triviale demande la memoire commune, avant de coder ou de partir chercher dehors.
---

# Brain Traverse

Le cerveau = vault Obsidian `C:\Users\henri\OneDrive\Obsidian\AgentMemory`, expose comme graphe par le serveur MCP `librarian`. On ne lit pas en vrac : on **chemine**.

## Quand l utiliser

- Tache technique non triviale (debug, feature, refactor multi-fichiers).
- Avant de coder du neuf ou de chercher sur GitHub : d abord voir ce que le graphe sait deja.

## Carte des neurones

| Type | Nom (unique) | Role |
|------|--------------|------|
| Racine | `00_INDEX` | Hub, liste les MAP |
| Domaine | `MAP-<domaine>` | Point d entree de traversee |
| Erreur | `erreurs/<nom>` (brut `[[<nom>]]`) | Lecon a lire avant debug |
| Session | `sessions/YYYY-MM-DD-<sujet>` | Decision/cloture datee |
| Capsule | ex `STAR_CITIZEN_USBIP`, `QUOTE_PROTOCOL` | Detail domaine |
| Registre | `00_REGISTRY` | Agents |

Domaines : automation, gaming, homelab, moonlight, padel, pricing, trading.

## Procedure

1. **Classer** le domaine. Entrer : `library_traverse { start: "MAP-<domaine>", depth: 1 }`.
   - Domaine inconnu : `library_search { query: "<mots>" }` -> rejoindre le MAP le plus proche.
2. **Lire les erreurs** listees par le MAP (neurones `erreurs/*`) : `library_read { path: "erreurs/<nom>.md" }`.
3. **Etendre** si besoin : `library_traverse { start: "<neurone>", depth: 2 }` ; suivre les synapses inter-domaines (MAP<->MAP).
4. **Relier A->B** : `library_shortest_path { from: "<probleme/MAP>", to: "<lecon candidate>" }`. Un chemin court = lecon reutilisable.
5. **Contradiction** : si le code du repo contredit une note, le **repo gagne** ; corriger la note au closeout.
6. **Manque dans le graphe** : library-first (regle 43), puis doc officielle / GitHub ; skill via `find-skills` (regle 46, catalogue `domains/cursor-skills`).
7. **Closeout** : ecrire la lecon avec `library_write` (auto-wikilinks) ou selon regle 44, en la reliant au `MAP-<domaine>` par un lien brut.

## Conventions librarian (regle d or)

- Noms de base **uniques** dans tout le vault (sinon les notes fusionnent en 1 noeud).
- Liens vers notes uniques : nom brut `[[nom]]` (sans chemin ni extension).
- Ne jamais ecrire sous `_backup/` (exclu via `.librarianignore`).

## Piege noms -> chemins

`traverse`/`shortest_path` renvoient des noms **bruts** (`padel`). Mais `library_read` exige le **chemin complet + .md** :
- erreur `padel` -> `library_read path="erreurs/padel.md"`
- session `2026-06-29-trading-charter` -> `sessions/2026-06-29-trading-charter.md`
- `MAP-padel` -> `domains/padel/MAP-padel.md`

`library_read path="padel"` ou `"padel.md"` ECHOUE. Commencer traverse a depth 1 sur le MAP ; depth 2 sur un MAP tire tout le cluster voisin (bruit).

## Trace de sortie (obligatoire)

```
CHEMIN: MAP-<domaine> -> <neurone> -> ... -> solution
ERREURS_LUES: [[...]]
CONTRADICTION_REPO_VAULT: oui/non (+ correction)
SKILL: competence_deja_disponible | skill_a_importer | skill_a_adapter | nouvelle_solution_justifiee
```

## Note d exploitation

Les outils `library_*` ne sont disponibles qu apres chargement du serveur MCP par Cursor (reload). En maintenance/CI, on peut interroger le moteur via `tests/hooks/probe-librarian-call.mjs <outil> '<jsonArgs>'`.
