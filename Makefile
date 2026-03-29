.PHONY: help setup setup-python setup-bal build run \
        start-agent stop-agent \
        crop-screenshots crop-screenshots-dry crop-screenshots-backup \
        publish-docs publish-docs-dry publish-docs-no-preview publish-docs-no-pr \
        cleanup cleanup-dry \
        clean clean-artifacts

# ── Default ──────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "Connector Docs Automation — available targets"
	@echo ""
	@echo "  Setup"
	@echo "    make setup            Install all dependencies (Ballerina + Python)"
	@echo "    make setup-python     Create python/.venv and install Python deps"
	@echo "    make setup-bal        Build the Ballerina project"
	@echo ""
	@echo "  Run"
	@echo "    make run              Run the full pipeline (bal run)"
	@echo "    make start-agent      Start the Python agent server in the foreground"
	@echo "    make stop-agent       Send shutdown request to the agent server"
	@echo ""
	@echo "  Publish"
	@echo "    make publish-docs             Publish docs + create PR (auto-detects docs-integrator path)"
	@echo "    make publish-docs-dry         Dry run — print planned actions, no changes"
	@echo "    make publish-docs-no-preview  Publish docs without Playwright preview screenshots"
	@echo "    make publish-docs-no-pr       Push branch + commit only, skip PR creation"
	@echo "    PUBLISH_ARGS='...'            Pass extra flags, e.g. PUBLISH_ARGS='--category messaging'"
	@echo "    DOCS_REPO=PATH                Override docs-integrator path"
	@echo "    DOCS_UPSTREAM=OWNER/REPO      Override docs PR target repo (.env: DOCS_INTEGRATOR_UPSTREAM)"
	@echo "    DOCS_BASE_BRANCH=BRANCH       Override docs PR base branch (.env: DOCS_INTEGRATOR_BASE_BRANCH)"
	@echo ""
	@echo "  Cleanup"
	@echo "    make cleanup                  Publish integration sample PR + delete local project + close tabs"
	@echo "    make cleanup-dry              Dry run — print planned actions, no changes"
	@echo "    CODE_SERVER_PORT=N            Override code-server port (.env: CODE_SERVER_PORT)"
	@echo "    AGENT_SERVER_PORT=N           Override agent server port (.env: AGENT_SERVER_PORT)"
	@echo "    SAMPLES_REPO=PATH             Override integration-samples path (.env: INTEGRATION_SAMPLES_REPO)"
	@echo "    INTEGRATION_UPSTREAM=OWNER/REPO  Override samples PR target repo (.env: INTEGRATION_SAMPLES_UPSTREAM)"
	@echo "    INTEGRATION_BASE_BRANCH=BRANCH   Override samples PR base branch (.env: INTEGRATION_SAMPLES_BASE_BRANCH)"
	@echo "    PROJECT_PATH=PATH             Manually set project path (writes created-project.txt)"
	@echo "    NO_PR=1                       Push branch but skip PR creation"
	@echo "    CLEANUP_ARGS='...'            Pass extra flags, e.g. CLEANUP_ARGS='--no-publish'"
	@echo ""
	@echo "  Artifacts"
	@echo "    make clean            Remove artifacts/, target/, Dependencies.toml, python/.venv"
	@echo "    make clean-artifacts  Remove only the artifacts/ directory"
	@echo ""

# ── Setup ────────────────────────────────────────────────────────────────────
setup: setup-python setup-bal
	@echo "Setup complete."

# Sentinel file: rebuilt whenever requirements.txt changes or .venv is missing.
python/.venv/.installed: python/requirements.txt
	@echo "→ Creating python/.venv and installing Python dependencies..."
	cd python && uv venv
	cd python && uv pip install -r requirements.txt
	cd python && .venv/bin/playwright install chromium
	touch python/.venv/.installed
	@echo "Python setup complete."

setup-python: python/.venv/.installed
	@echo "Python environment is ready. Activate with: source python/.venv/bin/activate"

setup-bal:
	@echo "→ Building Ballerina project..."
	bal build
	@echo "Ballerina build complete."

# ── Run ──────────────────────────────────────────────────────────────────────
run:
	@echo "→ Running full pipeline..."
	bal run

crop-screenshots: python/.venv/.installed
	python/.venv/bin/python python/crop_screenshots.py

crop-screenshots-dry: python/.venv/.installed
	python/.venv/bin/python python/crop_screenshots.py --dry-run

crop-screenshots-backup: python/.venv/.installed
	python/.venv/bin/python python/crop_screenshots.py --backup

start-agent: python/.venv/.installed
	@echo "→ Starting Python agent server (python/agent_server.py)..."
	cd python && unset CLAUDECODE && .venv/bin/python agent_server.py

AGENT_SERVER_PORT ?= 8765

stop-agent:
	@echo "→ Sending shutdown to agent server..."
	curl -s -X POST http://localhost:$(AGENT_SERVER_PORT)/shutdown || echo "Agent server not running."

# ── Publish docs ─────────────────────────────────────────────────────────────
# Defaults are read from .env by publish_docs.py.
# Set these Makefile vars to override .env values for a single run.
# DOCS_REPO          — override the docs-integrator path
# DOCS_UPSTREAM      — GitHub org/repo for docs-integrator PRs
# DOCS_BASE_BRANCH   — base branch for docs-integrator PRs
# PUBLISH_ARGS       — extra flags passed to publish_docs.py

DOCS_REPO ?=
DOCS_UPSTREAM ?=
DOCS_BASE_BRANCH ?=

_publish_docs_cmd = python/.venv/bin/python python/publish_docs.py \
  $(if $(DOCS_REPO),--docs-repo "$(DOCS_REPO)",) \
  $(if $(DOCS_UPSTREAM),--upstream "$(DOCS_UPSTREAM)",) \
  $(if $(DOCS_BASE_BRANCH),--base-branch "$(DOCS_BASE_BRANCH)",) \
  $(PUBLISH_ARGS)

publish-docs: python/.venv/.installed
	@echo "→ Publishing connector docs..."
	$(_publish_docs_cmd)

publish-docs-dry: python/.venv/.installed
	@echo "→ Publishing connector docs (dry run)..."
	$(_publish_docs_cmd) --dry-run

publish-docs-no-preview: python/.venv/.installed
	@echo "→ Publishing connector docs (no preview)..."
	$(_publish_docs_cmd) --no-preview

publish-docs-no-pr: python/.venv/.installed
	@echo "→ Publishing connector docs (branch + commit only, no PR)..."
	$(_publish_docs_cmd) --no-pr

# ── Publish sample ────────────────────────────────────────────────────────────
# Defaults are read from .env by publish_sample.py.
# Set these Makefile vars to override .env values for a single run.
# CODE_SERVER_PORT         — override code-server port
# SAMPLES_REPO             — override integration-samples path
# INTEGRATION_UPSTREAM     — GitHub org/repo for integration samples PRs
# INTEGRATION_BASE_BRANCH  — base branch for integration samples PRs
# NO_PR                    — set to 1 to push branch without creating a PR
# CLEANUP_ARGS             — extra flags passed to publish_sample.py

CODE_SERVER_PORT ?=
SAMPLES_REPO ?=
PROJECT_PATH ?=
INTEGRATION_UPSTREAM ?=
INTEGRATION_BASE_BRANCH ?=
NO_PR ?=

_cleanup_cmd = python/.venv/bin/python python/publish_sample.py \
  $(if $(CODE_SERVER_PORT),--url "http://localhost:$(CODE_SERVER_PORT)",) \
  $(if $(SAMPLES_REPO),--samples-repo "$(SAMPLES_REPO)",) \
  $(if $(PROJECT_PATH),--project-path "$(PROJECT_PATH)",) \
  $(if $(INTEGRATION_UPSTREAM),--upstream "$(INTEGRATION_UPSTREAM)",) \
  $(if $(INTEGRATION_BASE_BRANCH),--base-branch "$(INTEGRATION_BASE_BRANCH)",) \
  $(if $(NO_PR),--no-pr,) \
  $(CLEANUP_ARGS)

cleanup: python/.venv/.installed
	@echo "→ Publishing integration sample, deleting local project, closing tabs..."
	$(_cleanup_cmd)

cleanup-dry: python/.venv/.installed
	@echo "→ Cleanup dry run..."
	$(_cleanup_cmd) --dry-run

# ── Artifacts ────────────────────────────────────────────────────────────────
clean:
	@echo "→ Cleaning artifacts/, target/, Dependencies.toml, python/.venv..."
	rm -rf artifacts/ target/ Dependencies.toml python/.venv
	@echo "Done."

clean-artifacts:
	@echo "→ Removing artifacts/ directory..."
	rm -rf artifacts/
