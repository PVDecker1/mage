# MATL-AGENT

A Claude Code / Gemini CLI equivalent for MATLAB. An event-driven, LLM-powered autonomous agent that runs in the MATLAB Command Window and is built from the ground up to support a UI layer later — without changing the core loop.

---

## What it does

MATL-AGENT is an agentic harness around any OpenAI-compatible LLM endpoint. It can:

- Read, write, and patch files in your project
- Execute MATLAB code and capture outputs, errors, and figures
- Run your test suite and self-correct based on failures
- Generate documentation, live scripts, and reports
- Issue git operations (commit, diff, branch, log)
- Run shell commands and CI-adjacent tasks
- Load specialized **skills** on demand for focused tasks (testing, docs, Simulink, HPC, etc.)

---

## Architecture in one paragraph

`AgentLoop` is a MATLAB `handle` class. It fires events (`ResponseReceived`, `ToolCallStarted`, `ToolCallCompleted`, `UserInputRequired`, `ContextCompacted`, `AgentError`) at every meaningful transition. I/O adapters subscribe to those events — the Command Window adapter uses `fprintf`; a future App Designer UI adapter pushes to a `TextArea`. The loop never calls `input()` or `fprintf` directly. Swapping the UI is a drop-in listener replacement with zero changes to the loop.

---

## Quickstart

```matlab
% From the MATLAB Command Window
cd your_project/
agent = matl_agent();   % loads AGENT.md + .agent/config.json, attaches CmdWindowAdapter
agent.run();            % starts the REPL
```

On first run, MATL-AGENT will look for `AGENT.md` at the project root and `.agent/config.json` for endpoint configuration. If neither exists, it will prompt you to create them.

---

## Project structure

```
your_project/
├── AGENT.md                    ← Project instructions, conventions, toolbox list
├── .agent/
│   ├── config.json             ← LLM endpoint, model, token budgets, secrets
│   ├── session.json            ← T2 session state: branch, open files, ledger
│   ├── events.jsonl            ← Append-only event log (replay / audit)
│   ├── snapshots/              ← File snapshots before every edit
│   └── skills/                 ← Project-specific skill packs
│       └── my_skill/
│           └── SKILL.md
└── matl_agent/                 ← Agent source
    ├── matl_agent.m            ← Entry point
    ├── AgentLoop.m             ← handle class: events + core loop
    ├── AgentEventData.m        ← event.EventData subclass
    ├── io/
    │   ├── CmdWindowAdapter.m  ← Current I/O: fprintf + input()
    │   └── AppAdapter.m        ← Future: App Designer listeners
    ├── context/
    │   ├── ContextManager.m
    │   └── ...
    ├── tools/
    │   ├── ToolEngine.m
    │   └── ...
    ├── llm/
    │   └── LLMClient.m
    └── skills/
        └── SkillRegistry.m
```

---

## Configuration

**`.agent/config.json`**
```json
{
  "endpoint": "https://generativelanguage.googleapis.com/v1beta/openai/",
  "model": "gemini-2.5-pro",
  "compaction_model": "gemini-2.0-flash",
  "max_tokens": 8192,
  "context_budget": 100000,
  "compact_threshold": 0.70,
  "secrets": {
    "api_key": "YOUR_KEY_HERE",
    "gitlab_token": "glpat-xxxxxxxxxxxx",
    "gitlab_url": "https://gitlab.yourorg.com"
  }
}
```

Any OpenAI-compatible endpoint works — Gemini, Claude API directly, OpenAI, Azure OpenAI, or a local Ollama instance (`http://localhost:11434/v1`). Swap the endpoint and model fields and nothing else changes.

> **Note:** Never commit `.agent/config.json`. Add it to `.gitignore`. For CI environments, use environment variables (`MATL_AGENT_API_KEY`, `GITLAB_TOKEN`) instead — the agent checks `getenv()` before falling back to the config file.

---

## Context tiers

| Tier | Source | Survives compaction? |
|------|--------|----------------------|
| T1 – Project config | `AGENT.md` + `.agent/config.json` | Yes — always |
| T2 – Session state | `.agent/session.json` | Yes — summarized |
| T3 – Conversation | In-memory | No — compacted |
| T4 – Retrieved | Files, search, docs | No — injected per-turn |

When the conversation approaches 70% of the context budget, MATL-AGENT automatically summarizes T3 into a dense handoff block, writes it to T2, and clears the conversation. Sessions resume coherently.

---

## Skills

Skills are markdown knowledge packs that load on demand. Only their names and one-line descriptions are in context at startup. The full content loads when triggered.

```
.agent/skills/
  matlab_coding/SKILL.md        ← Style guide, naming, common patterns
  test_generation/SKILL.md      ← matlab.unittest, parameterized tests, fixtures
  docstring_writer/SKILL.md     ← MATLAB helptext format, input/output docs
  live_script_report/SKILL.md   ← .mlx structure, figures, LaTeX equations
  git_workflow/SKILL.md         ← Commit conventions, MR descriptions, changelogs
  hpc_submission/SKILL.md       ← Slurm job scripts, batch submission
```

Skills do **not** store credentials or state. They are read-only instructions. Credentials live in `config.json` or environment variables; session state lives in `session.json`.

---

## Modes

| Mode | Behavior |
|------|----------|
| `code` (default) | Full agentic loop — edits files, runs MATLAB, executes tools |
| `architect` | Plan first, execute after user approval |
| `ask` | Read-only — answers questions without touching files |
| `doc` | Documentation mode — loads `docstring_writer` and `live_script_report` skills |
| `test` | Test generation mode — targets uncovered functions |
| `report` | Report mode — outputs structured `.mlx` or PDF artifacts |

```matlab
agent.setMode('architect');
agent.run();
```

---

## Built-in tools

`read_file` · `write_file` · `edit_file` · `list_dir` · `search_files` · `matlab_eval` · `run_tests` · `run_script` · `shell_cmd` · `git_op` · `web_fetch` · `ask_human` · `load_skill` · `search_docs`

---

## Adding a UI later

The loop fires events. Your UI subscribes:

```matlab
agent = AgentLoop(cfg);

% Drop-in App Designer adapter
addlistener(agent, 'ResponseReceived',  @(~,e) obj.appendChat(e.Data.text));
addlistener(agent, 'ToolCallStarted',   @(~,e) obj.setStatus(e.Data.name));
addlistener(agent, 'ToolCallCompleted', @(~,e) obj.clearStatus());
addlistener(agent, 'AgentError',        @(~,e) obj.showError(e.Data.message));
```

For non-blocking UI operation, run the agent in a `parfeval` worker and push events to the main thread via a timer.

---

## Roadmap

- **Phase 1** — Core loop MVP: `AgentLoop`, `CmdWindowAdapter`, `LLMClient`, basic file + shell tools
- **Phase 2** — MATLAB-native tools: `matlab_eval`, `run_tests`, `edit_file` patches, git ops, event log
- **Phase 3** — Skills + context engineering: lazy skill loading, session handoff, auto-compaction
- **Phase 4** — Modes, reporting, App Designer UI, GitLab CI integration

---

## LLM backend options

MATL-AGENT's `LLMClient` speaks the OpenAI Chat Completions API format. Any compatible endpoint works:

| Provider | Endpoint | Notes |
|----------|----------|-------|
| Gemini | `generativelanguage.googleapis.com/v1beta/openai/` | Drop-in OpenAI-compat; recommended default |
| Claude (Anthropic) | `api.anthropic.com/v1` | Direct API access |
| OpenAI | `api.openai.com/v1` | Direct |
| Azure OpenAI | Your Azure endpoint | Needs deployment ID |
| Ollama (local) | `http://localhost:11434/v1` | Offline/air-gapped; no API key needed |

**MathWorks' llms-with-matlab library** ([matlab-deep-learning/llms-with-matlab](https://github.com/matlab-deep-learning/llms-with-matlab)) provides `openAIChat`, `ollamaChat`, `messageHistory`, and `openAIFunction` — actively maintained by MathWorks (v4.8+). MATL-AGENT's `LLMClient` either wraps this library or reimplements its patterns for full endpoint flexibility. The `openAIFunction` + `addParameter` pattern for defining tool schemas is directly applicable regardless of which HTTP path you choose.

---

## Requirements

- MATLAB R2021a or later (for `webwrite` options and `handle` class features used)
- A reachable OpenAI-compatible endpoint (AskSage, Ollama, OpenAI, Anthropic, etc.)
- Git (for git_op tool)

---

## License

MIT
