component {

    this.name = "CFMLAgents";
    this.applicationTimeout = createTimeSpan(1, 0, 0, 0);
    this.sessionManagement = true;
    this.sessionTimeout = createTimeSpan(0, 1, 0, 0);

    this.mappings["/models"] = expandPath("./models");
    this.mappings["/tools"] = expandPath("./models/tools");
    this.mappings["/handlers"] = expandPath("./handlers");

    public boolean function onApplicationStart() {
        application.toolRegistry = new models.ToolRegistry();
        application.llmProvider = new models.LLMProvider();

        // Register built-in tools
        application.toolRegistry.register(new models.tools.WebSearchTool());
        application.toolRegistry.register(new models.tools.HttpRequestTool());
        application.toolRegistry.register(new models.tools.DatabaseQueryTool());
        application.toolRegistry.register(new models.tools.CalculatorTool());
        application.toolRegistry.register(new models.tools.DateTimeTool());

        return true;
    }

    public boolean function onRequestStart(required string targetPage) {
        // Reinitialize on ?reinit=true
        if (structKeyExists(url, "reinit") && url.reinit) {
            onApplicationStart();
        }
        return true;
    }

    public void function onError(required any exception, required string eventName) {
        var errorResponse = {
            "error": true,
            "message": exception.message ?: "Unknown error",
            "detail": exception.detail ?: ""
        };

        if (findNoCase("api", cgi.SCRIPT_NAME)) {
            cfheader(statuscode="500", statustext="Internal Server Error");
            cfcontent(type="application/json", reset=true);
            writeOutput(serializeJSON(errorResponse));
        } else {
            writeOutput("<h1>Error</h1><p>#encodeForHTML(exception.message)#</p>");
        }
    }

}
