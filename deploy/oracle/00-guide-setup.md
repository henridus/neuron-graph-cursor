# Guide pas a pas — Oracle Cloud + MCP OCI + Hermes

Ne jamais coller de cles / tokens dans le chat Cursor.

## Phase A — Compte Oracle Free Tier

1. Ouvre : https://www.oracle.com/cloud/free/
2. Clique **Start for free** / **Essayer gratuitement**.
3. Choisis une **Home Region** EU (ex. France Central / Frankfurt) — **definitif**, choisis bien.
4. Valide email + carte (verification, pas forcement facturation si tu restes Free Tier).
5. Arrive dans la console : https://cloud.oracle.com/

**Stop** : dis a l'agent « A OK » quand le dashboard s'affiche.

## Phase B — Cle API OCI (pour MCP Cursor)

Doc officielle config SDK/CLI : https://docs.oracle.com/en-us/iaas/Content/API/Concepts/sdkconfig.htm

1. Console → icone profil (haut droite) → **User settings** (ou Identity → Users → ton user).
2. **API Keys** → **Add API Key** → **Generate API Key Pair**.
3. **Download private key** (`.pem`) — garde-la hors Git, ex. `C:\Users\henri\.oci\oci_api_key.pem`.
4. Oracle affiche un bloc **Configuration File Preview** — copie les valeurs (tenancy, user, fingerprint, region).
5. Sur le PC, cree :
   - dossier `%USERPROFILE%\.oci\`
   - fichier `%USERPROFILE%\.oci\config` (modele ci-dessous, chemins a toi)

```ini
[DEFAULT]
user=<ton-user-ocid>
fingerprint=<fingerprint>
tenancy=<tenancy-ocid>
region=<ex-eu-paris-1>
key_file=C:\Users\henri\.oci\oci_api_key.pem
```

6. Installe OCI CLI (optionnel mais utile) : https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm  
   Test : `oci iam region list` (doit lister des regions sans erreur).

**Stop** : « B OK » (sans coller le contenu de config).

## Phase C — MCP Oracle dans Cursor

Repo officiel : https://github.com/oracle/mcp  
Package cloud : `oracle.oci-cloud-mcp-server` (via uvx).

1. Installe `uv` si besoin : https://docs.astral.sh/uv/getting-started/installation/
2. Edite `%USERPROFILE%\.cursor\mcp.json` — **ajoute** (ne supprime pas librarian) :

```json
"oci-cloud": {
  "command": "uvx",
  "args": ["oracle.oci-cloud-mcp-server"],
  "env": {
    "OCI_CONFIG_FILE": "C:\\Users\\henri\\.oci\\config",
    "OCI_CONFIG_PROFILE": "DEFAULT"
  }
}
```

3. Redemarre Cursor (ferme/ouvre la fenetre).
4. Verifie dans Settings → MCP que `oci-cloud` est vert / tools visibles.

**Stop** : « C OK ».

## Phase D — VM ARM Free Tier

1. Console : https://cloud.oracle.com/ → **Compute** → **Instances** → **Create instance**.
2. Name : `atlas-hermes`.
3. Image : **Canonical Ubuntu 22.04** (ARM / aarch64).
4. Shape : **VM.Standard.A1.Flex** — 4 OCPU, 24 GB (Always Free).
   - Si capacite insuffisante : reessaie autre AD / region, ou baisse temporairement OCPU.
5. Networking : VCN par defaut, **Assign public IPv4**.
6. SSH : colle ta cle publique (`%USERPROFILE%\.ssh\id_ed25519.pub` ou `id_rsa.pub`).
   - Pas de cle ? `ssh-keygen -t ed25519` dans PowerShell.
7. Create → note l'**IP publique**.
8. Security List / NSG du subnet : ingress **TCP 22** depuis ton IP (ou 0.0.0.0/0 en test, a restreindre ensuite). **Rien d'autre** public.

Test local :

```powershell
ssh ubuntu@<IP>
uname -m
# attendu : aarch64
```

**Stop** : « D OK » + IP (l'IP publique n'est pas un secret critique ; ne colle pas de cle privee).

## Phase E — Sur la VM (Hermes stack)

Depuis le repo (sur la VM apres clone) : voir `deploy/oracle/05-checklist.md`.

Resume :

```bash
# clone atlas
git clone <ton-repo> /home/ubuntu/atlas
cd /home/ubuntu/atlas
bash deploy/oracle/01-harden.sh
bash deploy/oracle/02-install-hermes.sh
# puis FreeLLM sur VM, sync vault, librarian, .env — docs 03/04 + deploy/hermes/
```

## Liens utiles

| Sujet | URL |
|-------|-----|
| Free Tier | https://www.oracle.com/cloud/free/ |
| Console | https://cloud.oracle.com/ |
| Config API OCI | https://docs.oracle.com/en-us/iaas/Content/API/Concepts/sdkconfig.htm |
| Install OCI CLI | https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm |
| Oracle MCP GitHub | https://github.com/oracle/mcp |
| uv | https://docs.astral.sh/uv/getting-started/installation/ |
| Gabarit cerveau | https://github.com/henridus/neuron-graph-cursor |
| Secrets Atlas | `docs/secrets-setup.md` |
