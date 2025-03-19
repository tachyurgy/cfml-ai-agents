/**
 * Agent.cfc
 * The core ReAct (Reason + Act) agent. Sends tasks to an LLM, which decides
 * which tools to call, observes results, and iterates until it reaches an answer.
 */
component accessors="true" {

    property name="llmProvider" type="LLMProvider";
    property name="toolRegistry" type="ToolRegistry";
    property name="memory" type="ConversationMemory";
    property name="systemPrompt" type="string";
    property name="maxTokens" type="numeric" default=4096;

    public Agent function init(
        required LLMProvider llmProvider,
        required ToolRegistry toolRegistry,
        string systemPrompt = ""
    ) {
        variables.llmProvider = arguments.llmProvider;
        variables.toolRegistry = arguments.toolRegistry;
        variables.memory = new ConversationMemory();

        if (len(arguments.systemPrompt)) {
            variables.systemPrompt = arguments.systemPrompt;
        } else {
            variables.systemPrompt = buildDefaultSystemPrompt();
        }

        return this;
    }

    /**
     * Run the agent on a task. Returns the final text answer.
     * @task The user's question or instruction.
     * @maxSteps Maximum number of reasoning/tool-use cycles before giving up.
     */
    public string function run(required string task, numeric maxSteps = 10) {
        var trace = runWithTrace(arguments.task, arguments.maxSteps);
        return trace.finalAnswer;
    }

    /**
     * Run the agent and return the full execution trace, including every
     * thought, tool call, tool result, and the final answer.
     */
    public struct function runWithTrace(required string task, numeric maxSteps = 10) {
        var trace = {
            "task": arguments.task,
            "steps": [],
            "finalAnswer": "",
            "totalSteps": 0,
            "startTime": now(),
            "endTime": "",
            "status": "running"
        };

        // Start fresh conversation
        variables.memory.clear();
        variables.memory.addMessage("system", variables.systemPrompt);
        variables.memory.addMessage("user", arguments.task);

        var toolSchemas = variables.toolRegistry.getToolSchemas();
        var step = 0;

        while (step < arguments.maxSteps) {
            step++;

            var stepTrace = {
                "step": step,
                "timestamp": now(),
                "type": "",
                "thought": "",
                "toolCall": javaCast("null", ""),
                "toolResult": javaCast("null", ""),
                "response": ""
            };

            try {
                // Send the conversation to the LLM with tool definitions
                var llmResponse = variables.llmProvider.chat(
                    messages = variables.memory.getMessages(),
                    tools = toolSchemas
                );

                // Check if the LLM wants to use a tool
                if (arrayLen(llmResponse.toolCalls)) {
                    stepTrace.type = "tool_use";

                    // Capture any thinking text alongside tool calls
                    if (len(llmResponse.content)) {
                        stepTrace.thought = llmResponse.content;
                    }

                    // Add the assistant message (with tool calls) to memory
                    variables.memory.addMessage("assistant", llmResponse.content, llmResponse.toolCalls);

                    // Execute each tool call
                    for (var toolCall in llmResponse.toolCalls) {
                        stepTrace.toolCall = {
                            "name": toolCall.name,
                            "arguments": toolCall.arguments,
                            "id": toolCall.id
                        };

                        // Execute the tool
                        var toolArgs = isSimpleValue(toolCall.arguments)
                            ? deserializeJSON(toolCall.arguments)
                            : toolCall.arguments;

                        var toolResult = variables.toolRegistry.executeTool(
                            toolCall.name,
                            toolArgs
                        );

                        stepTrace.toolResult = toolResult;

                        // Add tool result to memory
                        variables.memory.addToolResult(toolCall.id, toolCall.name, toolResult);
                    }

                    arrayAppend(trace.steps, duplicate(stepTrace));

                } else {
                    // No tool calls - this is the final answer
                    stepTrace.type = "answer";
                    stepTrace.response = llmResponse.content;

                    variables.memory.addMessage("assistant", llmResponse.content);

                    trace.finalAnswer = llmResponse.content;
                    trace.status = "completed";

                    arrayAppend(trace.steps, stepTrace);
                    break;
                }

            } catch (any e) {
                stepTrace.type = "error";
                stepTrace.response = "Error at step #step#: #e.message#";
                arrayAppend(trace.steps, stepTrace);

                trace.finalAnswer = "I encountered an error while processing your request: #e.message#";
                trace.status = "error";
                break;
            }
        }

        // If we exhausted maxSteps without a final answer
        if (trace.status == "running") {
            trace.status = "max_steps_reached";
            trace.finalAnswer = "I reached the maximum number of reasoning steps (#arguments.maxSteps#) without arriving at a final answer. Here is what I found so far based on my research.";

            // Try one more call asking the LLM to summarize
            try {
                variables.memory.addMessage("user", "Please provide your best answer based on everything you have gathered so far.");
                var summary = variables.llmProvider.chat(
                    messages = variables.memory.getMessages(),
                    tools = []
                );
                trace.finalAnswer = summary.content;
            } catch (any e) {
                // Keep the default message
            }
        }

        trace.endTime = now();
        trace.totalSteps = step;

        return trace;
    }

    /**
     * Build the default system prompt that instructs the LLM on ReAct behavior.
     */
    private string function buildDefaultSystemPrompt() {
        return "You are a helpful AI assistant with access to tools. Your job is to answer the user's question as accurately and thoroughly as possible.

Follow this reasoning process:

1. THINK about what information you need to answer the question.
2. If you need external data or computation, USE the appropriate tool.
3. OBSERVE the tool's result and think about whether you have enough information.
4. If you need more information, use another tool. If you have enough, provide your final answer.

Guidelines:
- Break complex questions into smaller steps.
- Use tools when you need current information, calculations, or external data.
- If a tool returns an error, try a different approach.
- When you have gathered enough information, provide a clear, well-organized final answer.
- Be concise but thorough. Cite your sources when using web search results.
- If you cannot find the answer, say so honestly rather than guessing.

You have access to the following tool categories:
- Web search for current information
- HTTP requests for fetching web pages or APIs
- A calculator for math
- Date/time operations
- Database queries for structured data

Think step by step and use tools as needed.";
    }

}
