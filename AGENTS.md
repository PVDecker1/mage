# AGENTS.md

This file is loaded by Mage at the start of every session as persistent project context (T1 tier). It survives compaction. Keep it accurate and concise — every line costs tokens every turn.

---

## Project

**Name:** Mage  
**Description:** Event-driven LLM-powered autonomous agent for MATLAB  
**MATLAB version:** R2023b  
**Required toolboxes:** None beyond base MATLAB (Signal Processing Toolbox optional for demo scripts)

---

## Repository

**Platform:** GitLab  
**Default branch:** `main`  
**Branch convention:** `feature/short-description`, `fix/short-description`, `chore/short-description`  
**Merge requests:** Squash commits; MR title should complete the sentence "This MR..."

---

## Code conventions

- **Naming:** `camelCase` for variables and functions, `PascalCase` for classes, `UPPER_SNAKE` for constants
- **Classes:** All stateful components are `handle` classes; value objects use plain structs or value classes
- **Comments:** Full sentence helptext on every public function/method; inline comments only for non-obvious logic
- **Line length:** 100 characters max
- **No globals:** Pass config and state explicitly; never use `global` or `persistent` unless absolutely required
- **Error handling:** Use `error()` with an identifier (`'mage:component:errorType'`); never silently swallow exceptions

---

## Testing

**Framework:** `matlab.unittest`  
**Test location:** `tests/` directory, mirroring source structure  
**Run command:** `results = runtests('tests'); assertSuccess(results);`  
**Coverage target:** 80% line coverage on core loop and context manager  
**Before committing:** Always run the test suite; never commit a red build

---

## Key files and folders

| Path | Purpose |
|------|---------|
| `mage.m` | Entry point |
| `AgentLoop.m` | Core handle class — events, loop, do not add I/O here |
| `AgentEventData.m` | event.EventData subclass — keep fields minimal and serializable |
| `io/CmdWindowAdapter.m` | Command Window I/O — all fprintf/input lives here |
| `io/AppAdapter.m` | Future App Designer adapter — stub only until Phase 4 |
| `ContextManager.m` | Tiered context — T1/T2/T3/T4 management and compaction |
| `ToolEngine.m` | Tool dispatcher — routes tool_call JSON to handlers |
| `LLMClient.m` | HTTP client — OpenAI-compat POST; keep model-agnostic |
| `skills/SkillRegistry.m` | Discovers and lazy-loads skills from `skills/` and `.agent/skills/` |
| `.agent/config.json` | Runtime config — NOT committed; see config.json.example |
| `.agent/session.json` | T2 session state — auto-managed; do not hand-edit |
| `.agent/events.jsonl` | Append-only event log — do not edit or truncate manually |

---

## Files and folders to ignore

The agent should never read, write, or reason about these paths:

```
.agent/snapshots/
.agent/events.jsonl
*.asv
*.mex*
slprj/
codegen/
```

Do not propose edits to generated files (anything in `codegen/` or `slprj/`).

---

## Secrets and credentials

- **Never hardcode keys or tokens** in any `.m` file
- Credentials are in `.agent/config.json` (local) or environment variables (CI)
- When generating code that calls external APIs, always read from `cfg.secrets.<key>` or `getenv('<KEY_NAME>')`
- GitLab token: `cfg.secrets.gitlab_token` or `getenv('GITLAB_TOKEN')`
- LLM API key: `cfg.secrets.api_key` or `getenv('MAGE_API_KEY')`

---

## LLM preferences

- **Default model:** `gemini-2.5-pro` (via Gemini OpenAI-compat endpoint)
- **Compaction model:** `gemini-2.0-flash` or equivalent fast/cheap model
- **Local fallback:** Ollama with `qwen2.5-coder:14b`
- **Preferred diff format:** `str_replace` style (old_str → new_str) — not full-file rewrites
- **Response style:** Concise; no unsolicited explanations of what you just did; show code, not descriptions of code

---

## Common workflows

**Run tests:**
```matlab
results = runtests('tests');
assertSuccess(results);
```

**Generate docs for a function:**
```
/mode doc
Write helptext for tools/ToolEngine.m
```

**Compact context manually:**
```
/compact
```

**Check what the agent last did:**
```
/history
```

---

## Architecture reminders

- `AgentLoop` fires events — it never calls `fprintf` or `input()` directly
- I/O adapters are listeners — `CmdWindowAdapter` and `AppAdapter` are the only places that touch the terminal or UI
- Skills are read-only knowledge — they do not store state or credentials
- Every file write is preceded by a snapshot to `.agent/snapshots/`
- Context compaction writes a handoff block to `.agent/session.json` before clearing T3
