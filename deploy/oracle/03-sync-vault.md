# Sync vault AgentMemory (OneDrive) <-> Oracle (bidirectionnel)

## But

Hermes + librarian sur Oracle lisent **le meme cerveau** que Cursor, ET Hermes peut
**enrichir** le cerveau (nouvelles notes `sessions/` / `erreurs/`) sans dependre du PC allume.
Choix owner (2026-07-14) : ecriture bidirectionnelle des Phase 1.

## Methode : rclone bisync <-> OneDrive

1. Sur la VM :

```bash
sudo apt install -y rclone
rclone config          # remote name suggere : onedrive (type onedrive, suivre wizard)
```

2. Init bisync (une seule fois, --resync pose la baseline) :

```bash
mkdir -p /home/ubuntu/AgentMemory
rclone bisync onedrive:Obsidian/AgentMemory /home/ubuntu/AgentMemory \
  --resync --create-empty-src-dirs --conflict-resolve newer --verbose
ls /home/ubuntu/AgentMemory/00_INDEX.md
ls /home/ubuntu/AgentMemory/domains/openclaw/MAP-openclaw.md
```

3. Boucle reguliere (toutes les 15 min, deux sens) :

```bash
crontab -e
# */15 * * * * rclone bisync onedrive:Obsidian/AgentMemory /home/ubuntu/AgentMemory --conflict-resolve newer --quiet
```

## Regles ecriture (anti-conflit)

- **A:** Hermes ecrit des **nouveaux fichiers** (`sessions/YYYY-MM-DD-*.md`, `erreurs/*.md`) — convention fleet 1 note = 1 fichier -> pas de collision.
- **N:** editer en place une note existante depuis la VM en meme temps que le PC (risque conflit bisync).
- Conflit residuel : `--conflict-resolve newer` garde la version la plus recente ; bisync ecrit `*.conflict` si ambigu -> a arbitrer.
- **A:** `00_INDEX.md` + `MAP-openclaw.md` presents apres bisync = preuve.
- **N:** inventer un deuxieme vault parallele.

## Alternative (si rclone OneDrive bloque)

Repo Git prive miroir du vault : `git pull` (lecture) + commits Hermes pousses (ecriture).
Documenter l'URL ici quand choisi.
