.PHONY: help setup setup-python setup-bal build run \
        start-agent stop-agent \
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
	@echo "    make run              Run the full 8-step pipeline (bal run)"
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

setup-python:
	@echo "→ Creating agent/.venv and installing Python dependencies..."
	cd agent && uv venv
	cd agent && uv pip install -r requirements.txt
	@echo "Python setup complete. Activate with: source agent/.venv/bin/activate"

setup-bal:
	@echo "→ Building Ballerina project..."
	bal build
	@echo "Ballerina build complete."

# ── Run ──────────────────────────────────────────────────────────────────────
run:
	@echo "→ Running full pipeline..."
	bal run

start-agent:
	@echo "→ Starting Python agent server (agent/agent_server.py)..."
	cd agent && unset CLAUDECODE && uv run agent_server.py

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
