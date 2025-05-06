/**
 * HttpRequestTool.cfc
 * Make HTTP requests to fetch data from URLs. Useful for reading web pages,
 * calling APIs, or downloading data.
 */
component extends="models.Tool" accessors="true" {

    public HttpRequestTool function init() {
        super.init(
            name = "http_request",
            description = "Make an HTTP request to fetch data from a URL. Returns the response body. Use this to read web pages, call public APIs, or fetch specific data from the internet.",
            parameters = {
                "type": "object",
                "properties": {
                    "url": {
                        "type": "string",
                        "description": "The full URL to request (must start with http:// or https://)"
                    },
                    "method": {
                        "type": "string",
                        "description": "HTTP method to use. Defaults to GET.",
                        "enum": ["GET", "POST", "PUT", "DELETE", "HEAD"],
                        "default": "GET"
                    }
                },
                "required": ["url"]
            }
        );
        return this;
    }

    public struct function execute(required struct args) {
        var targetUrl = trim(arguments.args.url);
        var method = structKeyExists(arguments.args, "method") ? uCase(arguments.args.method) : "GET";

        // Basic URL validation
        if (!reFindNoCase("^https?://", targetUrl)) {
            return {"result": "Error: URL must start with http:// or https://"};
        }

        // Block internal/private IPs for safety
        if (reFindNoCase("^https?://(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)", targetUrl)) {
            return {"result": "Error: Requests to internal/private addresses are not allowed."};
        }

        try {
            var httpService = new http(
                method = method,
                url = targetUrl,
                timeout = 30,
                redirect = true,
                userAgent = "CFML-AI-Agent/1.0"
            );

            var httpResult = httpService.send().getPrefix();
            var statusCode = httpResult.statusCode;
            var body = httpResult.fileContent ?: "";

            // Truncate long responses
            var maxLen = 5000;
            if (isSimpleValue(body) && len(body) > maxLen) {
                body = left(body, maxLen) & "... [truncated, #len(httpResult.fileContent)# total characters]";
            }

            // Strip HTML tags for readability if it looks like HTML
            if (isSimpleValue(body) && reFindNoCase("<html|<body|<div|<p>", body)) {
                body = stripHTML(body);
                if (len(body) > maxLen) {
                    body = left(body, maxLen) & "... [truncated]";
                }
            }

            return {
                "result": "HTTP #statusCode##chr(10)##body#"
            };

        } catch (any e) {
            return {
                "result": "HTTP request failed: #e.message#"
            };
        }
    }

    /**
     * Strip HTML tags and collapse whitespace for readability.
     */
    private string function stripHTML(required string html) {
        // Remove script and style blocks
        var clean = reReplaceNoCase(arguments.html, "<(script|style)[^>]*>.*?</\1>", "", "all");
        // Remove tags
        clean = reReplace(clean, "<[^>]+>", " ", "all");
        // Decode entities
        clean = replaceList(clean, "&amp;,&lt;,&gt;,&nbsp;,&quot;", "&,<,>,  ,"" ");
        // Collapse whitespace
        clean = reReplace(clean, "\s+", " ", "all");
        return trim(clean);
    }

}
