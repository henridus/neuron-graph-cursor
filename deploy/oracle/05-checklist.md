# Checklist apply Oracle (quand VM prete)

- [ ] SSH `ubuntu@<ip>` OK ; `uname -m` = `aarch64`
- [ ] `bash deploy/oracle/01-harden.sh` ; ufw = SSH only
- [ ] `bash deploy/oracle/02-install-hermes.sh` ; doctor vert
- [ ] FreeLLMAPI installe/demarre **sur la VM** (ou URL 24/7)
- [ ] `~/.hermes/.env` depuis `deploy/hermes/env.example` ; chmod 600
- [ ] Sync vault (`03-sync-vault.md`) ; `MAP-openclaw.md` present
- [ ] librarian arm64 (`04-librarian-arm64.md`) + `config.yaml`
- [ ] `hermes chat "ping"` OK
- [ ] `hermes chat` + traversee MAP-openclaw OK
- [ ] `tmux new -d -s hermes 'hermes gateway run'`
- [ ] Telegram "hello" < 10 s
- [ ] **PC Windows eteint** — retest Telegram + cerveau OK
- [ ] `grep` secrets dans logs = vide
