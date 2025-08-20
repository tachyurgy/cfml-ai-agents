/**
 * api.cfc
 * REST API handler for the CFML AI Agent framework.
 * Endpoints:
 *   POST /api/agent/run    - Run agent with a task, return result + trace
 *   GET  /api/tools        - List all available tools
 *   POST /api/agent/stream - SSE endpoint for streaming agent execution
 */
component {

    /**
     * Route incoming requests to the appropriate handler.
     */
    remote void function index() {
        var path = cgi.PATH_INFO ?: "";
        var method = cgi.REQUEST_METHOD;

        // CORS headers
        cfheader(name="Access-Control-Allow-Origin", value="*");
        cfheader(name="Access-Control-Allow-Methods", value="GET, POST, OPTIONS");
        cfheader(name="Access-Control-Allow-Headers", value="Content-Type, Authorization");

        if (method == "OPTIONS") {
            cfheader(statuscode="204", statustext="No Content");
            return;
        }

        try {
            if (path contains "/agent/stream" && method == "POST") {
                handleAgentStream();
            } else if (path contains "/agent/run" && method == "POST") {
                handleAgentRun();
            } else if (path contains "/tools" && method == "GET") {
                handleListTools();
            } else {
                sendJSON({"error": true, "message": "Not found. Available endpoints: POST /api/agent/run, GET /api/tools, POST /api/agent/stream"}, 404);
            }
        } catch (any e) {
            sendJSON({"error": true, "message": e.message, "detail": e.detail ?: ""}, 500);
        }
    }

    /**
     * POST /api/agent/run
     * Body: { "task": "...", "maxSteps": 10 }
     * Returns: { "success": true, "result": "...", "trace": {...} }
     */
    private void function handleAgentRun() {
        var body = getRequestBody();

        if (!structKeyExists(body, "task") || !len(trim(body.task))) {
            sendJSON({"error": true, "message": "Missing required field: task"}, 400);
            return;
        }

        var maxSteps = structKeyExists(body, "maxSteps") ? val(body.maxSteps) : 10;
        if (maxSteps < 1) maxSteps = 1;
        if (maxSteps > 25) maxSteps = 25;

        var agent = new models.Agent(
            llmProvider = application.llmProvider,
            toolRegistry = application.toolRegistry
        );

        var trace = agent.runWithTrace(body.task, maxSteps);

        sendJSON({
            "success": true,
            "result": trace.finalAnswer,
            "trace": {
                "task": trace.task,
                "steps": trace.steps,
                "totalSteps": trace.totalSteps,
                "status": trace.status,
                "startTime": dateTimeFormat(trace.startTime, "yyyy-MM-dd'T'HH:nn:ss"),
                "endTime": isDate(trace.endTime) ? dateTimeFormat(trace.endTime, "yyyy-MM-dd'T'HH:nn:ss") : ""
            }
        });
    }

    /**
     * GET /api/tools
     * Returns all registered tools and their schemas.
     */
    private void function handleListTools() {
        var tools = application.toolRegistry.getAllTools();
        var toolList = [];

        for (var name in tools) {
            var tool = tools[name];
            arrayAppend(toolList, {
                "name": tool.getName(),
                "description": tool.getDescription(),
                "parameters": tool.getParameters()
            });
        }

        sendJSON({
            "success": true,
            "tools": toolList,
            "count": arrayLen(toolList)
        });
    }

    /**
     * POST /api/agent/stream
     * Server-Sent Events endpoint for streaming agent execution.
     * Body: { "task": "...", "maxSteps": 10 }
     */
    private void function handleAgentStream() {
        var body = getRequestBody();

        if (!structKeyExists(body, "task") || !len(trim(body.task))) {
            sendJSON({"error": true, "message": "Missing required field: task"}, 400);
            return;
        }

        var maxSteps = structKeyExists(body, "maxSteps") ? val(body.maxSteps) : 10;
        if (maxSteps < 1) maxSteps = 1;
        if (maxSteps > 25) maxSteps = 25;

        // Set SSE headers
        cfheader(name="Content-Type", value="text/event-stream");
        cfheader(name="Cache-Control", value="no-cache");
        cfheader(name="Connection", value="keep-alive");

        var pageContext = getPageContext();
        var response = pageContext.getResponse();
        var out = response.getOutputStream();

        // Helper to send an SSE event
        var sendEvent = function(required string eventType, required any data) {
            var line = "event: #arguments.eventType##chr(10)#data: #serializeJSON(arguments.data)##chr(10)##chr(10)#";
            out.write(line.getBytes("UTF-8"));
            out.flush();
        };

        try {
            sendEvent("start", {"task": body.task, "timestamp": dateTimeFormat(now(), "yyyy-MM-dd'T'HH:nn:ss")});

            // Run the agent step by step
            var agent = new models.Agent(
                llmProvider = application.llmProvider,
                toolRegistry = application.toolRegistry
            );

            var trace = agent.runWithTrace(body.task, maxSteps);

            // Stream each step
            for (var step in trace.steps) {
                var eventData = {
                    "step": step.step,
                    "type": step.type
                };

                if (step.type == "tool_use") {
                    if (len(step.thought)) {
                        sendEvent("thought", {"step": step.step, "text": step.thought});
                    }
                    if (!isNull(step.toolCall)) {
                        sendEvent("tool_call", {
                            "step": step.step,
                            "tool": step.toolCall.name,
                            "arguments": step.toolCall.arguments
                        });
                    }
                    if (!isNull(step.toolResult)) {
                        sendEvent("tool_result", {
                            "step": step.step,
                            "result": step.toolResult
                        });
                    }
                } else if (step.type == "answer") {
                    sendEvent("answer", {"step": step.step, "text": step.response});
                } else if (step.type == "error") {
                    sendEvent("error", {"step": step.step, "message": step.response});
                }
            }

            sendEvent("done", {
                "status": trace.status,
                "totalSteps": trace.totalSteps,
                "finalAnswer": trace.finalAnswer
            });

        } catch (any e) {
            try {
                sendEvent("error", {"message": e.message});
            } catch (any e2) {
                // Connection may have been closed
            }
        }
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private struct function getRequestBody() {
        var content = toString(getHttpRequestData().content);
        if (len(trim(content))) {
            try {
                return deserializeJSON(content);
            } catch (any e) {
                return {};
            }
        }
        return {};
    }

    private void function sendJSON(required any data, numeric statusCode = 200) {
        cfheader(statuscode="#arguments.statusCode#", statustext=(arguments.statusCode == 200 ? "OK" : "Error"));
        cfcontent(type="application/json", reset=true);
        writeOutput(serializeJSON(arguments.data));
    }

}
