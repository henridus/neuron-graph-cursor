# Neuron Graph for Cursor

**A traversable Obsidian brain for Cursor agents, powered by [librarian-mcp](https://github.com/ngmeyer/librarian-mcp) (MIT).**

Your notes become neurons, your `[[wikilinks]]` become synapses, and your agents walk the graph before they act — fail-open, measurable, no self-brick.

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

Then we validated it on live sessions, not in theory.

A booking-automation agent was handed a vague task about a recurring failure. Instead of guessing, it entered through `MAP-padel`, opened `erreurs/padel.md` **before** writing a single line, and surfaced the specific lesson it needed — a timing bug that only triggered around midnight. It finished with a trace showing exactly which neurons it had walked. The instrumentation confirmed it wasn't bluffing: **4 real `library_*` calls counted, zero hooks blocked**. A second agent, working on a completely different domain, got the same behaviour through its own map and its own guardrails.

That's the whole point. You no longer have to *trust* that the agent used your knowledge base — you can *read the count* and see the path it took.

This repository is that system, extracted and stripped of anything personal: the **Cursor hooks + traversable Obsidian brain** we wish had existed on day one.

---

## This is an orchestration, not an invention

We did not build a memory engine from scratch. We went looking on GitHub, found that **no single project delivered the whole thing**, and **wired several of them together** into one coherent system. That assembly *is* the contribution here — the glue, the conventions, and the enforcement that make separate pieces behave like one brain.

What we stood on:

| Building block | What it gave us | Origin |
|----------------|-----------------|--------|
| **[librarian-mcp](https://github.com/ngmeyer/librarian-mcp)** (MIT) | The graph engine: `library_traverse`, `library_shortest_path`, trigram search, auto-wikilinks | ngmeyer |
| **The LLM Wiki pattern** | The core idea: an LLM navigating a linked wiki instead of a flat dump | Andrej Karpathy |
| **Context Capsules + Tiered Retrieval** | Short notes (not walls of text), stop at the right depth, repo beats vault on conflict | obsidian-agent-memory ecosystem |
| **Skill acquisition** (`find-skills`) | Agents pulling in curated skills on demand instead of hardcoding everything | Vercel Labs pattern |
| **Cursor hooks** | The deterministic enforcement surface: sessionStart, preToolUse, stop | Cursor official docs |
| **Obsidian** | The vault: plain Markdown + `[[wikilinks]]` as the neuron substrate | obsidian.md |

**What we added on top** — the part that did not exist before:

- **Domain MAPs as forced entry points** so the agent always knows which doorway into the brain to use.
- **A traversal contract** (rule 49 + the `brain-traverse` skill) that makes "read the errors before you act" a rule, not a hope.
- **Fail-open enforcement** — hooks that guide without ever bricking the agent (a lesson learned the hard way).
- **Measurable proof** — every `library_*` call counted in `agent-gates.json`, so brain usage is a number, not a claim.

In short: the neurons come from Obsidian, the nervous system from librarian-mcp, the reflexes from Cursor hooks — and **this repo is the surgeon that connected them** so an AI agent can finally think with a memory that persists.

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
| Token compression (optional) | [Token Smithers](https://github.com/shacharbard/token-smithers) | MIT |
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

### Step 1b — Optional: compress librarian MCP tokens with Token Smithers

[librarian-mcp](https://github.com/ngmeyer/librarian-mcp) exposes ~20 tools; their schemas and graph results can consume a lot of context. **[Token Smithers](https://github.com/shacharbard/token-smithers)** is a stdio proxy that sits between Cursor and librarian-mcp and compresses schemas + results transparently.

**Install** (Python 3.11+):

```powershell
pip install "token-smithers[learning] @ git+https://github.com/shacharbard/token-smithers.git@stable"
```

**Configure** — copy `vault-starter/librarian-smithers.yaml.example` to `~/.cursor/librarian-smithers.yaml`, edit paths, then update `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "librarian": {
      "command": "token-smithers",
      "args": ["--config", "C:\\Users\\you\\.cursor\\librarian-smithers.yaml"]
    }
  }
}
```

**Important**: keep the server name `"librarian"` — hooks count `CallMcpTool` on that name; renaming breaks `librarian_calls` instrumentation.

**Verify** after reload:

```powershell
powershell -NoProfile -File tests\hooks\SIMULATE_LIBRARIAN_TERRAIN.ps1
powershell -NoProfile -File tests\hooks\RUN_HOOK_TESTS.ps1
```

**Stats**: `token-smithers stats` reads compression metrics from `~/.token-smithers/metrics.json`.

Token Smithers only compresses MCP traffic. Native Cursor tools (`Read`, `Write`, `Shell`, `Grep`) are unaffected.

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
| `vault-starter/librarian-smithers.yaml.example` | Optional Token Smithers proxy config for librarian-mcp |

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

## Credits — the projects this orchestrates

This project is an assembly. Full credit to the work it builds on:

- **[librarian-mcp](https://github.com/ngmeyer/librarian-mcp)** (ngmeyer, MIT) — the graph traversal engine that makes any Markdown folder walkable.
- **Andrej Karpathy** — the LLM Wiki pattern that inspired the whole "navigate, don't dump" approach.
- **The obsidian-agent-memory ecosystem** — Context Capsules and Tiered Retrieval, which shaped how notes stay short and traversal stops at the right depth.
- **Vercel Labs `find-skills`** — the on-demand skill acquisition pattern.
- **[Token Smithers](https://github.com/shacharbard/token-smithers)** (shacharbard) — optional MCP compression proxy for librarian token savings.
- **[Obsidian](https://obsidian.md)** and the **[Model Context Protocol](https://modelcontextprotocol.io)** — the substrate and the wiring standard.
- **Cursor** — the hooks API that made deterministic enforcement possible.

The original contribution of this repo is the **orchestration layer**: domain MAPs, the traversal contract, fail-open enforcement, and measurable brain-usage proof.

---

## License

MIT — see `template/LICENSE`.  
[librarian-mcp](https://github.com/ngmeyer/librarian-mcp) and the other referenced projects are licensed separately by their respective authors.
