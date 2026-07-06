# cursor-brain-graph

**Obsidian vault as a traversable neuron graph for Cursor AI agents.**

A template that makes Cursor agents navigate your Obsidian notes like a GPS — entering through domain maps, reading error neurons before acting, and measuring real brain usage with hook instrumentation. Designed to be **fail-open** (no self-blocking) while being **measurable** (every `library_*` call is counted).

---

## The idea in one diagram

```
Cursor Agent
  │
  ├─ sessionStart ──► brain-load.ps1
  │                     └─ detects domain (padel/trading/homelab/...)
  │                     └─ injects MAP entry point into context
  │                     └─ resets librarian_calls = 0
  │
  ├─ preToolUse (CallMcpTool) ──► track-librarian-pretool.ps1
  │                                 └─ librarian_calls++
  │
  └─ Agent calls librarian-mcp tools
       library_traverse(start="MAP-padel", depth=1)
       library_read(path="erreurs/padel.md")        ← BEFORE any synthesis
       library_shortest_path(from="MAP-padel", to="trading-data-dump")
         │
         ▼
     Obsidian vault (Markdown + [[wikilinks]])
       domains/padel/MAP-padel.md  ← domain entry neuron
       erreurs/padel.md            ← error neuron (read before coding)
       sessions/2026-07-06-padel.md
```

The agent ends every non-trivial task with a trace:
```
CHEMIN: MAP-padel -> padel -> domains/padel/README.md
ERREURS_LUES: [[padel]]
CONTRADICTION_REPO_VAULT: non
SKILL: competence_deja_disponible
```

---

## What problem does this solve

Standard Cursor agents either:
- Ignore shared memory entirely (answer from training data)
- Hard-block themselves when enforcement hooks are too strict (self-brick)

This template gives you a **middle path**: agents are *guided* to the vault without being *blocked* by it. If a hook fails, it fails open. If librarian-mcp is unavailable, the agent still works. Every real vault traversal is counted so you can verify the brain is actually being used.

---

## Stack

| Layer | Tool | License |
|-------|------|---------|
| Cursor hooks | PowerShell scripts in `.cursor/hooks/` | MIT (this repo) |
| Graph engine | [librarian-mcp](https://github.com/ngmeyer/librarian-mcp) | MIT |
| Knowledge base | Obsidian vault (your own) | yours |
| Agent rules | `.cursor/rules/*.mdc` | MIT (this repo) |

---

## Quickstart (Windows / PowerShell)

### Prerequisites

- [Cursor IDE](https://cursor.com) with hooks enabled
- [Obsidian](https://obsidian.md) (any vault, or use `vault-starter/`)
- PowerShell 7+ (or Windows PowerShell 5.1)

### Step 1 — Install librarian-mcp

Download the latest release from [ngmeyer/librarian-mcp](https://github.com/ngmeyer/librarian-mcp/releases) and note the path to the `.exe`.

Add to `~/.cursor/mcp.json` (global, shared across all agents):

```json
{
  "mcpServers": {
    "librarian": {
      "command": "C:\\Users\\you\\AppData\\Local\\librarian-mcp\\librarian-mcp.exe",
      "args": ["--vault", "C:\\Users\\you\\path\\to\\your\\vault"]
    }
  }
}
```

### Step 2 — Copy template into your Cursor project

```powershell
# Clone this repo
git clone https://github.com/YOUR_USERNAME/cursor-brain-graph.git
cd cursor-brain-graph

# Copy into your agent project
$target = "C:\path\to\your\agent-project"
Copy-Item -Recurse ".cursor" "$target\" -Force
Copy-Item -Recurse ".agents" "$target\" -Force
Copy-Item -Recurse "tests"   "$target\" -Force
Copy-Item ".cursor\memory.config.example.json" "$target\.cursor\memory.config.json"
```

Edit `.cursor/memory.config.json` in your project:
```json
{
  "brainMode": "central",
  "vaultPath": "C:\\Users\\you\\path\\to\\your\\vault",
  "agentId": "my-agent",
  "agentNote": "agents/my-agent.md"
}
```

### Step 3 — Bootstrap your vault

Either use `vault-starter/` as a base or add these files to your existing Obsidian vault:

```
vault/
  00_INDEX.md              ← hub (link all your MAPs here)
  domains/
    my-domain/
      MAP-my-domain.md     ← domain entry neuron
  erreurs/
    my-domain.md           ← error lessons (read before coding)
```

See `vault-starter/` for working examples.

**Important**: name your MAP notes uniquely — `MAP-padel`, `MAP-trading`, not `MAP.md`. librarian-mcp resolves by base name.

### Step 4 — Enable hooks in Cursor

Cursor Settings > General > Hooks — point to the `.cursor/hooks.json` in your project (or enable project hooks if that's your setup).

### Step 5 — Verify everything works

```powershell
cd "C:\path\to\your\agent-project"

# Run the full hook test suite (43 tests)
powershell -NoProfile -File tests\hooks\RUN_HOOK_TESTS.ps1

# Simulate a real librarian traversal and verify the counter
powershell -NoProfile -File tests\hooks\SIMULATE_LIBRARIAN_TERRAIN.ps1
```

Both should exit with `PASS`.

---

## How agents are expected to traverse the brain

Rule 49 (`49-brain-traversal.mdc`) imposes this pattern for non-trivial tasks:

1. **Enter by the domain MAP**: `library_traverse(start="MAP-my-domain", depth=1)`
2. **Read errors BEFORE synthesis**: `library_read(path="erreurs/my-domain.md")`
3. **Navigate**: `library_shortest_path` or `library_read` on specific neurons
4. **Trace** at the end:
   ```
   CHEMIN: MAP-my-domain -> my-domain -> ...
   ERREURS_LUES: [[my-domain]]
   CONTRADICTION_REPO_VAULT: non
   SKILL: competence_deja_disponible | skill_a_importer | ...
   ```

The `stop-depth-audit.ps1` hook automatically nudges the agent with a `followup_message` if it completed a task without this trace.

---

## What is measured

After each session, `.cursor/agent-gates.json` contains:

```json
{
  "brain_ok": true,
  "librarian_used": true,
  "librarian_calls": 4,
  "librarian_last_at": "2026-07-06T16:18:26+02:00"
}
```

`librarian_calls > 0` means the agent actually used the graph, not just the digest injected at session start.

---

## File reference

| Path | Purpose |
|------|---------|
| `.cursor/hooks/brain-load.ps1` | Session start: detect domain, inject MAP entry + digest |
| `.cursor/hooks/track-librarian-pretool.ps1` | Count every `CallMcpTool` librarian call |
| `.cursor/hooks/gate-write-unified.ps1` | Write/StrReplace gate (fail-open, brain-guided) |
| `.cursor/hooks/gate-shell-triage.ps1` | Shell gate (fail-open, recovery entrypoints allowed) |
| `.cursor/hooks/stop-depth-audit.ps1` | End-of-session: nudge if no traversal trace found |
| `.cursor/hooks/_hook-io.ps1` | Shared helpers: `Read-HookInput`, `Write-Gates`, `Record-LibrarianCall`, etc. |
| `.cursor/hooks.json` | Hook registration (sessionStart, preToolUse, beforeMCPExecution, stop) |
| `.cursor/memory.config.json` | Per-agent config: vaultPath, agentId |
| `.cursor/rules/49-brain-traversal.mdc` | Traversal contract (always-apply rule) |
| `.agents/skills/brain-traverse/SKILL.md` | Agent skill: how to traverse step by step |
| `tests/hooks/RUN_HOOK_TESTS.ps1` | 43-palier test suite |
| `tests/hooks/SIMULATE_LIBRARIAN_TERRAIN.ps1` | Simulate 2 librarian calls, assert counter > 0 |
| `vault-starter/` | Minimal Obsidian vault structure (no personal data) |

---

## Key design decisions

**Fail-open everywhere**: `failClosed: false` on all hooks. A broken hook never blocks the agent. `ENFORCEMENT_MAINTENANCE=1` env var bypasses all gates.

**No hard-blocking brain requirement**: agents are *nudged* not *blocked*. The gate denies only when both brain is confirmed loaded AND a specific risky pattern is detected (e.g. writing to a spec without a reflection proof).

**`preToolUse` not `beforeMCPExecution` for counting**: Cursor routes MCP calls through `preToolUse` with `tool_name="CallMcpTool"`. The `beforeMCPExecution` hook exists but is unreliable for MCP counting in practice. Both are wired as belt-and-suspenders.

**Unique node names**: librarian-mcp resolves by basename. Name your MAP notes `MAP-padel`, `MAP-trading`, etc. — never `MAP.md`. Duplicate basenames cause graph corruption.

---

## What is NOT included

- Personal vault content, profiles, or domain-specific knowledge
- Fleet propagation scripts (hardcoded to a specific machine setup)
- Domain-specific research gates (e.g. trading gamma/GEX gate) — wire your own via `agent-hooks-manifest.json`

---

## Validated terrain results

This template was developed and tested against real sessions:

| Agent | Calls measured | Hook denies | Notes |
|-------|---------------|-------------|-------|
| 010_Padel | 4 librarian calls | 0 | MAP-padel → erreurs/padel → session |
| 018_Trader | 2+ calls (sim) | 0 | MAP-trading gate + trading research gate |

---

## Contributing

Issues and PRs welcome. Keep changes fail-open and test with `RUN_HOOK_TESTS.ps1`.

---

## License

MIT — see `template/LICENSE`.  
[librarian-mcp](https://github.com/ngmeyer/librarian-mcp) is MIT licensed separately.
