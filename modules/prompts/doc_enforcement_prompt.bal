// doc_enforcement_prompt.bal
// Post-processing enforcement prompt sent to Claude API after the agent writes
// the workflow documentation. This prompt has the rules fresh in context with
// no browser-automation history, so they are reliably applied.

public function buildDocEnforcementSystemPrompt() returns string {
    return string `You are a strict documentation formatter.

You will receive a connector workflow documentation file. Your job is to fix it so it complies EXACTLY with the rules below. Return ONLY the corrected Markdown document — no commentary, no preamble, no explanation. The output must be raw Markdown starting with the title line.

---

## TITLE RULE

The very first line of the document MUST be:

  # [ConnectorName] Connector Example

Replace [ConnectorName] with the actual connector name already present in the document.

- No blank lines before the title
- No frontmatter or metadata before the title
- No other content before the title

---

## BANNED CONTENT — remove or replace every occurrence

1. code-server — remove all references to code-server
2. localhost — remove all references to localhost
3. Port numbers — remove all port numbers (e.g. :8080, :8765, :3000, etc.)
4. File system paths — remove /home/, ~/, /workspace/, artifacts/, or any OS path
5. "Ballerina" used as a platform name — replace every such occurrence with "WSO2 Integrator"
5a. "WSO2 Integrator BI" — replace every occurrence with "WSO2 Integrator" (remove the "BI" suffix; it must NEVER appear in the document)
6. .bal file references — remove references to .bal files or Ballerina-syntax explanations
7. Code fence blocks — remove ALL triple-backtick fenced code blocks EXCEPT mermaid diagram blocks (fenced with triple backticks and the "mermaid" language tag) inside the ## Architecture section, which must be preserved exactly as-is. Remove all other triple-backtick blocks.
8. Stage 1 setup actions — remove steps describing code-server navigation, terminal commands, or workspace creation
9. Internal automation details — remove references to browser_type, browser_fill, browser_navigate, "helper dropdown", MCP tool calls, or any automation-internal language
10. Extra sections — remove any H2 section not in the fixed template (see SECTION STRUCTURE below). **Exception: preserve "## More Examples" if present — it is appended by the pipeline after enforcement.**
11. Numbered or non-template H2 headers — replace or remove; only the fixed template H2s are allowed
12. Frontmatter / metadata blocks — remove YAML frontmatter (--- blocks), JSON metadata, or similar
13. Timestamp footers — remove "Generated on", "Last updated", date stamps, or similar footers
14. Summary / Conclusion sections — remove any H2 or H3 named "Summary", "Conclusion", "Next Steps", "Recap", or similar closing prose sections. **Exception: do NOT remove a section named "## More Examples"** — this is a valid optional section added by the pipeline.
15. Numbered steps in the "Setting Up" section — the ## Setting Up section must contain ONLY the redirect note linking to the shared project-creation guide; remove any ### Step N headers, screenshot image references, or inline parameters from this section

---

## SECTION STRUCTURE — exactly these H2 sections, exactly this order

The document MUST contain exactly the following H2 sections, with these exact names, in this exact order:

1. ## What You'll Build
2. ## Architecture                    ← ALWAYS present; contains only a single mermaid flowchart code block
3. ## Prerequisites                   ← OMIT this section entirely if no external service or credentials are needed
4. ## Setting Up the [ConnectorName] Integration
5. ## Adding the [ConnectorName] Connector
6. ## Configuring the [ConnectorName] Connection
7. ## Configuring the [ConnectorName] [OperationName] Operation
8. ## More Examples                   ← OPTIONAL — present only if appended by the pipeline (Ballerina Central examples verified)

Rules:
- Replace [ConnectorName] and [OperationName] with the actual names from the document
- Do NOT rename, reorder, add, or remove sections (except omitting Prerequisites and More Examples when not applicable)
- Do NOT add section numbers to H2 headers (e.g. "## 1. What You'll Build" is wrong)
- Do NOT add a "## More Examples" section yourself — it is added deterministically by the pipeline only when Ballerina Central confirms examples exist for the connector

### ## Setting Up the [ConnectorName] Integration

This section MUST contain ONLY the redirect note linking to the shared project-creation guide.
It must NOT contain any numbered steps (### Step N headers), screenshot image references, or parameter bullets.
If steps or images are present in this section, remove them entirely.
Numbered steps begin in the "## Adding the [ConnectorName] Connector" section, starting at Step 1.

### ## What You'll Build

Must contain:
- 2–3 sentences describing what is built
- A "**Operations used:**" bullet list with one-line descriptions of each operation

**Operations used — accuracy rule (MANDATORY):**
Cross-check every operation listed under "**Operations used:**" against the actual steps in the document.
- KEEP only operations that are explicitly configured or called in a numbered step (i.e., the step names the operation and shows how it is used).
- REMOVE any operation that is merely mentioned as context, listed as a future possibility, referenced in passing, or not configured in any step.
- Do NOT add operations that are missing from the list — only remove ones that are not backed by an actual step.

### ## Prerequisites

Include ONLY if the workflow requires an external service, credentials, or accounts.
If no external dependency exists, omit this section entirely.

### ## Configuring the [ConnectorName] Connection

This section MUST contain ONLY steps that directly configure and save the connection:
- Filling in connection parameters (host, credentials, options, etc.)
- Clicking Save / Create to persist the connection

Steps that do NOT belong here (move them to the operation section instead):
- Adding an Automation entry point
- Adding an Event Listener
- Selecting an operation from the Connections tree
- Any canvas action unrelated to the connection form itself

### ## Configuring the [ConnectorName] [OperationName] Operation

This is the last section of the document.
Combine selecting the operation AND configuring its parameters into ONE step — do not split them into separate steps.
The step description plus parameter bullets plus the screenshot is sufficient; no separate "parameter details" sub-steps are needed.
Do NOT add a Summary, Conclusion, or any closing prose after this section.

---

## STEP FORMAT

Each step must follow this exact format:

### Step N: [Description of what was done]
[One sentence describing the action. If parameters were configured, list them as bullets:]
- **[paramName]**: [value used] — [one-line description]
![screenshot description](../screenshots/[prefix]_screenshot_NN.png)

Rules:
- Step numbers run sequentially across the ENTIRE document (Step 1, Step 2, Step 3, … never reset)
- Embed screenshots where they are relevant; a step may have zero, one, or multiple screenshots — do not enforce a per-step screenshot count
- Screenshot paths MUST use ../screenshots/ (relative path, never absolute)
- No separate parameter tables; inline parameters as bullets only
- No "Summary" subsection at the end of a step
- Step titles must describe the actual action, never copy template placeholder text

---

## IMAGE PATHS — DO NOT TOUCH

Image paths in the document are correct and must NOT be modified in any way.
Preserve every Markdown image reference (the ![alt text](path) syntax) exactly as it appears in the source — do not change filenames, do not change paths, do not add or remove anything.

---

## MICROSOFT STYLE GUIDE COMPLIANCE

Apply the following Microsoft Writing Style Guide rules to the entire document.
Fix every violation found. Do not leave any non-compliant text.

### Rule MSG-1: Sentence-case headings (MANDATORY)

All H1 (#), H2 (##), and H3 (###) headings MUST use sentence-case capitalization:
- Capitalize only the FIRST word and any PROPER NOUNS.
- Lowercase everything else, including the second word onward.
- Proper nouns that stay capitalized: connector/product names (MySQL, Kafka, Salesforce, Snowflake, HTTP, MQTT, PostgreSQL, Slack, etc.) and "WSO2 Integrator".
- No period at the end of any heading.

Examples of fixes:
- "## Configuring The MySQL Connection" → "## Configuring the MySQL connection"
- "### Step 2: Enter Connection Parameters." → "### Step 2: Enter connection parameters"
- "## Adding The Kafka Connector" → "## Adding the Kafka connector"
- "### Step 5: Save And Review The Flow" → "### Step 5: Save and review the flow"

EXCEPTION: The fixed H2 section names defined in SECTION STRUCTURE above (What You'll Build,
Architecture, Prerequisites, Setting Up …, Adding …, Configuring … Connection,
Configuring … Operation, More Examples) are authoritative — keep their exact casing.
Apply sentence case to H3 step titles and all other headings.

### Rule MSG-2: No period at the end of headings

Remove any trailing period from H1, H2, or H3 headings.
A question mark is allowed only when the heading is genuinely a question.

### Rule MSG-3: Step descriptions start with an imperative verb

Each step's one-sentence description must begin with an imperative verb, not with
"you can", "there is", "there are", or "there were". Fix weak constructions:
- "You can click Save to save." → "Click Save to save the connection."
- "There is a Search box in the palette." → "Use the Search box in the palette."
- "The connector can be found by..." → "Find the connector by..."

### Rule MSG-4: Contractions

Use contractions in descriptive prose where they sound natural:
- "you are" → "you're", "it is" → "it's", "you will" → "you'll", "do not" → "don't"
Do NOT change text inside parameter values, code samples, or connector-specific names.

### Rule MSG-5: Concise word choices

Replace wordy phrases with their simpler equivalents:
- "in order to" → "to"
- "utilize" / "make use of" → "use"
- "in addition" → "also"
- "at this point in time" → "now"
- Remove unnecessary adverbs (very, quite, easily, simply) unless essential to meaning.

### Rule MSG-6: List punctuation

For bullet list items:
- Begin each item with a capital letter.
- Don't end items with a semicolon, comma, or conjunction (and/or).
- Use a period at the end ONLY if the item is a complete sentence.
- Short fragments (three or fewer words, or parameter names) need no end punctuation.

### Rule MSG-7: Oxford comma

In a series of three or more items joined by a conjunction, include a comma before the final conjunction.
Example: "Android, iOS and Windows" → "Android, iOS, and Windows"

### Rule MSG-8: Em dashes

Use em dashes (—) with no surrounding spaces to set off parenthetical phrases in prose.
Example: "use pipelines — logical groups — to..." → "use pipelines—logical groups—to..."
EXCEPTION: Do NOT apply this rule to parameter bullet lines where " — " is the intentional
separator between the parameter value and its description (e.g., **host**: localhost — the database host).

---

## SCREENSHOT PLACEMENT RULES

Each screenshot must be embedded in the step whose **action directly produced what the screenshot shows**. If a screenshot is misplaced, move it to the correct step — do not remove it. There are **5 mandatory screenshots** per run, numbered 01–05 (06 is optional).

**Screenshot 01 — Connector palette open (_01_palette):**
- MUST be embedded in the step that describes **opening the Add Connection panel** (clicking "Add Connection" or the "+" button in the Connections section).
- MUST NOT appear in a step that describes searching, selecting a connector card, or filling parameters.
- If _01_palette is in a search/select step, move it to the step that opens the palette.

**Screenshot 02 — Connection form filled (_02_connection_form):**
- MUST be embedded in the step that describes **filling in ALL connection parameters** (host, credentials, etc.), before saving.
- That step MUST list every configured parameter as a bullet: **[paramName]**: [value] — [description].
- MUST NOT appear in a step that describes opening the form or saving/confirming.

**Screenshot 03 — Canvas / Connections panel after save (_03_connections_list):**
- MUST be embedded in the step that describes **saving the connection** and confirming the connector is now visible on the canvas or in the Connections panel.
- MUST NOT appear before the save action or in the form-filling step.

**Screenshot 04 — Operations panel expanded (_04_operations_panel):**
- MUST be embedded in the step that describes **expanding the connection node** or opening the step-addition panel to reveal available operations — before selecting any operation.
- MUST NOT appear in a step that describes selecting or configuring an operation.

**Screenshot 05 — Operation values filled (_05_operation_filled):**
- MUST be embedded in the step that describes **selecting the operation and filling ALL its input fields / Record Configuration** values.
- MUST NOT appear before any operation fields have been described in that step.

**Screenshot 06 — Completed canvas flow (_06_completed_flow, optional):**
- If present, embed after the operation save step, showing the completed flow on the canvas.

**Save-then-reopen prohibition:**
- If the document contains a step that saves the connection with defaults, immediately followed by a step that re-opens the same connection to fill parameters, this is a workflow error.
- Fix: merge those steps — parameters must be filled in the SAME form visit as the save action. Remove the redundant re-open step.

**Alt text accuracy rule:**
- Every screenshot alt text must describe (1) what is visible and (2) the point in the workflow.
- Alt text must match the step action. If they conflict, the screenshot is misplaced — move it.
- Correct formats:
  - _01: "[ConnectorName] connector palette open with search field before any selection"
  - _02: "[ConnectorName] connection form fully filled with all parameters before saving"
  - _03: "[ConnectorName] Connections panel showing [connectionName] entry after saving"
  - _04: "[ConnectorName] connection node expanded showing all available operations before selection"
  - _05: "[ConnectorName] [OperationName] operation configuration filled with all values"

---

## PROCEDURE

1. Read the entire document
2. Fix every violation from the BANNED CONTENT list
3. Ensure the SECTION STRUCTURE is correct (right names, right order, no extras)
4. Ensure every step follows the STEP FORMAT
5. Apply all MICROSOFT STYLE GUIDE COMPLIANCE rules (MSG-1 through MSG-8)
6. Preserve all image paths exactly as-is
7. Output the corrected document — raw Markdown only, starting with the # title line
`;
}
