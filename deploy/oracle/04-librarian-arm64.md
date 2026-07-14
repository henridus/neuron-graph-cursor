# librarian-mcp linux-arm64 sur Oracle

## Source (verifiee 2026-07-14)

- Projet : <https://github.com/ngmeyer/librarian-mcp> (MIT)
- Release courante : **v0.1.2** — asset ARM64 Linux **confirme present**
- Meme outil qu'en Cursor (Windows `.exe`) — binaire Linux aarch64 sur la VM

## Install (recommande : installer officiel)

```bash
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/ngmeyer/librarian-mcp/releases/download/v0.1.2/librarian-mcp-installer.sh | sh
# place le binaire dans ~/.local/bin (ou similaire) ; verifier :
which librarian-mcp && librarian-mcp --help
```

## Install (alternatif : asset direct + checksum)

```bash
mkdir -p /home/ubuntu/bin && cd /tmp
curl -fsSL -o librarian.tar.xz \
  "https://github.com/ngmeyer/librarian-mcp/releases/download/v0.1.2/librarian-mcp-aarch64-unknown-linux-gnu.tar.xz"
# checksum attendu (sha256 de l'asset .tar.xz) :
echo "3a377ed323cd793164a6f5987358544bbee00b9b4a5b26919dafcefbb11ae6d1  librarian.tar.xz" | sha256sum -c -
tar -xJf librarian.tar.xz
install -m 755 librarian-mcp* /home/ubuntu/bin/librarian-mcp 2>/dev/null || \
  find . -name librarian-mcp -type f -exec install -m 755 {} /home/ubuntu/bin/librarian-mcp \;
/home/ubuntu/bin/librarian-mcp --help
```

## Brancher Hermes

```bash
cp /home/ubuntu/atlas/deploy/hermes/config.yaml.example ~/.hermes/config.yaml
# command: chemin reel du binaire (which librarian-mcp OU /home/ubuntu/bin/librarian-mcp)
# vault:   /home/ubuntu/AgentMemory  (adapter au flag reel : arg vault OU env LIBRARIAN_VAULT)
```

## Preuve

```bash
hermes chat "Utilise librarian : library_traverse start MAP-openclaw depth 1. Resume les voisins."
# Attendu : liste incluant agent-repond-sans-cerveau-chat ou 013-open-claw
```

**N:** tunnel vers le MCP du PC Windows.
