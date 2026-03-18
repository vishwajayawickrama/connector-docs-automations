.PHONY: help setup setup-python setup-bal build run \
        start-agent stop-agent \
        crop-screenshots crop-screenshots-dry crop-screenshots-backup \
        clean clean-artifacts convert-pdf

# ── Default ──────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "Connector Docs Automation — available targets"
	@echo ""
	@echo "  Setup"
	@echo "    make setup            Install all dependencies (Ballerina + Python)"
	@echo "    make setup-python     Create agent/.venv and install Python deps"
	@echo "    make setup-bal        Build the Ballerina project"
	@echo ""
	@echo "  Run"
	@echo "    make run              Run the full 12-step pipeline (bal run + crop)"
	@echo "    make start-agent      Start the Python agent server in the foreground"
	@echo "    make stop-agent       Send shutdown request to the agent server"
	@echo ""
	@echo "  Artifacts"
	@echo "    make convert-pdf      Convert workflow-docs markdown files to PDF"
	@echo "    make clean            Remove all generated artifacts and build output"
	@echo "    make clean-artifacts  Remove only the artifacts/ directory"
	@echo ""

# ── Setup ────────────────────────────────────────────────────────────────────
setup: setup-python setup-bal
	@echo "Setup complete."

# Sentinel file: rebuilt whenever requirements.txt changes or .venv is missing.
agent/.venv/.installed: agent/requirements.txt
	@echo "→ Creating agent/.venv and installing Python dependencies..."
	cd agent && uv venv
	cd agent && uv pip install -r requirements.txt
	touch agent/.venv/.installed
	@echo "Python setup complete."

setup-python: agent/.venv/.installed
	@echo "Python environment is ready. Activate with: source agent/.venv/bin/activate"

setup-bal:
	@echo "→ Building Ballerina project..."
	bal build
	@echo "Ballerina build complete."

# ── Run ──────────────────────────────────────────────────────────────────────
run:
	@echo "→ Running full pipeline..."
	bal run

crop-screenshots: agent/.venv/.installed
	agent/.venv/bin/python agent/crop_screenshots.py

crop-screenshots-dry: agent/.venv/.installed
	agent/.venv/bin/python agent/crop_screenshots.py --dry-run

crop-screenshots-backup: agent/.venv/.installed
	agent/.venv/bin/python agent/crop_screenshots.py --backup

start-agent: agent/.venv/.installed
	@echo "→ Starting Python agent server (agent/agent_server.py)..."
	cd agent && unset CLAUDECODE && .venv/bin/python agent_server.py

stop-agent:
	@echo "→ Sending shutdown to agent server..."
	curl -s -X POST http://localhost:8765/shutdown || echo "Agent server not running."

# ── Artifacts ────────────────────────────────────────────────────────────────
convert-pdf:
	@echo "→ Converting workflow docs to PDF..."
	./scripts/convert-to-pdf.sh

clean:
	@echo "→ Cleaning all generated artifacts and build output..."
	./scripts/cleanup.sh --force

clean-artifacts:
	@echo "→ Removing artifacts/ directory..."
	rm -rf artifacts/
