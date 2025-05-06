/**
 * WebSearchTool.cfc
 * Search the web using SerpAPI. Falls back to mock results if no API key is configured.
 */
component extends="models.Tool" accessors="true" {

    public WebSearchTool function init() {
        super.init(
            name = "web_search",
            description = "Search the web for current information. Use this when you need up-to-date facts, news, or data that may not be in your training set.",
            parameters = {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "The search query to look up"
                    }
                },
                "required": ["query"]
            }
        );
        return this;
    }

    public struct function execute(required struct args) {
        var query = arguments.args.query;
        var apiKey = getEnvVar("SERPAPI_KEY");

        if (len(apiKey)) {
            return executeWithSerpAPI(query, apiKey);
        }

        return executeMock(query);
    }

    private struct function executeWithSerpAPI(required string query, required string apiKey) {
        var searchUrl = "https://serpapi.com/search.json?q=#encodeForURL(arguments.query)#&api_key=#arguments.apiKey#&num=5";

        var httpService = new http(method="GET", url=searchUrl, timeout=30);
        var httpResult = httpService.send().getPrefix();

        if (!(httpResult.statusCode contains "200")) {
            return {
                "result": "Search API returned an error (status #httpResult.statusCode#). Try a different query or use the http_request tool to fetch a specific URL directly."
            };
        }

        var data = deserializeJSON(httpResult.fileContent);
        var results = [];

        if (structKeyExists(data, "organic_results") && isArray(data.organic_results)) {
            var count = 0;
            for (var item in data.organic_results) {
                count++;
                if (count > 5) break;
                arrayAppend(results, {
                    "title": item.title ?: "",
                    "url": item.link ?: "",
                    "snippet": item.snippet ?: ""
                });
            }
        }

        if (structKeyExists(data, "answer_box") && structKeyExists(data.answer_box, "answer")) {
            return {
                "result": "Direct Answer: #data.answer_box.answer##chr(10)##chr(10)#Search Results:#chr(10)##formatResults(results)#"
            };
        }

        return {
            "result": arrayLen(results) ? formatResults(results) : "No results found for '#arguments.query#'. Try rephrasing the search."
        };
    }

    private struct function executeMock(required string query) {
        return {
            "result": "[Mock Search Results for '#arguments.query#']#chr(10)#Note: No SERPAPI_KEY configured. Set it in your environment or .env file for real search results.#chr(10)##chr(10)#In a live setup, this tool would return current web search results for your query. For now, the agent should try using the http_request tool to fetch specific URLs, or answer from its training data."
        };
    }

    private string function formatResults(required array results) {
        var output = "";
        var idx = 0;
        for (var r in arguments.results) {
            idx++;
            output &= "#idx#. #r.title##chr(10)#   URL: #r.url##chr(10)#   #r.snippet##chr(10)##chr(10)#";
        }
        return output;
    }

    private string function getEnvVar(required string name) {
        var val = createObject("java", "java.lang.System").getenv(arguments.name);
        if (!isNull(val) && len(val)) return val;
        return "";
    }

}
