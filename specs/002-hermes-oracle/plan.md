# Implementation Plan: Hermes on Oracle Cloud (Phase 1)

**Branch** : `002-hermes-oracle`  
**Date** : 2026-05-26  
**Spec** : `specs/002-hermes-oracle/spec.md`

## Summary

Provisionner une VM Oracle Cloud Free Tier ARM Ampere, y installer Hermes Agent, configurer DeepSeek comme provider et la gateway Telegram avec allowlist stricte sur l'owner, afin que Atlas reponde aux messages Telegram depuis le mobile en moins de 10 secondes.

C'est la **premiere phase d'execution reelle** d'Atlas (Phase 0 etait le cadre documentaire). L'objectif est minimal : Telegram echo via Hermes + DeepSeek, securise, persistant.

## Technical Context

- **Hote** : Oracle Cloud Free Tier, instance VM.Standard.A1.Flex (4 OCPU, 24 GB RAM, ARM Ampere A1).
- **OS** : Ubuntu 22.04 LTS arm64.
- **Runtime** : Hermes Agent (install via script officiel `install.sh`).
- **Provider LLM** : DeepSeek (`deepseek-v4-flash` ou `deepseek-v4-pro` au choix au setup).
- **Canal** : Telegram (`hermes gateway`).
- **Stockage** : `~/.hermes/` (etat + FTS5) sur la VM ; `~/atlas/` pour le repo Git (cloned).
- **Secrets** : `~/.hermes/.env` chmod 600, jamais commit.
- **Tests** : tests manuels (echo Telegram, `hermes doctor`, rejet user non allowlist). Pas de tests automatises Phase 1.

## Constitution Check

- [x] Scope clair et testable (echo Telegram via DeepSeek, allowlist stricte).
- [x] Aucun chemin ou secret hardcode (tout via `~/.hermes/.env` et CLI Hermes).
- [x] Compatibilite avec phases futures (Phase 2 = vault Obsidian via `OBSIDIAN_VAULT_PATH`).
- [x] Contrats explicites (variables `.env`, format `TELEGRAM_ALLOWED_USERS`, modeles DeepSeek via `hermes model`).
- [x] Strategie de validation definie (US1/US2/US3 ont chacune un test independant).
- [x] Regle `library-first` respectee : Hermes upstream sans fork (voir ADR-002), provider DeepSeek natif, provider Gemini natif (Phase 3), skill Obsidian natif (Phase 2).
- [x] Regle `security-non-negotiables` respectee : pas de port public hors SSH, allowlist stricte, pas d'execution shell depuis input externe, pas d'outil a effet de bord en Phase 1.

## Impacted Files

| File | Change Type | Reason |
|------|-------------|--------|
| `RUNBOOK.md` | Update | Remplacer placeholder Oracle par procedure concrete |
| `.env.example` | Already created | Reference des variables (Phase 0) |
| `UNKNOWN_CHECKLIST.md` | Update | UNK-008 (Hermes arm64) a re-tester en Phase 1 etape B |
| `specs/002-hermes-oracle/spec.md` | New | Spec Phase 1 |
| `specs/002-hermes-oracle/plan.md` | New | Ce plan |
| `specs/002-hermes-oracle/tasks.md` | New | Taches executables |
| `docs/secrets-setup.md` | New | Guide creation cles (DeepSeek, BotFather, userinfobot) |
| `adrs/ADR-003-*.md` | Update (done) | Correction acces API Gemini |
| (Oracle) `~/.hermes/.env` | New (sur VM) | Secrets runtime, jamais commit |
| (Oracle) `~/.hermes/config.*` | New (sur VM) | Genere par `hermes setup` |
| (Oracle) `/home/ubuntu/atlas/` | Clone | Repo Atlas pour Phase 2 |

## Methodological Steps

> Note : ce sont les *etapes methodologiques* (comment on pense le travail).  
> L'execution concrete est numerotee dans `tasks.md` en `Phase 1..5`.

### Step Research

UNK encore ouvert qui peut bloquer : **UNK-008 (Hermes sur arm64)**. A re-tester via `hermes doctor` immediatement apres l'install.

Resolus en amont (voir `UNKNOWN_CHECKLIST.md`) :

- UNK-001 modeles DeepSeek (`deepseek-v4-pro` / `deepseek-v4-flash`),
- UNK-004 API Gemini independante de Google AI Pro (Phase 3),
- UNK-006 provider Gemini natif Hermes (Phase 3),
- UNK-009 format allowlist Telegram (`TELEGRAM_ALLOWED_USERS=<id>` dans `~/.hermes/.env`).

A verifier au moment du setup :

- Reponse de `GET /v1/models` DeepSeek pour confirmer le nom exact du modele.
- Existence du script `install.sh` upstream Hermes pour arm64.

### Step Design

- Architecture cible (voir `ARCHITECTURE.md`) :
  - **Channel Layer** = Telegram (via Hermes gateway).
  - **Hermes Gateway** = process `hermes gateway run` dans `tmux`, ecoute Telegram, applique l'allowlist.
  - **Hermes Agent Kernel** = invoque par la gateway, parle a DeepSeek.
  - **Model Plane** = DeepSeek via abstraction provider Hermes.
  - **Memory Plane** = uniquement memoire interne Hermes (FTS5) en Phase 1 ; vault Obsidian active Phase 2.
  - **Tool Plane** = aucun outil actif en Phase 1 (shell/MCP/browser desactives).
- Frontiere de securite :
  - Allowlist au niveau gateway, AVANT que le message atteigne le Kernel.
  - Aucun port public en dehors de SSH.
  - Secrets dans `~/.hermes/.env` chmod 600.
- Persistance :
  - `tmux new -s hermes 'hermes gateway run'` (option par defaut Phase 1).
  - Alternative : `systemd --user` (a evaluer Phase 6 si on veut un service vraiment durci).

### Step Implementation

Ordre execute :

1. **Documentation** (etape A du plan) :
   - Mettre a jour `RUNBOOK.md` (procedure Oracle concrete).
   - Creer `docs/secrets-setup.md` (DeepSeek, BotFather, userinfobot).
   - `.env.example` deja cree en Phase 0.
   - `UNKNOWN_CHECKLIST.md` : noter "UNK-008 a re-tester etape B".
2. **Owner cote utilisateur** (etape B) :
   - Creer compte Oracle Cloud Free Tier.
   - Creer instance VM.Standard.A1.Flex Ubuntu 22.04.
   - Creer cle SSH, configurer Security List (SSH 22 only).
   - Creer cle API DeepSeek sur `platform.deepseek.com`.
   - Creer bot Telegram via `@BotFather` (token).
   - Recuperer son user_id via `@userinfobot`.
3. **Install Hermes** (etape C) sur la VM :
   - `apt update && apt install -y curl git tmux ufw`.
   - `ufw allow ssh && ufw enable`.
   - `curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash`.
   - `hermes doctor` -> preuve UNK-008.
4. **Configuration** (etape C suite) :
   - `~/.hermes/.env` : `DEEPSEEK_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`. chmod 600.
   - `hermes setup` (provider DeepSeek).
   - `hermes model` (choisir `deepseek-v4-flash` par defaut, `deepseek-v4-pro` si raisonnement critique).
   - `hermes tools` : desactiver shell, MCP, browser.
   - `hermes gateway setup` (wizard Telegram).
5. **Repo Atlas** (etape D) :
   - `git clone <repo-prive> /home/ubuntu/atlas`.
   - (Phase 2 : pointer `OBSIDIAN_VAULT_PATH` ici).
6. **Lancement** (etape D suite) :
   - `tmux new -s hermes 'hermes gateway run'`.
7. **Validation** (etape E) :
   - Test echo : "hello" depuis mobile -> reponse.
   - Test rejet : message depuis compte non-allowlist -> aucune reponse.
   - `grep -i "api_key\|token" ~/.hermes/logs/*` -> aucun secret en clair.

### Step Validation

- Tests manuels listes dans `tasks.md` Phase 5.
- Lint des fichiers documentaires modifies (`ReadLints`).
- Non-regression Phase 0 : vault toujours 9 dossiers, regles MDC toujours 10, `.env.example` toujours sans valeur.
- Checkpoint : capture Telegram, sortie `hermes doctor`, `.env` anonymise, commandes exactes, prochaines etapes Phase 2.
