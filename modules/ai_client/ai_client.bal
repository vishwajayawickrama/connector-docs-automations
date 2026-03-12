import ballerina/http;
import ballerinaconnectors/documentation_automation_workflow.utils;

# Anthropic message content block.
type ContentBlock record {
    # The type of content block (e.g. "text")
    string 'type;
    # The text content (present when type is "text")
    string text?;
};

# Anthropic token usage info.
type UsageInfo record {
    # Number of input tokens consumed
    int input_tokens;
    # Number of output tokens generated
    int output_tokens;
};

# Anthropic Messages API response (partial — only fields we need).
type MessagesResponse record {
    # Unique identifier for this message
    string id;
    # The model used to generate the response
    string model;
    # The reason the model stopped generating
    string stop_reason?;
    # The content blocks in the response
    ContentBlock[] content;
    # Token usage for this response
    UsageInfo? usage;
};

# Default Claude model to use.
const string DEFAULT_MODEL = "claude-sonnet-4-6";

# Anthropic API base URL.
const string ANTHROPIC_BASE_URL = "https://api.anthropic.com";

# Anthropic API version header value.
const string ANTHROPIC_VERSION = "2023-06-01";

# Validates the Anthropic API key by sending a minimal test request.
# Logs a clean success message or extracts and displays error details.
# Fails fast before the expensive pipeline calls run.
#
# + apiKey - the Anthropic API key
# + return - nil on success, or an error with the HTTP diagnostic details
public function validateApiKey(string apiKey) returns error? {
    utils:log("\t[INFO] Sending ping request...");

    http:Client httpClient = check new (ANTHROPIC_BASE_URL);

    json payload = {
        "model": DEFAULT_MODEL,
        "max_tokens": 10,
        "messages": [
            {"role": "user", "content": "Reply with the single word: OK"}
        ]
    };

    http:Request req = new;
    req.setJsonPayload(payload);
    req.setHeader("x-api-key", apiKey);
    req.setHeader("anthropic-version", ANTHROPIC_VERSION);
    req.setHeader("content-type", "application/json");

    http:Response response = check httpClient->post("/v1/messages", req);
    int statusCode = response.statusCode;

    if statusCode >= 200 && statusCode < 300 {
        utils:log("\t[INFO] ✓ API key is valid — Anthropic responded successfully.");
        return;
    }

    // Handle error response
    string|error body = response.getTextPayload();
    string errorMsg = "API key validation failed";
    if body is string {
        json|error jsonBody = body.fromJsonString();
        if jsonBody is map<json> {
            json errField = jsonBody["error"];
            if errField is map<json> {
                json msgField = errField["message"];
                if msgField is string {
                    errorMsg = msgField;
                }
            }
        }
    }

    utils:log(string `\t[ERROR] HTTP ${statusCode}: ${errorMsg}`);
    return error(string `Anthropic API key validation failed (HTTP ${statusCode}): ${errorMsg}`);
}

# Sends the system and user prompts to Claude and returns the generated text content.
#
# + systemPrompt - the system prompt instructing the model
# + userMessage - the user message with the goal details
# + apiKey - the Anthropic API key
# + return - the generated execution prompt or an error
public function callClaude(string systemPrompt, string userMessage, string apiKey) returns string|error {
    utils:log("\t[INFO] Model:              " + DEFAULT_MODEL);
    utils:log("\t[INFO] System prompt len:  " + systemPrompt.length().toString() + " chars");
    utils:log("\t[INFO] User message len:   " + userMessage.length().toString() + " chars");
    utils:log("\t[INFO] Sending request to Anthropic API...");

    json payload = {
        "model": DEFAULT_MODEL,
        "max_tokens": 16000,
        "system": systemPrompt,
        "messages": [
            {"role": "user", "content": userMessage}
        ]
    };

    // Generous timeout — large prompts can take 2–3 minutes to generate
    http:Client httpClient = check new (ANTHROPIC_BASE_URL, timeout = 300);

    http:Request req = new;
    req.setJsonPayload(payload);
    req.setHeader("x-api-key", apiKey);
    req.setHeader("anthropic-version", ANTHROPIC_VERSION);
    req.setHeader("content-type", "application/json");

    http:Response response = check httpClient->post("/v1/messages", req);
    int statusCode = response.statusCode;

    if statusCode < 200 || statusCode >= 300 {
        string|error errBody = response.getTextPayload();
        string detail = errBody is string ? errBody : "(unable to read response body)";
        utils:log("\t[ERROR] Anthropic API returned HTTP " + statusCode.toString());
        utils:log("\t[ERROR] Response: " + detail);
        return error(string `Anthropic API returned HTTP ${statusCode}: ${detail}`);
    }

    json responseJson = check response.getJsonPayload();
    MessagesResponse msgResp = check responseJson.cloneWithType(MessagesResponse);

    if msgResp.content.length() == 0 {
        return error("No content blocks in Anthropic API response");
    }

    // Find the first text block
    string resultText = "";
    foreach ContentBlock block in msgResp.content {
        if block.'type == "text" {
            string? text = block.text;
            if text is string {
                resultText = text;
                break;
            }
        }
    }

    if resultText.trim().length() == 0 {
        return error("Empty text content in Anthropic API response");
    }

    utils:log("\t[INFO] Response received. Length: " + resultText.length().toString() + " chars");

    UsageInfo? usage = msgResp.usage;
    if usage is UsageInfo {
        utils:log("\t[INFO] Tokens used — Input: " + usage.input_tokens.toString()
            + " | Output: " + usage.output_tokens.toString()
            + " | Total: " + (usage.input_tokens + usage.output_tokens).toString());
    }

    return resultText;
}

# Asks the LLM to generate a short 3-4 word filename-safe slug from the goal.
#
# + goal - the full goal description
# + apiKey - the Anthropic API key
# + return - a sanitized hyphenated slug or an error
public function generateGoalSlug(string goal, string apiKey) returns string|error {
    utils:log("\t[INFO] Generating short filename slug from goal...");

    json payload = {
        "model": DEFAULT_MODEL,
        "max_tokens": 30,
        "system": "You are a filename generator. Given a goal description, output ONLY a short 3-4 word slug suitable for a filename. Use lowercase words separated by hyphens. No punctuation, no explanation, no quotes. Just the slug. Example input: 'Create an HTTP GET request endpoint that returns hello world' -> Example output: http-get-hello-endpoint",
        "messages": [
            {"role": "user", "content": goal}
        ]
    };

    http:Client httpClient = check new (ANTHROPIC_BASE_URL, timeout = 30);

    http:Request req = new;
    req.setJsonPayload(payload);
    req.setHeader("x-api-key", apiKey);
    req.setHeader("anthropic-version", ANTHROPIC_VERSION);
    req.setHeader("content-type", "application/json");

    http:Response response = check httpClient->post("/v1/messages", req);
    int statusCode = response.statusCode;

    if statusCode < 200 || statusCode >= 300 {
        string|error errBody = response.getTextPayload();
        string detail = errBody is string ? errBody : "(unable to read response body)";
        utils:log("\t[ERROR] Slug generation returned HTTP " + statusCode.toString());
        utils:log("\t[ERROR] Response: " + detail);
        return error(string `Anthropic API returned HTTP ${statusCode}: ${detail}`);
    }

    json responseJson = check response.getJsonPayload();
    MessagesResponse msgResp = check responseJson.cloneWithType(MessagesResponse);

    if msgResp.content.length() == 0 {
        return error("No content blocks in Anthropic slug response");
    }

    string content = "";
    foreach ContentBlock block in msgResp.content {
        if block.'type == "text" {
            string? text = block.text;
            if text is string {
                content = text;
                break;
            }
        }
    }

    if content.trim().length() == 0 {
        return error("Empty response when generating goal slug");
    }

    // Sanitize: lowercase, trim, remove anything not alphanumeric or hyphen
    string slug = content.trim().toLowerAscii();
    slug = re `[^a-z0-9\-]`.replaceAll(slug, "");
    slug = re `-+`.replaceAll(slug, "-");

    if slug.trim().length() == 0 {
        slug = "unnamed-goal";
    }

    utils:log("\t[INFO] Generated slug: " + slug);
    return slug;
}
