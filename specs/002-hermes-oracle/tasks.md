# Tasks: Hermes on Oracle Cloud (Phase 1)

**Input** : `specs/002-hermes-oracle/spec.md` + `plan.md`

> Note : les etapes methodologiques (Research/Design/Implementation/Validation) vivent dans `plan.md`.  
> Les phases ci-dessous sont les phases d'execution numerotees par user story.

## Format

`- [ ] T001 [P?] [USx] Description (path) -- proof: <cmd or check>`

- `[P]` : parallelisable
- `[USx]` : linked user story
- `proof` : commande, check, ou artefact (regle `42-autonomous-execution-loop`)

---

## Phase 1 - Documentation cote Cursor (avant action utilisateur)

- [x] T101 [US1] Re-ecrire `RUNBOOK.md` avec procedure Oracle concrete (instance ARM, SSH, ufw, install Hermes, tmux gateway, troubleshooting) -- proof: section "Oracle ARM" remplace le placeholder, etapes ordonnees A-G
- [x] T102 [US1] Creer `docs/secrets-setup.md` : guide pas a pas creation cles DeepSeek + BotFather + userinfobot -- proof: fichier present, 3 sections numerotees, anti-fuite documente
- [x] T103 [US3] Verifier `.env.example` racine (cree en Phase 0) contient bien `DEEPSEEK_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS` -- proof: lecture fichier OK
- [x] T104 [US1] Marquer UNK-008 (Hermes arm64) `a re-tester etape B Phase 1` dans `UNKNOWN_CHECKLIST.md` -- proof: section UNK-008 mise a jour + section "P1 — bloquants Phase 1"
- [x] T105 [US1] Verifier ADR-002 (Hermes upstream sans fork) et ADR-006 (Oracle ARM target) toujours coherents avec ce plan -- proof: relecture, OK ; ADR-003 corrige aussi (Google Pro vs API Gemini)
- [x] T106 [US1] Lint files modifies (ReadLints) -- proof: 0 erreur sur RUNBOOK.md, docs/secrets-setup.md, spec/plan/tasks 002, UNKNOWN_CHECKLIST, ADR-003

## Phase 1b - Prep locale FreeLLM + cerveau (2026-07-14)

- [x] T110 [US2] Aligner `.env.example` sur Free LLM API (`OPENAI_*`) + chemins AgentMemory/librarian -- proof: fichier present
- [x] T111 [US2] Reecrire `docs/secrets-setup.md` FreeLLM + contrainte PC-off -- proof: section FreeLLM + Telegram
- [x] T112 [US2] MAJ `RUNBOOK.md` prep WSL + etape D FreeLLM/librarian -- proof: section "Prep local"
- [x] T113 [US2] Pack `deploy/` (hermes templates + oracle scripts/checklists) -- proof: `deploy/README.md` + oracle/01-05
- [x] T114 [US2] MAJ `specs/002-hermes-oracle/spec.md` UserNeed/US2/FR FreeLLM + librarian local -- proof: FR-003/005/010
- [ ] T115 [US2] Hermes local WSL : `hermes doctor` + `hermes chat ping` via FreeLLM -- proof: sortie console (bloque si Hermes/FreeLLM absents)
- [ ] T116 [US2] Wire MCP librarian local → AgentMemory depuis Hermes -- proof: chat cite neurone MAP-openclaw

## Phase 1c - Infra provisionnement OCI (2026-07-14, plan propre)

- [x] T120 [US1] P0 freeze : inventaire read-only reseau OCI (pas de doublon) -- proof: `deploy/oracle/get_config.py` = VCN atlas-hermes-vcn AVAILABLE, subnet public, image Ubuntu 22.04 aarch64, INSTANCE=none
- [x] T121 [US1] P1 MCP oci-cloud repare (bug Windows /tmp/audit.log) -- proof: handshake stdio initialize + tools/list = 5 outils ; `mcp.json` TMP/TEMP=C:\tmp
- [x] T122 [US1] P2 catcher A1 poli (300s, backoff 429, stop non-transitoire) -- proof: `deploy/oracle/catch_a1.py` + log attempt 1 = 500 Out of host capacity -> sleep 300s
- [x] T123 [US2] P3 pack deploy valide + URL install Hermes verifiee vs doc Nous Research -- proof: `deploy/oracle/02-install-hermes.sh` + `05-checklist.md`
- [ ] T124 [US1] Catcher attrape la VM (async, capacite Zurich) -- proof: `CAUGHT` dans `deploy/oracle/catch_a1.log` + `ssh ... uname -m` = aarch64

## Phase 2 - US1 Provision Oracle (cote owner, guide par Cursor)

- [ ] T201 [US1] Creer compte Oracle Cloud Free Tier (si pas deja fait) -- proof: capture dashboard Oracle (anonymisee)
- [ ] T202 [US1] Provisioner instance `VM.Standard.A1.Flex` (4 OCPU, 24 GB) Ubuntu 22.04 arm64 -- proof: `uname -m` retourne `aarch64` apres SSH
- [ ] T203 [US1] Configurer cle SSH owner + Security List : ingress SSH 22 only -- proof: `ssh ubuntu@<ip>` reussit, scan port externe ne montre que 22
- [ ] T204 [US1] Sur la VM : `sudo apt update && sudo apt upgrade -y && sudo apt install -y curl git tmux ufw` -- proof: `tmux -V`, `git --version`, `curl --version` OK
- [ ] T205 [US1] Sur la VM : `sudo ufw allow ssh && sudo ufw enable` -- proof: `sudo ufw status` montre 22/tcp ALLOW, rien d'autre

## Phase 3 - US2 Hermes + DeepSeek sur la VM

- [ ] T301 [US2] Install Hermes via script officiel : `curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash` -- proof: sortie du script + `source ~/.bashrc`
- [ ] T302 [US2] `hermes doctor` -- proof: sortie console verte, **resoud UNK-008 si OK** (sinon documenter l'echec)
- [ ] T303 [US2] Owner cree cle DeepSeek sur <https://platform.deepseek.com/> -- proof: cle copiee dans gestionnaire de secrets local de l'owner (jamais envoyee a Cursor)
- [ ] T304 [US2] Owner cree fichier `~/.hermes/.env` sur la VM, chmod 600, contenant `DEEPSEEK_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS` -- proof: `ls -l ~/.hermes/.env` montre `-rw-------`
- [ ] T305 [US2] `hermes setup` -- proof: provider DeepSeek configure, output console
- [ ] T306 [US2] `hermes model` : choisir `deepseek-v4-flash` (default) ou `deepseek-v4-pro` selon preference -- proof: `hermes model --current` retourne le modele actif
- [ ] T307 [US2] `hermes tools` : desactiver shell, MCP, browser -- proof: `hermes tools --list` ne montre aucun outil a effet de bord actif
- [ ] T308 [US2] Test : `hermes chat "ping en 1 mot"` -- proof: reponse texte coherente

## Phase 4 - US3 Gateway Telegram securisee

- [ ] T401 [US3] Owner cree bot Telegram via `@BotFather` -- proof: token recupere par l'owner (jamais envoye a Cursor)
- [ ] T402 [US3] Owner recupere son user_id Telegram via `@userinfobot` -- proof: id numerique note par l'owner
- [ ] T403 [US3] Ajouter `TELEGRAM_BOT_TOKEN` et `TELEGRAM_ALLOWED_USERS=<owner_id>` dans `~/.hermes/.env` -- proof: `grep -c TELEGRAM_ ~/.hermes/.env` >= 2
- [ ] T404 [US3] Verifier que `GATEWAY_ALLOW_ALL_USERS` n'est PAS positionne -- proof: `grep GATEWAY_ALLOW_ALL_USERS ~/.hermes/.env` vide
- [ ] T405 [US3] `hermes gateway setup` (wizard Telegram) -- proof: sortie console
- [ ] T406 [US3] Lancer la gateway : `tmux new -d -s hermes 'hermes gateway run'` -- proof: `tmux ls` montre session `hermes`, logs sans erreur fatale dans `~/.hermes/logs/`
- [ ] T407 [US3] **Test echo** : owner envoie "hello" depuis Telegram mobile -- proof: reponse Hermes recue en moins de 10 s (capture ecran anonymisee dans le checkpoint)
- [ ] T408 [US3] **Test rejet** (optionnel) : depuis un compte Telegram tiers, envoyer un message au bot -- proof: aucune reponse, log gateway montre "user not allowed" ou equivalent
- [ ] T409 [US3] Verifier absence de secret en clair dans les logs : `grep -E "DEEPSEEK_API_KEY=|sk-|token=" ~/.hermes/logs/*.log` -- proof: aucun match
- [ ] T410 [US3] Cloner le repo Atlas : `git clone <repo-prive> /home/ubuntu/atlas` (Phase 2 utilisera ce path pour `OBSIDIAN_VAULT_PATH`) -- proof: `ls /home/ubuntu/atlas/README.md`

## Phase 5 - Final Validation et clotures

- [ ] T901 [P] Lint des fichiers documentaires modifies (ReadLints) -- proof: 0 erreur
- [ ] T902 Verifier non-regression Phase 0 : `.cursor/rules/` toujours 10 fichiers, `knowledge/vault/` toujours 9 dossiers -- proof: listing
- [ ] T903 Mettre a jour `UNKNOWN_CHECKLIST.md` : UNK-008 `resolved` ou documenter le contournement -- proof: section UNK-008 a jour
- [ ] T904 Cocher toutes les taches de ce fichier au fil de l'avancement -- proof: tasks.md a jour
- [ ] T905 Resume final au checkpoint Phase 1 : commandes exactes, modeles utilises, captures (anonymisees), modeles DeepSeek choisis, decision Phase 2 -- proof: message structure dans le checkpoint

---

## Statut consolide

- **Phase 1 (docs Cursor)** : **terminee** (T101-T106). Tous les artefacts de documentation pour la Phase 1 Oracle sont prets.
- **Phase 2 (provision Oracle, cote owner)** : **bloquee — action owner requise**. Cursor ne peut pas creer de compte Oracle ni configurer SSH a la place du proprietaire (regle `20-security-non-negotiables`).
- **Phase 3 (Hermes + DeepSeek)** : depend de Phase 2. Cle DeepSeek a creer par owner (T303).
- **Phase 4 (gateway Telegram)** : depend de Phase 3. Bot Telegram + user_id a creer par owner (T401-T402).
- **Phase 5 (validation)** : derniere ; sera executee par Cursor + owner ensemble une fois Phase 4 terminee.

## Prochaine action (owner)

Suivre dans l'ordre :

1. Lire `docs/secrets-setup.md` et creer les 3 cles (DeepSeek, BotFather, userinfobot). **Garder pour toi**, ne rien envoyer dans le chat.
2. Suivre `RUNBOOK.md` etapes A-B : creer le compte Oracle, provisionner la VM ARM, durcir le reseau (ufw).
3. Suivre `RUNBOOK.md` etapes C-G : installer Hermes, configurer DeepSeek, lancer la gateway Telegram, tester l'echo.
4. Revenir cocher les taches T201-T410 avec preuves.

Cursor peut t'accompagner sur chaque etape (commandes a coller, diagnostic d'erreur), mais ne peut pas executer ces commandes a ta place.

## Risques residuels acceptes Phase 1

| Risque | Mitigation |
|---|---|
| Install Hermes arm64 echoue | T302 `hermes doctor` immediat ; documenter UNK-008 ; fallback VM x86 payante ou report Phase 1 |
| Pas de secrets encore cote owner | Phase 3-4 bloquees jusqu'a creation DeepSeek + BotFather (T303, T401-T402) |
| Vault OneDrive + Oracle | Phase 2 : Git comme source de verite, pas de sync directe OneDrive sur serveur |
| Pas d'embeddings DeepSeek | OK jusqu'a Phase 8 ; FTS5 Hermes suffit (voir ADR-004) |
| Owner indisponible pour creer les comptes | Cursor peut continuer T101-T106 (docs) en autonome |
