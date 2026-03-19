# Mage

An autonomous, event-driven software engineer for MATLAB. Mage provides a Gemini CLI / Claude Code equivalent for the MATLAB Command Window, built to automate engineering workflows, testing, and documentation.

---

## What it does

Mage is an agentic harness around any OpenAI-compatible LLM endpoint. It can:

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
agent = mage();         % loads AGENTS.md + .agent/config.json, attaches CmdWindowAdapter
agent.run();            % starts the REPL
```

On first run, Mage will look for `AGENTS.md` at the project root and `.agent/config.json` for endpoint configuration. If neither exists, it will create templates for you.

---

## Skills

Skills are markdown knowledge packs that load on demand. They provide Mage with specialized expertise without cluttering the permanent context.

### Installing Skills

To install a skill, simply place its `SKILL.md` file inside a subdirectory of either:
1.  **Global Skills:** `Mage/skills/` (available to all projects)
2.  **Project Skills:** `your_project/.agent/skills/` (specific to the current project)

Example structure:
```
your_project/
└── .agent/
    └── skills/
        └── simulink/
            └── SKILL.md
```

### Community Rules & Skills

Mage behavior is heavily influenced by external knowledge bases:
-   [**matlab/rules**](https://github.com/matlab/rules): A repository of standard `AGENTS.md` files and coding conventions. Use these to jumpstart a new project's instructions.
-   [**matlab/skills**](https://github.com/matlab/skills): A central hub for community-contributed `SKILL.md` packs. Download these to add capabilities like specialized toolbox support or cloud integration.

---

## Project structure

```
your_project/
├── AGENTS.md                   ← Project instructions, conventions, toolbox list
├── .agent/
│   ├── config.json             ← LLM endpoint, model, token budgets, secrets
│   ├── session.json            ← T2 session state: branch, open files, ledger
│   ├── events.jsonl            ← Append-only event log (replay / audit)
│   ├── snapshots/              ← File snapshots before every edit
│   └── skills/                 ← Project-specific skill packs
└── Mage/                       ← Agent source
    ├── mage.m                  ← Entry point
    ├── AgentLoop.m             ← handle class: events + core loop
    ├── AgentEventData.m        ← event.EventData subclass
    ├── io/
    │   ├── CmdWindowAdapter.m  ← Current I/O: fprintf + input()
    │   └── AppAdapter.m        ← Future: App Designer listeners
    ├── ContextManager.m        ← Tiered context management
    ├── ToolEngine.m            ← Tool dispatcher
    ├── LLMClient.m             ← HTTP client
    └── skills/
        └── SkillRegistry.m     ← Skill discovery and loading
```

---

## Configuration

**`.agent/config.json`**
```json
{
  "endpoint": "https://generativelanguage.googleapis.com/v1beta/openai/",
  "model": "gemini-1.5-flash",
  "compaction_model": "gemini-1.5-flash",
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

Any OpenAI-compatible endpoint works. For CI environments, use environment variables (`MAGE_API_KEY`, `GITLAB_TOKEN`) instead — the agent checks `getenv()` before falling back to the config file.

---

## Built-in tools

`read_file` · `write_file` · `edit_file` · `list_dir` · `search_files` · `matlab_eval` · `run_tests` · `run_script` · `shell_cmd` · `git_op` · `web_fetch` · `ask_human` · `load_skill` · `search_docs`

---

## Requirements

- MATLAB R2021a or later
- A reachable OpenAI-compatible endpoint
- Git (for git_op tool)

---

## License

MIT
