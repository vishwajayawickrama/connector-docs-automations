# WSO2 Integrator Connector Docs Automation

An AI-driven pipeline that uses **Ballerina** + **Claude (Anthropic)** + **Claude Agent SDK** to fully automate WSO2 Integrator low-code workflow documentation. The pipeline generates a detailed browser-automation prompt via Claude, then runs a Python agent server that executes the prompt end-to-end inside a **code-server** (in-browser VS Code) instance using Playwright MCP — capturing screenshots and producing step-by-step workflow documentation with no manual interaction.

```
Goal → Claude generates XML-tagged execution prompt → Python Agent SDK executes it via Playwright MCP → Artifacts
```

---

## Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Ballerina | 2201.12.0+ | [ballerina.io/downloads](https://ballerina.io/downloads/) |
| Python | 3.11+ | [python.org](https://www.python.org/downloads/) |
| uv | latest | [docs.astral.sh/uv](https://docs.astral.sh/uv/getting-started/installation/) |
| Node.js | LTS+ | [nodejs.org](https://nodejs.org/) |
| Playwright MCP | latest | `npm install -g @playwright/mcp@latest` |
| Claude Code CLI | latest | [claude.ai/code](https://claude.ai/code) |
| code-server | latest | [github.com/coder/code-server](https://github.com/coder/code-server) |

### Setup

**1. Clone and enter project**

```bash
cd connector-docs-automations
```

**2. Create Config.toml**

```bash
cp Config.toml.example Config.toml
# Edit Config.toml and fill in the required fields
```

**3. Install uv (Python package manager)**

```bash
# Linux / macOS
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

**4. Set up all dependencies**

```bash
# Install Ballerina deps + create agent/.venv + install Python deps + install Playwright Chromium
make setup

# Or step by step:
make setup-python   # creates agent/.venv, installs Python deps, installs Playwright Chromium
make setup-bal      # runs bal build
```

**5. Set your Anthropic API key as an environment variable**

The Python agent server reads the key from the environment:

```bash
# Linux / macOS
export ANTHROPIC_API_KEY="sk-ant-..."

# Windows (PowerShell)
$env:ANTHROPIC_API_KEY = "sk-ant-..."
```

> The same key also goes into `Config.toml` as `llmApiKey` for the Ballerina steps.

**6. Run the full pipeline**

```bash
make run
# equivalent to: bal run
```

The pipeline automatically installs/starts code-server and the Python agent server, generates the execution prompt, and runs the Claude agent until complete.

**Output:** All generated files are saved under `artifacts/` (git-ignored).

---

## Project Structure

```
.
├── main.bal                         # Entry point — orchestrates the 16-step pipeline
├── Ballerina.toml                   # Ballerina package manifest & dependencies
├── Config.toml                      # Runtime configuration (git-ignored)
├── Config.toml.example              # Template for Config.toml
├── Dependencies.toml                # Resolved Ballerina dependency lock file
├── Makefile                         # All common commands (setup, run, clean, etc.)
│
├── agent/                           # Python Claude Agent SDK server + post-processing scripts
│   ├── agent_server.py              # aiohttp HTTP server wrapping claude-agent-sdk
│   ├── crop_screenshots.py          # Post-processing: crops UI chrome from screenshots
│   ├── append_examples_link.py      # Post-processing: appends Ballerina Central examples link
│   ├── cleanup_workspace.py         # Post-processing: closes editor tabs in code-server
│   ├── pyproject.toml               # Python package manifest
│   ├── requirements.txt             # Pinned Python dependencies
│   └── .venv/                       # Python virtual environment (git-ignored)
│
├── modules/                         # Ballerina sub-modules
│   ├── ai_client/
│   │   └── ai_client.bal            # Claude API calls (validate, generate, slug, doc enforcement)
│   ├── agent_client/
│   │   └── agent_client.bal         # REST client for the Python agent server
│   ├── prompts/
│   │   ├── system_prompt.bal        # System prompt builder (XML-tagged template)
│   │   └── user_prompt.bal          # User message builder
│   └── utils/
│       ├── file_utils.bal           # Timestamped file saving (returns saved path)
│       ├── logger.bal               # ANSI coloured logger (colorize + log)
│       ├── code_server_utils.bal    # code-server health check & startup
│       └── python_server_utils.bal  # Python agent server health check & startup
│
├── .mcp.json                        # Claude Code MCP server config (Playwright)
├── .claude/
│   ├── settings.json                # Claude Code permissions & model config
│   └── settings.local.json          # Local overrides (git-ignored)
│
└── artifacts/                       # All generated run output (git-ignored)
    ├── execution-prompt/            # Generated execution prompts
    │   └── <slug>_execution_prompt_<timestamp>.md
    ├── workflow-docs/               # Step-by-step workflow guides with screenshots
    │   └── *.md
    ├── screenshots/                 # Captured browser screenshots (cropped)
    └── run-log/                     # JSON run logs with cost and timing stats
        └── <slug>_<timestamp>.json
```

---

## Makefile Reference

```
make help                   Show this reference

Setup
  make setup                Install all deps (Python venv + Playwright Chromium + Ballerina build)
  make setup-python         Create agent/.venv, install Python deps, install Playwright Chromium
  make setup-bal            Build the Ballerina project (bal build)

Run
  make run                  Run the full 16-step pipeline (bal run)
  make start-agent          Start the Python agent server in the foreground
  make stop-agent           Send shutdown request to the running agent server

Screenshots
  make crop-screenshots     Crop UI chrome from all screenshots in artifacts/screenshots/
  make crop-screenshots-dry Preview what would be cropped (no changes made)
  make crop-screenshots-backup Crop screenshots and keep originals as .bak files

Artifacts
  make clean                Remove artifacts/, target/, Dependencies.toml, agent/.venv
  make clean-artifacts      Remove only the artifacts/ directory
```

---

## How It Works

```
┌──────────────────────────────┐
│  Goal defined in Config.toml  │
└──────────┬───────────────────┘
           │
    ═══════════════════════════════════════════════════════
    PHASE 1 — Pre-flight validation (Steps 1–2)
    ═══════════════════════════════════════════════════════
           │
    ┌──────▼──────────────────────┐
    │  Step 1: Validate API key    │
    │  (Anthropic ping)            │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 2: Check Claude Code   │
    │  CLI is installed            │
    └──────┬──────────────────────┘
           │
    ═══════════════════════════════════════════════════════
    PHASE 2 — Infrastructure (Steps 3–5)
    ═══════════════════════════════════════════════════════
           │
    ┌──────▼────────────────────────────────────────────┐
    │  Step 3: Is code-server binary installed?          │
    │  code-server --version                             │
    └──────┬───────────────────────┬───────────────────┘
           │ installed             │ not installed
           │                       ▼
           │            ┌──────────────────────┐
           │            │  curl -fsSL           │
           │            │  code-server.dev/     │
           │            │  install.sh | sh      │
           │            └──────────┬────────────┘
           └───────────────────────┘
           │
    ┌──────▼────────────────────────────────────────────┐
    │  Step 4: Is code-server running?                   │
    │  curl http://localhost:<port> (3s timeout)         │
    └──────┬───────────────────────┬───────────────────┘
           │ already running       │ not running → auto-start + poll
           └───────────────────────┘
           │
    ┌──────▼────────────────────────────────────────────┐
    │  Step 5: Is Python agent server running?           │
    │  curl http://localhost:<agentPort>/health (3s)     │
    └──────┬───────────────────────┬───────────────────┘
           │ already running       │ not running → auto-start + poll
           └───────────────────────┘
           │
    ═══════════════════════════════════════════════════════
    PHASE 3 — Prompt generation (Steps 6–10)
    ═══════════════════════════════════════════════════════
           │
    ┌──────▼──────────────────────┐
    │  Step 6: Build system +      │
    │  user prompts                │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 7: Claude Sonnet 4.6   │
    │  generates execution prompt  │
    │  (up to 16 000 tokens)       │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 8: Claude generates    │
    │  filename slug from goal     │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 9: Add Markdown header │
    │  to the execution prompt     │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────────────────┐
    │  Step 10: Save to                        │
    │  artifacts/execution-prompt/             │
    │  → returns file path                     │
    └──────┬──────────────────────────────────┘
           │
    ═══════════════════════════════════════════════════════
    PHASE 4 — Agent execution & post-processing (Steps 11–16)
    ═══════════════════════════════════════════════════════
           │
    ┌──────▼──────────────────────────────────────────────┐
    │  Step 11: POST /run to agent server                  │
    │  { "prompt_path": "<path>" }                         │
    │  Poll /jobs/<id> every 1s                            │
    │  Stream [SESSION/CLAUDE/TOOL/RESULT/USAGE] logs      │
    │  until status == "done"                              │
    └──────┬──────────────────────────────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 12: Workspace cleanup  │
    │  Close all editor tabs in    │
    │  code-server                 │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 13: Enforce doc        │
    │  structure via dedicated     │
    │  Claude API call             │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 14: Append Ballerina   │
    │  Central examples link       │
    │  (if connector has examples) │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 15: Crop UI chrome     │
    │  from screenshots            │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────┐
    │  Step 16: Write JSON run log │
    │  (cost, tokens, timing)      │
    └──────┬──────────────────────┘
           │
    ┌──────▼──────────────────────────────────┐
    │  artifacts/screenshots/                  │
    │  artifacts/workflow-docs/               │
    │  artifacts/execution-prompt/            │
    │  artifacts/run-log/                     │
    └─────────────────────────────────────────┘
```

### Step descriptions

**Phase 1 — Pre-flight validation**
1. **Step 1 — API validation** — Minimal Anthropic API ping before running the expensive steps.
2. **Step 2 — Claude Code CLI check** — Verifies `claude` is installed and on `PATH` (required for agent execution).

**Phase 2 — Infrastructure**
3. **Step 3 — code-server install** — Runs `code-server --version`. If not found, installs via the official `curl` script.
4. **Step 4 — code-server start** — Probes `http://localhost:<port>`. If not running, spawns code-server and polls for up to 15 s.
5. **Step 5 — Agent server check** — Probes `/health`. If not running, spawns `agent/.venv/bin/python agent_server.py` and polls for up to 20 s.

**Phase 3 — Prompt generation**
6. **Step 6 — Prompt building** — Constructs the system prompt (XML-tagged template) and user message with goal + code-server URL.
7. **Step 7 — Prompt generation** — Calls Claude Sonnet 4.6 (up to 16 000 tokens) to produce the execution prompt.
8. **Step 8 — Slug generation** — Second Claude call produces a 3–4 word filename-safe slug.
9. **Step 9 — Format** — Prepends a Markdown metadata header.
10. **Step 10 — Save** — Writes to `artifacts/execution-prompt/<slug>_execution_prompt_<timestamp>.md` and returns the path.

**Phase 4 — Agent execution & post-processing**
11. **Step 11 — Agentic execution** — POSTs the prompt path to `/run`, receives a `job_id`, then polls `/jobs/<id>` every second printing coloured `[SESSION]`, `[CLAUDE]`, `[TOOL]`, `[RESULT]`, `[USAGE]` log lines until done.
12. **Step 12 — Workspace cleanup** — Runs `cleanup_workspace.py` to close all open editor tabs in code-server.
13. **Step 13 — Doc enforcement** — Dedicated Claude API call rewrites the generated workflow doc with doc-structure rules fresh in context (no browser-automation noise).
14. **Step 14 — Examples link** — Runs `append_examples_link.py`: checks Ballerina Central for an examples section and appends a `## More Examples` link if found.
15. **Step 15 — Screenshot crop** — Runs `crop_screenshots.py` to trim UI chrome from all captured screenshots.
16. **Step 16 — Run log** — Writes a JSON run log to `artifacts/run-log/` with timing, token counts, and cost breakdown for all LLM calls.

---

## Configuration

```bash
cp Config.toml.example Config.toml
```

```toml
# Anthropic API Key (required)
llmApiKey = "sk-ant-..."

# code-server port
codeServerPort = 8080

# Python agent server port (agent/agent_server.py)
agentServerPort = 8765

# Automation goal
userGoal = "Create an HTTP GET endpoint that returns Hello World using WSO2 Integrator"
```

> **Note:** `Config.toml` is git-ignored and must never be committed.

> **Note:** Also export `ANTHROPIC_API_KEY` for the Python agent server:
> ```bash
> export ANTHROPIC_API_KEY="sk-ant-..."
> ```

---

## Python Agent Server (`agent/`)

`agent/agent_server.py` is a lightweight `aiohttp` HTTP server wrapping the **Claude Agent SDK**. It accepts a prompt file path, runs the agent asynchronously with Playwright MCP, and exposes a polling API for Ballerina to stream live logs.

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/run` | Submit a job: `{ "prompt_path": "..." }` → `{ "job_id": "..." }` |
| `GET` | `/jobs/<id>` | Poll job: `{ "status": "running\|done", "logs": [...], "cost": {...} }` |
| `GET` | `/health` | Health check: `{ "status": "ok" }` |
| `POST` | `/shutdown` | Gracefully stop the server |

The `cost` field in `/jobs/<id>` contains `totalCostUsd`, `inputTokens`, `outputTokens`, `cacheReadTokens`, `cacheWriteTokens`, and `numTurns` once the job completes.

### Python setup

```bash
# Create venv inside agent/, install deps, and install Playwright Chromium
make setup-python

# Or manually:
cd agent
uv venv                          # creates agent/.venv
uv pip install -r requirements.txt
.venv/bin/playwright install chromium
```

### Start / stop manually

```bash
make start-agent    # foreground: cd agent && .venv/bin/python agent_server.py
make stop-agent     # curl -X POST http://localhost:8765/shutdown

# Custom port:
cd agent && .venv/bin/python agent_server.py --port 9000
```

---

## Post-processing Scripts (`agent/`)

| Script | When it runs | What it does |
|--------|-------------|--------------|
| `cleanup_workspace.py` | Step 12 | Closes all open editor tabs in code-server via Playwright |
| `append_examples_link.py` | Step 14 | Checks Ballerina Central registry; appends `## More Examples` link if connector has examples |
| `crop_screenshots.py` | Step 15 | Crops UI chrome (browser frame, sidebars) from all screenshots |

Run screenshot cropping manually:

```bash
make crop-screenshots         # crop in-place
make crop-screenshots-dry     # preview only (no changes)
make crop-screenshots-backup  # crop and keep originals as .bak files
```

---

## code-server

The automation target is a **code-server** instance (VS Code in the browser) with the **WSO2 Integrator** extension installed. Start it manually if needed:

```bash
code-server --auth none --bind-addr 0.0.0.0:8080
```

Or let the pipeline handle it automatically (Step 4).

---

## Running on GitHub Actions

The pipeline can run fully unattended via the included workflow at [`.github/workflows/connector-docs-automation.yml`](.github/workflows/connector-docs-automation.yml). Trigger it manually from the **Actions** tab with a goal string; it will generate the documentation, open a PR in the docs repo, and upload all artifacts.

### Required Secrets

Add these in your repo at **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Required | Description |
|--------|----------|-------------|
| `LLM_API_KEY` | ✅ Yes | Anthropic API key — used by the Ballerina pipeline (prompt generation + doc enforcement) and by the Claude Code CLI subprocess (agent execution + docs placement) |
| `DOCS_INTEGRATOR_TOKEN` | ✅ Yes | GitHub PAT — used by `publish-connector-docs.yml` to push a feature branch to `vishwajayawickrama/docs-integrator` and open a PR against `thuva9872/docs-integrator:dev` |

#### `LLM_API_KEY`

1. Go to [console.anthropic.com](https://console.anthropic.com/) → **API Keys** → **Create Key**
2. Copy the key (shown only once)
3. Add it as a secret named `LLM_API_KEY`

#### `DOCS_INTEGRATOR_TOKEN`

Used by the publish workflow (`publish-connector-docs.yml`) to:
- **Clone** `vishwajayawickrama/docs-integrator` via HTTPS
- **Push** a new feature branch (`docs/publish-{connector}-{run-id}`) to the fork
- **Create a PR** from the fork's feature branch to `thuva9872/docs-integrator:dev`

**Required PAT scopes (classic token):**

| Scope | Why it is needed |
|-------|-----------------|
| `repo` | Full access to clone and push branches to `vishwajayawickrama/docs-integrator`, and to create PRs against `thuva9872/docs-integrator` |

**How to create the token:**

1. GitHub → **Settings** (top-right avatar) → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Set a descriptive note, e.g. `docs-integrator-automation`
4. Set expiration as appropriate for your use case
5. Check the **`repo`** scope (this covers all sub-scopes: `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`)
6. Click **Generate token** — copy it immediately (shown only once)
7. Add it as a secret named `DOCS_INTEGRATOR_TOKEN` in the `docs-automation` environment of **this** repository

> **Note:** The token must belong to an account with `write` access to `vishwajayawickrama/docs-integrator`. Any GitHub account can open PRs against a public repo (`thuva9872/docs-integrator`) — no special upstream permissions are required.

### Required GitHub Environment

The workflow uses an environment named `docs-automation` (used for environment-level protection rules if desired).

Create it at: **Settings → Environments → New environment → name it `docs-automation`** → Save.

> If you don't want environment protection rules, you can also remove the `environment: docs-automation` line from the workflow file.

### Workflow Inputs

Trigger via **Actions → Connector Documentation Automation → Run workflow**:

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `userGoal` | ✅ Yes | — | The WSO2 integration to document, e.g. `"Create a Redis key-value connection using WSO2 Integrator connectors"` |
| `codeServerPort` | No | `8080` | Port for the code-server instance |
| `agentServerPort` | No | `8765` | Port for the Python agent server |

### What the Workflow Produces

On a successful run:

1. **A branch and PR** in `vishwajayawickrama/Generated-Connector-Documentation.`:
   - Branch: `[connector-name]-example-document`
   - Directory: `[connector-name]-connector-example-documentation/workflow-docs/` + `/screenshots/`
2. **GitHub Actions artifact** (retained 30 days) named `[connector-name]-connector-example-documentation-[run_id]`:
   - `artifacts/execution-prompt/` — the generated XML-tagged automation prompt
   - `artifacts/workflow-docs/` — the step-by-step connector guide (Markdown)
   - `artifacts/screenshots/` — captured workflow screenshots (cropped)
   - `artifacts/run-log/` — JSON run log with cost and timing stats

---

## Customization

### Change the goal

```toml
userGoal = "Create a Kafka producer connection in WSO2 Integrator"
```

### Change ports

```toml
codeServerPort = 9000
agentServerPort = 9765
```

### Modify prompt templates

- System prompt: [modules/prompts/system_prompt.bal](modules/prompts/system_prompt.bal)
- User message: [modules/prompts/user_prompt.bal](modules/prompts/user_prompt.bal)

### Add agent tools

Edit the `allowed_tools` list in [agent/agent_server.py](agent/agent_server.py).

---

## Utility Scripts & Makefile

| Action | Makefile | Direct command |
|--------|----------|----------------|
| Setup all deps | `make setup` | — |
| Setup Python venv | `make setup-python` | `cd agent && uv venv && uv pip install -r requirements.txt && .venv/bin/playwright install chromium` |
| Build Ballerina | `make setup-bal` | `bal build` |
| Run pipeline | `make run` | `bal run` |
| Start agent server | `make start-agent` | `cd agent && .venv/bin/python agent_server.py` |
| Stop agent server | `make stop-agent` | `curl -X POST http://localhost:8765/shutdown` |
| Crop screenshots | `make crop-screenshots` | `agent/.venv/bin/python agent/crop_screenshots.py` |
| Clean everything | `make clean` | `rm -rf artifacts/ target/ Dependencies.toml agent/.venv` |
| Clean artifacts only | `make clean-artifacts` | `rm -rf artifacts/` |

---

## Troubleshooting

### "Anthropic API key validation failed"
```bash
cp Config.toml.example Config.toml
# Set llmApiKey in Config.toml
export ANTHROPIC_API_KEY="sk-ant-..."
```

### "Claude Code CLI not installed"
```bash
# Install from https://claude.ai/code, then verify:
claude --version
```

### "Agent server did not become ready"
```bash
make start-agent   # run in foreground to see Python errors
curl http://localhost:8765/health
```

### "uv: command not found"
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc   # or ~/.zshrc
```

### Python import error: claude_agent_sdk not found
```bash
make setup-python
cd agent && .venv/bin/python -c "import claude_agent_sdk; print('OK')"
```

### "code-server installer script failed"
```bash
curl --version
curl -fsSL https://code-server.dev/install.sh | sh
```

### Build errors
```bash
bal clean && make setup-bal
```

### Playwright MCP not available
```bash
npm install -g @playwright/mcp@latest
```

### Screenshots not cropped
```bash
make crop-screenshots
# or preview first:
make crop-screenshots-dry
```

---

## Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| Ballerina | 2201.12.0+ | Pipeline orchestration |
| Python | 3.11+ | Claude Agent SDK server + post-processing scripts (`agent/`) |
| uv | latest | Python venv & dependency management |
| Anthropic API | Claude Sonnet 4.6 | Execution prompt generation & doc enforcement |
| Claude Code CLI | latest | Required by Agent SDK to spawn subagent |
| Claude Agent SDK | latest | Agentic browser automation execution |
| Playwright MCP | latest | Browser control via MCP |
| Node.js | LTS+ | npm / npx for Playwright |
| code-server | latest | In-browser VS Code (automation target) |

---

## References

- [Ballerina](https://ballerina.io/)
- [Anthropic API](https://docs.anthropic.com/)
- [Claude Agent SDK](https://github.com/anthropics/claude-agent-sdk)
- [Claude Code CLI](https://claude.ai/code)
- [Playwright](https://playwright.dev/)
- [Playwright MCP](https://github.com/anthropics/playwright-mcp)
- [Model Context Protocol](https://spec.modelcontextprotocol.io/)
- [uv — Python package manager](https://docs.astral.sh/uv/)
- [aiohttp](https://docs.aiohttp.org/)
- [code-server](https://github.com/coder/code-server)
- [WSO2 Integrator](https://wso2.com/integrator/)
- [Ballerina Central](https://central.ballerina.io/)

---

## Developer Notes & Insights

### Why do we have both .mcp.json and mcp_servers in Python?

The project uses **two layers** of Claude agents:

1. **Top-level agent** (Python `agent_server.py`) — configured via `ClaudeAgentOptions` with `mcp_servers` dict
2. **Subagent** (spawned by Task tool) — a Claude Code instance that reads `.mcp.json` from the CWD

When the Agent SDK spawns a subagent via the `Task` tool, that subagent is a **Claude Code** process. Claude Code automatically discovers MCP servers by reading `.mcp.json` from the current working directory. This is why you'll see logs like:

```
[TOOL] Bash → {'command': 'cat .mcp.json', ...}
[TOOL] Bash → {'command': 'ls .claude/', ...}
```

**Do NOT remove these files** — they're essential for the subagent to access Playwright MCP for browser automation.

| File | Purpose |
|------|---------|
| `.mcp.json` | Configures Playwright MCP for Claude Code subagent |
| `.claude/settings.json` | Sets permissions & model for Claude Code subagent |
| `agent_server.py` (mcp_servers) | Configures MCP for top-level agent (if it needs tools directly) |

### Why is `CLAUDECODE` unset when starting the agent server?

`make start-agent` runs `unset CLAUDECODE` before launching `agent_server.py`. This prevents a conflict when the server is started from within an active Claude Code session — the Agent SDK needs to spawn its own Claude Code subprocess, which fails if `CLAUDECODE` is already set in the environment.

---

**Last Updated:** March 19, 2026
