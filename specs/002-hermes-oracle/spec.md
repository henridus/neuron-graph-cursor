# Specification: Hermes on Oracle Cloud (Phase 1)

**Branch** : `002-hermes-oracle`  
**Date** : 2026-05-26  
**Status** : Draft  
**UserNeed** : "Lancer Atlas sur Oracle Cloud Free Tier ARM avec Hermes + Free LLM API + Telegram, allowlist stricte, cerveau AgentMemory via librarian MCP local (PC Windows eteint OK), et repondre 'hello' depuis mon mobile en moins de 10 s."

## Scope

**In scope** :

- Provision d'une instance Oracle Cloud Free Tier ARM (Ampere A1.Flex).
- Installation d'Hermes Agent sur la VM Ubuntu 22.04 arm64.
- Configuration du provider **Free LLM API** (OpenAI-compatible) — FreeLLMAPI sur la VM ou URL 24/7.
- Configuration de la gateway Telegram avec allowlist stricte.
- Sync vault OneDrive `AgentMemory` → VM + **librarian-mcp local** (MIT, meme outil que Cursor) branche sur Hermes MCP.
- Prep locale (WSL) documentee dans `deploy/` avant apply Oracle.
- Validation : message Telegram owner → reponse ; autonomie PC eteint ; traversee neurone via librarian.

**Out of scope** (Phase 2+) :

- Routage multi-contexte vers `20-pro-soc1/`, `21-pro-soc2/`, `30-familial/` (skill Obsidian + frontmatter).
- Provider Gemini / DeepSeek comme chemin nominal (restent optionnels).
- Cron, scheduler, automatisations recurrentes.
- MCP a effet de bord externe (hors librarian cerveau).
- Tunnel MCP vers le PC Windows.
- PostgreSQL / pgvector (Phase 8).

## User Stories

### US1 (P1) — Oracle ARM provisionne et accessible

- **Goal** : disposer d'une VM Linux arm64 stable, accessible en SSH par l'owner uniquement, prete a accueillir Hermes.
- **Independent test** : `ssh ubuntu@<ip>` reussit, `uname -m` retourne `aarch64`, `ufw status` montre uniquement le port SSH ouvert.
- **Acceptance** :
  1. Given un compte Oracle Cloud Free Tier, When je cree une instance VM.Standard.A1.Flex (4 OCPU, 24 GB) en Ubuntu 22.04, Then la VM est accessible en SSH par cle publique.
  2. Given la VM accessible, When je configure `ufw`, Then seul le port 22 (SSH) est ouvert publiquement.
  3. Given la VM accessible, When je lance `apt update && apt upgrade`, Then la VM est a jour sans erreur.

### US2 (P1) — Hermes + Free LLM API + cerveau librarian sur la VM

- **Goal** : Hermes parle a FreeLLM et traverse AgentMemory via librarian local (sans PC allume).
- **Independent test** : `hermes doctor` OK ; `hermes chat "ping"` OK ; demande traversee `MAP-openclaw` cite un neurone reel.
- **Acceptance** :
  1. Given la VM ARM, When install Hermes, Then `hermes doctor` vert.
  2. Given `OPENAI_API_KEY` + `OPENAI_BASE_URL` (FreeLLM sur VM ou URL 24/7), When `hermes setup` / `hermes model`, Then un modele FreeLLM est actif.
  3. Given vault sync + librarian arm64 + `config.yaml` MCP, When Hermes appelle librarian, Then voisins de `MAP-openclaw` visibles.
  4. Given Hermes configure, When `hermes chat "ping"`, Then reponse texte coherente.
  5. Given gateway active, When PC Windows eteint, Then Telegram + cerveau restent OK.

### US3 (P1) — Gateway Telegram avec allowlist stricte

- **Goal** : Atlas repond a un message Telegram envoye par l'owner depuis son mobile, et rejette tout autre utilisateur.
- **Independent test** : envoyer "hello" depuis le mobile de l'owner -> reponse Hermes recue ; envoyer depuis un autre compte test -> aucune reponse (rejet silencieux ou message poli).
- **Acceptance** :
  1. Given `TELEGRAM_BOT_TOKEN` et `TELEGRAM_ALLOWED_USERS=<owner_user_id>` dans `~/.hermes/.env`, When je lance `hermes gateway run` dans `tmux`, Then la gateway demarre sans erreur.
  2. Given la gateway active, When l'owner envoie "hello" depuis Telegram mobile, Then une reponse Hermes arrive en moins de 10 s.
  3. Given la gateway active, When un user_id non present dans l'allowlist envoie un message, Then le message est rejete et n'est pas relaye au Kernel.
  4. Given la gateway active, When je lis `~/.hermes/logs/`, Then aucun secret (cle API, token, user_id complet en clair) n'apparait en clair.

## Functional Requirements

- **FR-001** : la VM Oracle Cloud ARM doit etre sur `aarch64` Ubuntu 22.04 LTS minimum.
- **FR-002** : aucun port public en dehors de SSH (22) ne doit etre ouvert ; la gateway Hermes parle a Telegram en sortie uniquement.
- **FR-003** : Hermes Phase 1 utilise Free LLM API (OpenAI-compatible) comme provider nominal ; FreeLLMAPI accessible 24/7 sans PC Windows.
- **FR-004** : la gateway Telegram doit imposer une allowlist stricte (`TELEGRAM_ALLOWED_USERS`), jamais `GATEWAY_ALLOW_ALL_USERS=true`.
- **FR-005** : shell/browser a effet de bord desactives en Phase 1 ; **MCP librarian cerveau autorise** (local VM uniquement).
- **FR-006** : la persistance de la gateway doit etre assuree via `tmux` (ou `systemd --user`) pour resister a une fermeture de session SSH.
- **FR-007** : les secrets doivent etre stockes dans `~/.hermes/.env` avec permissions `chmod 600`, jamais commit dans Git.
- **FR-008** : repo Atlas clone en `/home/ubuntu/atlas` ; vault cerveau sync en `/home/ubuntu/AgentMemory` (OneDrive via rclone).
- **FR-009** : un user_id non-allowlist ne doit jamais voir son message remonter jusqu'au Kernel (rejet au niveau gateway).
- **FR-010** : aucun tunnel MCP vers le PC Windows ; librarian = process local Oracle.

## Edge Cases

- **Install Hermes echoue sur arm64** (binaire manquant, dependance Python manquante, etc.) : documenter UNK-008, fallback temporaire VM x86 payante ou report Phase 1.
- **FreeLLM API timeout / 5xx** : Hermes doit retourner une erreur claire a l'utilisateur sans crash. Politique retry par defaut Hermes.
- **Token Telegram revoque ou invalide** : la gateway doit refuser de demarrer avec un message d'erreur explicite.
- **Reseau Oracle bloquant** : verifier les regles de Security List Oracle (egress libre, ingress SSH only).
- **Session SSH fermee** : la gateway dans `tmux` doit continuer a tourner.
- **Fichier `.env` perdu** : la gateway doit refuser de demarrer plutot que tomber en mode degrade silencieux.
- **FreeLLM quota epuise** : message d'erreur clair, pas de hang.
- **Ecriture Hermes dans AgentMemory** : sync **bidirectionnel** via `rclone bisync` (choix owner 2026-07-14). Hermes ecrit des NOUVEAUX fichiers (`sessions/`, `erreurs/`) pour eviter les conflits ; `--conflict-resolve newer` arbitre le reste. Voir `deploy/oracle/03-sync-vault.md`.

## Success Criteria

- **SC-001** : `hermes doctor` est vert sur la VM ARM.
- **SC-002** : l'owner envoie "hello" depuis Telegram mobile et recoit une reponse en moins de 10 s.
- **SC-003** : un compte Telegram non-allowlist n'obtient aucune reponse (rejet effectif).
- **SC-004** : `grep -i "api_key\|token" ~/.hermes/logs/*` ne retourne aucun secret en clair.
- **SC-005** : la gateway survit a une deconnexion SSH (tmux persistant).
- **SC-006** : `specs/002-hermes-oracle/tasks.md` toutes taches cochees avec preuve.
- **SC-007** : aucune regle MDC violee (security non-negotiables, library-first, research-and-transparency).
