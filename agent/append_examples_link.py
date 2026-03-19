#!/usr/bin/env python3
"""
append_examples_link.py

Post-processing step: checks whether the connector has an examples section on
Ballerina Central and appends a '## More Examples' section to the workflow doc
if the check succeeds.

Usage: python append_examples_link.py <doc_path>

Verification strategy:
  1. Extract connector name from the H1 title of the doc.
  2. Query the Ballerina Central registry API to confirm the package exists.
  3. Fetch the connector's package page and check whether the HTML contains an
     'examples' anchor (present when the connector has an Examples tab).
  4. Append the section only if both checks pass.
"""

import json
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

REGISTRY_API = "https://api.central.ballerina.io/2.0/registry/packages/ballerinax/{name}"
CENTRAL_PAGE = "https://central.ballerina.io/ballerinax/{name}/latest"
EXAMPLES_URL  = "https://central.ballerina.io/ballerinax/{name}/latest#examples"


def extract_connector_name(doc_content: str) -> str | None:
    """Return lowercase connector name from '# [Name] Connector Example' title."""
    match = re.match(r"^#\s+(\w+)\s+Connector\s+Example", doc_content.strip(), re.IGNORECASE)
    return match.group(1).lower() if match else None


def package_exists_on_central(connector_name: str) -> bool:
    """Return True if the ballerinax/[connector] package is found in the registry."""
    url = REGISTRY_API.format(name=connector_name)
    try:
        req = Request(url, headers={"Accept": "application/json"})
        with urlopen(req, timeout=10) as resp:
            return resp.status == 200
    except (HTTPError, URLError):
        return False


def has_examples_section(connector_name: str) -> bool:
    """
    Return True if the connector's Ballerina Central page contains an examples
    section anchor. The page HTML is checked for 'id="examples"' or the
    navigation tab label 'Examples', which are present when examples exist.
    """
    url = CENTRAL_PAGE.format(name=connector_name)
    try:
        req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urlopen(req, timeout=10) as resp:
            if resp.status != 200:
                return False
            html = resp.read().decode("utf-8", errors="replace")
            # Ballerina Central includes an 'Examples' tab anchor in the HTML
            # when the connector ships example code.
            return (
                'id="examples"' in html
                or '"examples"' in html
                or ">Examples<" in html
                or "examples" in html.lower()
            )
    except (HTTPError, URLError):
        return False


def build_examples_section(connector_name: str) -> str:
    display_name = connector_name.capitalize()
    url = EXAMPLES_URL.format(name=connector_name)
    return (
        "\n## More Examples\n\n"
        f"For additional usage patterns and real-world scenarios, browse the "
        f"[{display_name} connector examples]({url}) on Ballerina Central.\n"
    )


def main() -> None:
    if len(sys.argv) < 2:
        print("[WARN] append_examples_link: no doc path provided — skipping.")
        sys.exit(0)

    doc_path = Path(sys.argv[1])
    if not doc_path.exists():
        print(f"[WARN] append_examples_link: doc not found at {doc_path} — skipping.")
        sys.exit(0)

    content = doc_path.read_text(encoding="utf-8")

    # Idempotency: don't append if already present
    if "central.ballerina.io" in content:
        print("[INFO] append_examples_link: examples link already present — skipping.")
        sys.exit(0)

    connector_name = extract_connector_name(content)
    if not connector_name:
        print("[WARN] append_examples_link: could not extract connector name from doc title — skipping.")
        sys.exit(0)

    print(f"[INFO] append_examples_link: checking Ballerina Central for '{connector_name}'...")

    if not package_exists_on_central(connector_name):
        print(f"[INFO] append_examples_link: package 'ballerinax/{connector_name}' not found on Central — skipping.")
        sys.exit(0)

    if not has_examples_section(connector_name):
        print(f"[INFO] append_examples_link: no examples section found for '{connector_name}' — skipping.")
        sys.exit(0)

    doc_path.write_text(content.rstrip() + "\n" + build_examples_section(connector_name), encoding="utf-8")
    print(f"[INFO] append_examples_link: appended examples link for '{connector_name}'.")


if __name__ == "__main__":
    main()
