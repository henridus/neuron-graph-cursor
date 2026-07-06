# cursor-brain-graph

Open-source template: **Obsidian vault as a traversable neuron graph** + **Cursor hooks** that inject context and measure brain usage without self-blocking agents.

## Architecture

```
Cursor Agent
  | sessionStart -> brain-load (digest + MAP entry)
  | preToolUse CallMcpTool -> track-librarian-pretool (librarian_calls++)
  v
librarian-mcp (MIT)  ----traverse/read---->  Obsidian vault (neurons + wikilinks)
```

- **Graph engine**: [librarian-mcp](https://github.com/ngmeyer/librarian-mcp) (MIT) — `library_traverse`, `library_read`, `library_shortest_path`
- **Neurons**: Markdown notes in an Obsidian vault, linked with `[[wikilinks]]`
- **Entry points**: `MAP-<domain>` notes per domain (see `vault-starter/`)
- **Hooks**: fail-open (`failClosed: false`), anti-brick by design

## Quickstart

### 1. Install librarian-mcp (global MCP)

Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "librarian": {
      "command": "C:\\path\\to\\librarian-mcp.exe",
      "args": ["--vault", "{{VAULT_PATH}}"]
    }
  }
}
```

### 2. Copy template into your Cursor project

```powershell
# From this repo root into your agent project:
Copy-Item -Recurse .cursor, .agents, tests your-project\
Copy-Item .cursor\memory.config.example.json your-project\.cursor\memory.config.json
# Edit vaultPath and agentId in memory.config.json
```

### 3. Bootstrap vault

Use `vault-starter/` as a minimal Obsidian vault or merge into your existing vault:
- `00_INDEX.md` hub
- `domains/example/MAP-example.md` domain entry
- `erreurs/example-error.md` error neuron

### 4. Enable hooks

Cursor Settings > Hooks — point to `.cursor/hooks.json` in your project.

### 5. Verify

```powershell
powershell -NoProfile -File tests\hooks\RUN_HOOK_TESTS.ps1
powershell -NoProfile -File tests\hooks\SIMULATE_LIBRARIAN_TERRAIN.ps1
```

## What is included

| Path | Role |
|------|------|
| `.cursor/hooks/` | sessionStart, gates, librarian tracking |
| `.cursor/rules/` | brain traversal contract (rule 49), memory, skills |
| `.agents/skills/brain-traverse/` | Agent skill for graph traversal |
| `tests/hooks/` | Hook tests (43 paliers) + librarian simulation |
| `vault-starter/` | Minimal vault structure (no personal data) |

## What is NOT included

- Personal vault content, profiles, trading PDFs, reports
- Fleet propagation scripts with hardcoded paths
- Domain-specific gates (e.g. trading research) — add via `agent-hooks-manifest.json` pattern

## License

This template layer: MIT.  
Graph engine [librarian-mcp](https://github.com/ngmeyer/librarian-mcp): MIT (separate project).

## Traversal contract (agent output)

After non-trivial tasks, agents should end with:

```
CHEMIN: MAP-<domaine> -> <neurone> -> ...
ERREURS_LUES: [[...]]
CONTRADICTION_REPO_VAULT: non
SKILL: competence_deja_disponible | ...
```
