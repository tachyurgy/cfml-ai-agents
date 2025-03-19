/**
 * ConversationMemory.cfc
 * Manages conversation history for an agent session. Stores messages in
 * the format expected by LLM APIs and supports summarization of long histories.
 */
component accessors="true" {

    property name="messages" type="array";
    property name="maxMessages" type="numeric" default=50;

    public ConversationMemory function init(numeric maxMessages = 50) {
        variables.messages = [];
        variables.maxMessages = arguments.maxMessages;
        return this;
    }

    /**
     * Add a message to the conversation history.
     * @role "system", "user", or "assistant"
     * @content The text content of the message.
     * @toolCalls Optional array of tool calls (for assistant messages).
     */
    public void function addMessage(
        required string role,
        required string content,
        array toolCalls = []
    ) {
        var msg = {
            "role": arguments.role,
            "content": arguments.content,
            "timestamp": now()
        };

        if (arrayLen(arguments.toolCalls)) {
            msg["toolCalls"] = arguments.toolCalls;
        }

        arrayAppend(variables.messages, msg);
        enforceLimit();
    }

    /**
     * Add a tool result message to the conversation.
     * This gets formatted as a user message with tool_result content blocks.
     */
    public void function addToolResult(
        required string toolUseId,
        required string toolName,
        required any result
    ) {
        var resultText = isSimpleValue(arguments.result)
            ? arguments.result
            : serializeJSON(arguments.result);

        var msg = {
            "role": "user",
            "toolResult": resultText,
            "toolUseId": arguments.toolUseId,
            "toolName": arguments.toolName,
            "timestamp": now()
        };

        arrayAppend(variables.messages, msg);
        enforceLimit();
    }

    /**
     * Add a tool use record (combines call + result for trace purposes).
     */
    public void function addToolUse(
        required string toolName,
        required any toolInput,
        required any toolResult
    ) {
        addMessage("assistant", "Using tool: #arguments.toolName#", [{
            "id": createUUID(),
            "name": arguments.toolName,
            "arguments": arguments.toolInput
        }]);

        addToolResult(
            toolUseId = variables.messages[arrayLen(variables.messages)].toolCalls[1].id,
            toolName = arguments.toolName,
            result = arguments.toolResult
        );
    }

    /**
     * Get the full message array for sending to the LLM.
     */
    public array function getMessages() {
        return duplicate(variables.messages);
    }

    /**
     * Get the message count.
     */
    public numeric function getMessageCount() {
        return arrayLen(variables.messages);
    }

    /**
     * Summarize older messages using the LLM to compress conversation history.
     * Keeps the system message and the last N messages, replacing the middle
     * with a summary.
     * @llmProvider An LLMProvider instance to generate the summary.
     * @keepLast Number of recent messages to keep verbatim.
     */
    public void function summarize(required any llmProvider, numeric keepLast = 6) {
        if (arrayLen(variables.messages) <= arguments.keepLast + 2) {
            return; // Not enough messages to bother summarizing
        }

        // Separate system message, old messages, and recent messages
        var systemMsg = "";
        var startIdx = 1;
        if (arrayLen(variables.messages) && variables.messages[1].role == "system") {
            systemMsg = variables.messages[1].content;
            startIdx = 2;
        }

        var cutoff = arrayLen(variables.messages) - arguments.keepLast;
        if (cutoff <= startIdx) return;

        // Build text of old messages for summarization
        var oldText = "";
        for (var i = startIdx; i <= cutoff; i++) {
            var msg = variables.messages[i];
            if (structKeyExists(msg, "toolResult")) {
                oldText &= "[Tool Result] #msg.toolResult##chr(10)#";
            } else if (structKeyExists(msg, "toolCalls")) {
                oldText &= "[Assistant - Tool Call] #msg.content##chr(10)#";
            } else {
                oldText &= "[#msg.role#] #msg.content##chr(10)#";
            }
        }

        // Ask the LLM to summarize
        var summaryMessages = [
            {"role": "user", "content": "Summarize the following conversation concisely, preserving all key facts, tool results, and decisions made. This summary will replace the original messages in the conversation context.#chr(10)##chr(10)##oldText#"}
        ];

        try {
            var summaryResponse = arguments.llmProvider.chat(messages = summaryMessages);
            var summaryText = summaryResponse.content;

            // Rebuild the messages array
            var newMessages = [];
            if (len(systemMsg)) {
                arrayAppend(newMessages, {"role": "system", "content": systemMsg, "timestamp": now()});
            }
            arrayAppend(newMessages, {"role": "user", "content": "[Conversation Summary] #summaryText#", "timestamp": now()});

            // Append the recent messages
            for (var i = cutoff + 1; i <= arrayLen(variables.messages); i++) {
                arrayAppend(newMessages, variables.messages[i]);
            }

            variables.messages = newMessages;
        } catch (any e) {
            // If summarization fails, just keep the messages as-is
        }
    }

    /**
     * Clear all messages.
     */
    public void function clear() {
        variables.messages = [];
    }

    /**
     * Enforce the maximum message limit by trimming from the middle.
     */
    private void function enforceLimit() {
        if (arrayLen(variables.messages) > variables.maxMessages) {
            // Keep system message (first) and last half of messages
            var keep = int(variables.maxMessages / 2);
            var newMessages = [];

            // Keep the system message if present
            if (variables.messages[1].role == "system") {
                arrayAppend(newMessages, variables.messages[1]);
            }

            // Keep the most recent messages
            var startFrom = arrayLen(variables.messages) - keep + 1;
            for (var i = startFrom; i <= arrayLen(variables.messages); i++) {
                arrayAppend(newMessages, variables.messages[i]);
            }

            variables.messages = newMessages;
        }
    }

}
