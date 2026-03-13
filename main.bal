import ballerina/os;
import ballerina/time;

import ballerinaconnectors/documentation_automation_workflow.agent_client;
import ballerinaconnectors/documentation_automation_workflow.ai_client;
import ballerinaconnectors/documentation_automation_workflow.prompts;
import ballerinaconnectors/documentation_automation_workflow.utils;

// Configuration
configurable string llmApiKey = ?;
configurable string userGoal = ?;
configurable int codeServerPort = 8080;
configurable int agentServerPort = 8765;

# Entry point for the full automation pipeline.
#
# Phase 1  (Steps 1–2):  Pre-flight validation — API key and Claude Code CLI.
# Phase 2  (Steps 3–5):  Infrastructure     — code-server and Python agent server.
# Phase 3  (Steps 6–10): Prompt generation  — build, call Claude, format, save.
# Phase 4  (Steps 11–12): Agent execution  — run the Claude agent, crop screenshots.
#
# + return - an error if any step fails
public function main() returns error? {
    utils:log("=== Ballerina Execution Prompt Generator ===");
    utils:log("");

    time:Utc startTime = time:utcNow();
    utils:log("[INFO] Start time: " + time:utcToString(startTime));
    utils:log("[INFO] Goal: " + userGoal);
    utils:log("");

    // ── Phase 1: Pre-flight validation ─────────────────────────────────────

    // Step 1: Validate Anthropic API key with a small ping before doing anything else
    utils:log("[STEP 1] Validating Anthropic API key...");
    check ai_client:validateApiKey(llmApiKey);
    utils:log("");

    // Step 2: Check Claude Code CLI is installed (required for agent execution)
    utils:log("[STEP 2] Checking if Claude Code CLI is installed...");
    boolean claudeInstalled = utils:checkClaudeCodeInstalled();
    if !claudeInstalled {
        return error("Claude Code CLI ('claude') is not installed or not on PATH. " +
                     "Install it from https://claude.ai/code and re-run the pipeline.");
    }
    utils:log("\t[INFO] Claude Code CLI is installed.");
    utils:log("");

    // ── Phase 2: Infrastructure ─────────────────────────────────────────────

    // Step 3: Check if code-server binary is installed; install via official script if not
    utils:log("[STEP 3] Checking if code-server is installed...");
    boolean codeServerBinaryInstalled = utils:checkCodeServerInstalled();
    if !codeServerBinaryInstalled {
        utils:log("\t[INFO] code-server not found. Installing via official script (curl -fsSL https://code-server.dev/install.sh | sh)...");
        check utils:installCodeServer();
        utils:log("\t[INFO] code-server installed successfully.");
    } else {
        utils:log("\t[INFO] code-server is already installed.");
    }
    utils:log("");

    // Step 4: Verify code-server is running on the configured port, start if needed
    utils:log("[STEP 4] Verifying code-server on port " + codeServerPort.toString() + "...");
    boolean codeServerRunning = utils:checkCodeServerRunning(codeServerPort);
    if !codeServerRunning {
        utils:log("\t[INFO] Code-server not running. Starting code-server...");
        check utils:startCodeServer(codeServerPort);
        utils:log("\t[INFO] Code-server started successfully.");
    } else {
        utils:log("\t[INFO] Code-server is already running.");
    }
    string codeServerUrl = "http://localhost:" + codeServerPort.toString();
    utils:log("\t[INFO] Code-server URL: " + codeServerUrl);
    utils:log("");

    // Step 5: Check if the Python agent server is running; start it if not
    utils:log("[STEP 5] Checking Python agent server on port " + agentServerPort.toString() + "...");
    boolean agentRunning = utils:checkAgentServerRunning(agentServerPort);
    if !agentRunning {
        utils:log("\t[INFO] Agent server not running. Starting via `uv run agent_server.py`...");
        check utils:startAgentServer(agentServerPort);
        utils:log("\t[INFO] Agent server started.");
    } else {
        utils:log("\t[INFO] Agent server is already running.");
    }
    string agentUrl = "http://localhost:" + agentServerPort.toString();
    utils:log("\t[INFO] Agent server URL: " + agentUrl);
    utils:log("");

    // ── Phase 3: Prompt generation ──────────────────────────────────────────

    // Step 6: Build system and user prompts
    utils:log("[STEP 6] Building system and user prompts...");
    string projectRoot = os:getEnv("PWD");
    string systemPrompt = prompts:buildSystemPrompt();
    string userMessage = prompts:buildUserMessage(userGoal, codeServerUrl, projectRoot);

    // Step 7: Call Anthropic API to generate the execution prompt
    utils:log("[STEP 7] Calling Anthropic API to generate execution prompt...");
    string executionPrompt = check ai_client:callClaude(systemPrompt, userMessage, llmApiKey);

    // Step 8: Generate a short filename slug from the goal via LLM
    utils:log("[STEP 8] Generating short filename slug...");
    string goalSlug = check ai_client:generateGoalSlug(userGoal, llmApiKey);

    // Step 9: Add header to the generated prompt
    utils:log("[STEP 9] Formatting execution prompt...");
    string header = string `# Execution Prompt

<!-- ============================================================
     XML-TAGGED MARKDOWN EXECUTION PROMPT
     Generated by: Ballerina Execution Prompt Pipeline
     Agent: Playwright MCP (Browser Automation)
     Target: Code-Server — WSO2 Integrator: BI (Low-Code)
     Goal: ${userGoal}
     ============================================================ -->

`;
    string fullPrompt = header + executionPrompt;

    // Step 10: Save to file — returns the path used for the agent in Step 11
    utils:log("[STEP 10] Saving execution prompt to " + utils:OUTPUT_DIR + "...");
    string promptPath = check utils:saveExecutionPrompt(fullPrompt, goalSlug);
    utils:log("\t[INFO] Saved to: " + promptPath);
    utils:log("");

    // ── Phase 4: Agent execution ────────────────────────────────────────────

    // Step 11: Submit the execution prompt to the agent server and stream logs
    utils:log("[STEP 11] Running Claude agent...");
    check agent_client:runClaudeAgent(promptPath, agentUrl);
    utils:log("");

    // ── Phase 4 (cont.): Post-processing ────────────────────────────────────

    // Step 12: Crop UI chrome from screenshots produced by the agent
    utils:log("[STEP 12] Cropping screenshots...");
    os:Process|error cropProc = os:exec({
        value: "agent/.venv/bin/python",
        arguments: ["agent/crop_screenshots.py"]
    });
    if cropProc is error {
        utils:log("\t[WARN] Could not launch crop_screenshots.py: " + cropProc.message());
        utils:log("\t[WARN] Run `make crop-screenshots` manually to crop screenshots.");
    } else {
        int exitCode = check cropProc.waitForExit();
        if exitCode == 0 {
            utils:log("\t[INFO] Screenshots cropped successfully.");
        } else {
            utils:log("\t[WARN] crop_screenshots.py exited with code " + exitCode.toString() + ".");
            utils:log("\t[WARN] Run `make crop-screenshots` manually to crop screenshots.");
        }
    }
    utils:log("");

    // Print stats
    time:Utc endTime = time:utcNow();
    decimal durationSecs = time:utcDiffSeconds(endTime, startTime);

    int charCount = fullPrompt.length();
    utils:log("--- Pipeline Stats ---");
    utils:log(string `Start time:    ${time:utcToString(startTime)}`);
    utils:log(string `End time:      ${time:utcToString(endTime)}`);
    utils:log(string `Duration:      ${durationSecs}s`);
    utils:log(string `Prompt length: ${charCount} chars`);

    utils:log("");
    utils:log("=== Pipeline Complete ===");
    utils:log("Artifacts saved under '" + utils:OUTPUT_DIR + "'.");
}
