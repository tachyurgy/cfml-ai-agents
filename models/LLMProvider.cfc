/**
 * LLMProvider.cfc
 * Abstraction over LLM APIs supporting Anthropic Claude and OpenAI.
 * Handles tool_use responses from Claude and function_call from OpenAI.
 */
component accessors="true" {

    property name="provider" type="string" default="anthropic";
    property name="model" type="string" default="claude-sonnet-4-6-20250514";
    property name="apiKey" type="string" default="";
    property name="maxTokens" type="numeric" default=4096;

    public LLMProvider function init() {
        variables.provider = getEnvVar("LLM_PROVIDER", "anthropic");
        variables.model = getEnvVar("LLM_MODEL", "claude-sonnet-4-6-20250514");
        variables.maxTokens = 4096;

        if (variables.provider == "anthropic") {
            variables.apiKey = getEnvVar("ANTHROPIC_API_KEY", "");
            variables.baseUrl = "https://api.anthropic.com/v1";
        } else if (variables.provider == "openai") {
            variables.apiKey = getEnvVar("OPENAI_API_KEY", "");
            variables.baseUrl = "https://api.openai.com/v1";
        }

        return this;
    }

    /**
     * Send a chat completion request with optional tool definitions.
     * Returns a struct with: role, content, toolCalls (array), stopReason
     */
    public struct function chat(
        required array messages,
        array tools = [],
        struct options = {}
    ) {
        if (variables.provider == "anthropic") {
            return chatAnthropic(arguments.messages, arguments.tools, arguments.options);
        } else if (variables.provider == "openai") {
            return chatOpenAI(arguments.messages, arguments.tools, arguments.options);
        }
        throw(type="LLMProvider.UnsupportedProvider", message="Provider '#variables.provider#' is not supported.");
    }

    /**
     * Streaming chat request. Calls the callback function for each chunk.
     * callback receives: (type, data) where type is "text", "tool_use_start", "tool_use_delta", "tool_use_end", "done"
     */
    public struct function chatStream(
        required array messages,
        array tools = [],
        any callback = ""
    ) {
        // For simplicity, we fall back to non-streaming and simulate events
        var result = chat(arguments.messages, arguments.tools);

        if (isCustomFunction(arguments.callback) || isClosure(arguments.callback)) {
            if (len(result.content)) {
                arguments.callback("text", result.content);
            }
            for (var tc in result.toolCalls) {
                arguments.callback("tool_use_start", tc);
                arguments.callback("tool_use_end", tc);
            }
            arguments.callback("done", result);
        }

        return result;
    }

    /**
     * Convert internal tool format to the provider-specific format.
     */
    public array function formatToolsForProvider(required array tools) {
        if (variables.provider == "anthropic") {
            return formatToolsAnthropic(arguments.tools);
        } else {
            return formatToolsOpenAI(arguments.tools);
        }
    }

    // -----------------------------------------------------------------------
    // Anthropic Claude
    // -----------------------------------------------------------------------

    private struct function chatAnthropic(required array messages, array tools = [], struct options = {}) {
        var body = {
            "model": structKeyExists(arguments.options, "model") ? arguments.options.model : variables.model,
            "max_tokens": structKeyExists(arguments.options, "maxTokens") ? arguments.options.maxTokens : variables.maxTokens,
            "messages": buildAnthropicMessages(arguments.messages)
        };

        if (arrayLen(arguments.tools)) {
            body["tools"] = formatToolsAnthropic(arguments.tools);
        }

        // Extract system message if present
        var systemMsg = extractSystemMessage(arguments.messages);
        if (len(systemMsg)) {
            body["system"] = systemMsg;
        }

        var response = httpPost(
            url = variables.baseUrl & "/messages",
            body = body,
            headers = {
                "x-api-key": variables.apiKey,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json"
            }
        );

        return parseAnthropicResponse(response);
    }

    private array function buildAnthropicMessages(required array messages) {
        var result = [];
        for (var msg in arguments.messages) {
            if (msg.role == "system") continue;

            var formatted = {"role": msg.role};

            if (structKeyExists(msg, "content") && isSimpleValue(msg.content)) {
                formatted["content"] = msg.content;
            } else if (structKeyExists(msg, "content") && isArray(msg.content)) {
                formatted["content"] = msg.content;
            } else if (structKeyExists(msg, "toolCalls") && isArray(msg.toolCalls)) {
                // Assistant message with tool use
                var contentBlocks = [];
                if (structKeyExists(msg, "content") && len(msg.content)) {
                    arrayAppend(contentBlocks, {"type": "text", "text": msg.content});
                }
                for (var tc in msg.toolCalls) {
                    arrayAppend(contentBlocks, {
                        "type": "tool_use",
                        "id": tc.id,
                        "name": tc.name,
                        "input": isSimpleValue(tc.arguments) ? deserializeJSON(tc.arguments) : tc.arguments
                    });
                }
                formatted["content"] = contentBlocks;
            } else if (structKeyExists(msg, "toolResult")) {
                // Tool result message
                formatted["role"] = "user";
                formatted["content"] = [{
                    "type": "tool_result",
                    "tool_use_id": msg.toolUseId,
                    "content": isSimpleValue(msg.toolResult) ? msg.toolResult : serializeJSON(msg.toolResult)
                }];
            }

            arrayAppend(result, formatted);
        }
        return result;
    }

    private array function formatToolsAnthropic(required array tools) {
        var result = [];
        for (var tool in arguments.tools) {
            arrayAppend(result, {
                "name": tool.name,
                "description": tool.description,
                "input_schema": tool.parameters
            });
        }
        return result;
    }

    private struct function parseAnthropicResponse(required struct response) {
        var result = {
            "role": "assistant",
            "content": "",
            "toolCalls": [],
            "stopReason": response.stop_reason ?: "end_turn",
            "usage": structKeyExists(response, "usage") ? response.usage : {}
        };

        if (structKeyExists(response, "content") && isArray(response.content)) {
            for (var block in response.content) {
                if (block.type == "text") {
                    result.content &= block.text;
                } else if (block.type == "tool_use") {
                    arrayAppend(result.toolCalls, {
                        "id": block.id,
                        "name": block.name,
                        "arguments": block.input
                    });
                }
            }
        }

        return result;
    }

    // -----------------------------------------------------------------------
    // OpenAI
    // -----------------------------------------------------------------------

    private struct function chatOpenAI(required array messages, array tools = [], struct options = {}) {
        var body = {
            "model": structKeyExists(arguments.options, "model") ? arguments.options.model : variables.model,
            "max_tokens": structKeyExists(arguments.options, "maxTokens") ? arguments.options.maxTokens : variables.maxTokens,
            "messages": buildOpenAIMessages(arguments.messages)
        };

        if (arrayLen(arguments.tools)) {
            body["tools"] = formatToolsOpenAI(arguments.tools);
        }

        var response = httpPost(
            url = variables.baseUrl & "/chat/completions",
            body = body,
            headers = {
                "Authorization": "Bearer #variables.apiKey#",
                "Content-Type": "application/json"
            }
        );

        return parseOpenAIResponse(response);
    }

    private array function buildOpenAIMessages(required array messages) {
        var result = [];
        for (var msg in arguments.messages) {
            var formatted = {"role": msg.role};

            if (structKeyExists(msg, "content")) {
                formatted["content"] = isSimpleValue(msg.content) ? msg.content : serializeJSON(msg.content);
            }

            if (structKeyExists(msg, "toolCalls") && isArray(msg.toolCalls)) {
                formatted["tool_calls"] = [];
                for (var tc in msg.toolCalls) {
                    arrayAppend(formatted["tool_calls"], {
                        "id": tc.id,
                        "type": "function",
                        "function": {
                            "name": tc.name,
                            "arguments": isSimpleValue(tc.arguments) ? tc.arguments : serializeJSON(tc.arguments)
                        }
                    });
                }
            }

            if (structKeyExists(msg, "toolResult")) {
                formatted["role"] = "tool";
                formatted["tool_call_id"] = msg.toolUseId;
                formatted["content"] = isSimpleValue(msg.toolResult) ? msg.toolResult : serializeJSON(msg.toolResult);
            }

            arrayAppend(result, formatted);
        }
        return result;
    }

    private array function formatToolsOpenAI(required array tools) {
        var result = [];
        for (var tool in arguments.tools) {
            arrayAppend(result, {
                "type": "function",
                "function": {
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameters
                }
            });
        }
        return result;
    }

    private struct function parseOpenAIResponse(required struct response) {
        var result = {
            "role": "assistant",
            "content": "",
            "toolCalls": [],
            "stopReason": "end_turn",
            "usage": structKeyExists(response, "usage") ? response.usage : {}
        };

        if (structKeyExists(response, "choices") && arrayLen(response.choices)) {
            var choice = response.choices[1];
            var msg = choice.message;

            result.content = msg.content ?: "";
            result.stopReason = choice.finish_reason ?: "stop";

            if (structKeyExists(msg, "tool_calls") && isArray(msg.tool_calls)) {
                for (var tc in msg.tool_calls) {
                    arrayAppend(result.toolCalls, {
                        "id": tc.id,
                        "name": tc["function"].name,
                        "arguments": isSimpleValue(tc["function"].arguments)
                            ? deserializeJSON(tc["function"].arguments)
                            : tc["function"].arguments
                    });
                }
            }
        }

        return result;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private string function extractSystemMessage(required array messages) {
        for (var msg in arguments.messages) {
            if (msg.role == "system") {
                return msg.content;
            }
        }
        return "";
    }

    private struct function httpPost(required string url, required struct body, required struct headers) {
        var httpService = new http(method="POST", url=arguments.url, timeout=120);

        for (var key in arguments.headers) {
            httpService.addParam(type="header", name=key, value=arguments.headers[key]);
        }

        httpService.addParam(type="body", value=serializeJSON(arguments.body));

        var httpResult = httpService.send().getPrefix();

        if (httpResult.statusCode contains "200" || httpResult.statusCode contains "201") {
            return deserializeJSON(httpResult.fileContent);
        }

        var errorDetail = "";
        try { errorDetail = httpResult.fileContent; } catch(any e) { errorDetail = httpResult.statusCode; }

        throw(
            type = "LLMProvider.APIError",
            message = "LLM API returned status #httpResult.statusCode#",
            detail = errorDetail
        );
    }

    private string function getEnvVar(required string name, string defaultValue = "") {
        var val = createObject("java", "java.lang.System").getenv(arguments.name);
        if (!isNull(val) && len(val)) {
            return val;
        }
        // Also check server scope
        if (structKeyExists(server, "system") && structKeyExists(server.system, "environment") && structKeyExists(server.system.environment, arguments.name)) {
            return server.system.environment[arguments.name];
        }
        return arguments.defaultValue;
    }

}
