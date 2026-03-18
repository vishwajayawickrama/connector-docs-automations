#!/usr/bin/env python3
"""Close all editor tabs in the code-server instance (VS Code Close All Editors)."""
import argparse
import sys

from playwright.sync_api import sync_playwright


def main():
    parser = argparse.ArgumentParser(description="Workspace cleanup: close all editor tabs in code-server.")
    parser.add_argument("--url", required=True, help="code-server URL (e.g. http://localhost:8080)")
    args = parser.parse_args()

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1920, "height": 1080})
        page.goto(args.url, wait_until="networkidle", timeout=30_000)
        # VS Code keyboard chord: Ctrl+K then W = Close All Editors
        page.keyboard.press("Control+k")
        page.keyboard.press("w")
        page.wait_for_timeout(1000)
        browser.close()

    print("Workspace cleanup complete.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Cleanup failed: {e}", file=sys.stderr)
        sys.exit(1)
