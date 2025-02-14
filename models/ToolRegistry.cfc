/**
 * ToolRegistry.cfc
 * Central registry managing all available tools for the agent.
 * Thread-safe via locking on mutations.
 */
component accessors="true" {

    property name="tools" type="struct";

    public ToolRegistry function init() {
        variables.tools = {};
        return this;
    }

    /**
     * Register a tool instance. The tool's name is used as the key.
     */
    public void function register(required Tool tool) {
        lock name="ToolRegistry_#createUUID()#" type="exclusive" timeout=5 {
            variables.tools[arguments.tool.getName()] = arguments.tool;
        }
    }

    /**
     * Get a tool by name.
     * @return Tool instance or throws if not found.
     */
    public Tool function getTool(required string name) {
        if (structKeyExists(variables.tools, arguments.name)) {
            return variables.tools[arguments.name];
        }
        throw(
            type = "ToolRegistry.NotFound",
            message = "Tool '#arguments.name#' is not registered."
        );
    }

    /**
     * Check if a tool exists by name.
     */
    public boolean function hasTool(required string name) {
        return structKeyExists(variables.tools, arguments.name);
    }

    /**
     * Returns a struct of all registered tools keyed by name.
     */
    public struct function getAllTools() {
        return duplicate(variables.tools);
    }

    /**
     * Returns an array of tool schemas suitable for sending to the LLM.
     */
    public array function getToolSchemas() {
        var schemas = [];
        for (var toolName in variables.tools) {
            arrayAppend(schemas, variables.tools[toolName].getSchema());
        }
        return schemas;
    }

    /**
     * Find a tool by name, validate arguments, and execute it.
     * Returns the tool's result struct.
     */
    public struct function executeTool(required string name, required struct arguments) {
        var tool = getTool(arguments.name);

        // Validate arguments against schema
        var validation = tool.validate(arguments.arguments);
        if (!validation.valid) {
            return {
                "success": false,
                "error": "Validation failed: " & arrayToList(validation.errors, "; ")
            };
        }

        try {
            var result = tool.execute(arguments.arguments);
            result["success"] = true;
            return result;
        } catch (any e) {
            return {
                "success": false,
                "error": "Tool execution failed: #e.message#",
                "detail": e.detail ?: ""
            };
        }
    }

    /**
     * Returns the count of registered tools.
     */
    public numeric function getToolCount() {
        return structCount(variables.tools);
    }

}
