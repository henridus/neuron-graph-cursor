# cursor-brain-graph

**Give your Cursor agents a memory that behaves like a brain — one they actually walk through, neuron by neuron, before they act.**

---

## The story

It started with a simple frustration: AI coding agents have amnesia. Every session, they forget what broke last time. They re-invent the same fix, re-make the same mistake, ignore the hard-won lesson buried in your notes. You can hand them documentation — but "having access" to a knowledge base and *actually using it* are two very different things.

So we tried something. We took a small open-source MIT project — [**librarian-mcp**](https://github.com/ngmeyer/librarian-mcp), which turns a folder of Markdown notes into a *graph* you can traverse — and we wired it into Cursor. The notes became **neurons**. The `[[wikilinks]]` between them became **synapses**. And each domain got a **MAP** — an entry point, like a doorway into that region of the brain.

Then came the hard part, and it took the better part of a week of trial and error. Because the first instinct — "force the agent to read the brain" — backfires spectacularly. Hooks that *block* the agent until it proves it read the vault don't create a smart agent; they create a **bricked** one. We watched agents lock themselves out of their own workspace, unable to write a single file, while a human had to paste PowerShell into an external terminal just to unblock them. Enforcement that fails *closed* is enforcement that eventually kills the patient.

The breakthrough was reframing the whole thing. Stop *blocking*. Start *guiding* — and *measuring*.

- On every session start, a hook detects what the task is about and quietly injects the right MAP as the doorway. The agent doesn't have to guess where to enter.
- A rule (the "traversal contract") teaches the agent the path: enter by the MAP, **read the error neurons before touching code**, follow the synapses to the lesson, and end with a trace of exactly where it walked.
- And critically — every single `library_*` call the agent makes gets **counted**. Not to punish it. To *prove* it. After a session you can open one JSON file and see: `librarian_calls: 4`. The brain wasn't decoration. It was used.

Every hook fails **open**. If something breaks, the agent keeps working. If the graph engine is down, the agent keeps working. There is no scenario where this system bricks you — that lesson was paid for in full.

We tested it on real agents doing real work. A booking-automation agent (Padel) entered through `MAP-padel`, read `erreurs/padel.md` *before* proposing anything, pulled the exact lesson about a midnight timing bug, and left a clean trace behind — 4 measured traversals, zero blocks. A trading-research agent got the same treatment with its own domain map and its own guardrails. It worked. The brain held.

This repository is that system, extracted and cleaned of anything personal. It's the **mix of Cursor hooks + a traversable Obsidian brain** that we wish had existed when we started.

---

## In one diagram

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

The agent ends every non-trivial task with a trace of the path it walked:
```
CHEMIN: MAP-padel -> padel -> domains/padel/README.md
ERREURS_LUES: [[padel]]
CONTRADICTION_REPO_VAULT: non
SKILL: competence_deja_disponible
```

---

## The two failure modes this avoids

Most attempts at "agent memory" fall into one of two traps:

| Trap | What happens |
|------|--------------|
| **Too loose** | Agent has a vault but ignores it, answering from training data. Memory is decoration. |
| **Too strict** | Hooks block the agent until it "proves" it read the brain. One bug and the agent bricks itself — can't write, can't run, needs a human to rescue it. |

`cursor-brain-graph` sits deliberately in the middle: **guided, not blocked; measured, not trusted.** Agents are nudged toward the vault and every traversal is counted, but a broken hook never stops the work.

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
