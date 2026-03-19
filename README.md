# Connector Docs Automation

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
| code-server | latest | [github.com/coder/code-server](https://github.com/coder/code-server) |

### Setup

**1. Clone and enter project**

```bash
cd connector-docs-automation
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
# Install Ballerina deps + create agent/.venv + install Python deps
make setup

# Or step by step:
make setup-python   # creates agent/.venv, installs aiohttp + claude-agent-sdk
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

> The same key also goes into `Config.toml` as `anthropicApiKey` for the Ballerina steps.

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
├── main.bal                         # Entry point — orchestrates the 8-step pipeline
├── Ballerina.toml                   # Ballerina package manifest & dependencies
├── Config.toml                      # Runtime configuration (git-ignored)
├── Config.toml.example              # Template for Config.toml
├── Dependencies.toml                # Resolved Ballerina dependency lock file
├── Makefile                         # All common commands (setup, run, clean, etc.)
│
├── agent/                           # Python Claude Agent SDK server
│   ├── agent_server.py              # aiohttp HTTP server wrapping claude-agent-sdk
│   ├── pyproject.toml               # Python package manifest
│   ├── requirements.txt             # Pinned Python dependencies
│   └── .venv/                       # Python virtual environment (git-ignored)
│
├── modules/                         # Ballerina sub-modules
│   ├── ai_client/
│   │   └── ai_client.bal            # Claude API calls (validate, generate, slug)
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
├── scripts/                         # Utility scripts (cross-platform)
│   ├── cleanup.sh / cleanup.ps1     # Remove generated artifacts and build output
│   └── convert-to-pdf.sh / .ps1    # Convert workflow docs to PDF
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
    └── screenshots/                 # Captured browser screenshots
```

---

## Makefile Reference

```
make help             Show this reference

Setup
  make setup          Install all deps (Python venv + Ballerina build)
  make setup-python   Create agent/.venv and install Python deps
  make setup-bal      Build the Ballerina project (bal build)

Run
  make run            Run the full 8-step pipeline (bal run)
  make start-agent    Start the Python agent server in the foreground
  make stop-agent     Send shutdown request to the running agent server

Artifacts
  make convert-pdf    Convert workflow-docs markdown files to PDF
  make clean          Remove all artifacts/ and target/ (with confirmation)
  make clean-artifacts Remove only the artifacts/ directory
```

---

## How It Works

```
┌──────────────────────────────┐
│  Goal defined in Config.toml  │
└──────────────┬───────────────┘
               │
    ┌──────────▼──────────────────────────────────────────┐
    │  Step 0a: Is code-server installed?                  │
    │  code-server --version                               │
    └──────────┬──────────────────────┬───────────────────┘
               │ installed            │ not installed
               │                      ▼
               │           ┌──────────────────────┐
               │           │  curl -fsSL           │
               │           │  code-server.dev/     │
               │           │  install.sh | sh      │
               │           └──────────┬────────────┘
               │                      │ success / error
               └──────────────────────┘
               │
    ┌──────────▼──────────────────────────────────────────┐
    │  Step 0b: Is code-server running?                    │
    │  curl http://localhost:<port> (3s timeout)           │
    └──────────┬──────────────────────┬───────────────────┘
               │ already running      │ not running
               │                      ▼
               │           ┌──────────────────────┐
               │           │  Auto-start:          │
               │           │  code-server          │
               │           │  --auth none          │
               │           │  --bind-addr          │
               │           │  0.0.0.0:<port>       │
               │           └──────────┬────────────┘
               │                      │ poll (15 attempts)
               └──────────────────────┘
               │
    ┌──────────▼──────────┐
    │  Step 1: Validate    │
    │  Anthropic API key   │
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │  Step 2: Build       │
    │  system + user       │
    │  prompts             │
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │  Step 3: Claude API  │
    │  (Sonnet 4.6) generates│
    │  XML-tagged prompt   │
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │  Step 4: Claude      │
    │  generates filename  │
    │  slug from goal      │
    └──────────┬──────────┘
               │
    ┌──────────▼────────────────────────┐
    │  Step 5: Format prompt with       │
    │  XML header                       │
    └──────────┬────────────────────────┘
               │
    ┌──────────▼────────────────────────┐
    │  Step 6: Save to                  │
    │  artifacts/execution-prompt/      │
    │  → returns file path              │
    └──────────┬────────────────────────┘
               │
    ┌──────────▼──────────────────────────────────────────┐
    │  Step 7: Is Python agent server running?             │
    │  curl http://localhost:<agentPort>/health (3s)       │
    └──────────┬──────────────────────┬───────────────────┘
               │ already running      │ not running
               │                      ▼
               │           ┌──────────────────────┐
               │           │  cd agent &&          │
               │           │  uv run               │
               │           │  agent_server.py      │
               │           │  --port <agentPort>   │
               │           └──────────┬────────────┘
               │                      │ poll /health (20 attempts)
               └──────────────────────┘
               │
    ┌──────────▼──────────────────────────┐
    │  Step 8: POST /run to agent server   │
    │  { "prompt_path": "<path>" }         │
    │  Poll /jobs/<id> every 1s            │
    │  Stream [SESSION/CLAUDE/TOOL/RESULT] │
    │  logs until status == "done"         │
    └──────────┬──────────────────────────┘
               │
    ┌──────────▼──────────────────────────┐
    │  artifacts/screenshots/             │
    │  artifacts/workflow-docs/           │
    │  artifacts/execution-prompt/        │
    └─────────────────────────────────────┘
```

### Step descriptions

1. **Step 0a — code-server install** — Runs `code-server --version`. If not found, installs via the official `curl` script.
2. **Step 0b — code-server start** — Probes `http://localhost:<port>`. If not running, spawns code-server and polls for up to 15 s.
3. **Step 1 — API validation** — Minimal Anthropic API ping before running the expensive steps.
4. **Step 2 — Prompt building** — Constructs the system prompt (XML-tagged template) and user message with goal + code-server URL.
5. **Step 3 — Prompt generation** — Calls Claude Sonnet 4.6 (up to 16 000 tokens) to produce the execution prompt.
6. **Step 4 — Slug generation** — Second Claude call produces a 3–4 word filename-safe slug.
7. **Step 5 — Format** — Prepends a Markdown metadata header.
8. **Step 6 — Save** — Writes to `artifacts/execution-prompt/<slug>_execution_prompt_<timestamp>.md` and returns the path.
9. **Step 7 — Agent server check** — Probes `/health`. If not running, spawns `cd agent && uv run agent_server.py --port <agentPort>` and polls for up to 20 s.
10. **Step 8 — Agentic execution** — POSTs the prompt path to `/run`, receives a `job_id`, then polls `/jobs/<id>` every second printing coloured `[SESSION]`, `[CLAUDE]`, `[TOOL]`, `[RESULT]`, `[USAGE]` log lines until done.

---

## Configuration

```bash
cp Config.toml.example Config.toml
```

```toml
# Anthropic API Key (required)
anthropicApiKey = "sk-ant-..."

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
| `GET` | `/jobs/<id>` | Poll job: `{ "status": "running\|done", "logs": [...] }` |
| `GET` | `/health` | Health check: `{ "status": "ok" }` |
| `POST` | `/shutdown` | Gracefully stop the server |

### Python setup

```bash
# Create venv inside agent/ and install deps
make setup-python

# Or manually:
cd agent
uv venv                          # creates agent/.venv
uv pip install -r requirements.txt
```

### Start / stop manually

```bash
make start-agent    # foreground: cd agent && uv run agent_server.py
make stop-agent     # curl -X POST http://localhost:8765/shutdown

# Custom port:
cd agent && uv run agent_server.py --port 9000
```

---

## code-server

The automation target is a **code-server** instance (VS Code in the browser) with the **WSO2 Integrator** extension installed. Start it manually if needed:

```bash
code-server --auth none --bind-addr 0.0.0.0:8080
```

Or let the pipeline handle it automatically (Step 0b).

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
| Setup Python venv | `make setup-python` | `cd agent && uv venv && uv pip install -r requirements.txt` |
| Build Ballerina | `make setup-bal` | `bal build` |
| Run pipeline | `make run` | `bal run` |
| Start agent server | `make start-agent` | `cd agent && uv run agent_server.py` |
| Stop agent server | `make stop-agent` | `curl -X POST http://localhost:8765/shutdown` |
| Convert docs to PDF | `make convert-pdf` | `./scripts/convert-to-pdf.sh` |
| Clean everything | `make clean` | `./scripts/cleanup.sh --force` |
| Clean artifacts only | `make clean-artifacts` | `rm -rf artifacts/` |

---

## Troubleshooting

### "Anthropic API key validation failed"
```bash
cp Config.toml.example Config.toml
# Set anthropicApiKey in Config.toml
export ANTHROPIC_API_KEY="sk-ant-..."
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
cd agent && uv run python -c "import claude_agent_sdk; print('OK')"
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

---

## Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| Ballerina | 2201.12.0+ | Pipeline orchestration |
| Python | 3.11+ | Claude Agent SDK server (`agent/`) |
| uv | latest | Python venv & dependency management |
| Anthropic API | Claude Sonnet 4.6 | Execution prompt generation |
| Claude Agent SDK | latest | Agentic browser automation execution |
| Playwright MCP | latest | Browser control via MCP |
| Node.js | LTS+ | npm / npx for Playwright |
| code-server | latest | In-browser VS Code (automation target) |

---

## References

- [Ballerina](https://ballerina.io/)
- [Anthropic API](https://docs.anthropic.com/)
- [Claude Agent SDK](https://github.com/anthropics/claude-agent-sdk)
- [Playwright](https://playwright.dev/)
- [Playwright MCP](https://github.com/anthropics/playwright-mcp)
- [Model Context Protocol](https://spec.modelcontextprotocol.io/)
- [uv — Python package manager](https://docs.astral.sh/uv/)
- [aiohttp](https://docs.aiohttp.org/)
- [code-server](https://github.com/coder/code-server)
- [WSO2 Integrator](https://wso2.com/integrator/)

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


---

**Last Updated:** March 2, 2026
