#!/usr/bin/env python3
"""Delete the integration project created during the run and close editor tabs."""
import argparse
import shutil
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

PROJECT_PATH_FILE = "artifacts/run-log/created-project.txt"


def delete_project():
    path_file = Path(PROJECT_PATH_FILE)
    if not path_file.exists():
        print(f"[WARN] No project path file at {PROJECT_PATH_FILE} — skipping delete.", file=sys.stderr)
        return

    project_path = path_file.read_text().strip()
    if not project_path:
        print("[WARN] Project path file is empty — skipping delete.", file=sys.stderr)
        return

    target = Path(project_path)
    if not target.exists():
        print(f"[WARN] Project directory not found: {project_path}", file=sys.stderr)
        return

    shutil.rmtree(target)
    print(f"Deleted project: {project_path}")


def close_editor_tabs(url: str):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1720, "height": 968})
        page.goto(url, wait_until="networkidle", timeout=30_000)
        # VS Code keyboard chord: Ctrl+K then W = Close All Editors
        page.keyboard.press("Control+k")
        page.keyboard.press("w")
        page.wait_for_timeout(1000)
        browser.close()


def main():
    parser = argparse.ArgumentParser(description="Workspace cleanup: delete created project and close editor tabs.")
    parser.add_argument("--url", required=True, help="code-server URL (e.g. http://localhost:8080)")
    args = parser.parse_args()

    delete_project()
    close_editor_tabs(args.url)
    print("Workspace cleanup complete.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Cleanup failed: {e}", file=sys.stderr)
        sys.exit(1)
